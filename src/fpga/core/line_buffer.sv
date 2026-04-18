// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev


//------------------------------------------------------------------------------
// Line Buffer with Pipelined Pre-fetch and Synchronized Swapping
// Optimized for M10K inference and reduced ALM usage.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module line_buffer #(
  parameter int unsigned LineWidth  = 640,
  parameter int unsigned PixelWidth = 32,
  parameter int unsigned BusWidth   = 128
) (
  // System Domain (SDRAM)
  input  logic                  clk_sys_i,
  input  logic                  rst_sys_ni,
  
  input  logic                  sys_start_fetch_i,
  input  logic [31:0]           sys_base_addr_i,
  output logic                  sys_fetch_done_o,
  
  output logic                  sys_rd_req_o,
  output logic [31:0]           sys_rd_addr_o,
  input  logic                  sys_rd_ready_i,
  input  logic [BusWidth-1:0]   sys_rdata_i,
  input  logic                  sys_rdata_valid_i,

  // Pixel Domain (Video Output)
  input  logic                  clk_pix_i,
  input  logic                  rst_pix_ni,
  input  logic                  pix_swap_buffers_i,
  input  logic                  pix_en_i,
  output logic [PixelWidth-1:0] pix_data_o
);

  localparam int unsigned PixelsPerWord = BusWidth / PixelWidth;
  localparam int unsigned WordsPerLine  = (LineWidth + PixelsPerWord - 1) / PixelsPerWord;
  localparam int unsigned AddrWidth     = $clog2(WordsPerLine);
  localparam int unsigned PixAddrWidth  = $clog2(LineWidth);
  localparam int unsigned PixWordWidth  = $clog2(PixelsPerWord);

  (* ramstyle = "M10K" *) logic [BusWidth-1:0] buffer_a [WordsPerLine];
  (* ramstyle = "M10K" *) logic [BusWidth-1:0] buffer_b [WordsPerLine];

  typedef enum logic [1:0] { ST_SYS_IDLE, ST_SYS_FETCH, ST_SYS_WAIT } sys_state_e;
  sys_state_e sys_state_q /* verilator public */, sys_state_d;
  logic [AddrWidth:0] sys_req_cnt_q, sys_req_cnt_d;
  logic [AddrWidth:0] sys_rcv_cnt_q /* verilator public */, sys_rcv_cnt_d;
  logic [31:0]        sys_addr_q, sys_addr_d;
  logic               sys_write_buf_sel_q;

  assign sys_rd_req_o  = (sys_state_q == ST_SYS_FETCH);
  assign sys_rd_addr_o = sys_addr_q;

  always_comb begin
    sys_state_d   = sys_state_q;
    sys_req_cnt_d = sys_req_cnt_q;
    sys_addr_d    = sys_addr_q;
    
    case (sys_state_q)
      ST_SYS_IDLE: begin
        if (sys_start_fetch_i) begin
          sys_state_d   = ST_SYS_FETCH;
          sys_req_cnt_d = '0;
          sys_addr_d    = sys_base_addr_i;
        end
      end
      
      ST_SYS_FETCH: begin
        if (sys_rd_ready_i) begin
          sys_addr_d    = sys_addr_q + 32'(BusWidth / 16);
          sys_req_cnt_d = sys_req_cnt_q + 1'b1;
          if (sys_req_cnt_q == (AddrWidth + 1)'(WordsPerLine - 1)) begin
            sys_state_d = ST_SYS_WAIT;
          end
        end
      end

      ST_SYS_WAIT: begin
        if (sys_rcv_cnt_q == (AddrWidth + 1)'(WordsPerLine)) begin
          sys_state_d = ST_SYS_IDLE;
        end
      end
      
      default: sys_state_d = ST_SYS_IDLE;
    endcase
  end

  always_ff @(posedge clk_sys_i or negedge rst_sys_ni) begin
    if (!rst_sys_ni) begin
      sys_state_q         <= ST_SYS_IDLE;
      sys_req_cnt_q       <= '0;
      sys_rcv_cnt_q       <= '0;
      sys_addr_q          <= '0;
      sys_write_buf_sel_q <= 1'b0;
      sys_fetch_done_o    <= 1'b0;
    end else begin
      sys_state_q   <= sys_state_d;
      sys_req_cnt_q <= sys_req_cnt_d;
      sys_addr_q    <= sys_addr_d;
      sys_fetch_done_o <= 1'b0;
      
      if (sys_state_q == ST_SYS_IDLE && sys_start_fetch_i) begin
        sys_rcv_cnt_q       <= '0;
        sys_write_buf_sel_q <= ~sys_write_buf_sel_q;
      end else if (sys_rdata_valid_i) begin
        if (sys_write_buf_sel_q == 1'b0) buffer_a[sys_rcv_cnt_q[AddrWidth-1:0]] <= sys_rdata_i;
        else                            buffer_b[sys_rcv_cnt_q[AddrWidth-1:0]] <= sys_rdata_i;
        sys_rcv_cnt_q <= sys_rcv_cnt_q + 1'b1;
      end

      if (sys_state_q == ST_SYS_WAIT && sys_state_d == ST_SYS_IDLE) begin
        sys_fetch_done_o <= 1'b1;
      end
    end
  end

  // Pixel Domain Logic
  logic [PixAddrWidth:0] pix_read_ptr_q;
  logic                  pix_read_buf_sel_q;
  
  logic [AddrWidth-1:0]  pix_word_addr;
  assign pix_word_addr = pix_read_ptr_q[PixAddrWidth-1:PixWordWidth];

  logic [AddrWidth-1:0]  pix_next_word_addr;
  assign pix_next_word_addr = (pix_read_ptr_q[PixAddrWidth-1:0] + PixAddrWidth'(PixelsPerWord)) >> PixWordWidth;

  logic [AddrWidth-1:0]  ram_rd_addr;
  always_comb begin
    if (pix_swap_buffers_i) begin
      ram_rd_addr = '0;
    end else if (pix_en_i && (pix_read_ptr_q[PixWordWidth-1:0] == {PixWordWidth{1'b1}})) begin
      // When at the last pixel of the current word, fetch the next one.
      // This compensates for the 1-cycle RAM latency.
      ram_rd_addr = pix_next_word_addr;
    end else begin
      ram_rd_addr = pix_word_addr;
    end
  end

  logic [BusWidth-1:0] pix_word_a, pix_word_b, pix_word_q;
  
  // Mandatory registered read for M10K inference.
  // No reset on pix_word_a/b to allow mapping to RAM internal registers.
  always_ff @(posedge clk_pix_i) begin
    pix_word_a <= buffer_a[ram_rd_addr];
    pix_word_b <= buffer_b[ram_rd_addr];
  end
  
  assign pix_word_q = (pix_read_buf_sel_q == 1'b0) ? pix_word_a : pix_word_b;

  always_ff @(posedge clk_pix_i or negedge rst_pix_ni) begin
    if (!rst_pix_ni) begin
      pix_read_ptr_q     <= '0;
      pix_read_buf_sel_q <= 1'b0;
    end else begin
      if (pix_swap_buffers_i) begin
        pix_read_buf_sel_q <= ~pix_read_buf_sel_q;
        pix_read_ptr_q     <= '0;
      end else if (pix_en_i) begin
        if (pix_read_ptr_q < PixAddrWidth'(LineWidth - 1)) begin
          pix_read_ptr_q <= pix_read_ptr_q + 1'b1;
        end
      end
    end
  end

  assign pix_data_o = pix_word_q[pix_read_ptr_q[PixWordWidth-1:0] * PixelWidth +: PixelWidth];

endmodule

// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

`timescale 1ns / 1ps

`include "sdram_pkg.sv"

module sdram_arbiter_cdc #(
  parameter int unsigned NumPorts      = 3,
  parameter int unsigned AddrWidth     = 25,
  parameter int unsigned MaxDataWidth  = 128, 
  parameter int unsigned QueueDepth    = 16,
  parameter logic [AddrWidth-1:0] SegmentSize = 25'h080_0000
) (
  // --- Client Clock Domain ---
  input  logic                      clk_port_i,
  input  logic                      rst_port_ni,

  // --- SDRAM Controller Clock Domain ---
  input  logic                      clk_sdram_i,
  input  logic                      rst_sdram_ni,

  // --- Virtual Client Ports (Synchronous to clk_port_i) ---
  input  logic [NumPorts-1:0]                 port_wr_req_i,
  input  logic [NumPorts-1:0]                 port_rd_req_i,
  input  logic [NumPorts-1:0][AddrWidth-1:0]  port_addr_i,
  input  logic [NumPorts-1:0][MaxDataWidth-1:0]port_wdata_i,
  input  logic [NumPorts-1:0][15:0]           port_byte_en_i,
  output logic [NumPorts-1:0][MaxDataWidth-1:0]port_rdata_o,
  output logic [NumPorts-1:0]                 port_available_o,
  output logic [NumPorts-1:0]                 port_ready_o, 
  output logic [NumPorts-1:0]                 port_rvalid_o,

  // --- Single Physical SDRAM Interface (Synchronous to clk_sdram_i) ---
  output logic [AddrWidth-1:0]                sdram_addr_o,
  output logic [MaxDataWidth-1:0]             sdram_data_o,
  output logic [15:0]                         sdram_byte_en_o,
  output logic [3:0]                          sdram_burst_len_o,
  output logic                                sdram_wr_req_o,
  output logic                                sdram_rd_req_o,
  input  logic                                sdram_available_i,
  input  logic                                sdram_ready_i,
  input  logic [MaxDataWidth-1:0]             sdram_rdata_i,

  // Profiling
  output logic [31:0]                         total_completed_o
);

  import sdram_pkg::*;

  localparam int PortIdWidth = (NumPorts > 1) ? $clog2(NumPorts) : 1;

  typedef struct packed {
    logic [AddrWidth-1:0]    addr;
    logic [MaxDataWidth-1:0] data;
    logic [15:0]             byte_en;
    logic [3:0]              burst_len;
    logic                    write;
    logic [PortIdWidth-1:0]  port_id;
  } req_cdc_t;

  //----------------------------------------------------------------------------
  // 1. Client-Side Arbiter (Synchronous to clk_port_i)
  //----------------------------------------------------------------------------
  
  logic [NumPorts-1:0] q_empty, q_pop;
  req_cdc_t [NumPorts-1:0] q_dout;
  logic [NumPorts-1:0] q_full;

  typedef struct packed {
    logic [AddrWidth-1:0]    addr;
    logic [MaxDataWidth-1:0] data;
    logic [15:0]             byte_en;
    logic                    write;
  } client_req_t;

  genvar i;
  generate
    for (i = 0; i < NumPorts; i++) begin : gen_port_sync
      client_req_t din;
      assign din = '{
        addr:    port_addr_i[i], 
        data:    port_wdata_i[i], 
        byte_en: port_byte_en_i[i], 
        write:   port_wr_req_i[i]
      };

      client_req_t dout_raw;

      fifo #(.Width($bits(client_req_t)), .Depth(QueueDepth)) u_fifo (
        .clk_i(clk_port_i), .rst_ni(rst_port_ni), .flush_i(1'b0),
        .full_o(q_full[i]), .empty_o(q_empty[i]),
        .usage_o(), .data_i(din), .push_i((port_wr_req_i[i] || port_rd_req_i[i]) && !q_full[i]),
        .data_o(dout_raw),
        .pop_i(q_pop[i])
      );

      assign q_dout[i] = '{
        addr:      dout_raw.addr,
        data:      dout_raw.data,
        byte_en:   dout_raw.byte_en,
        burst_len: 4'(sdram_pkg::PORT_WIDTHS[i] / 16),
        write:     dout_raw.write,
        port_id:   PortIdWidth'(i)
      };
      
      assign port_available_o[i] = !q_full[i];
    end
  endgenerate

  logic [PortIdWidth-1:0] rr_ptr_q, rr_ptr_d;
  req_cdc_t arb_req;
  logic arb_valid;
  logic cmd_fifo_full;

  always_comb begin
    rr_ptr_d = rr_ptr_q;
    arb_req = '0;
    arb_valid = 1'b0;
    q_pop = '0;

    for (int j = 0; j < NumPorts; j++) begin
      logic [PortIdWidth-1:0] p_idx;
      // Quartus-friendly modulo arithmetic
      p_idx = PortIdWidth'((int'(rr_ptr_q) + j) % NumPorts);
      if (!q_empty[p_idx]) begin
        arb_req = q_dout[p_idx];
        arb_valid = 1'b1;
        if (!cmd_fifo_full) begin
          q_pop[p_idx] = 1'b1;
          rr_ptr_d = PortIdWidth'((int'(p_idx) + 1) % NumPorts);
        end
        break;
      end
    end
  end

  always_ff @(posedge clk_port_i or negedge rst_port_ni) begin
    if (!rst_port_ni) rr_ptr_q <= '0;
    else rr_ptr_q <= rr_ptr_d;
  end

  //----------------------------------------------------------------------------
  // 2. Command CDC (Port Domain -> SDRAM Domain)
  //----------------------------------------------------------------------------
  logic cmd_fifo_empty;
  req_cdc_t cmd_fifo_dout;

  async_fifo #(.Width($bits(req_cdc_t)), .Depth(QueueDepth)) u_cmd_cdc (
    .wclk_i(clk_port_i), .wrst_ni(rst_port_ni),
    .wpush_i(arb_valid && !cmd_fifo_full), .wdata_i(arb_req), .wfull_o(cmd_fifo_full),
    .rclk_i (clk_sdram_i), .rrst_ni(rst_sdram_ni),
    .rpop_i (sdram_ready_i && !cmd_fifo_empty), .rdata_o(cmd_fifo_dout), .rempty_o(cmd_fifo_empty)
  );

  // Controller side driving
  assign sdram_wr_req_o    = !cmd_fifo_empty && cmd_fifo_dout.write;
  assign sdram_rd_req_o    = !cmd_fifo_empty && !cmd_fifo_dout.write;
  assign sdram_addr_o      = (AddrWidth'(cmd_fifo_dout.port_id) * SegmentSize) + cmd_fifo_dout.addr;
  assign sdram_data_o      = cmd_fifo_dout.data;
  assign sdram_byte_en_o   = cmd_fifo_dout.byte_en;
  assign sdram_burst_len_o = cmd_fifo_dout.burst_len;

  //----------------------------------------------------------------------------
  // 3. Response CDC (SDRAM Domain -> Port Domain)
  //----------------------------------------------------------------------------
  
  typedef struct packed {
    logic [MaxDataWidth-1:0] data;
    logic [PortIdWidth-1:0]  port_id;
    logic                    is_write;
  } resp_cdc_t;
  
  logic resp_fifo_full, resp_fifo_empty;
  resp_cdc_t resp_fifo_din, resp_fifo_dout;

  assign resp_fifo_din = '{
    data:     sdram_rdata_i, 
    port_id:  cmd_fifo_dout.port_id, 
    is_write: cmd_fifo_dout.write
  };

  async_fifo #(.Width($bits(resp_cdc_t)), .Depth(QueueDepth)) u_resp_cdc (
    .wclk_i(clk_sdram_i), .wrst_ni(rst_sdram_ni),
    .wpush_i(sdram_ready_i && !resp_fifo_full), .wdata_i(resp_fifo_din), .wfull_o(resp_fifo_full),
    .rclk_i (clk_port_i), .rrst_ni(rst_port_ni),
    .rpop_i (!resp_fifo_empty), .rdata_o(resp_fifo_dout), .rempty_o(resp_fifo_empty)
  );

  // Distribute responses back to client domain ports
  always_comb begin
    port_ready_o = '0;
    port_rvalid_o = '0;
    port_rdata_o = '0;
    if (!resp_fifo_empty) begin
      port_ready_o[resp_fifo_dout.port_id] = 1'b1;
      if (!resp_fifo_dout.is_write) begin
        port_rvalid_o[resp_fifo_dout.port_id] = 1'b1;
        port_rdata_o[resp_fifo_dout.port_id] = resp_fifo_dout.data;
      end
    end
  end

  logic [31:0] completed_q;
  always_ff @(posedge clk_sdram_i or negedge rst_sdram_ni) begin
    if (!rst_sdram_ni) completed_q <= '0;
    else if (sdram_ready_i) completed_q <= completed_q + 1;
  end
  assign total_completed_o = completed_q;

endmodule

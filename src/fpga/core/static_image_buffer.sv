// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

//------------------------------------------------------------------------------
// Static Image Buffer IP - Bit-Accurate Production Version
// Fetches a static image from SDRAM and displays it via standard video timing.
// Optimized for raw 32-bit (XRGB) pixel assets.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module static_image_buffer #(
  parameter int unsigned LineWidth   = 640,
  parameter int unsigned NumLines    = 480,
  parameter int unsigned PixelWidth  = 32,
  parameter int unsigned BusWidth    = 128,
  
  // Default Timings (VGA 640x480 @ 60Hz approx at 25MHz)
  parameter int unsigned HFrontPorch = 16,
  parameter int unsigned HSyncPulse  = 96,
  parameter int unsigned HBackPorch  = 48,
  parameter int unsigned VFrontPorch = 10,
  parameter int unsigned VSyncPulse  = 2,
  parameter int unsigned VBackPorch  = 33
) (
  // System Domain (SDRAM Arbiter)
  input  logic                  clk_sys_i,
  input  logic                  rst_sys_ni,
  
  input  logic [31:0]           base_addr_i,
  
  output logic                  sdram_req_o,
  output logic [31:0]           sdram_addr_o,
  input  logic                  sdram_ready_i,
  input  logic [BusWidth-1:0]   sys_rdata_i,
  input  logic                  sdram_rdata_valid_i,
  input  logic                  init_done_i,

  // Pixel Interface (Video Output)
  input  logic                  clk_pix_i,
  input  logic                  rst_pix_ni,
  input  logic                  clk_pix_en_i,
  input  logic                  sync_rst_i,
  
  output logic                  hsync_o,
  output logic                  vsync_o,
  output logic                  hblank_o,
  output logic                  vblank_o,
  output logic [9:0]            h_cnt_o,
  output logic [9:0]            v_cnt_o,
  output logic [PixelWidth-1:0] pix_data_o,
  output logic                  pix_valid_o,
  output logic                  frame_sync_o
);

  localparam int unsigned HTotal = LineWidth + HFrontPorch + HSyncPulse + HBackPorch;
  localparam int unsigned VTotal = NumLines + VFrontPorch + VSyncPulse + VBackPorch;
  
  localparam int unsigned HCountWidth = $clog2(HTotal);
  localparam int unsigned VCountWidth = $clog2(VTotal);

  //----------------------------------------------------------------------------
  // Timing Generator
  //----------------------------------------------------------------------------
  logic [HCountWidth-1:0] h_count_q, h_count_d;
  logic [VCountWidth-1:0] v_count_q, v_count_d;

  always_comb begin
    h_count_d = h_count_q;
    v_count_d = v_count_q;
    
    h_count_d = (h_count_q == HCountWidth'(HTotal - 1)) ? '0 : h_count_q + 1'b1;
    if (h_count_q == HCountWidth'(HTotal - 1)) begin
      v_count_d = (v_count_q == VCountWidth'(VTotal - 1)) ? '0 : v_count_q + 1'b1;
    end
  end

  always_ff @(posedge clk_pix_i or negedge rst_pix_ni) begin
    if (!rst_pix_ni) begin
      h_count_q <= '0;
      v_count_q <= VCountWidth'(VTotal - 2); // Pre-roll 2 lines for scaler latency
    end else if (sync_rst_i) begin
      h_count_q <= '0;
      v_count_q <= VCountWidth'(VTotal - 2); 
    end else if (clk_pix_en_i) begin
      h_count_q <= h_count_d;
      v_count_q <= v_count_d;
    end
  end

  assign h_cnt_o = h_count_q;
  assign v_cnt_o = v_count_q;

  assign hsync_o  = ~((h_count_q >= HCountWidth'(LineWidth + HFrontPorch)) && (h_count_q < HCountWidth'(LineWidth + HFrontPorch + HSyncPulse)));
  assign vsync_o  = ~((v_count_q >= VCountWidth'(NumLines + VFrontPorch)) && (v_count_q < VCountWidth'(NumLines + VFrontPorch + VSyncPulse)));
  assign hblank_o = (h_count_q >= HCountWidth'(LineWidth));
  assign vblank_o = (v_count_q >= VCountWidth'(NumLines));

  wire active_video = (h_count_q < HCountWidth'(LineWidth)) && (v_count_q < VCountWidth'(NumLines));
  assign pix_valid_o = active_video;

  //----------------------------------------------------------------------------
  // Line Buffer Control
  //----------------------------------------------------------------------------
  logic hsync_start;
  assign hsync_start = (h_count_q == HCountWidth'(LineWidth + HFrontPorch));

  logic pix_swap_buffers;
  assign pix_swap_buffers = hsync_start && (v_count_q < VCountWidth'(NumLines - 1) || v_count_q == VCountWidth'(VTotal - 1));

  // One-shot fetch trigger per line
  logic                   line_triggered_q;
  logic [VCountWidth-1:0] pix_y_to_fetch_q;
  logic                   fetch_toggle_pix_q;

  always_ff @(posedge clk_pix_i or negedge rst_pix_ni) begin
    if (!rst_pix_ni) begin
      line_triggered_q   <= 1'b0;
      pix_y_to_fetch_q   <= '0;
      fetch_toggle_pix_q <= 1'b0;
      frame_sync_o       <= 1'b0;
    end else if (sync_rst_i) begin
      line_triggered_q   <= 1'b0;
      pix_y_to_fetch_q   <= '0;
      fetch_toggle_pix_q <= 1'b0;
      frame_sync_o       <= 1'b0;
    end else if (clk_pix_en_i) begin
      frame_sync_o <= 1'b0;
      if (h_count_q == 0) begin
        line_triggered_q <= 1'b0;
      end else if (!line_triggered_q && init_done_sync_q && (fetch_toggle_pix_q == fetch_ack_sync_q)) begin
        if (v_count_q == VCountWidth'(VTotal - 1)) begin
          line_triggered_q   <= 1'b1;
          pix_y_to_fetch_q   <= '0;
          fetch_toggle_pix_q <= ~fetch_toggle_pix_q;
          frame_sync_o       <= 1'b1; // Sync core to backdrop start
        end else if (v_count_q < VCountWidth'(NumLines - 1)) begin
          line_triggered_q   <= 1'b1;
          pix_y_to_fetch_q   <= v_count_q + 1'b1;
          fetch_toggle_pix_q <= ~fetch_toggle_pix_q;
        end
      end
    end
  end

  logic fetch_toggle_sys_m, fetch_toggle_sys_q, fetch_toggle_sys_q_delay;
  logic [31:0] base_addr_sys_m, base_addr_sys_q;
  logic        init_done_sys_m, init_done_sys_q;
  logic        fetch_ack_sync_m, fetch_ack_sync_q;
  logic        init_done_sync_m, init_done_sync_q;
  
  // Handshake feedback from sys domain
  logic        fetch_ack_sys_q;

  always_ff @(posedge clk_pix_i or negedge rst_pix_ni) begin
    if (!rst_pix_ni) begin
      fetch_ack_sync_m <= 1'b0; fetch_ack_sync_q <= 1'b0;
      init_done_sync_m <= 1'b0; init_done_sync_q <= 1'b0;
    end else begin
      fetch_ack_sync_m <= fetch_ack_sys_q;
      fetch_ack_sync_q <= fetch_ack_sync_m;
      init_done_sync_m <= init_done_i;
      init_done_sync_q <= init_done_sync_m;
    end
  end

  always_ff @(posedge clk_sys_i or negedge rst_sys_ni) begin
    if (!rst_sys_ni) begin
      fetch_toggle_sys_m       <= 1'b0;
      fetch_toggle_sys_q       <= 1'b0;
      fetch_toggle_sys_q_delay <= 1'b0;
      base_addr_sys_m          <= '0;
      base_addr_sys_q          <= '0;
      init_done_sys_m          <= 1'b0;
      init_done_sys_q          <= 1'b0;
      fetch_ack_sys_q          <= 1'b0;
    end else begin
      fetch_toggle_sys_m       <= fetch_toggle_pix_q;
      fetch_toggle_sys_q       <= fetch_toggle_sys_m;
      fetch_toggle_sys_q_delay <= fetch_toggle_sys_q;
      base_addr_sys_m          <= base_addr_i;
      base_addr_sys_q          <= base_addr_sys_m;
      init_done_sys_m          <= init_done_i;
      init_done_sys_q          <= init_done_sys_m;
      
      if (sys_fetch_done) begin
        fetch_ack_sys_q <= ~fetch_ack_sys_q;
      end
    end
  end

  logic sys_start_fetch;
  assign sys_start_fetch = (fetch_toggle_sys_q != fetch_toggle_sys_q_delay) && init_done_sys_q;

  logic sys_fetch_done;
  logic [31:0] sys_current_fetch_addr;
  assign sys_current_fetch_addr = base_addr_sys_q + 32'(pix_y_to_fetch_q) * 32'((LineWidth * PixelWidth) / 16);

  line_buffer #(
    .LineWidth  (LineWidth),
    .PixelWidth (PixelWidth),
    .BusWidth   (BusWidth)
  ) u_line_buffer (
    .clk_sys_i          (clk_sys_i),
    .rst_sys_ni         (rst_sys_ni),
    .sys_start_fetch_i  (sys_start_fetch),
    .sys_base_addr_i    (sys_current_fetch_addr),
    .sys_fetch_done_o   (sys_fetch_done),
    .sys_rd_req_o       (sdram_req_o),
    .sys_rd_addr_o      (sdram_addr_o),
    .sys_rd_ready_i     (sdram_ready_i),
    .sys_rdata_i        (sys_rdata_i),
    .sys_rdata_valid_i  (sdram_rdata_valid_i),
    .clk_pix_i          (clk_pix_i),
    .rst_pix_ni         (rst_pix_ni),
    .pix_swap_buffers_i (pix_swap_buffers),
    .pix_en_i           (clk_pix_en_i && active_video),
    .pix_data_o         (pix_data_o)
  );

endmodule : static_image_buffer

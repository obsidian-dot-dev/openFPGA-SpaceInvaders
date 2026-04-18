// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Graphics Subsystem
// Integrates SDRAM background circuits, video scaling, and effects.

module invaders_graphics (
  input  logic        clk_i,            // 20MHz Client Clock
  input  logic        rst_ni,           // Global Reset
  
  input  logic        clk_sdram_i,      // 100MHz SDRAM Clock
  input  logic        rst_sdram_ni,     // SDRAM Reset
  
  // Core Video Input
  input  logic        core_video_i,
  input  logic [8:0]  core_h_cnt_i,
  input  logic [8:0]  core_v_cnt_i,
  input  logic        core_hblank_i,
  input  logic        core_vblank_i,
  input  logic        vclk_5mhz_i,
  
  // Background Loading Port (from data_loader)
  input  logic        load_bg_en_i,
  input  logic [24:0] load_bg_addr_i,
  input  logic [15:0] load_bg_data_i,
  input  logic        loading_done_i,
  
  // Physical SDRAM Interface
  output logic [24:0]  sdram_addr_o,
  output logic [127:0] sdram_data_o,
  output logic [15:0]  sdram_byte_en_o,
  output logic [3:0]   sdram_burst_len_o,
  output logic         sdram_wr_req_o,
  output logic         sdram_rd_req_o,
  input  logic         sdram_available_i,
  input  logic         sdram_ready_i,
  input  logic [127:0] sdram_rdata_i,
  
  // Mirror Backdrop Emulation Enabled
  input  logic 		  backdrop_en_i,
  
  // Final Video Output
  input  logic [2:0]  scanline_strength_i,
  output logic [23:0] video_rgb_o,
  output logic        hsync_o,
  output logic        vsync_o,
  output logic        hblank_o,
  output logic        vblank_o,
  
  // Internal Timing (Optional expose)
  output logic [9:0]  bg_h_cnt_o,
  output logic [9:0]  bg_v_cnt_o
);

  import invaders_pkg::*;

  // -------------------------------------------------------------------------
  // SDRAM Loading Aggregator
  // -------------------------------------------------------------------------
  wire [24:0]  agg_addr;
  wire [127:0] agg_data;
  wire [15:0]  agg_be;
  wire         agg_wr;
  
  wire [24:0] loader_word_addr = load_bg_addr_i >> 1;

  sdram_aggregator u_agg (
    .clk_i       (clk_sdram_i),
    .rst_ni      (rst_sdram_ni),
    .in_wr_i     (load_bg_en_i && !loading_done_i),
    .in_addr_i   (loader_word_addr),
    .in_data_i   (load_bg_data_i),
    .in_ack_o    (),
    
    .out_wr_o    (agg_wr),
    .out_addr_o  (agg_addr),
    .out_wdata_o (agg_data),
    .out_be_o    (agg_be),
    .out_ready_i (sdram_ready_i)
  );

  // -------------------------------------------------------------------------
  // SDRAM Arbiter (CDC)
  // -------------------------------------------------------------------------
  wire [2:0]         port_wr_req;
  wire [2:0]         port_rd_req;
  wire [2:0][24:0]   port_addr;
  wire [2:0][127:0]  port_wdata;
  wire [2:0][127:0]  port_rdata;
  wire [2:0][15:0]   port_byte_en;
  wire [2:0]         port_available;
  wire [2:0]         port_ready;
  wire [2:0]         port_rvalid;

  // Mux between loader and arbiter for physical SDRAM access
  wire [24:0]  mux_addr   = !loading_done_i ? agg_addr : internal_sd_addr;
  wire [127:0] mux_wdata  = !loading_done_i ? agg_data : internal_sd_wdata;
  wire [15:0]  mux_be     = !loading_done_i ? agg_be   : internal_sd_be;
  wire [3:0]   mux_burst  = !loading_done_i ? 4'd8     : internal_sd_burst;
  wire         mux_wr_req = !loading_done_i ? agg_wr   : internal_sd_wr_req;
  wire         mux_rd_req = !loading_done_i ? 1'b0     : internal_sd_rd_req;

  wire mux_sd_available = !loading_done_i ? 1'b0 : sdram_available_i;
  wire mux_sd_ready     = !loading_done_i ? 1'b0 : sdram_ready_i;

  assign sdram_addr_o      = mux_addr;
  assign sdram_data_o      = mux_wdata;
  assign sdram_byte_en_o   = mux_be;
  assign sdram_burst_len_o = mux_burst;
  assign sdram_wr_req_o    = mux_wr_req;
  assign sdram_rd_req_o    = mux_rd_req;

  wire [24:0]  internal_sd_addr;
  wire [127:0] internal_sd_wdata;
  wire [15:0]  internal_sd_be;
  wire [3:0]   internal_sd_burst;
  wire         internal_sd_wr_req, internal_sd_rd_req;

  sdram_arbiter_cdc #(
    .NumPorts(3),
    .MaxDataWidth(128),
    .QueueDepth(16),
    .SegmentSize(0)
  ) u_arbiter (
    .clk_port_i(clk_i),
    .rst_port_ni(rst_ni),
    .clk_sdram_i(clk_sdram_i),
    .rst_sdram_ni(rst_sdram_ni),

    .port_wr_req_i(port_wr_req),
    .port_rd_req_i(port_rd_req),
    .port_addr_i(port_addr),
    .port_wdata_i(port_wdata),
    .port_byte_en_i(port_byte_en),
    .port_rdata_o(port_rdata),
    .port_available_o(port_available),
    .port_ready_o(port_ready),
    .port_rvalid_o(port_rvalid),

    .sdram_addr_o(internal_sd_addr),
    .sdram_data_o(internal_sd_wdata),
    .sdram_byte_en_o(internal_sd_be),
    .sdram_burst_len_o(internal_sd_burst),
    .sdram_wr_req_o(internal_sd_wr_req),
    .sdram_rd_req_o(internal_sd_rd_req),
    .sdram_available_i(mux_sd_available),
    .sdram_ready_i(mux_sd_ready),
    .sdram_rdata_i(sdram_rdata_i),

    .total_completed_o()
  );

  // -------------------------------------------------------------------------
  // Static Image Buffer (Backdrop)
  // -------------------------------------------------------------------------
  wire [31:0] pix_data;
  wire        pix_valid;
  wire        hsync_img, vsync_img, hblank_img, vblank_img;
  wire [9:0]  bg_h_cnt, bg_v_cnt;

  static_image_buffer #(
    .LineWidth(512),
    .NumLines(448),
    .PixelWidth(32),
    .BusWidth(128),
    .HFrontPorch(32),
    .HSyncPulse(64),
    .HBackPorch(32),
    .VFrontPorch(10),
    .VSyncPulse(2),
    .VBackPorch(61)
  ) img_buf (
    .clk_sys_i          (clk_i),
    .rst_sys_ni         (rst_ni),
    .base_addr_i        (32'h0),

    .sdram_req_o        (port_rd_req[1]),
    .sdram_addr_o       (port_addr[1]),
    .sdram_ready_i      (port_available[1]),
    .sys_rdata_i        (port_rdata[1]),
    .sdram_rdata_valid_i(port_rvalid[1]),
    .init_done_i        (loading_done_i),

    .clk_pix_i          (clk_i),
    .rst_pix_ni         (rst_ni),
    .clk_pix_en_i       (1'b1),
    .sync_rst_i         (1'b0),

    .hsync_o            (hsync_img),
    .vsync_o            (vsync_img),
    .hblank_o           (hblank_img),
    .vblank_o           (vblank_img),
    .h_cnt_o            (bg_h_cnt),
    .v_cnt_o            (bg_v_cnt),
    .pix_data_o         (pix_data),
    .pix_valid_o        (pix_valid),
    .frame_sync_o       ()
  );

  assign port_wr_req[1] = 1'b0;
  assign port_wdata[1]  = '0;
  assign port_byte_en[1] = 16'hFFFF;

  // Tie off other arbiter ports
  assign port_wr_req[0] = 1'b0;
  assign port_rd_req[0] = 1'b0;
  assign port_addr[0]   = '0;
  assign port_wdata[0]  = '0;
  assign port_byte_en[0] = '0;

  assign port_wr_req[2] = 1'b0;
  assign port_rd_req[2] = 1'b0;
  assign port_addr[2]   = '0;
  assign port_wdata[2]  = '0;
  assign port_byte_en[2] = '0;

  // -------------------------------------------------------------------------
  // Gameplay Scaler (2x)
  // -------------------------------------------------------------------------
  logic video_2x;
  invaders_video_scaler u_scaler (
    .clk_i, .rst_ni,
    .vclk_5mhz_i (vclk_5mhz_i),
    .video_i     (core_video_i),
    .h_cnt_i     (core_h_cnt_i),
    .v_cnt_i     (core_v_cnt_i),
    .hblank_i    (core_hblank_i),
    .vblank_i    (core_vblank_i),
    .h_cnt_20mhz_i(bg_h_cnt),
    .v_cnt_20mhz_i(bg_v_cnt),
    .video_2x_o  (video_2x)
  );

  // -------------------------------------------------------------------------
  // Video Effects & Blending
  // -------------------------------------------------------------------------
  invaders_video_effects u_fx (
    .clk_i, .rst_ni,
    .backdrop_en_i(backdrop_en_i),
    .scanline_strength_i(scanline_strength_i),
    .video_i     (video_2x),
    .h_cnt_i     (bg_h_cnt), 
    .v_cnt_i     (bg_v_cnt),
    .hblank_i    (hblank_img),
    .vblank_i    (vblank_img),
    
    .bg_addr_o   (),
    .bg_idx_i    (8'h0),
    .pal_addr_o  (),
    .pal_rgb_i   (24'h0),
    
    // pix_data is 0xXXBBGGRR
    .bg_rgb_sdram_i({8'h0, pix_data[7:0], pix_data[15:8], pix_data[23:16]}), 
    .video_rgb_o (video_rgb_o)
  );

  assign hsync_o = hsync_img;
  assign vsync_o = vsync_img;
  assign hblank_o = hblank_img;
  assign vblank_o = vblank_img;
  assign bg_h_cnt_o = bg_h_cnt;
  assign bg_v_cnt_o = bg_v_cnt;

endmodule

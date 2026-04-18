// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders System Wrapper
// Integrates core, graphics subsystem, and scaling.

module invaders_system (
  input  logic        clk_i,            // 20MHz System Clock
  input  logic        rst_ni,           // Global Reset (Active Low)
  input  logic        sync_rst_i,       // Frame Sync Reset
  
  // Configuration
  input  logic [1:0]  dip_lives_i,
  input  logic        dip_bonus_life_i,
  input  logic        dip_coinage_i,
  input  logic        dip_cabinet_i,
  
  // Video Controls
  input  logic        backdrop_en_i,
  input  logic [2:0]  scanline_strength_i,
  
  // ROM Loading Port (from data_loader)
  input  logic        load_rom_en_i,
  input  logic [24:0] load_rom_addr_i,
  input  logic [7:0]  load_rom_data_i,
  
  // BG Loading Port (from data_loader)
  input  logic        load_bg_en_i,
  input  logic [24:0] load_bg_addr_i,
  input  logic [15:0] load_bg_data_i,
  
  // Global loading status
  input  logic        loading_done_i,
  
  // SDRAM Clock Domain (for background)
  input  logic        clk_sdram_i,
  input  logic        rst_sdram_ni,
  
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
  
  // External Inputs
  input  logic [7:0]  port0_i,
  input  logic [7:0]  port1_i,
  input  logic [7:0]  port2_i,
  
  // Outputs
  output logic [15:0] audio_sample_o,
  output logic        audio_strobe_o,
  
  output logic        vclk_o,
  output logic        hsync_o,
  output logic        vsync_o,
  output logic        hblank_o,
  output logic        vblank_o,
  output logic [23:0] video_rgb_o,
  
  // Status
  output logic [15:0] pc_o,

  // Exposed for simulator
  output logic [9:0]  h_cnt_o,
  output logic [9:0]  v_cnt_o
);

  import invaders_pkg::*;

  // Core signals
  logic video_pix;
  logic hs_raw, vs_raw, hb_raw, vb_raw;
  logic [8:0] h_cnt_core, v_cnt_core;
  logic vclk_5m;

  invaders_top u_core (
    .clk_i, .rst_ni,
    .sync_rst_i     (sync_rst_i),
    .dip_lives_i, .dip_bonus_life_i, .dip_coinage_i, .dip_cabinet_i,
    .load_addr_i    (load_rom_addr_i[18:0]), 
    .load_data_i    (load_rom_data_i), 
    .load_en_i      (load_rom_en_i),
    .port0_i, .port1_i, .port2_i,
    .port3_o(), .port5_o(), .watchdog_reset_o(),
    .audio_sample_o, .audio_strobe_o,
    .vclk_o(vclk_5m), .hsync_o(hs_raw), .vsync_o(vs_raw), .hblank_o(hb_raw), .vblank_o(vb_raw),
    .video_o(video_pix),
    .h_cnt_o(h_cnt_core), .v_cnt_o(v_cnt_core), .pc_o(pc_o)
  );

  // -------------------------------------------------------------------------
  // Graphics Subsystem (Handles SDRAM, Scaling, and Effects)
  // -------------------------------------------------------------------------
  invaders_graphics u_graphics (
    .clk_i, .rst_ni,
    .clk_sdram_i, .rst_sdram_ni,
    
    .core_video_i   (video_pix),
    .core_h_cnt_i   (h_cnt_core),
    .core_v_cnt_i   (v_cnt_core),
    .core_hblank_i  (hb_raw),
    .core_vblank_i  (vb_raw),
    .vclk_5mhz_i    (vclk_5m),
    
    .load_bg_en_i,
    .load_bg_addr_i,
    .load_bg_data_i,
    .loading_done_i,
    
    .sdram_addr_o,
    .sdram_data_o,
    .sdram_byte_en_o,
    .sdram_burst_len_o,
    .sdram_wr_req_o,
    .sdram_rd_req_o,
    .sdram_available_i,
    .sdram_ready_i,
    .sdram_rdata_i,
    
	 .backdrop_en_i, 
	 .scanline_strength_i(scanline_strength_i),
	 
    .video_rgb_o,
    .hsync_o,
    .vsync_o,
    .hblank_o,
    .vblank_o,
    
    .bg_h_cnt_o     (h_cnt_o),
    .bg_v_cnt_o     (v_cnt_o)
  );

  assign vclk_o  = clk_i;

endmodule

// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Top-level Module
// Integrates CPU, Memory, I/O, Video, and Interrupts

module invaders_top (
  input  logic        clk_i,            // 50MHz System Clock
  input  logic        rst_ni,
  input  logic        sync_rst_i,
  
  // DIP Switches
  input  logic [1:0]  dip_lives_i,      // 00=3, 01=4, 10=5, 11=6
  input  logic        dip_bonus_life_i, // 0=1500, 1=1000
  input  logic        dip_coinage_i,    // 0=ON, 1=OFF
  input  logic        dip_cabinet_i,    // 0=Upright, 1=Cocktail
  
  // Runtime Loading Port (Expanded to 19-bit for high assets)
  input  logic [18:0] load_addr_i,
  input  logic [7:0]  load_data_i,
  input  logic        load_en_i,
  
  // External Inputs
  input  logic [7:0]  port0_i,
  input  logic [7:0]  port1_i,
  input  logic [7:0]  port2_i,
  
  // External Outputs
  output logic [7:0]  port3_o,
  output logic [7:0]  port5_o,
  output logic        watchdog_reset_o,
  
  // Audio Output
  output logic [15:0] audio_sample_o,
  output logic        audio_strobe_o,
  
  // Video Output (Timing-based)
  output logic        vclk_o,
  output logic        hsync_o,
  output logic        vsync_o,
  output logic        hblank_o,
  output logic        vblank_o,
  output logic        video_o,
  output logic [8:0]  h_cnt_o,
  output logic [8:0]  v_cnt_o,
  output logic [15:0] pc_o
);

  import invaders_pkg::*;

  // -------------------------------------------------------------------------
  // 2MHz Logic Clock & Enable Generation (20MHz / 10)
  // -------------------------------------------------------------------------
  logic [3:0] logic_cnt_q;
  logic clk_2mhz_q;
  logic pulse_en_2mhz;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      logic_cnt_q <= 4'd0;
      clk_2mhz_q <= 1'b0;
      pulse_en_2mhz <= 1'b0;
    end else if (sync_rst_i) begin
      logic_cnt_q <= 4'd0;
      clk_2mhz_q <= 1'b0;
      pulse_en_2mhz <= 1'b0;
    end else begin
      if (logic_cnt_q == 4'd9) begin
        logic_cnt_q <= 4'd0;
        clk_2mhz_q <= 1'b1;
        pulse_en_2mhz <= 1'b1;
      end else begin
        logic_cnt_q <= logic_cnt_q + 4'd1;
        pulse_en_2mhz <= 1'b0;
        if (logic_cnt_q == 4'd4) begin
          clk_2mhz_q <= 1'b0;
        end
      end
    end
  end

  // -------------------------------------------------------------------------
  // Signals
  // -------------------------------------------------------------------------
  
  // CPU Signals
  logic [15:0] cpu_addr;
  logic [7:0]  cpu_data_in;
  logic [7:0]  cpu_data_out;
  logic        cpu_data_out_en;
  logic        cpu_wr_n;
  logic        cpu_dbin;
  logic        cpu_sync;
  logic [7:0]  cpu_status;
  logic        cpu_intr;
  logic        cpu_inte;
  
  // Bus / Memory Signals
  logic [15:0] mem_addr;
  logic [7:0]  mem_data_to_mem;
  logic [7:0]  mem_data_from_mem;
  logic        mem_wr_en;
  
  // Bus / I/O Signals
  logic [2:0]  io_port;
  logic [7:0]  io_data_to_io;
  logic [7:0]  io_data_from_io;
  logic        io_rd_en;
  logic        io_wr_en;
  
  // Video / Memory Signals
  logic [15:0] v_mem_addr;
  logic [7:0]  v_mem_data;
  
  // Interrupt Signals
  logic [7:0]  intr_vec;
  logic        is_inta;

  // -------------------------------------------------------------------------
  // Watchdog Timer
  // -------------------------------------------------------------------------
  logic [23:0] watchdog_cnt_q;
  logic        watchdog_timeout;
  
  always_ff @(posedge clk_2mhz_q or negedge rst_ni) begin
    if (!rst_ni) begin
      watchdog_cnt_q <= 24'd0;
    end else begin
      if (watchdog_reset_o || watchdog_timeout) begin
        watchdog_cnt_q <= 24'd0;
      end else begin
        watchdog_cnt_q <= watchdog_cnt_q + 1;
      end
    end
  end
  assign watchdog_timeout = (watchdog_cnt_q[23]); // ~4.19s at 2MHz (2^23 / 2e6)

  logic system_rst_n;
  assign system_rst_n = rst_ni && !watchdog_timeout;

  // -------------------------------------------------------------------------
  // CPU Core
  // -------------------------------------------------------------------------
  i8080 u_cpu (
    .clk        (clk_2mhz_q),
    .reset      (!system_rst_n),
    .addr       (cpu_addr),
    .data_in    (cpu_data_in),
    .data_out   (cpu_data_out),
    .data_out_en(cpu_data_out_en),
    .wr_n       (cpu_wr_n),
    .dbin       (cpu_dbin),
    .sync       (cpu_sync),
    .hold_a     (),
    .wait_a     (),
    .intr       (cpu_intr),
    .inte       (cpu_inte),
    .status_out (cpu_status),
    .pc_o       (pc_o)
  );

  // -------------------------------------------------------------------------
  // Bus Controller
  // -------------------------------------------------------------------------
  logic [7:0] io_data_muxed;
  assign io_data_muxed = is_inta ? intr_vec : io_data_from_io;

  invaders_bus u_bus (
    .clk_i         (clk_2mhz_q),
    .rst_ni        (system_rst_n),
    .cpu_addr_i    (cpu_addr),
    .cpu_data_out_i(cpu_data_out),
    .cpu_status_i  (cpu_status),
    .cpu_sync_i    (cpu_sync),
    .cpu_wr_n_i    (cpu_wr_n),
    .cpu_dbin_i    (cpu_dbin),
    .cpu_data_in_o (cpu_data_in),
    .mem_addr_o    (mem_addr),
    .mem_data_o    (mem_data_to_mem),
    .mem_wr_en_o   (mem_wr_en),
    .mem_data_i    (mem_data_from_mem),
    .io_port_o     (io_port),
    .io_data_o     (io_data_to_io),
    .io_rd_en_o    (io_rd_en),
    .io_wr_en_o    (io_wr_en),
    .io_data_i     (io_data_muxed),
    .inta_o        (is_inta)
  );
  
  // -------------------------------------------------------------------------
  // Memory (Multi-port)
  // -------------------------------------------------------------------------
  invaders_mem u_mem (
    .clk_i    (clk_i),
    .clk_en_i (pulse_en_2mhz),
    .addr_a_i (mem_addr),
    .data_a_i (mem_data_to_mem),
    .wr_a_en_i(mem_wr_en),
    .data_a_o (mem_data_from_mem),
    .addr_b_i (v_mem_addr),
    .data_b_o (v_mem_data),  
    .load_addr_i,
    .load_data_i,
    .load_en_i
  );

  // -------------------------------------------------------------------------
  // I/O Peripherals
  // -------------------------------------------------------------------------
  logic [7:0] port0_muxed, port2_muxed;
  assign port0_muxed = {dip_cabinet_i, port0_i[6:0]};
  assign port2_muxed = {dip_coinage_i, port2_i[6:4], dip_bonus_life_i, port2_i[2], dip_lives_i};

  invaders_io u_io (
    .clk_i           (clk_i),
    .clk_en_i        (pulse_en_2mhz),
    .rst_ni          (system_rst_n),
    .io_port_i       (io_port),
    .io_data_i       (io_data_to_io),
    .io_rd_en_i      (io_rd_en),
    .io_wr_en_i      (io_wr_en),
    .io_data_o       (io_data_from_io),
    .port0_i         (port0_muxed),
    .port1_i,
    .port2_i         (port2_muxed),
    .port3_o,
    .port5_o,
    .watchdog_reset_o
  );

  // -------------------------------------------------------------------------
  // Video Controller
  // -------------------------------------------------------------------------
  logic [8:0] v_scanline;
  invaders_video u_video (
    .clk_i         (clk_i),
    .rst_ni        (system_rst_n),
    .sync_rst_i    (sync_rst_i),
    .vram_addr_o   (v_mem_addr),
    .vram_data_i   (v_mem_data),
    .vclk_o        (vclk_o),
    .hsync_o       (hsync_o),
    .vsync_o       (vsync_o),
    .hblank_o      (hblank_o),
    .vblank_o      (vblank_o),
    .video_o       (video_o),
    .h_cnt_o       (h_cnt_o),
    .v_cnt_o       (v_cnt_o),
    .v_scanline_o  (v_scanline)
  );

  // -------------------------------------------------------------------------
  // Interrupt Controller
  // -------------------------------------------------------------------------
  invaders_int_ctrl u_int_ctrl (
    .clk_i       (clk_i),
    .clk_en_i    (pulse_en_2mhz),
    .rst_ni      (system_rst_n),
    .v_scanline_i(v_scanline),
    .intr_o      (cpu_intr),
    .inta_i      (is_inta),
    .dbin_i      (cpu_dbin),
    .intr_vec_o  (intr_vec)
  );

  // -------------------------------------------------------------------------
  // Audio Controller
  // -------------------------------------------------------------------------
  audio_top u_audio (
    .clk_i          (clk_i),
    .rst_ni         (system_rst_n),
    .port3_i        (port3_o),
    .port5_i        (port5_o),
    .audio_o        (audio_sample_o),
    .sample_strobe_o(audio_strobe_o)
  );

endmodule
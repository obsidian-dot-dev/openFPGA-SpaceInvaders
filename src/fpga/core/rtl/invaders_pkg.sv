// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Package
// Defines constants for the Space Invaders hardware

package invaders_pkg;

  // Clock frequencies
  // Master clock for the core (passed in)
  parameter real CLK_MASTER_MHZ = 50.0; 
  // Target CPU frequency: 2.0 MHz (50 / 25)
  // Target Pixel frequency: 5.0 MHz (50 / 10)

  // Memory Map
  // 0000-1FFF: ROM (8KB)
  // 2000-3FFF: RAM (8KB) - Mirrored every 8KB up to FFFF? 
  // Reference says memory map is 16-bit, but mirrored.
  // Actually:
  // 0000-1FFF: ROM
  // 2000-23FF: RAM
  // 2400-3FFF: Video RAM
  // 4000-FFFF: Mirrors of 0000-3FFF
  
  // Memory Map sizes as int
  parameter int ROM_SIZE = 8192;
  parameter int RAM_SIZE = 8192; 
  
  parameter logic [15:0] ROM_BASE = 16'h0000;
  parameter logic [15:0] RAM_BASE = 16'h2000;
  parameter logic [15:0] VRAM_BASE = 16'h2400;
  
  // High memory for effects (not reachable by 8080 directly)
  parameter logic [18:0] BACKDROP_BASE = 19'h40000; // 256KB offset
  parameter logic [18:0] PALETTE_BASE  = 19'h50000; // 320KB offset

  // I/O Ports (using localparam because IN and OUT ports overlap in value)
  localparam logic [2:0] PORT_IN0  = 3'd0; // Input 0
  localparam logic [2:0] PORT_IN1  = 3'd1; // Input 1
  localparam logic [2:0] PORT_IN2  = 3'd2; // Input 2
  localparam logic [2:0] PORT_IN3  = 3'd3; // Shift Register Result (Read)
  
  localparam logic [2:0] PORT_OUT2 = 3'd2; // Shift Amount (Write)
  localparam logic [2:0] PORT_OUT3 = 3'd3; // Sound Port 1 (Write)
  localparam logic [2:0] PORT_OUT4 = 3'd4; // Shift Data (Write)
  localparam logic [2:0] PORT_OUT5 = 3'd5; // Sound Port 2 (Write)
  localparam logic [2:0] PORT_OUT6 = 3'd6; // Watchdog (Write)

  // Video Constants
  localparam int VIDEO_WIDTH  = 256;
  localparam int VIDEO_HEIGHT = 224;
  
  // Timing Constants (based on 2MHz clock)
  localparam int CYCLES_PER_LINE = 128;
  localparam int VTOTAL = 262;
  localparam logic [8:0] IRQ_LINE_MID = 9'd96;
  localparam logic [8:0] IRQ_LINE_VBLANK = 9'd224;

  // Colors (RGB888)
  parameter logic [23:0] COLOR_WHITE = 24'hFFFFFF;
  parameter logic [23:0] COLOR_RED   = 24'hFF0000;
  parameter logic [23:0] COLOR_GREEN = 24'h00FF00;
  parameter logic [23:0] COLOR_BLUE  = 24'h0000FF;

  // Interrupt Vectors
  parameter logic [7:0] VEC_RST1 = 8'hCF;
  parameter logic [7:0] VEC_RST2 = 8'hD7;

endpackage : invaders_pkg

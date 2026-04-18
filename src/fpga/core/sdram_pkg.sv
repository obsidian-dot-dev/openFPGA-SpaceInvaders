// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

`timescale 1ns / 1ps

`ifndef SDRAM_PKG_SV
`define SDRAM_PKG_SV

package sdram_pkg;

  //----------------------------------------------------------------------------
  // SDRAM Physical Configuration
  //----------------------------------------------------------------------------
  localparam int SDRAM_ADDR_WIDTH    = 25;
  localparam int SDRAM_DATA_WIDTH    = 16;
  
  //----------------------------------------------------------------------------
  // Multi-Port Configuration (Full Heterogeneous Phase 4)
  //----------------------------------------------------------------------------
  localparam int NUM_PORTS           = 3;
  
  // Array defining the native data width of each port (in bits)
  typedef int port_widths_t [NUM_PORTS];
  localparam port_widths_t PORT_WIDTHS = '{128, 128, 128};

  // Max width for top-level interface ports
  localparam int MAX_PORT_WIDTH      = 128;

  // Configuration Constants
  localparam int QUEUE_DEPTH         = 16;
  localparam logic [SDRAM_ADDR_WIDTH-1:0] SEGMENT_SIZE = 25'h080_0000;
  localparam int CLOCK_SPEED_MHZ     = 100;
  
  localparam int CTRL_LATENCY_CYCLES = 8;

endpackage : sdram_pkg

`endif // SDRAM_PKG_SV

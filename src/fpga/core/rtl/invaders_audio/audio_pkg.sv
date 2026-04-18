// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

package audio_pkg;
  // Standard audio path width
  typedef logic signed [15:0] audio_t;
  
  // Phase accumulator for oscillators
  typedef logic [31:0] phase_t;

  // High-precision accumulator for filters
  typedef logic signed [63:0] accum_t;
  parameter int FRAC_BITS = 24;
  parameter int ACCUM_FRAC_BITS = 48;

  // Global constants (Master 20MHz clock)
  localparam int CLK_FREQ = 20000000;

endpackage

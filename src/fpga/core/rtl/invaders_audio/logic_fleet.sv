// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module logic_fleet (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic [3:0] fleet_data_i,
  output logic signed [15:0] audio_o
);
  import audio_pkg::*;

  logic enable;
  assign enable = (fleet_data_i != 0);

  logic [31:0] freq_inc;
  always_comb begin
    case (fleet_data_i)
      4'h1: freq_inc = 32'd13314; // 62.0 Hz @ 20MHz
      4'h2: freq_inc = 32'd12455; // 58.0 Hz
      4'h4: freq_inc = 32'd12240; // 57.0 Hz
      4'h8: freq_inc = 32'd11811; // 55.0 Hz
      default: freq_inc = 32'd13314;
    endcase
  end

  // Phase accumulator for the base timing
  logic [31:0] phase_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      phase_q <= '0;
    end else begin
      if (enable) phase_q <= phase_q + freq_inc;
      else        phase_q <= '0;
    end
  end

  // Asymmetric pulse (20% duty cycle)
  logic pulse_q;
  always_comb begin
    pulse_q = (phase_q < 32'h3333_3333);
  end

  // 48-bit precision DSP Filters (Relaxed from 64-bit for FPGA timing)
  logic signed [47:0] lpf1_q, lpf2_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lpf1_q <= '0;
      lpf2_q <= '0;
    end else begin
      if (enable) begin
        logic signed [47:0] x1;
        // Upscale binary pulse to 48-bit signed (+/- 16384 << 16)
        x1 = pulse_q ? (48'sh0000_4000_0000) : - (48'sh0000_4000_0000);
        
        // 2-pole LPF (~300Hz cutoff)
        lpf1_q <= lpf1_q + ((x1 - lpf1_q) >>> 13);
        lpf2_q <= lpf2_q + ((lpf1_q - lpf2_q) >>> 13);
      end else begin
        // Natural ring out
        lpf1_q <= lpf1_q - (lpf1_q >>> 13);
        lpf2_q <= lpf2_q - (lpf2_q >>> 13);
      end
    end
  end

  always_comb begin
    logic signed [31:0] filtered;
    filtered = 32'(lpf2_q >>> 16);
    // Saturating clamp prevents wrap-around distortion
    if ((filtered << 1) > 32767)      audio_o = 16'sd32767;
    else if ((filtered << 1) < -32768) audio_o = -16'sd32768;
    else                              audio_o = 16'(filtered << 1);
  end

endmodule

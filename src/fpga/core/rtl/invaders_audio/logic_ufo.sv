// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders UFO Flying Sound (Logic Based - SN76477 Recalibrated)
module logic_ufo (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic enable_i,
  output logic signed [15:0] audio_o
);
  import audio_pkg::*;

  // Parameters in Q16.32 fixed point for high precision at 20MHz
  // Range: SLF sweeps 0.33V to 2.37V. VCO uses (SLF + 0.35V) as charging ceiling.
  localparam logic [47:0] V_MIN = 48'h0000_547A_0000; // 0.33V
  localparam logic [47:0] V_MAX = 48'h0002_5EB8_0000; // 2.37V
  localparam logic [47:0] V_OFF = 48'h0000_5999_0000; // 0.35V
  
  // SLF: 6.0 Hz LFO (Half-cycle 1/12s = 1,666,666 cycles @ 20MHz)
  // Delta = 2.04V. Step = Delta / 1.66M = 1.224e-6 V/cycle
  // In Q16.32: 5257
  localparam logic [47:0] SLF_STEP = 48'd5257;

  // VCO: Calibrated for 450Hz - 2900Hz range
  // Fmax (2900Hz) happens when ceiling is lowest (0.35V above V_MIN)
  // Step = (2 * DeltaV * F) / Fclk = (2 * 0.35 * 2900) / 20M = 0.0001015 V/cycle
  // In Q16.32: 435924
  localparam logic [47:0] VCO_STEP = 48'd435924;

  logic [47:0] slf_v_q;
  logic        slf_dir_q;
  logic [47:0] vco_v_q;
  logic        vco_dir_q;
  logic        out_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      slf_v_q <= V_MIN;
      slf_dir_q <= 1'b1;
      vco_v_q <= V_MIN;
      vco_dir_q <= 1'b1;
      out_q <= 1'b0;
    end else begin
      if (enable_i) begin
        // 1. Update SLF (Triangle LFO)
        if (slf_dir_q) begin
          slf_v_q <= slf_v_q + SLF_STEP;
          if (slf_v_q >= V_MAX) slf_dir_q <= 1'b0;
        end else begin
          slf_v_q <= slf_v_q - SLF_STEP;
          if (slf_v_q <= V_MIN) slf_dir_q <= 1'b1;
        end

        // 2. Update VCO (Square Wave)
        if (vco_dir_q) begin
          vco_v_q <= vco_v_q + VCO_STEP;
          if (vco_v_q >= (slf_v_q + V_OFF)) begin
            vco_dir_q <= 1'b0;
            out_q <= 1'b1;
          end
        end else begin
          vco_v_q <= vco_v_q - VCO_STEP;
          if (vco_v_q <= V_MIN) begin
            vco_dir_q <= 1'b1;
            out_q <= 1'b0;
          end
        end
      end else begin
        // Reset state
        slf_v_q <= V_MIN;
        slf_dir_q <= 1'b1;
        vco_v_q <= V_MIN;
        vco_dir_q <= 1'b1;
        out_q <= 1'b0;
      end
    end
  end

  // Scale 1-bit square wave to full 16-bit range
  assign audio_o = enable_i ? (out_q ? 16'sd16384 : -16'sd16384) : 16'sd0;

endmodule

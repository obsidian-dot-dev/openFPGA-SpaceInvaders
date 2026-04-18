// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module logic_osc (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic [31:0] freq_inc_i,
  input  logic [31:0] duty_i, // Threshold for square wave (0.5 = 32'h8000_0000)
  input  logic [1:0]  type_i, // 0: Square, 1: Triangle, 2: Saw
  output logic signed [15:0] audio_o
);
  import audio_pkg::*;

  phase_t phase_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) phase_q <= '0;
    else phase_q <= phase_q + freq_inc_i;
  end

  logic [15:0] tri_raw;
  always_comb begin
    // Triangle: 0->MAX->0->MIN->0
    if (phase_q[31]) tri_raw = ~phase_q[30:15];
    else             tri_raw = phase_q[30:15];
  end

  always_comb begin
    case (type_i)
      2'd0: audio_o = (phase_q < duty_i) ? 16'sd16384 : -16'sd16384; // Standard bipolar
      2'd1: audio_o = 16'(tri_raw) - 16'sd32768;
      2'd2: audio_o = 16'(phase_q[31:16]);
      default: audio_o = '0;
    endcase
  end
endmodule

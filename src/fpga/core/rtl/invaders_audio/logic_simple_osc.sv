// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module logic_simple_osc (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic enable_i,
  input  logic [31:0] freq_inc_i,
  output logic signed [15:0] audio_o
);
  import audio_pkg::*;
  phase_t phase_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) phase_q <= '0;
    else if (enable_i) phase_q <= phase_q + freq_inc_i;
  end
  // 33% duty cycle (102/300)
  assign audio_o = enable_i ? ((phase_q < 32'h5555_5555) ? 16'sd16384 : -16'sd16384) : 16'sd0;
endmodule

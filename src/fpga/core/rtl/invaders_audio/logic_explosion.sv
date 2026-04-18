// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module logic_explosion (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic trigger_i,
  output logic signed [15:0] audio_o
);
  import audio_pkg::*;

  // Player Die Envelope: 107ms attack, ~600ms decay
  logic [15:0] amp;
  logic_env u_env (
    .clk_i, .rst_ni, .trigger_i,
    .attack_inc_i(32'd2007), 
    .decay_a_inc_i(32'd357), .decay_b_inc_i(32'd357), .decay_a_limit_i(32'd0),
    .amp_o(amp), .active_o()
  );

  logic signed [15:0] noise_raw;
  // 10kHz noise updates (20MHz / 2000 = 10kHz)
  // This produces a "gravelly" broadband noise rich in low frequencies.
  logic_noise_gen u_noise (.clk_i, .rst_ni, .freq_div_i(16'd2000), .audio_o(noise_raw));

  logic signed [31:0] lpf1_q, lpf2_q;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lpf1_q <= '0;
      lpf2_q <= '0;
    end else begin
      logic signed [31:0] x1;
      x1 = (int'(noise_raw) << 16);
      
      // 2-pole LPF at ~388 Hz.
      // alpha = 2 * pi * 388 / 20000000 = 0.000121
      // 1 / 8192 = 0.000122 -> Right shift 13.
      lpf1_q <= lpf1_q + ((x1 - lpf1_q) >>> 13);
      lpf2_q <= lpf2_q + ((lpf1_q - lpf2_q) >>> 13);
    end
  end

  always_comb begin
    logic signed [31:0] filtered_noise;
    filtered_noise = lpf2_q >>> 16;
    audio_o = 16'((filtered_noise * $signed({1'b0, amp})) >>> 16);
  end

endmodule

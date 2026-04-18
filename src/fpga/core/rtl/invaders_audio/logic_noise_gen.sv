// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module logic_noise_gen (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic [15:0] freq_div_i,
  output logic signed [15:0] audio_o
);
  logic [15:0] count_q;
  logic [16:0] lfsr_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      count_q <= '0;
      lfsr_q  <= 17'h1FFFF;
    end else begin
      if (count_q >= freq_div_i) begin
        count_q <= '0;
        lfsr_q <= {lfsr_q[15:0], lfsr_q[16] ^ lfsr_q[13]};
      end else begin
        count_q <= count_q + 1;
      end
    end
  end

  assign audio_o = lfsr_q[0] ? 16'sd16384 : -16'sd16384;
endmodule
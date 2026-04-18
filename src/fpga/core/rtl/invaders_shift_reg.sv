// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Shift Register (MB14241)
// Specialized hardware for fast sprite shifting

module invaders_shift_reg (
  input  logic        clk_i,
  input  logic        clk_en_i,
  input  logic        rst_ni,
  
  input  logic [7:0]  data_i,
  input  logic [2:0]  shift_amount_i,
  input  logic        load_data_i,
  input  logic        load_amount_i,
  
  output logic [7:0]  data_o
);

  logic [15:0] shift_reg_q;
  logic [2:0]  shift_count_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shift_reg_q   <= 16'h0000;
      shift_count_q <= 3'd0;
    end else if (clk_en_i) begin
      if (load_data_i) begin
        shift_reg_q <= {data_i, shift_reg_q[15:8]};
      end
      if (load_amount_i) begin
        shift_count_q <= shift_amount_i;
      end
    end
  end

  logic [15:0] shifted;
  assign shifted = shift_reg_q << shift_count_q;
  assign data_o = shifted[15:8];

endmodule
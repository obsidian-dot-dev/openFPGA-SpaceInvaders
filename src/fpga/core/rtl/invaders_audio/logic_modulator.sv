// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module logic_modulator (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic trigger_i,
  input  logic [31:0] start_inc_i,
  input  logic [31:0] end_inc_i,
  input  logic [31:0] sweep_step_i, // Amount to change per cycle (Q32.32 internally)
  output logic [31:0] current_inc_o,
  output logic        active_o
);
  import audio_pkg::*;

  // Use 64-bit internal for fractional steps (Q32.32)
  logic [63:0] current_q;
  logic        active_q;
  logic        down_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      current_q <= '0;
      active_q  <= 1'b0;
      down_q <= 1'b0;
    end else begin
      if (trigger_i) begin
        active_q  <= 1'b1;
        current_q <= {start_inc_i, 32'd0};
        down_q <= (start_inc_i > end_inc_i);
      end else if (active_q) begin
        if (down_q) begin
          if (current_q[63:32] <= end_inc_i || (current_q - sweep_step_i) > current_q) begin
            current_q <= {end_inc_i, 32'd0};
            active_q  <= 1'b0;
          end else begin
            current_q <= current_q - sweep_step_i;
          end
        end else begin
          if (current_q[63:32] >= end_inc_i || (current_q + sweep_step_i) < current_q) begin
            current_q <= {end_inc_i, 32'd0};
            active_q  <= 1'b0;
          end else begin
            current_q <= current_q + sweep_step_i;
          end
        end
      end
    end
  end

  assign current_inc_o = active_q ? current_q[63:32] : end_inc_i;
  assign active_o = active_q;

endmodule
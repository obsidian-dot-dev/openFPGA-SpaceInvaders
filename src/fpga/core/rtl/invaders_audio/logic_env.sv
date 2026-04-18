// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module logic_env (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic trigger_i,
  input  logic [31:0] attack_inc_i,
  input  logic [31:0] decay_a_inc_i,
  input  logic [31:0] decay_b_inc_i,
  input  logic [31:0] decay_a_limit_i, // Point at which to switch from A to B
  output logic [15:0] amp_o,
  output logic        active_o
);
  import audio_pkg::*;

  typedef enum logic [1:0] { IDLE, ATTACK, DECAY_A, DECAY_B } state_e;
  state_e state_q;
  
  logic [31:0] count_q;
  logic        prev_trig_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      count_q <= '0;
      prev_trig_q <= 1'b0;
    end else begin
      prev_trig_q <= trigger_i;
      
      case (state_q)
        IDLE: begin
          if (trigger_i && !prev_trig_q) begin
            state_q <= ATTACK;
          end
          count_q <= '0;
        end
        
        ATTACK: begin
          if (count_q >= (32'hFFFF_FFFF - attack_inc_i)) begin
            count_q <= 32'hFFFF_FFFF;
            state_q <= DECAY_A;
          end else begin
            count_q <= count_q + attack_inc_i;
          end
        end
        
        DECAY_A: begin
          if (count_q <= decay_a_limit_i) begin
            state_q <= DECAY_B;
          end else begin
            if (count_q <= decay_a_inc_i) begin
              count_q <= '0;
              state_q <= IDLE;
            end else begin
              count_q <= count_q - decay_a_inc_i;
            end
          end
          // Allow re-trigger
          if (trigger_i && !prev_trig_q) begin
            state_q <= ATTACK;
          end
        end

        DECAY_B: begin
          if (count_q <= decay_b_inc_i) begin
            count_q <= '0;
            state_q <= IDLE;
          end else begin
            count_q <= count_q - decay_b_inc_i;
          end
          // Allow re-trigger
          if (trigger_i && !prev_trig_q) begin
            state_q <= ATTACK;
          end
        end
      endcase
    end
  end

  assign amp_o = count_q[31:16];
  assign active_o = (state_q != IDLE);

endmodule

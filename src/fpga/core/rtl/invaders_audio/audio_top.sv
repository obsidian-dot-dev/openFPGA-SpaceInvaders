// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module audio_top (
  input  logic clk_i,      // 20MHz
  input  logic rst_ni,
  input  logic [7:0] port3_i,
  input  logic [7:0] port5_i,
  output logic signed [15:0] audio_o,
  output logic        sample_strobe_o
);
  import audio_pkg::*;

  // 1. Sample Strobe Logic (44.1kHz from 20MHz)
  logic [31:0] sample_acc_q;
  logic sample_strobe;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sample_acc_q <= 32'd0;
      sample_strobe <= 1'b0;
    end else begin
      {sample_strobe, sample_acc_q} <= {1'b0, sample_acc_q} + 33'd9470403;
    end
  end
  assign sample_strobe_o = sample_strobe;

  // --- Voices ---
  audio_t s_ufo, s_shot, s_p_die, s_i_hit, s_bonus, s_fleet, s_ufo_hit;

  logic_ufo u_ufo (.clk_i, .rst_ni, .enable_i(port3_i[0]), .audio_o(s_ufo));
  invaders_shot_sampled u_shot (.clk_i, .rst_ni, .trigger_i(port3_i[1]), .audio_o(s_shot));
  logic_explosion u_p_die (.clk_i, .rst_ni, .trigger_i(port3_i[2]), .audio_o(s_p_die));
  logic_invader_hit u_i_hit (.clk_i, .rst_ni, .trigger_i(port3_i[3]), .audio_o(s_i_hit));

  logic [31:0] bonus_cnt_q;
  logic bonus_gate;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) bonus_cnt_q <= 0;
    else if (port3_i[4]) begin
      if (bonus_cnt_q >= 5000000) bonus_cnt_q <= 0;
      else bonus_cnt_q <= bonus_cnt_q + 1;
    end else bonus_cnt_q <= 0;
  end
  assign bonus_gate = (bonus_cnt_q < 4000000);
  logic_simple_osc u_bonus (.clk_i, .rst_ni, .enable_i(port3_i[4] && bonus_gate), .freq_inc_i(32'd103079), .audio_o(s_bonus));

  logic_fleet u_fleet (.clk_i, .rst_ni, .fleet_data_i(port5_i[3:0]), .audio_o(s_fleet));
  logic_ufo_hit u_ufo_hit (.clk_i, .rst_ni, .clk_en_i(1'b1), .sample_strobe_i(sample_strobe), .enable_i(port5_i[4]), .audio_o(s_ufo_hit));

  // 2. High-Headroom Mixing with Calibrated Weights
  // Relative weights calculated from MAME reference absolute peaks,
  // then halved (50% global volume) to provide headroom for simultaneous voices.
  // 256 = 1.0 scaling (before headroom halving)
  
  logic signed [31:0] mixed;
  logic signed [31:0] w_ufo;
  logic signed [31:0] w_shot;
  logic signed [31:0] w_p_die;
  logic signed [31:0] w_i_hit;
  logic signed [31:0] w_bonus;
  logic signed [31:0] w_fleet;
  logic signed [31:0] w_uhit;

  always_comb begin
    w_ufo   = (32'(s_ufo)     * 32'sd66)  >>> 8; // UFO 
    w_shot  = (32'(s_shot)    * 32'sd130) >>> 8; // Shot 
    w_p_die = (32'(s_p_die)   * 32'sd418) >>> 8; // Player Die 
    w_i_hit = (32'(s_i_hit)   * 32'sd86)  >>> 8; // Invader Hit
    w_bonus = (32'(s_bonus)   * 32'sd83)  >>> 8; // Bonus
    w_fleet = (32'(s_fleet)   * 32'sd134) >>> 8; // Fleet
    w_uhit  = (32'(s_ufo_hit) * 32'sd219) >>> 8; // UFO Hit
    
    mixed = w_ufo + w_shot + w_p_die + w_i_hit + w_bonus + w_fleet + w_uhit;
  end

  // 3. Accumulate-and-Dump Anti-Aliasing Filter
  // Average all 20MHz samples within the 44.1kHz window.
  // Using 40 bits is plenty for accumulating ~453 samples of 32-bit values.
  logic signed [39:0] integrator_q;
  logic signed [31:0] final_sample_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      integrator_q <= '0;
      final_sample_q <= '0;
    end else begin
      if (sample_strobe) begin
        // Average = Sum / 453. Shift by 9 (~512) is synthesis-safe and avoids division logic,
        // while also providing a slight ~11% natural attenuation for extra headroom.
        final_sample_q <= 32'(integrator_q >>> 9);
        integrator_q <= 40'(mixed);
      end else begin
        integrator_q <= integrator_q + 40'(mixed);
      end
    end
  end

  // 4. DC Block High-Pass Filter (~400Hz)
  logic signed [47:0] hpf_q, prev_val_q; 
  logic first_sample_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      hpf_q <= '0; prev_val_q <= '0;
      audio_o <= '0;
      first_sample_q <= 1'b1;
    end else begin
      if (sample_strobe) begin
        logic signed [47:0] x_in, hpf_next;
        x_in = 48'(final_sample_q) << 16;
        
        if (first_sample_q) begin
          hpf_q <= '0;
          prev_val_q <= x_in;
          hpf_next = '0;
          first_sample_q <= 1'b0;
        end else begin
          // y[n] = x[n] - x[n-1] + a * y[n-1]
          // Shift by 4 at 44.1kHz is ~400Hz
          hpf_next = (x_in - prev_val_q) + (hpf_q - (hpf_q >>> 4));
          hpf_q <= hpf_next;
          prev_val_q <= x_in;
        end

        if (port3_i[5] == 0) begin
          audio_o <= '0;
        end else begin
          logic signed [47:0] out_val;
			 out_val = hpf_next >>> 16;
          // Saturating clamp to 16-bit range
          if (out_val > 32767)      audio_o <= 16'sd32767;
          else if (out_val < -32768) audio_o <= -16'sd32768;
          else                      audio_o <= 16'(out_val);
        end
      end
    end
  end

endmodule

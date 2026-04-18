// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module logic_invader_hit (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic trigger_i,
  output logic signed [15:0] audio_o
);
  import audio_pkg::*;

  // 1. Triple Burst Sequencer (0ms, 90ms, 270ms)
  logic [31:0] timer_q;
  logic active_q, prev_trig_q, env_trig;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      active_q <= 1'b0;
      timer_q <= '0;
      prev_trig_q <= 1'b0;
    end else begin
      prev_trig_q <= trigger_i;
      if (trigger_i && !prev_trig_q) begin
        active_q <= 1'b1;
        timer_q <= 32'd0;
      end else if (active_q) begin
        if (timer_q < 32'd7000000) timer_q <= timer_q + 1; // 350ms total @ 20MHz
        else active_q <= 1'b0;
      end
    end
  end

  // Frequency logic: Use high-precision incremental accumulator (Q32.32)
  logic [63:0] freq_acc_q;
  logic [31:0] freq_step;
  logic [31:0] start_inc;
  
  always_comb begin
    // Default Phase 1 (0-90ms)
    start_inc = 32'd215241;
    freq_step = 32'd410953521;

    if (timer_q >= 1800000 && timer_q < 5400000) begin
      // Phase 2
      start_inc = 32'd387425;
      freq_step = 32'd256587144;
    end else if (timer_q >= 5400000) begin
      // Phase 3
      start_inc = 32'd387425;
      freq_step = 32'd346654120;
    end
  end

  assign env_trig = (timer_q == 0 && active_q) || (timer_q == 1800000) || (timer_q == 5400000);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) freq_acc_q <= '0;
    else if (env_trig) freq_acc_q <= 64'(start_inc) << 32;
    else if (active_q) freq_acc_q <= freq_acc_q - 64'(freq_step);
  end

  // Phase control signals
  logic [31:0] attack_inc, decay_a_inc, decay_b_inc, decay_a_limit;
  logic [15:0] burst_scale;

  always_comb begin
    attack_inc = 32'd18199;    
    decay_a_inc = 32'd2147; decay_b_inc = 32'd3700; decay_a_limit = 32'h8000_0000; 
    burst_scale = 16'hFFFF; 

    if (timer_q >= 1800000 && timer_q < 5400000) begin
      attack_inc = 32'd21474; decay_a_inc = 32'd894; decay_b_inc = 32'd2147; decay_a_limit = 32'h8000_0000; 
      burst_scale = 16'hF400; 
    end else if (timer_q >= 5400000) begin
      attack_inc = 32'd238609; decay_a_inc = 32'd2684; decay_b_inc = 32'd2752; decay_a_limit = 32'h8000_0000;
      burst_scale = 16'h4000; 
    end
  end

  // 2. Audio Generation
  logic [15:0] amp;
  logic_env u_env (
    .clk_i, .rst_ni, .trigger_i(env_trig),
    .attack_inc_i(attack_inc), 
    .decay_a_inc_i(decay_a_inc), .decay_b_inc_i(decay_b_inc), .decay_a_limit_i(decay_a_limit),
    .amp_o(amp), .active_o()
  );

  logic signed [15:0] osc_out;
  logic_osc u_osc (.clk_i, .rst_ni, .freq_inc_i(freq_acc_q[63:32]), .duty_i(32'h5555_5555), .type_i(2'd0), .audio_o(osc_out));

  // 3. DSP Filtering (48-bit precision for Synthesis Timing)
  logic signed [47:0] lpf1_q, lpf2_q, lpf3_q;
  logic signed [47:0] hpf_acc_q, prev_osc_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lpf1_q <= '0; lpf2_q <= '0; lpf3_q <= '0;
      hpf_acc_q <= '0; prev_osc_q <= '0;
    end else begin
      logic signed [47:0] x1, hpf_next;
      x1 = 48'(osc_out) << 16;
      lpf1_q <= lpf1_q + ((x1 - lpf1_q) >>> 11);
      lpf2_q <= lpf2_q + ((lpf1_q - lpf2_q) >>> 11);
      lpf3_q <= lpf3_q + ((lpf2_q - lpf3_q) >>> 11);
      hpf_next = (lpf3_q - prev_osc_q) + (hpf_acc_q - (hpf_acc_q >>> 17));
      hpf_acc_q <= hpf_next;
      prev_osc_q <= lpf3_q;
    end
  end

  always_comb begin
    logic signed [31:0] scaled_amp;
    logic signed [31:0] filtered_osc;
    logic signed [63:0] mixed_vol;
    
    if (active_q) begin
      filtered_osc = 32'(hpf_acc_q >>> 16);
      scaled_amp = (32'($signed({1'b0, amp})) * 32'($signed({1'b0, burst_scale}))) >>> 16;
      mixed_vol = (64'(filtered_osc) * 64'(scaled_amp)) >>> 15;
      
      if (mixed_vol > 32767)      audio_o = 16'sd32767;
      else if (mixed_vol < -32768) audio_o = -16'sd32768;
      else                        audio_o = 16'(mixed_vol);
    end else begin
      audio_o = '0;
    end
  end
endmodule

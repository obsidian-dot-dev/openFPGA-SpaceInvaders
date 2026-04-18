// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module invaders_shot_sampled (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic trigger_i,
  output logic signed [15:0] audio_o
);
  import audio_pkg::*;

  // 1. Unified Envelope Generator
  // Match the raw sample: 2ms Atk, 100ms Sus, 200ms Dec
  logic [15:0] amp;
  logic active;
  logic [31:0] timer_q;
  logic prev_trig_q;
  logic force_decay;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      timer_q <= '0;
      prev_trig_q <= 1'b0;
      force_decay <= 1'b0;
    end else begin
      prev_trig_q <= trigger_i;
      if (trigger_i && !prev_trig_q) begin
        timer_q <= 32'd1;
        force_decay <= 1'b0;
      end else if (active && timer_q != 0) begin
        // Always increment timer while active so Doppler sweep continues
        timer_q <= timer_q + 1;
        if (timer_q < 32'd2040000) begin
          force_decay <= 1'b0;
        end else begin
          force_decay <= 1'b1;
        end
      end else begin
        timer_q <= '0;
        force_decay <= 1'b0;
      end
    end
  end

  logic_env u_env (
    .clk_i, .rst_ni, .trigger_i,
    .attack_inc_i(32'd107374),
    .decay_a_inc_i(32'd0),
    .decay_b_inc_i(32'd1073), // ~200ms decay
    .decay_a_limit_i(force_decay ? 32'hFFFF_FFFF : 32'd0), 
    .amp_o(amp), .active_o(active)
  );

  // 2. Shaped Noise (Airy Path)
  // HPF (DC Blocker) -> 2-pole LPF (~3kHz) to remove "hiss" and leave "wind/air"
  logic signed [15:0] noise_raw;
  logic_noise_gen u_noise (.clk_i, .rst_ni, .freq_div_i(16'd2661), .audio_o(noise_raw));

  logic signed [47:0] prev_noise;
  logic signed [47:0] noise_hpf_q;
  logic signed [47:0] noise_lpf1_q;
  logic signed [47:0] noise_lpf2_q;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      prev_noise <= '0;
      noise_hpf_q <= '0;
      noise_lpf1_q <= '0;
      noise_lpf2_q <= '0;
    end else begin
      logic signed [47:0] x_in;
      x_in = 48'(noise_raw) << 16;
      
      // HPF (~50Hz) to remove LFSR DC Bias
      noise_hpf_q <= x_in - prev_noise + noise_hpf_q - (noise_hpf_q >>> 12);
      prev_noise <= x_in;
      
      // ~3kHz cutoff LPF
      noise_lpf1_q <= noise_lpf1_q + ((noise_hpf_q - noise_lpf1_q) >>> 10);
      noise_lpf2_q <= noise_lpf2_q + ((noise_lpf1_q - noise_lpf2_q) >>> 10);
    end
  end
  
  // 3. Frequency Sweep (Tone Path)
  logic [31:0] base_freq_inc;
  logic [31:0] sweep_drop;

  always_comb begin
    // Doppler drop starts at 100ms
    if (timer_q > 32'd2000000) begin
      sweep_drop = (timer_q - 32'd2000000) >> 8; // Shallower drop (~70Hz over 200ms)
    end else begin
      sweep_drop = '0;
    end
    base_freq_inc = 32'd552767 - sweep_drop;
  end

  // 4. Oscillators
  // Sine Wave (Smooth fundamental)
  logic signed [15:0] osc_sine;
  logic_sine_osc u_osc_sine (
    .clk_i, .rst_ni, .freq_inc_i(base_freq_inc), 
    .audio_o(osc_sine)
  );

  // Triangle Wave (Odd harmonics for "nasal" tone)
  logic signed [15:0] osc_tri;
  logic_osc u_osc_tri (
    .clk_i, .rst_ni, .freq_inc_i(base_freq_inc), 
    .duty_i(32'h8000_0000), // Doesn't matter for triangle
    .type_i(2'd1),          // 1 = Triangle
    .audio_o(osc_tri)
  );

  // Blend Tone: 50% Sine, 50% Triangle
  logic signed [15:0] osc_out;
  always_comb begin
    osc_out = 16'((32'($signed(osc_sine)) + 32'($signed(osc_tri))) >>> 1);
  end

  // 5. Final Mix, VCA, & Lo-Fi Filter
  logic signed [47:0] lofi_lpf1_q;
  logic signed [47:0] lofi_lpf2_q;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      audio_o <= '0;
      lofi_lpf1_q <= '0;
      lofi_lpf2_q <= '0;
    end else begin
      logic signed [63:0] mixed_source;
      logic signed [63:0] vca_mult;
      logic signed [47:0] pre_filter_val;
      logic signed [47:0] final_val;

      if (active) begin
        // Mix: 45% Tone, 55% Shaped Noise (Tuning for -3dB TNR target)
        mixed_source = (64'($signed(osc_out)) * 64'sd29 + 64'($signed(noise_lpf2_q >>> 16)) * 64'sd35) >>> 6;
        vca_mult = mixed_source * $signed({1'b0, amp});
        pre_filter_val = 48'(vca_mult >>> 15) << 16;
      end else begin
        pre_filter_val = '0;
      end
      
      // 2-pole LPF at ~6kHz (Shift by 9) to simulate 11kHz sample rate Nyquist limit
      lofi_lpf1_q <= lofi_lpf1_q + ((pre_filter_val - lofi_lpf1_q) >>> 9);
      lofi_lpf2_q <= lofi_lpf2_q + ((lofi_lpf1_q - lofi_lpf2_q) >>> 9);
      
      final_val = lofi_lpf2_q >>> 16;
      
      // Saturate to prevent integer wraparound
      if (final_val > 32767)      audio_o <= 16'sd32767;
      else if (final_val < -32768) audio_o <= -16'sd32768;
      else                        audio_o <= 16'(final_val);
    end
  end
endmodule

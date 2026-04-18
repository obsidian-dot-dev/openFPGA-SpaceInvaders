// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

module logic_shot (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic trigger_i,
  output logic signed [15:0] audio_o
);
  import audio_pkg::*;

  // 1. 3-Point Envelope Generator (Optimized Parameter Analog)
  // Timings at 20MHz:
  // Attack: 2ms -> 40,000 cycles -> Inc: 107374
  // Sustain: 605ms -> 12,100,000 cycles
  // Decay: 24ms -> 480,000 cycles -> Inc: 8947
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
        // Total time before tail drop: Attack + Sustain = 12,140,000 cycles
        if (timer_q < 32'd12140000) begin
          timer_q <= timer_q + 1;
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

  logic [31:0] dynamic_decay_limit;
  assign dynamic_decay_limit = force_decay ? 32'hFFFF_FFFF : 32'd0;

  logic_env u_env (
    .clk_i, .rst_ni, .trigger_i,
    .attack_inc_i(32'd107374),
    .decay_a_inc_i(32'd0),           // Sustain phase
    .decay_b_inc_i(32'd8947),        // Decay tail
    .decay_a_limit_i(dynamic_decay_limit), 
    .amp_o(amp), .active_o(active)
  );

  // 2. Noise Generator (7.5kHz Clock) & HPF
  logic signed [15:0] noise_raw;
  logic_noise_gen u_noise (.clk_i, .rst_ni, .freq_div_i(16'd2661), .audio_o(noise_raw));

  // High-Pass Filter on the noise to prevent fundamental wander (~100Hz)
  // Shift by 15 at 20MHz is approx 100Hz
  logic signed [31:0] noise_hpf_q;
  logic signed [31:0] prev_noise_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      noise_hpf_q <= '0;
      prev_noise_q <= '0;
    end else begin
      logic signed [31:0] x_in = 32'(noise_raw) << 16;
      logic signed [31:0] diff = x_in - prev_noise_q;
      logic signed [31:0] delayed = noise_hpf_q - (noise_hpf_q >>> 15);
      
      noise_hpf_q <= diff + delayed;
      prev_noise_q <= x_in;
    end
  end
  
  // 3. Frequency Modulation & Doppler Sweep
  logic [31:0] base_freq_inc;
  logic [31:0] sweep_drop;
  logic signed [31:0] noise_mod;
  logic [31:0] final_freq_inc;
  logic signed [31:0] centered_noise;

  always_comb begin
    // Start Doppler drop at 500ms (10,000,000 cycles). 
    // Drop rate: 1 phase inc every 64 cycles (~150Hz drop over the last 100ms)
    if (timer_q > 32'd10000000) begin
      sweep_drop = (timer_q - 32'd10000000) >> 6;
    end else begin
      sweep_drop = '0;
    end
    
    // Base Freq: 2826 Hz -> Phase Inc: 606879
    base_freq_inc = 32'd606879 - sweep_drop;
    
    // FM Depth: +/- 500 Hz -> +/- 107374 inc.
    // noise_hpf_q is shifted by 16, so it's +/- (16384 << 16).
    // We want (+/- 16384 * 3) =~ +/- 49152.
    // noise * 3 = (noise << 1) + noise.
    centered_noise = noise_hpf_q >>> 16;
    noise_mod = (centered_noise << 1) + centered_noise;

    final_freq_inc = base_freq_inc + 32'(noise_mod);
  end

  // 4. Square Wave Oscillator
  logic signed [15:0] osc_out;
  logic_osc u_osc (
    .clk_i, .rst_ni, .freq_inc_i(final_freq_inc), 
    // Duty Cycle: 22% -> 32'h3851_EB85
    .duty_i(32'h3851_EB85), 
    .type_i(2'd0), 
    .audio_o(osc_out)
  );

  // 5. VCA & Output Scaling
  // Scale to hit MAME RMS. 
  // (>>> 18) gives a channel peak of ~4095. After top-level mixer attenuation, 
  // this results in a final peak of ~0.10 and an RMS of ~0.04.
  // Wait, >>> 17 gave peak 0.19, >>> 19 gave peak 0.05. 
  // Let's use >>> 18.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      audio_o <= '0;
    end else begin
      if (active) begin
        logic signed [63:0] vca_mult;
        vca_mult = 64'(osc_out) * $signed({1'b0, amp});
        audio_o <= 16'(vca_mult >>> 18);
      end else begin
        audio_o <= '0;
      end
    end
  end
endmodule

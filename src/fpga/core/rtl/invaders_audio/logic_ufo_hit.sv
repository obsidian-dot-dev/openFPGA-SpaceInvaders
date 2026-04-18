// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Audio UFO Hit
module logic_ufo_hit (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic clk_en_i,
  input  logic sample_strobe_i,
  input  logic enable_i,
  output logic signed [15:0] audio_o
);
  import audio_pkg::*;

  // 1. Sine LUT (256 entries, signed 16-bit)
  logic signed [15:0] sine_lut [256];
  initial begin
    sine_lut[0] = 16'd0; sine_lut[1] = 16'd402; sine_lut[2] = 16'd803; sine_lut[3] = 16'd1205;
    sine_lut[4] = 16'd1605; sine_lut[5] = 16'd2005; sine_lut[6] = 16'd2404; sine_lut[7] = 16'd2801;
    sine_lut[8] = 16'd3196; sine_lut[9] = 16'd3589; sine_lut[10] = 16'd3980; sine_lut[11] = 16'd4370;
    sine_lut[12] = 16'd4756; sine_lut[13] = 16'd5139; sine_lut[14] = 16'd5519; sine_lut[15] = 16'd5896;
    sine_lut[16] = 16'd6269; sine_lut[17] = 16'd6639; sine_lut[18] = 16'd7004; sine_lut[19] = 16'd7366;
    sine_lut[20] = 16'd7723; sine_lut[21] = 16'd8075; sine_lut[22] = 16'd8423; sine_lut[23] = 16'd8765;
    sine_lut[24] = 16'd9102; sine_lut[25] = 16'd9434; sine_lut[26] = 16'd9759; sine_lut[27] = 16'd10079;
    sine_lut[28] = 16'd10393; sine_lut[29] = 16'd10701; sine_lut[30] = 16'd11002; sine_lut[31] = 16'd11297;
    sine_lut[32] = 16'd11585; sine_lut[33] = 16'd11866; sine_lut[34] = 16'd12139; sine_lut[35] = 16'd12406;
    sine_lut[36] = 16'd12665; sine_lut[37] = 16'd12916; sine_lut[38] = 16'd13159; sine_lut[39] = 16'd13395;
    sine_lut[40] = 16'd13622; sine_lut[41] = 16'd13842; sine_lut[42] = 16'd14053; sine_lut[43] = 16'd14255;
    sine_lut[44] = 16'd14449; sine_lut[45] = 16'd14634; sine_lut[46] = 16'd14810; sine_lut[47] = 16'd14977;
    sine_lut[48] = 16'd15136; sine_lut[49] = 16'd15286; sine_lut[50] = 16'd15426; sine_lut[51] = 16'd15557;
    sine_lut[52] = 16'd15678; sine_lut[53] = 16'd15791; sine_lut[54] = 16'd15893; sine_lut[55] = 16'd15986;
    sine_lut[56] = 16'd16069; sine_lut[57] = 16'd16142; sine_lut[58] = 16'd16206; sine_lut[59] = 16'd16259;
    sine_lut[60] = 16'd16303; sine_lut[61] = 16'd16336; sine_lut[62] = 16'd16360; sine_lut[63] = 16'd16374;
    sine_lut[64] = 16'd16383; sine_lut[65] = 16'd16383; sine_lut[66] = 16'd16373; sine_lut[67] = 16'd16353;
    sine_lut[68] = 16'd16323; sine_lut[69] = 16'd16284; sine_lut[70] = 16'd16235; sine_lut[71] = 16'd16176;
    sine_lut[72] = 16'd16108; sine_lut[73] = 16'd16030; sine_lut[74] = 16'd15942; sine_lut[75] = 16'd15844;
    sine_lut[76] = 16'd15738; sine_lut[77] = 16'd15622; sine_lut[78] = 16'd15496; sine_lut[79] = 16'd15362;
    sine_lut[80] = 16'd15218; sine_lut[81] = 16'd15065; sine_lut[82] = 16'd14903; sine_lut[83] = 16'd14732;
    sine_lut[84] = 16'd14552; sine_lut[85] = 16'd14364; sine_lut[86] = 16'd14166; sine_lut[87] = 16'd13960;
    sine_lut[88] = 16'd13746; sine_lut[89] = 16'd13523; sine_lut[90] = 16'd13292; sine_lut[91] = 16'd13053;
    sine_lut[92] = 16'd12806; sine_lut[93] = 16'd12551; sine_lut[94] = 16'd12288; sine_lut[95] = 16'd12018;
    sine_lut[96] = 16'd11740; sine_lut[97] = 16'd11456; sine_lut[98] = 16'd11164; sine_lut[99] = 16'd10866;
    sine_lut[100] = 16'd10561; sine_lut[101] = 16'd10250; sine_lut[102] = 16'd9933; sine_lut[103] = 16'd9611;
    sine_lut[104] = 16'd9282; sine_lut[105] = 16'd8949; sine_lut[106] = 16'd8610; sine_lut[107] = 16'd8266;
    sine_lut[108] = 16'd7917; sine_lut[109] = 16'd7564; sine_lut[110] = 16'd7207; sine_lut[111] = 16'd6846;
    sine_lut[112] = 16'd6480; sine_lut[113] = 16'd6112; sine_lut[114] = 16'd5740; sine_lut[115] = 16'd5365;
    sine_lut[116] = 16'd4987; sine_lut[117] = 16'd4606; sine_lut[118] = 16'd4223; sine_lut[119] = 16'd3838;
    sine_lut[120] = 16'd3450; sine_lut[121] = 16'd3061; sine_lut[122] = 16'd2671; sine_lut[123] = 16'd2280;
    sine_lut[124] = 16'd1888; sine_lut[125] = 16'd1495; sine_lut[126] = 16'd1101; sine_lut[127] = 16'd707;
    sine_lut[128] = 16'd314; sine_lut[129] = -16'd79; sine_lut[130] = -16'd473; sine_lut[131] = -16'd866;
    sine_lut[132] = -16'd1258; sine_lut[133] = -16'd1650; sine_lut[134] = -16'd2040; sine_lut[135] = -16'd2428;
    sine_lut[136] = -16'd2815; sine_lut[137] = -16'd3200; sine_lut[138] = -16'd3583; sine_lut[139] = -16'd3964;
    sine_lut[140] = -16'd4342; sine_lut[141] = -16'd4718; sine_lut[142] = -16'd5091; sine_lut[143] = -16'd5460;
    sine_lut[144] = -16'd5825; sine_lut[145] = -16'd6187; sine_lut[146] = -16'd6543; sine_lut[147] = -16'd6896;
    sine_lut[148] = -16'd7243; sine_lut[149] = -16'd7586; sine_lut[150] = -16'd7924; sine_lut[151] = -16'd8256;
    sine_lut[152] = -16'd8583; sine_lut[153] = -16'd8904; sine_lut[154] = -16'd9218; sine_lut[155] = -16'd9526;
    sine_lut[156] = -16'd9827; sine_lut[157] = -16'd10121; sine_lut[158] = -16'd10408; sine_lut[159] = -16'd10688;
    sine_lut[160] = -16'd10959; sine_lut[161] = -16'd11223; sine_lut[162] = -16'd11478; sine_lut[163] = -16'd11725;
    sine_lut[164] = -16'd11963; sine_lut[165] = -16'd12193; sine_lut[166] = -16'd12413; sine_lut[167] = -16'd12624;
    sine_lut[168] = -16'd12826; sine_lut[169] = -16'd13018; sine_lut[170] = -16'd13201; sine_lut[171] = -16'd13374;
    sine_lut[172] = -16'd13537; sine_lut[173] = -16'd13690; sine_lut[174] = -16'd13833; sine_lut[175] = -16'd13965;
    sine_lut[176] = -16'd14088; sine_lut[177] = -16'd14201; sine_lut[178] = -16'd14302; sine_lut[179] = -16'd14394;
    sine_lut[180] = -16'd14475; sine_lut[181] = -16'd14545; sine_lut[182] = -16'd14605; sine_lut[183] = -16'd14654;
    sine_lut[184] = -16'd14692; sine_lut[185] = -16'd14720; sine_lut[186] = -16'd14736; sine_lut[187] = -16'd14742;
    sine_lut[188] = -16'd14737; sine_lut[189] = -16'd14722; sine_lut[190] = -16'd14696; sine_lut[191] = -16'd14659;
    sine_lut[192] = -16'd14612; sine_lut[193] = -16'd14554; sine_lut[194] = -16'd14486; sine_lut[195] = -16'd14407;
    sine_lut[196] = -16'd14318; sine_lut[197] = -16'd14219; sine_lut[198] = -16'd14110; sine_lut[199] = -16'd13991;
    sine_lut[200] = -16'd13862; sine_lut[201] = -16'd13723; sine_lut[202] = -16'd13575; sine_lut[203] = -16'd13417;
    sine_lut[204] = -16'd13250; sine_lut[205] = -16'd13073; sine_lut[206] = -16'd12888; sine_lut[207] = -16'd12694;
    sine_lut[208] = -16'd12491; sine_lut[209] = -16'd12279; sine_lut[210] = -16'd12059; sine_lut[211] = -16'd11831;
    sine_lut[212] = -16'd11595; sine_lut[213] = -16'd11351; sine_lut[214] = -16'd11099; sine_lut[215] = -16'd10840;
    sine_lut[216] = -16'd10574; sine_lut[217] = -16'd10301; sine_lut[218] = -16'd10021; sine_lut[219] = -16'd9735;
    sine_lut[220] = -16'd9442; sine_lut[221] = -16'd9144; sine_lut[222] = -16'd8840; sine_lut[223] = -16'd8531;
    sine_lut[224] = -16'd8216; sine_lut[225] = -16'd7897; sine_lut[226] = -16'd7573; sine_lut[227] = -16'd7245;
    sine_lut[228] = -16'd6912; sine_lut[229] = -16'd6576; sine_lut[230] = -16'd6236; sine_lut[231] = -16'd5892;
    sine_lut[232] = -16'd5545; sine_lut[233] = -16'd5195; sine_lut[234] = -16'd4842; sine_lut[235] = -16'd4487;
    sine_lut[236] = -16'd4129; sine_lut[237] = -16'd3769; sine_lut[238] = -16'd3407; sine_lut[239] = -16'd3044;
    sine_lut[240] = -16'd2679; sine_lut[241] = -16'd2313; sine_lut[242] = -16'd1946; sine_lut[243] = -16'd1578;
    sine_lut[244] = -16'd1210; sine_lut[245] = -16'd841; sine_lut[246] = -16'd473; sine_lut[247] = -16'd104;
    sine_lut[248] = 16'd264; sine_lut[249] = 16'd632; sine_lut[250] = 16'd999; sine_lut[251] = 16'd1365;
    sine_lut[252] = 16'd1730; sine_lut[253] = 16'd2093; sine_lut[254] = 16'd2455; sine_lut[255] = 16'd2815;
  end

  // 2. Control Registers
  logic [31:0] vco_phase_q;
  logic [31:0] lfo_phase_q;
  logic [31:0] env_acc_q;

  // Constants @ 44.1kHz sample rate
  // LFO: 6.25 Hz -> (6.25 / 44100) * 2^32 = 608736
  localparam logic [31:0] LFO_STEP = 32'd608736;
  
  // VCO: Carrier 780 Hz (Obsidian) -> (780 / 44100) * 2^32 = 75963257
  localparam logic [31:0] VCO_CENTER = 32'd75963257;
  
  // VCO: Deviation 380 Hz (to cover 400-1160 Hz) -> (380 / 44100) * 2^32 / 16384 = 2258
  localparam logic [31:0] FM_DEV_STEP = 32'd2258;

  // Envelope Rates @ 44.1kHz
  // Attack: ~40ms -> 2^32 / (44100 * 0.04) = 2434784
  localparam logic [31:0] ENV_ATTACK_STEP = 32'd2434784;
  // Decay: 500ms -> 2^32 / (44100 * 0.5) = 194783
  localparam logic [31:0] ENV_DECAY_STEP = 32'd194783;

  // 3. Synthesis Logic (44.1kHz)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      vco_phase_q  <= '0;
      lfo_phase_q  <= '0;
      env_acc_q    <= '0;
    end else if (sample_strobe_i) begin
      // LFO Phase
      lfo_phase_q <= lfo_phase_q + LFO_STEP;
      
      // Master Gating Envelope (High precision fade-out)
      if (enable_i) begin
        if (env_acc_q < 32'hFFFF_FFFF - ENV_ATTACK_STEP) env_acc_q <= env_acc_q + ENV_ATTACK_STEP;
        else env_acc_q <= 32'hFFFF_FFFF;
      end else begin
        if (env_acc_q > ENV_DECAY_STEP) env_acc_q <= env_acc_q - ENV_DECAY_STEP;
        else env_acc_q <= 0;
      end

      // VCO Phase Update (FM)
      vco_phase_q <= vco_phase_q + VCO_CENTER + (32'($signed(sine_lut[lfo_phase_q[31:24]])) * FM_DEV_STEP);
    end
  end

  // 4. Output Modulation (AM) and Filtering (LPF ~1.2kHz)
  logic signed [31:0] am_mod;
  logic signed [31:0] raw_vco;
  logic signed [63:0] lpf1_q, lpf2_q;
  
  always_comb begin
    // am_mod = 1.0 + sine (Range 0..32767)
    am_mod = 16'sd16384 + sine_lut[lfo_phase_q[31:24]];
    // raw_vco = sine(vco_phase) * am_mod * envelope
    raw_vco = (32'($signed(sine_lut[vco_phase_q[31:24]])) * am_mod) >>> 14;
    // Scale by 32-bit envelope (result fits in signed 32-bit because env_acc_q is unsigned)
    raw_vco = (raw_vco * $signed({1'b0, env_acc_q[31:16]})) >>> 16;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lpf1_q <= '0;
      lpf2_q <= '0;
      audio_o <= '0;
    end else begin
      // Update filter at 20MHz for high-precision smoothing
      lpf1_q <= lpf1_q + (((64'(raw_vco) << 32) - lpf1_q) >>> 11);
      lpf2_q <= lpf2_q + ((lpf1_q - lpf2_q) >>> 11);
      
      if (sample_strobe_i) begin
        audio_o <= 16'(lpf2_q >>> 32);
      end
    end
  end

endmodule

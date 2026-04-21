// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Video Effects
// Implements colored overlay and background underlay (backdrop)
// Simulates arcade "Mirror" effect with darkened background and blending.
// Includes a toggle to switch between backdrop and solid black modes.

module invaders_video_effects (
  input  logic        clk_i,
  input  logic        clk_en_i,
  input  logic        rst_ni,
  
  // Controls
  input  logic        backdrop_en_i, // 1: Mirror effect, 0: Solid Black background
  input  logic        is_15khz_i,
  input  logic [2:0]  scanline_strength_i, // 0: Off, 1: 25%, 2: 50%, 3: 75%, 4: 100%
  
  // From Scaler (Landscape 512x448)
  input  logic        video_i,
  input  logic [9:0]  h_cnt_i,
  input  logic [9:0]  v_cnt_i,
  input  logic        hblank_i,
  input  logic        vblank_i,
  
  // Backdrop Memory Interface (8-bit indices)
  output logic [15:0] bg_addr_o,
  input  logic [7:0]  bg_idx_i,
  
  // Palette Memory Interface (RGB888)
  output logic [7:0]  pal_addr_o,
  input  logic [23:0] pal_rgb_i,
  
  // SDRAM Backdrop Input
  input  logic [31:0] bg_rgb_sdram_i,
  
  // Final Output
  output logic [23:0] video_rgb_o
);

  import invaders_pkg::*;

  // 1. Physical Coordinate Mapping (Landscape -> Portrait)
  // Scaling: 256x224 -> 512x448
  // input h_cnt_i: 0-511 (Landscape width)
  // input v_cnt_i: 0-447 (Landscape height)
  // Portrait: px (0-447), py (0-511)
  logic [9:0] px_base, py_base;
  assign px_base = is_15khz_i ? {v_cnt_i[8:0], 1'b0} : v_cnt_i[9:0];
  assign py_base = is_15khz_i ? {h_cnt_i[8:0], 1'b0} : h_cnt_i[9:0];

  logic [8:0] px;
  logic [9:0] py;
  assign px = px_base[8:0];
  assign py = 10'd511 - py_base;

  // 2. Color Overlay Logic (Updated for 512 scale)
  logic [23:0] overlay_color;
  always_comb begin
    if (py < 64) begin
      overlay_color = COLOR_WHITE;
    end else if (py < 122) begin     
      overlay_color = COLOR_RED;
    end else if (py >= 364 && py < 478) begin 
      overlay_color = COLOR_GREEN;
    end else if (py >= 478) begin
      if (px >= 32 && px < 256) begin
        overlay_color = COLOR_GREEN;
      end else begin
        overlay_color = COLOR_WHITE;
      end
    end else begin
      overlay_color = COLOR_WHITE;
    end
  end

  // 3. Background Mapping
  logic [15:0] py_core, px_core;
  assign px_core = {1'b0, px[8:1]}; // Scale back to 256x224 core domain for indexing
  assign py_core = py[9:1];

  logic [15:0] py_addr;
  assign py_addr = (py_core << 7) + (py_core << 6) + (py_core << 5); // y * 224
  
  assign bg_addr_o  = py_addr + px_core;
  assign pal_addr_o = bg_idx_i;

  // 4. Pipelined Mixing with Mirror Blending
  logic [23:0] overlay_color_q, overlay_color_q2;
  logic        video_q, video_q2;
  logic        blank_q, blank_q2;
  logic        backdrop_en_q, backdrop_en_q2;
  logic [9:0]  v_cnt_q, v_cnt_q2;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      {video_q, video_q2} <= '0;
      {blank_q, blank_q2} <= '1;
      {backdrop_en_q, backdrop_en_q2} <= '0;
      {v_cnt_q, v_cnt_q2} <= '0;
      video_rgb_o <= 24'd0;
    end else if (clk_en_i) begin
      video_q <= video_i;
      video_q2 <= video_q;
      
      overlay_color_q <= overlay_color;
      overlay_color_q2 <= overlay_color_q;
      
      blank_q <= hblank_i || vblank_i;
      blank_q2 <= blank_q;

      backdrop_en_q <= backdrop_en_i;
      backdrop_en_q2 <= backdrop_en_q;

      v_cnt_q <= v_cnt_i;
      v_cnt_q2 <= v_cnt_q;
      
      if (blank_q2) begin
        video_rgb_o <= 24'd0;
      end else begin
        // Calculate scanline-affected game pixel color
        logic [23:0] game_rgb_scanline;
        if (v_cnt_q2[0]) begin
          // Every second line is darkened according to strength
          logic [7:0] s_r, s_g, s_b;
          case (scanline_strength_i)
            3'd1: begin // 25% Darker (scale by 0.75 = 1/2 + 1/4)
              s_r = (overlay_color_q2[23:16] >> 1) + (overlay_color_q2[23:16] >> 2);
              s_g = (overlay_color_q2[15:8]  >> 1) + (overlay_color_q2[15:8]  >> 2);
              s_b = (overlay_color_q2[7:0]   >> 1) + (overlay_color_q2[7:0]   >> 2);
            end
            3'd2: begin // 50% Darker (scale by 0.5)
              s_r = (overlay_color_q2[23:16] >> 1);
              s_g = (overlay_color_q2[15:8]  >> 1);
              s_b = (overlay_color_q2[7:0]   >> 1);
            end
            3'd3: begin // 75% Darker (scale by 0.25)
              s_r = (overlay_color_q2[23:16] >> 2);
              s_g = (overlay_color_q2[15:8]  >> 2);
              s_b = (overlay_color_q2[7:0]   >> 2);
            end
            3'd4: begin // 100% Darker (Black)
              s_r = 8'd0; s_g = 8'd0; s_b = 8'd0;
            end
            default: begin // 0% Darker (Off)
              s_r = overlay_color_q2[23:16];
              s_g = overlay_color_q2[15:8];
              s_b = overlay_color_q2[7:0];
            end
          endcase
          game_rgb_scanline = {s_r, s_g, s_b};
        end else begin
          game_rgb_scanline = overlay_color_q2;
        end

        if (backdrop_en_q2) begin
          // MIRROR MODE: Use SDRAM background if available, else use internal palette
          logic [7:0] bg_r, bg_g, bg_b;
          if (bg_rgb_sdram_i != 32'h0) begin
              bg_r = bg_rgb_sdram_i[23:16];
              bg_g = bg_rgb_sdram_i[15:8];
              bg_b = bg_rgb_sdram_i[7:0];
          end else begin
              bg_r = pal_rgb_i[23:16];
              bg_g = pal_rgb_i[15:8];
              bg_b = pal_rgb_i[7:0];
          end
          
          if (video_q2) begin
            // Blend 75% FG (with scanlines) + 25% BG
            logic [7:0] out_r, out_g, out_b;
            out_r = (game_rgb_scanline[23:16] >> 1) + (game_rgb_scanline[23:16] >> 2) + bg_r;
            out_g = (game_rgb_scanline[15:8]  >> 1) + (game_rgb_scanline[15:8]  >> 2) + bg_g;
            out_b = (game_rgb_scanline[7:0]   >> 1) + (game_rgb_scanline[7:0]   >> 2) + bg_b;
            video_rgb_o <= {out_r, out_g, out_b};
          end else begin
            video_rgb_o <= {bg_r, bg_g, bg_b};
          end
        end else begin
          // SOLID BLACK BACKGROUND: Active Pixels (with scanlines), Black Background
          if (video_q2) begin
            video_rgb_o <= game_rgb_scanline;
          end else begin
            video_rgb_o <= 24'd0;
          end
        end
      end
    end
  end

endmodule

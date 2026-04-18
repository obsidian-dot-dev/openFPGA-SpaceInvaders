// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Interrupt Controller
// Generates RST 1 and RST 2 interrupts based on video scanlines

module invaders_int_ctrl (
  input  logic        clk_i,
  input  logic        clk_en_i,
  input  logic        rst_ni,
  
  // Timing from Video
  input  logic [8:0]  v_scanline_i,
  
  // CPU Interface
  output logic        intr_o,
  input  logic        inta_i,    // From bus decoder (status_q[0])
  input  logic        dbin_i,    // From CPU
  output logic [7:0]  intr_vec_o
);

  import invaders_pkg::*;

  logic intr_q;
  logic [7:0] vec_q;
  logic line_96_trig_q;
  logic line_224_trig_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      intr_q <= 1'b0;
      vec_q  <= 8'h00;
      line_96_trig_q  <= 1'b0;
      line_224_trig_q <= 1'b0;
    end else if (clk_en_i) begin
      // Trigger RST 1 at line 96
      if (v_scanline_i == IRQ_LINE_MID) begin
        if (!line_96_trig_q) begin
          intr_q <= 1'b1;
          vec_q  <= VEC_RST1;
          line_96_trig_q <= 1'b1;
        end
      end else begin
        line_96_trig_q <= 1'b0;
      end

      // Trigger RST 2 at line 224
      if (v_scanline_i == IRQ_LINE_VBLANK) begin
        if (!line_224_trig_q) begin
          intr_q <= 1'b1;
          vec_q  <= VEC_RST2;
          line_224_trig_q <= 1'b1;
        end
      end else begin
        line_224_trig_q <= 1'b0;
      end

      // Clear interrupt when CPU acknowledges and starts reading the vector
      if (inta_i && dbin_i) begin
        intr_q <= 1'b0;
      end
    end
  end
  
  assign intr_o = intr_q;
  assign intr_vec_o = vec_q;

endmodule

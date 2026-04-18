// Space Invaders Video Controller (Monochrome Timing-based)
// Generates standard video timing and serialized pixel output.

module invaders_video (
  input  logic        clk_i,      // 20MHz System Clock
  input  logic        rst_ni,
  input  logic        sync_rst_i,
  
  // Memory Interface (Port B)
  output logic [15:0] vram_addr_o,
  input  logic [7:0]  vram_data_i,
  
  // Video Output (Timing-based)
  output logic        vclk_o,     // 5MHz Pixel Clock
  output logic        hsync_o,    // Active LOW
  output logic        vsync_o,    // Active LOW
  output logic        hblank_o,
  output logic        vblank_o,
  output logic        video_o,    // Monochrome pixel
  
  // Raster Counters for external effects
  output logic [8:0]  h_cnt_o,
  output logic [8:0]  v_cnt_o,
  
  // Internal scanline for interrupts
  output logic [8:0]  v_scanline_o
);

  import invaders_pkg::*;

  // 5MHz Video Clock Generation (20MHz / 4)
  logic [1:0] vclk_cnt_q;
  logic       vclk_q;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      vclk_cnt_q <= 0;
      vclk_q     <= 0;
    end else begin
      if (vclk_cnt_q == 1) begin
        vclk_cnt_q <= 0;
        vclk_q     <= ~vclk_q;
      end else begin
        vclk_cnt_q <= vclk_cnt_q + 1;
      end
    end
  end
  assign vclk_o = vclk_q;
  
  wire vclk_en = (vclk_cnt_q == 1 && vclk_q == 1); // Rising edge of vclk_q

  // Raster Counters
  // HTOTAL = 320, VTOTAL = 262
  logic [8:0] h_cnt_q; // 0-319
  logic [8:0] v_cnt_q; // 0-261
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      h_cnt_q <= 0;
      v_cnt_q <= 0;
    end else if (sync_rst_i) begin
      h_cnt_q <= 0;
      v_cnt_q <= 0;
    end else if (vclk_en) begin
      if (h_cnt_q == 319) begin
        h_cnt_q <= 0;
        if (v_cnt_q == 261) v_cnt_q <= 0;
        else                v_cnt_q <= v_cnt_q + 1;
      end else begin
        h_cnt_q <= h_cnt_q + 1;
      end
    end
  end
  
  assign h_cnt_o = h_cnt_q;
  assign v_cnt_o = v_cnt_q;
  assign v_scanline_o = v_cnt_q;

  // Sync and Blank Generation (Visible area is 0-255, 0-223)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      hsync_o  <= 1'b1;
      vsync_o  <= 1'b1;
      hblank_o <= 1'b0;
      vblank_o <= 1'b0;
    end else if (vclk_en) begin
      // H-Timing: Visible(256), Front(16), Sync(32), Back(16) -> Total 320
      hsync_o  <= ~(h_cnt_q >= 272 && h_cnt_q < 304);
      hblank_o <= (h_cnt_q >= 256);
      
      // V-Timing: Visible(224), Front(10), Sync(2), Back(26) -> Total 262
      vsync_o  <= ~(v_cnt_q >= 234 && v_cnt_q < 236);
      vblank_o <= (v_cnt_q >= 224);
    end
  end

  // Pixel Data Fetching
  logic [7:0] pixel_byte_q;
  
  // Request address 1 pixel clock early to account for memory latency
  logic [8:0] h_cnt_next;
  assign h_cnt_next = (h_cnt_q == 319) ? 9'd0 : h_cnt_q + 9'd1;

  always_comb begin
    // We want data for pixel N ready at start of pixel N.
    // Memory takes 1 clk_i to respond.
    // Latching happens at start of block (h_cnt_q % 8 == 0).
    // So we should request at (h_cnt_q % 8 == 7).
    if (v_cnt_q < 224 && h_cnt_next < 256) begin
      vram_addr_o = VRAM_BASE + (16'(v_cnt_q) << 5) + 16'(h_cnt_next[7:3]);
    end else begin
      vram_addr_o = 16'h0000;
    end
  end
  
  always_ff @(posedge clk_i) begin
    if (vclk_en) begin
      if (h_cnt_q[2:0] == 0) begin
        // At start of 8-pixel block, latch the byte from memory port
        pixel_byte_q <= vram_data_i;
      end else begin
        // Shift out bits (LSB first)
        pixel_byte_q <= {1'b0, pixel_byte_q[7:1]};
      end
    end
  end
  
  assign video_o = pixel_byte_q[0] && (h_cnt_q < 256) && (v_cnt_q < 224);

endmodule
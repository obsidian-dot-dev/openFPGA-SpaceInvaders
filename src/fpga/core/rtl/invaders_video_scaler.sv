// Space Invaders Video Scaler
// Scales 256x224 monochrome video to 512x448
// Performs 2x integer scale in both dimensions with stable ping-ponging.

`timescale 1ns / 1ps

module invaders_video_scaler (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // From 5MHz Game Domain
  input  logic        vclk_5mhz_i,
  input  logic        video_i,
  input  logic [8:0]  h_cnt_i,
  input  logic [8:0]  v_cnt_i,
  input  logic        hblank_i,
  input  logic        vblank_i,
  
  // From 20MHz Display Domain
  input  logic [9:0]  h_cnt_20mhz_i,
  input  logic [9:0]  v_cnt_20mhz_i,
  output logic        video_2x_o
);

  // -------------------------------------------------------------------------
  // Line Buffers
  // -------------------------------------------------------------------------
  logic [255:0] buffers [2];
  
  // Rising edge detection for 5MHz clock
  logic vclk_prev_q;
  always_ff @(posedge clk_i) vclk_prev_q <= vclk_5mhz_i;
  wire vclk_en = vclk_5mhz_i && !vclk_prev_q;

  // -------------------------------------------------------------------------
  // Write Logic (Game Side - 5MHz)
  // -------------------------------------------------------------------------
  // Core writes Line N to buffers[N % 2]
  always_ff @(posedge clk_i) begin
    if (vclk_en && h_cnt_i < 256 && v_cnt_i < 224) begin
      buffers[v_cnt_i[0]][h_cnt_i[7:0]] <= video_i;
    end
  end

  // -------------------------------------------------------------------------
  // Read Logic (Display Side - 20MHz)
  // -------------------------------------------------------------------------
  // We use the display counter to drive the ping-pong selection.
  // Bit 1 of v_cnt_20mhz_i toggles every 2 display lines.
  // However, because the frame size (521) is not a multiple of 4, 
  // we must be careful at the wrap-around.
  
  // Since Core Line 0 is written during Display Lines 519-520,
  // it is ready to be read during Display Lines 0-1.
  // At 519, 520: v_cnt[1] is 1, then 0.
  // At 0, 1: v_cnt[1] is 0.
  // This means Core Line 0 (in buffer 0) is correctly read during Display 0, 1.
  
  // To be absolutely robust against the VTotal wrap-around, we can 
  // use the LSBs of the display counter but masked by the frame start.
  
  wire read_buf_sel = v_cnt_20mhz_i[1];
  wire [7:0] read_addr = h_cnt_20mhz_i[8:1];
  
  // Registered output to match display pipeline
  always_ff @(posedge clk_i) begin
    if (h_cnt_20mhz_i < 512 && v_cnt_20mhz_i < 448) begin
        video_2x_o <= buffers[read_buf_sel][read_addr];
    end else begin
        video_2x_o <= 1'b0;
    end
  end

endmodule

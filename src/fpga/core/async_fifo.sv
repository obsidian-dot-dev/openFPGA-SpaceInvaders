// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

//------------------------------------------------------------------------------
// Asynchronous FIFO (CDC - Optimized)
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module async_fifo #(
  parameter int unsigned Width = 32,
  parameter int unsigned Depth = 16 
) (
  // Write Domain
  input  logic              wclk_i,
  input  logic              wrst_ni,
  input  logic              wpush_i,
  input  logic [Width-1:0]  wdata_i,
  output logic              wfull_o,

  // Read Domain
  input  logic              rclk_i,
  input  logic              rrst_ni,
  input  logic              rpop_i,
  output logic [Width-1:0]  rdata_o,
  output logic              rempty_o
);

  localparam int unsigned AddrPtrWidth = $clog2(Depth);

  logic [Width-1:0] mem [Depth];

  logic [AddrPtrWidth:0] wptr_bin_q, rptr_bin_q;
  logic [AddrPtrWidth:0] wptr_gray_q, rptr_gray_q;

  logic [AddrPtrWidth:0] wptr_gray_sync_r1, wptr_gray_sync_r2;
  logic [AddrPtrWidth:0] rptr_gray_sync_w1, rptr_gray_sync_w2;

  //----------------------------------------------------------------------------
  // Write Domain
  //----------------------------------------------------------------------------
  always_ff @(posedge wclk_i or negedge wrst_ni) begin
    if (!wrst_ni) begin
      wptr_bin_q  <= '0;
      wptr_gray_q <= '0;
    end else if (wpush_i && !wfull_o) begin
      wptr_bin_q  <= wptr_bin_q + 1'b1;
      wptr_gray_q <= ((wptr_bin_q + 1'b1) >> 1) ^ (wptr_bin_q + 1'b1);
    end
  end

  always_ff @(posedge wclk_i) begin
    if (wpush_i && !wfull_o) mem[wptr_bin_q[AddrPtrWidth-1:0]] <= wdata_i;
  end

  always_ff @(posedge wclk_i or negedge wrst_ni) begin
    if (!wrst_ni) begin
      rptr_gray_sync_w1 <= '0;
      rptr_gray_sync_w2 <= '0;
    end else begin
      rptr_gray_sync_w1 <= rptr_gray_q;
      rptr_gray_sync_w2 <= rptr_gray_sync_w1;
    end
  end

  // Full condition: MSB and next-to-MSB of Gray pointers are inverted, rest match
  assign wfull_o = (wptr_gray_q == {~rptr_gray_sync_w2[AddrPtrWidth:AddrPtrWidth-1], 
                                     rptr_gray_sync_w2[AddrPtrWidth-2:0]});

  //----------------------------------------------------------------------------
  // Read Domain
  //----------------------------------------------------------------------------
  always_ff @(posedge rclk_i or negedge rrst_ni) begin
    if (!rrst_ni) begin
      rptr_bin_q  <= '0;
      rptr_gray_q <= '0;
    end else if (rpop_i && !rempty_o) begin
      rptr_bin_q  <= rptr_bin_q + 1'b1;
      rptr_gray_q <= ((rptr_bin_q + 1'b1) >> 1) ^ (rptr_bin_q + 1'b1);
    end
  end

  assign rdata_o = mem[rptr_bin_q[AddrPtrWidth-1:0]];

  always_ff @(posedge rclk_i or negedge rrst_ni) begin
    if (!rrst_ni) begin
      wptr_gray_sync_r1 <= '0;
      wptr_gray_sync_r2 <= '0;
    end else begin
      wptr_gray_sync_r1 <= wptr_gray_q;
      wptr_gray_sync_r2 <= wptr_gray_sync_r1;
    end
  end

  assign rempty_o = (rptr_gray_q == wptr_gray_sync_r2);

endmodule

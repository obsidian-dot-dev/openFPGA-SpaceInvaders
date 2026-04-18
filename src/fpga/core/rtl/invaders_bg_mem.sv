// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Background Memory
// Stores 8 pixels per entry (4bpp each)

module invaders_bg_mem (
  input  logic        clk_i,
  input  logic [12:0] addr_i, // 0-7167
  output logic [31:0] data_o
);

  // 32 bytes per line * 224 lines = 7168 entries
  logic [31:0] mem [0:7167] /* verilator public */;

  always_ff @(posedge clk_i) begin
    data_o <= mem[addr_i];
  end

endmodule : invaders_bg_mem
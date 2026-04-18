// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Memory Module - Optimized for synchronous BRAM inference
module invaders_mem (
  input  logic        clk_i,
  input  logic        clk_en_i,
  
  // Port A (CPU)
  input  logic [15:0] addr_a_i,
  input  logic [7:0]  data_a_i,
  input  logic        wr_a_en_i,
  output logic [7:0]  data_a_o,
  
  // Port B (Video)
  input  logic [15:0] addr_b_i,
  output logic [7:0]  data_b_o,
    
  // Loading Port (External - 19-bit for high assets)
  input  logic [18:0] load_addr_i,
  input  logic [7:0]  load_data_i,
  input  logic        load_en_i
);

  import invaders_pkg::*;

  // 1. Core RAM/ROM
  (* ramstyle = "M10K" *) logic [7:0] rom [0:8191];
  (* ramstyle = "M10K" *) logic [7:0] ram [0:8191];

  logic [12:0] ram_addr_a, ram_addr_b, rom_addr_a;
  logic [7:0]  ram_din_a;
  logic        ram_we_a, rom_we_a;

  assign ram_addr_a = load_en_i ? load_addr_i[12:0] : addr_a_i[12:0];
  assign ram_din_a  = load_en_i ? load_data_i : data_a_i;
  assign ram_we_a   = load_en_i ? (load_addr_i[15:13] == 3'b001 && load_addr_i[18:16] == 3'b000) : 
                                  (clk_en_i && wr_a_en_i && (addr_a_i[15:13] == 3'b001));

  assign ram_addr_b = addr_b_i[12:0];
  assign rom_addr_a = load_en_i ? load_addr_i[12:0] : addr_a_i[12:0];
  assign rom_we_a   = load_en_i && (load_addr_i[15:13] == 3'b000 && load_addr_i[18:16] == 3'b000);

  logic [7:0] ram_q_a, ram_q_b, rom_q_a;
  logic is_ram_sel_a_q, is_ram_sel_b_q;

  always_ff @(posedge clk_i) begin
    if (ram_we_a) ram[ram_addr_a] <= ram_din_a;
    ram_q_a <= ram[ram_addr_a];
    ram_q_b <= ram[ram_addr_b];
    is_ram_sel_a_q <= (addr_a_i[15:13] == 3'b001);
    is_ram_sel_b_q <= (addr_b_i[15:13] == 3'b001);
  end

  always_ff @(posedge clk_i) begin
    if (rom_we_a) rom[rom_addr_a] <= load_data_i;
    rom_q_a <= rom[rom_addr_a];
  end

  assign data_a_o = is_ram_sel_a_q ? ram_q_a : rom_q_a;
  assign data_b_o = is_ram_sel_b_q ? ram_q_b : 8'h00;

endmodule
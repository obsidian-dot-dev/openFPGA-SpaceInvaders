// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders Bus Controller
// Handles address decoding and I/O routing

module invaders_bus (
  input  logic        clk_i,
  input  logic        rst_ni,
  
  // 8080 Interface
  input  logic [15:0] cpu_addr_i,
  input  logic [7:0]  cpu_data_out_i,
  input  logic [7:0]  cpu_status_i,
  input  logic        cpu_sync_i,
  input  logic        cpu_wr_n_i,
  input  logic        cpu_dbin_i,
  output logic [7:0]  cpu_data_in_o,
  
  // Memory Interface
  output logic [15:0] mem_addr_o,
  output logic [7:0]  mem_data_o,
  output logic        mem_wr_en_o,
  input  logic [7:0]  mem_data_i,
  
  // Peripheral Interface
  output logic [2:0]  io_port_o,
  output logic [7:0]  io_data_o,
  output logic        io_rd_en_o,
  output logic        io_wr_en_o,
  input  logic [7:0]  io_data_i,

  // Status Export
  output logic        inta_o
);

  import invaders_pkg::*;

  // Status Latch
  logic [7:0] status_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      status_q <= 8'h00;
    end else if (cpu_sync_i) begin
      status_q <= cpu_status_i;
    end
  end

  // Status Decoding
  // Bit 7: MEMR, Bit 6: INP, Bit 5: M1, Bit 4: OUT, Bit 1: WO_n, Bit 0: INTA
  logic is_mem_rd, is_mem_wr, is_io_rd, is_io_wr, is_inta;
  assign is_mem_rd = status_q[7] || status_q[5];
  assign is_io_rd  = status_q[6];
  assign is_io_wr  = status_q[4];
  assign is_mem_wr = !status_q[1] && !status_q[4] && !status_q[0];
  assign is_inta   = status_q[0];
  
  assign inta_o = is_inta;

  // Bus Signal Routing
  assign mem_addr_o   = cpu_addr_i;
  assign mem_data_o   = cpu_data_out_i;
  assign mem_wr_en_o  = is_mem_wr && !cpu_wr_n_i;

  assign io_port_o    = cpu_addr_i[2:0];
  assign io_data_o    = cpu_data_out_i;
  assign io_wr_en_o   = is_io_wr && !cpu_wr_n_i;
  assign io_rd_en_o   = is_io_rd && cpu_dbin_i;

  // Data Input Mux
  always_comb begin
    if (is_inta) begin
      cpu_data_in_o = io_data_i; // Vector comes from I/O block / Int Ctrl
    end else if (is_mem_rd) begin
      cpu_data_in_o = mem_data_i;
    end else if (is_io_rd) begin
      cpu_data_in_o = io_data_i;
    end else begin
      cpu_data_in_o = 8'hFF;
    end
  end

endmodule

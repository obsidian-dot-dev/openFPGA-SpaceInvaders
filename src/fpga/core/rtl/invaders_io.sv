// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Space Invaders I/O Controller
// Manages input ports, output latches, and the shift hardware

module invaders_io (
  input  logic        clk_i,
  input  logic        clk_en_i,
  input  logic        rst_ni,
  
  // Bus Interface
  input  logic [2:0]  io_port_i,
  input  logic [7:0]  io_data_i,
  input  logic        io_rd_en_i,
  input  logic        io_wr_en_i,
  output logic [7:0]  io_data_o,
  
  // External Inputs (Joysticks, Buttons, DIPs)
  input  logic [7:0]  port0_i,
  input  logic [7:0]  port1_i,
  input  logic [7:0]  port2_i,
  
  // External Outputs (Audio, etc.)
  output logic [7:0]  port3_o,
  output logic [7:0]  port5_o,
  output logic        watchdog_reset_o
);

  import invaders_pkg::*;

  // Shift Register Instance
  logic [7:0] shift_res;
  invaders_shift_reg u_shift (
    .clk_i,
    .clk_en_i,
    .rst_ni,
    .data_i        (io_data_i),
    .shift_amount_i(io_data_i[2:0]),
    .load_data_i   (io_wr_en_i && (io_port_i == PORT_OUT4)),
    .load_amount_i (io_wr_en_i && (io_port_i == PORT_OUT2)),
    .data_o        (shift_res)
  );

  // Read Port Multiplexing
  always_comb begin
    if (io_rd_en_i) begin
      unique case (io_port_i)
        PORT_IN0: io_data_o = port0_i;
        PORT_IN1: io_data_o = port1_i;
        PORT_IN2: io_data_o = port2_i;
        PORT_IN3: io_data_o = shift_res;
        default:  io_data_o = 8'hFF;
      endcase
    end else begin
      io_data_o = 8'hFF;
    end
  end

  // Write Port Latches
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      port3_o          <= 8'h00;
      port5_o          <= 8'h00;
      watchdog_reset_o <= 1'b0;
    end else if (clk_en_i) begin
      watchdog_reset_o <= 1'b0;
      if (io_wr_en_i) begin
        unique case (io_port_i)
          PORT_OUT3: port3_o <= io_data_i;
          PORT_OUT5: port5_o <= io_data_i;
          PORT_OUT6: watchdog_reset_o <= 1'b1;
          default: ;
        endcase
      end
    end
  end

endmodule

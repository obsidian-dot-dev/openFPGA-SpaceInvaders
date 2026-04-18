`timescale 1ns / 1ps

`ifndef FIFO_SV
`define FIFO_SV

module fifo #(
  parameter int unsigned Width = 32,
  parameter int unsigned Depth = 8
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              flush_i,
  output logic              full_o,
  output logic              empty_o,
  output logic [$clog2(Depth+1)-1:0] usage_o,
  input  logic [Width-1:0]  data_i,
  input  logic              push_i,
  output logic [Width-1:0]  data_o,
  input  logic              pop_i
);

  localparam int unsigned IdxWidth = $clog2(Depth);

  logic [Depth-1:0][Width-1:0] mem_q;
  logic [IdxWidth-1:0] wr_ptr_q, rd_ptr_q;
  logic [$clog2(Depth+1)-1:0] count_q;

  assign full_o  = (count_q == Depth);
  assign empty_o = (count_q == 0);
  assign usage_o = count_q;
  assign data_o  = mem_q[rd_ptr_q];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q  <= '0;
      mem_q    <= '0;
    end else if (flush_i) begin
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q  <= '0;
    end else begin
      if (push_i && !full_o) begin
        mem_q[wr_ptr_q] <= data_i;
        wr_ptr_q        <= (wr_ptr_q == (Depth - 1)) ? '0 : (wr_ptr_q + 1'b1);
      end
      if (pop_i && !empty_o) begin
        rd_ptr_q        <= (rd_ptr_q == (Depth - 1)) ? '0 : (rd_ptr_q + 1'b1);
      end
      if (push_i && !full_o && !(pop_i && !empty_o)) begin
        count_q <= count_q + 1'b1;
      end else if (pop_i && !empty_o && !(push_i && !full_o)) begin
        count_q <= count_q - 1'b1;
      end
    end
  end

endmodule : fifo

`endif // FIFO_SV

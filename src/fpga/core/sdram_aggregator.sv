// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

`timescale 1ns / 1ps

module sdram_aggregator (
    input  logic         clk_i,
    input  logic         rst_ni,

    // Input from Data Loader (16-bit)
    input  logic         in_wr_i,
    input  logic [24:0]  in_addr_i,
    input  logic [15:0]  in_data_i,
    output logic         in_ack_o,

    // Output to SDRAM Controller (128-bit)
    output logic         out_wr_o,
    output logic [24:0]  out_addr_o,
    output logic [127:0] out_wdata_o,
    output logic [15:0]  out_be_o,
    input  logic         out_ready_i
);

    logic [2:0]   word_ptr_q;
    logic [127:0] buffer_q;
    logic [24:0]  base_addr_q;
    logic         pending_q;

    // We can accept new data if we are not currently waiting for the SDRAM controller to acknowledge a burst
    assign in_ack_o = !pending_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            word_ptr_q  <= '0;
            buffer_q    <= '0;
            base_addr_q <= '0;
            out_wr_o    <= 1'b0;
            out_wdata_o <= '0;
            out_addr_o  <= '0;
            out_be_o    <= '0;
            pending_q   <= 1'b0;
        end else begin
            if (pending_q) begin
                // Hold the write request until the SDRAM controller says it's ready
                out_wr_o <= 1'b1;
                if (out_ready_i) begin
                    pending_q <= 1'b0;
                    out_wr_o  <= 1'b0;
                end
            end else if (in_wr_i) begin
                if (word_ptr_q == 3'd0) begin
                    base_addr_q <= in_addr_i;
                end
                
                // Pack the 16-bit word into the 128-bit buffer
                buffer_q[word_ptr_q * 16 +: 16] <= in_data_i;
                
                if (word_ptr_q == 3'd7) begin
                    word_ptr_q <= 3'd0;
                    pending_q  <= 1'b1;
                    
                    // Setup the 128-bit burst output
                    out_addr_o  <= base_addr_q & 25'h1FFFFF8; // Force alignment to 8-word boundary
                    // buffer_q[111:0] contains words 0 to 6. Word 7 is currently in in_data_i
                    out_wdata_o <= {in_data_i, buffer_q[111:0]};
                    out_be_o    <= 16'hFFFF;
                    out_wr_o    <= 1'b1;
                end else begin
                    word_ptr_q <= word_ptr_q + 3'd1;
                end
            end
        end
    end
endmodule

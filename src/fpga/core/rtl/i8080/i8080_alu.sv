// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

`default_nettype none

module i8080_alu 
    import i8080_pkg::*;
(
    input  logic [7:0]  op_a,
    input  logic [7:0]  op_b,
    input  flags_t      flags_in,
    input  i8080_pkg::alu_op_t op,
    
    output logic [7:0]  res,
    output flags_t      flags_out
);
    
    logic [8:0] sum;
    
    always_comb begin
        res = op_a;
        flags_out = flags_in;
        
        sum = 0;
        
        case (op)
            ALU_ADD: begin
                sum = {1'b0, op_a} + {1'b0, op_b};
                res = sum[7:0];
                flags_out[0] = sum[8];
                flags_out[4] = (5'({1'b0, op_a[3:0]} + {1'b0, op_b[3:0]}) > 5'hF);
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
            end
            ALU_ADC: begin
                sum = {1'b0, op_a} + {1'b0, op_b} + {8'h00, flags_in[0]};
                res = sum[7:0];
                flags_out[0] = sum[8];
                flags_out[4] = (5'({1'b0, op_a[3:0]} + {1'b0, op_b[3:0]} + {4'h0, flags_in[0]}) > 5'hF);
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
            end
            ALU_SUB, ALU_CMP: begin
                sum = {1'b0, op_a} - {1'b0, op_b};
                res = sum[7:0];
                flags_out[0] = sum[8]; // Carry (Borrow)
                flags_out[4] = (op_a[3:0] >= op_b[3:0]); // AC: set if NO borrow
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
                if (op == ALU_CMP) res = op_a;
            end
            ALU_SBB: begin
                sum = {1'b0, op_a} - {1'b0, op_b} - {8'h00, flags_in[0]};
                res = sum[7:0];
                flags_out[0] = sum[8];
                flags_out[4] = ({1'b0, op_a[3:0]} >= ({1'b0, op_b[3:0]} + {4'h0, flags_in[0]}));
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
            end
            ALU_ANA: begin
                res = op_a & op_b;
                flags_out[0] = 0;
                flags_out[4] = ((op_a | op_b) & 8'h08) != 0;
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
            end
            ALU_XRA: begin
                res = op_a ^ op_b;
                flags_out[0] = 0;
                flags_out[4] = 0;
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
            end
            ALU_ORA: begin
                res = op_a | op_b;
                flags_out[0] = 0;
                flags_out[4] = 0;
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
            end
            ALU_RLC: begin
                res = {op_a[6:0], op_a[7]};
                flags_out[0] = op_a[7];
            end
            ALU_RRC: begin
                res = {op_a[0], op_a[7:1]};
                flags_out[0] = op_a[0];
            end
            ALU_RAL: begin
                res = {op_a[6:0], flags_in[0]};
                flags_out[0] = op_a[7];
            end
            ALU_RAR: begin
                res = {flags_in[0], op_a[7:1]};
                flags_out[0] = op_a[0];
            end
            ALU_CMA: begin
                res = ~op_a;
            end
            ALU_STC: begin
                flags_out[0] = 1;
            end
            ALU_CMC: begin
                flags_out[0] = ~flags_in[0];
            end
            ALU_INR: begin
                res = op_a + 8'h01;
                flags_out[4] = (op_a[3:0] == 4'hF);
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
            end
            ALU_DCR: begin
                res = op_a - 8'h01;
                flags_out[4] = (op_a[3:0] != 4'h0); // AC for DCR: set if NO borrow
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
            end
            ALU_DAA: begin
                logic [7:0] daa_add;
                daa_add = 0;
                if ((op_a[3:0] > 9) || flags_in[4]) daa_add[3:0] = 6;
                if ((op_a > 8'h99) || flags_in[0]) begin
                    daa_add[7:4] = 6;
                    flags_out[0] = 1;
                end
                res = op_a + daa_add;
                flags_out[4] = (5'({1'b0, op_a[3:0]} + {1'b0, daa_add[3:0]}) > 5'hF);
                flags_out[6] = (res == 0);
                flags_out[7] = res[7];
                flags_out[2] = ~(^res);
            end
            default: ;
        endcase
        
        // Final normalization to ensure hardware-consistent bit values
        flags_out[1] = 1'b1;
        flags_out[3] = 1'b0;
        flags_out[5] = 1'b0;
    end

endmodule
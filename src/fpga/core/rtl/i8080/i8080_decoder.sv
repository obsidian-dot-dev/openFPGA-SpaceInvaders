// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

`default_nettype none

module i8080_decoder (
    input  logic [7:0]  ir,
    
    // Control Flags
    output logic        is_nop,
    output logic        is_hlt,
    output logic        is_mov,
    output logic        is_mov_r_r,
    output logic        is_mov_r_m,
    output logic        is_mov_m_r,
    output logic        is_mvi,
    output logic        is_lxi,
    output logic        is_lda,
    output logic        is_sta,
    output logic        is_ldax,
    output logic        is_stax,
    output logic        is_lhld,
    output logic        is_shld,
    output logic        is_xchg,
    output logic        is_inr,
    output logic        is_dcr,
    output logic        is_inx,
    output logic        is_dcx,
    output logic        is_dad,
    output logic        is_jmp,
    output logic        is_call,
    output logic        is_ret,
    output logic        is_push,
    output logic        is_pop,
    output logic        is_rst,
    output logic        is_sphl,
    output logic        is_pchl,
    output logic        is_xthl,
    output logic        is_in,
    output logic        is_out,
    output logic        is_ei,
    output logic        is_di,
    
    output logic        is_alu_reg, 
    output logic        is_alu_imm,
    
    output i8080_pkg::alu_op_t alu_op
);

    import i8080_pkg::*;

    logic is_add, is_adc, is_sub, is_sbb, is_ana, is_xra, is_ora, is_cmp;
    logic is_rot, is_imm_flags; 
    logic is_mov_group;

    always_comb begin
        is_nop = (ir == 8'h00) || (ir == 8'h08) || (ir == 8'h10) || (ir == 8'h18) || (ir == 8'h20) || (ir == 8'h28) || (ir == 8'h30) || (ir == 8'h38);
        is_hlt = (ir == OP_HLT);
        
        // MOV
        is_mov_group = (ir[7:6] == 2'b01) && (ir != 8'h76);
        is_mov_r_m = is_mov_group && (ir[2:0] == 3'd6);
        is_mov_m_r = is_mov_group && (ir[5:3] == 3'd6);
        is_mov_r_r = is_mov_group && !is_mov_r_m && !is_mov_m_r;
        is_mov = is_mov_group; 
        
        is_mvi = (ir[7:6] == 2'b00) && (ir[2:0] == 3'b110);
        is_lxi = (ir[7:6] == 2'b00) && (ir[3:0] == 4'b0001);
        is_lda = (ir == 8'h3A);
        is_sta = (ir == 8'h32);
        is_ldax = (ir[7:6] == 2'b00) && (ir[3:0] == 4'b1010);
        is_stax = (ir[7:6] == 2'b00) && (ir[3:0] == 4'b0010);
        is_lhld = (ir == 8'h2A);
        is_shld = (ir == 8'h22);
        is_xchg = (ir == 8'hEB);
        
        is_add = (ir[7:3] == 5'b10000); 
        is_adc = (ir[7:3] == 5'b10001); 
        is_sub = (ir[7:3] == 5'b10010); 
        is_sbb = (ir[7:3] == 5'b10011); 
        is_ana = (ir[7:3] == 5'b10100); 
        is_xra = (ir[7:3] == 5'b10101); 
        is_ora = (ir[7:3] == 5'b10110); 
        is_cmp = (ir[7:3] == 5'b10111);
        
        is_alu_imm = (ir[7:6] == 2'b11) && (ir[2:0] == 3'b110);
        is_inr = (ir[7:6] == 2'b00) && (ir[2:0] == 3'b100);
        is_dcr = (ir[7:6] == 2'b00) && (ir[2:0] == 3'b101);
        is_inx = (ir[7:6] == 2'b00) && (ir[3:0] == 4'b0011);
        is_dcx = (ir[7:6] == 2'b00) && (ir[3:0] == 4'b1011);
        is_dad = (ir[7:6] == 2'b00) && (ir[3:0] == 4'b1001);
        
        is_rot = (ir == 8'h07 || ir == 8'h0F || ir == 8'h17 || ir == 8'h1F);
        is_imm_flags = (ir == 8'h2F || ir == 8'h3F || ir == 8'h37 || ir == 8'h27); 
        
        is_jmp = (ir == 8'hC3) || (ir == 8'hCB) || ((ir[7:6] == 2'b11) && (ir[2:0] == 3'b010));
        is_call = (ir == 8'hCD) || (ir == 8'hDD) || (ir == 8'hED) || (ir == 8'hFD) || ((ir[7:6] == 2'b11) && (ir[2:0] == 3'b100));
        is_ret = (ir == 8'hC9) || (ir == 8'hD9) || ((ir[7:6] == 2'b11) && (ir[2:0] == 3'b000));
        is_push = (ir[7:6] == 2'b11) && (ir[3:0] == 4'b0101);
        is_pop = (ir[7:6] == 2'b11) && (ir[3:0] == 4'b0001);
        is_rst = (ir[7:6] == 2'b11) && (ir[2:0] == 3'b111);
        
        is_sphl = (ir == 8'hF9);
        is_pchl = (ir == 8'hE9);
        is_xthl = (ir == 8'hE3);
        
        is_in = (ir == 8'hDB);
        is_out = (ir == 8'hD3);
        is_ei = (ir == 8'hFB);
        is_di = (ir == 8'hF3);
        
        is_alu_reg = is_add | is_adc | is_sub | is_sbb | is_ana | is_xra | is_ora | is_cmp | is_rot | is_imm_flags;
        
        alu_op = ALU_ADD;
        if (is_add) alu_op = ALU_ADD;
        else if (is_adc) alu_op = ALU_ADC;
        else if (is_sub) alu_op = ALU_SUB;
        else if (is_sbb) alu_op = ALU_SBB;
        else if (is_ana) alu_op = ALU_ANA;
        else if (is_xra) alu_op = ALU_XRA;
        else if (is_ora) alu_op = ALU_ORA;
        else if (is_cmp) alu_op = ALU_CMP;
        else if (is_alu_imm) begin
            case (ir[5:3])
                3'd0: alu_op = ALU_ADD;
                3'd1: alu_op = ALU_ADC;
                3'd2: alu_op = ALU_SUB;
                3'd3: alu_op = ALU_SBB;
                3'd4: alu_op = ALU_ANA;
                3'd5: alu_op = ALU_XRA;
                3'd6: alu_op = ALU_ORA;
                3'd7: alu_op = ALU_CMP;
                default: ;
            endcase
        end
        else if (ir == 8'h07) alu_op = ALU_RLC;
        else if (ir == 8'h0F) alu_op = ALU_RRC;
        else if (ir == 8'h17) alu_op = ALU_RAL;
        else if (ir == 8'h1F) alu_op = ALU_RAR;
        else if (ir == 8'h2F) alu_op = ALU_CMA;
        else if (ir == 8'h3F) alu_op = ALU_CMC;
        else if (ir == 8'h37) alu_op = ALU_STC;
        else if (ir == 8'h27) alu_op = ALU_DAA;
        else if (is_inr) alu_op = ALU_INR;
        else if (is_dcr) alu_op = ALU_DCR;
    end

endmodule

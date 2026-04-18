// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

package i8080_pkg;

    // -------------------------------------------------------------------------
    // Opcodes
    // -------------------------------------------------------------------------
    typedef enum logic [7:0] {
        OP_NOP  = 8'h00,
        OP_HLT  = 8'h76,
        OP_MOV_B_B = 8'h40,
        OP_ADD_B = 8'h80
    } opcode_t;

    // -------------------------------------------------------------------------
    // ALU Operations
    // -------------------------------------------------------------------------
    typedef enum logic [4:0] {
        ALU_ADD = 5'd0,
        ALU_ADC = 5'd1,
        ALU_SUB = 5'd2,
        ALU_SBB = 5'd3,
        ALU_ANA = 5'd4,
        ALU_XRA = 5'd5,
        ALU_ORA = 5'd6,
        ALU_CMP = 5'd7,
        ALU_RLC = 5'd8,
        ALU_RRC = 5'd9,
        ALU_RAL = 5'd10,
        ALU_RAR = 5'd11,
        ALU_DAA = 5'd12,
        ALU_CMA = 5'd13,
        ALU_STC = 5'd14,
        ALU_CMC = 5'd15,
        ALU_INR = 5'd16,
        ALU_DCR = 5'd17
    } alu_op_t;

    // -------------------------------------------------------------------------
    // Register Selectors
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        REG_B = 3'd0,
        REG_C = 3'd1,
        REG_D = 3'd2,
        REG_E = 3'd3,
        REG_H = 3'd4,
        REG_L = 3'd5,
        REG_M = 3'd6, 
        REG_A = 3'd7
    } reg_sel_t;

    typedef enum logic [1:0] {
        RP_BC = 2'd0,
        RP_DE = 2'd1,
        RP_HL = 2'd2,
        RP_SP = 2'd3
    } rp_sel_t;

    // -------------------------------------------------------------------------
    // Flags
    // -------------------------------------------------------------------------
    localparam int FLAG_S_BIT  = 7;
    localparam int FLAG_Z_BIT  = 6;
    localparam int FLAG_AC_BIT = 4;
    localparam int FLAG_P_BIT  = 2;
    localparam int FLAG_C_BIT  = 0;

    typedef logic [7:0] flags_t;

    // -------------------------------------------------------------------------
    // States
    // -------------------------------------------------------------------------
    typedef enum logic [4:0] {
        S_FETCH,
        S_EXECUTE,
        S_MEM_READ,
        S_MEM_WRITE,
        S_STACK_PUSH,
        S_STACK_POP,
        S_HALT
    } state_t;

endpackage
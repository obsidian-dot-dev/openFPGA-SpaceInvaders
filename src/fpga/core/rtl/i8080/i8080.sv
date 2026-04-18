// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

`default_nettype none

module i8080 (
    input  logic        clk,
    input  logic        reset, 
    
    output logic [15:0] addr,
    input  logic [7:0]  data_in,
    output logic [7:0]  data_out,
    output logic        data_out_en, 
    
    output logic        wr_n, 
    output logic        dbin, 
    output logic        sync, 
    output logic        hold_a, 
    output logic        wait_a, 
    
    input  logic        intr, 
    output logic        inte, 
    
    output logic [7:0]  status_out,
    output logic [15:0] pc_o
);

    import i8080_pkg::*;

    // -------------------------------------------------------------------------
    // Registers & State
    // -------------------------------------------------------------------------
    logic [15:0] pc , pc_next ;
    logic [15:0] sp , sp_next;
    logic [7:0]  a , a_next;
    logic [7:0]  b , b_next;
    logic [7:0]  c , c_next;
    logic [7:0]  d , d_next;
    logic [7:0]  e , e_next;
    logic [7:0]  h , h_next;
    logic [7:0]  l , l_next;
    flags_t      f , f_next;
    
    logic [7:0]  ir, ir_next;
    logic [15:0] maddr, maddr_next; 
    logic [7:0]  maddr_low, maddr_low_next;
    logic [7:0]  temp_reg, temp_reg_next; 
    logic [15:0] target_pc, target_pc_next;
    logic [7:0]  high_val, low_val;
    logic        ei_pending, ei_pending_next;
    logic        inta_cycle, inta_cycle_next;
    
    state_t      state , next_state;
    logic [3:0]  t_state , next_t_state;
    logic [2:0]  step , next_step;
    
    // Temp signals for always_comb
    logic [7:0]  src_val_f;
    logic [15:0] rp_val, rp_res;
    logic [16:0] dad_res;
    logic [15:0] target_jmp;
    logic [15:0] val_pop;
    logic [15:0] rp_val_dad;

    // Decoder Signals
    logic is_nop, is_hlt, is_mov, is_alu_reg, is_mvi, is_lxi, is_lda, is_sta;
    logic is_ldax, is_stax, is_lhld, is_shld, is_xchg, is_alu_imm;
    logic is_inr, is_dcr, is_inx, is_dcx, is_dad;
    logic is_jmp, is_call, is_ret, is_push, is_pop, is_rst;
    logic is_sphl, is_pchl, is_xthl;
    logic is_in, is_out, is_ei, is_di;
    logic is_mov_r_r, is_mov_r_m, is_mov_m_r;
    alu_op_t decoder_alu_op;
    
    i8080_decoder decoder (
        .ir(ir),
        .is_nop(is_nop),
        .is_hlt(is_hlt),
        .is_mov(is_mov),
        .is_mov_r_r(is_mov_r_r),
        .is_mov_r_m(is_mov_r_m),
        .is_mov_m_r(is_mov_m_r),
        .is_mvi(is_mvi),
        .is_lxi(is_lxi),
        .is_lda(is_lda),
        .is_sta(is_sta),
        .is_ldax(is_ldax),
        .is_stax(is_stax),
        .is_lhld(is_lhld),
        .is_shld(is_shld),
        .is_xchg(is_xchg),
        .is_inx(is_inx),
        .is_dcx(is_dcx),
        .is_dad(is_dad),
        .is_jmp(is_jmp),
        .is_call(is_call),
        .is_ret(is_ret),
        .is_push(is_push),
        .is_pop(is_pop),
        .is_rst(is_rst),
        .is_sphl(is_sphl),
        .is_pchl(is_pchl),
        .is_xthl(is_xthl),
        .is_in(is_in),
        .is_out(is_out),
        .is_ei(is_ei),
        .is_di(is_di),
        .is_alu_reg(is_alu_reg),
        .is_alu_imm(is_alu_imm),
        .is_inr(is_inr),
        .is_dcr(is_dcr),
        .alu_op(decoder_alu_op)
    );
    
    // ALU Signals
    logic [7:0] alu_op_a, alu_op_b;
    alu_op_t    alu_cmd;
    logic [7:0] alu_res;
    flags_t     alu_flags;
    
    i8080_alu alu (
        .op_a(alu_op_a),
        .op_b(alu_op_b),
        .flags_in(f),
        .op(alu_cmd),
        .res(alu_res),
        .flags_out(alu_flags)
    );
    
    logic cond_met;
    always_comb begin
        case (ir[5:3])
            3'd0: cond_met = !f[6]; // NZ (Z is bit 6)
            3'd1: cond_met = f[6];  // Z
            3'd2: cond_met = !f[0]; // NC (C is bit 0)
            3'd3: cond_met = f[0];  // C
            3'd4: cond_met = !f[2]; // PO (P is bit 2)
            3'd5: cond_met = f[2];  // PE
            3'd6: cond_met = !f[7]; // P (S is bit 7)
            3'd7: cond_met = f[7];  // M
            default: cond_met = 1;
        endcase
        if (ir == 8'hC3 || ir == 8'hCB || ir == 8'hCD || ir == 8'hDD || ir == 8'hED || ir == 8'hFD || ir == 8'hC9 || ir == 8'hD9) cond_met = 1;
    end

    // -------------------------------------------------------------------------
    // Debug Tags
    // -------------------------------------------------------------------------
    /* verilator public_module */
    logic [15:0] debug_pc /* verilator public_flat */;
    assign debug_pc = pc;
    assign pc_o = pc;

    // -------------------------------------------------------------------------
    // Combinatorial Logic
    // -------------------------------------------------------------------------
    always_comb begin
        // Initialize temps
        src_val_f = 0;
        rp_val = 0; rp_res = 0; dad_res = 0; target_jmp = 0; val_pop = 0; rp_val_dad = 0;

        // Stack Value Muxing
        high_val = 0;
        low_val = 0;
        case (ir[5:4])
            2'd0: begin high_val = b; low_val = c; end
            2'd1: begin high_val = d; low_val = e; end
            2'd2: begin high_val = h; low_val = l; end
            2'd3: begin high_val = a; low_val = f; end
            default: ;
        endcase

        // ALU Muxing
        alu_op_a = a;
        if (is_inr || is_dcr) begin
            case (ir[5:3])
                3'd0: alu_op_a = b;
                3'd1: alu_op_a = c;
                3'd2: alu_op_a = d;
                3'd3: alu_op_a = e;
                3'd4: alu_op_a = h;
                3'd5: alu_op_a = l;
                3'd6: alu_op_a = (state == S_MEM_READ && t_state == 2) ? data_in : temp_reg; 
                3'd7: alu_op_a = a;
                default: alu_op_a = a;
            endcase
        end
        
        alu_op_b = 0;
        alu_cmd = decoder_alu_op;
        
        case (ir[2:0])
            3'd0: alu_op_b = b;
            3'd1: alu_op_b = c;
            3'd2: alu_op_b = d;
            3'd3: alu_op_b = e;
            3'd4: alu_op_b = h;
            3'd5: alu_op_b = l;
            3'd6: alu_op_b = (state == S_MEM_READ && t_state == 2) ? data_in : temp_reg; 
            3'd7: alu_op_b = a;
        endcase
        
        if (is_alu_imm) begin
            alu_op_b = (state == S_MEM_READ && t_state == 2) ? data_in : temp_reg;
        end

        // Default Next State: Hold values
        next_state = state;
        next_t_state = t_state;
        next_step = step;
        pc_next = pc; 
        sp_next = sp;
        a_next = a; b_next = b; c_next = c; d_next = d; e_next = e; h_next = h; l_next = l;
        f_next = f;
        ir_next = ir;
        maddr_next = maddr;
        maddr_low_next = maddr_low;
        temp_reg_next = temp_reg;
        target_pc_next = target_pc;
        ei_pending_next = 0;
        inta_cycle_next = inta_cycle;
        
        // Default Outputs
        addr = 0;
        data_out = 0; data_out_en = 0;
        wr_n = 1; dbin = 0; sync = 0;
        hold_a = 0; wait_a = 0; status_out = 0;
        
        case (state)
            S_FETCH: begin
                `include "states/s_fetch.svh"
            end
            S_MEM_READ: begin
                `include "states/s_mem_rd.svh"
            end
            S_MEM_WRITE: begin
                `include "states/s_mem_wr.svh"
            end
            S_EXECUTE: begin
                `include "states/s_execute.svh"
            end
            S_HALT: begin
                next_state = S_HALT;
                addr = pc;
                sync = 1;
                status_out = 8'h08; // HALT status
            end
            default: begin
                next_state = S_FETCH;
                next_t_state = 0;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Sequential Logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_FETCH;
            t_state <= 0;
            step <= 0;
            pc <= 16'h0000;
            sp <= 16'h0000; 
            ir <= 0;
            maddr <= 0;
            maddr_low <= 0;
            temp_reg <= 0;
            target_pc <= 0;
            a <= 0; b <= 0; c <= 0; d <= 0; e <= 0; h <= 0; l <= 0; f <= 8'h02;
            inte <= 0;
            ei_pending <= 0;
        end else begin
            state <= next_state;
            t_state <= next_t_state;
            step <= next_step;
            pc <= pc_next;
            sp <= sp_next;
            a <= a_next; b <= b_next; c <= c_next; d <= d_next; e <= e_next; h <= h_next; l <= l_next;
            f <= f_next;
            ir <= ir_next;
            maddr <= maddr_next;
            maddr_low <= maddr_low_next;
            temp_reg <= temp_reg_next;
            target_pc <= target_pc_next;
            inta_cycle <= inta_cycle_next;
            
            if (is_ei && state == S_FETCH && t_state == 3) begin
                ei_pending <= 1;
            end else if (ei_pending) begin
                inte <= 1;
                ei_pending <= 0;
            end
            
            if (is_di && state == S_FETCH && t_state == 3) begin
                inte <= 0;
            end

            if (inta_cycle && state == S_FETCH && t_state == 2) begin
                inte <= 0;
                inta_cycle <= 0;
            end
        end
    end

endmodule

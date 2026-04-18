// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Fetch Cycle Logic

if (t_state == 0) begin
    next_step = 0;
    addr = pc;
    sync = 1;
    if (intr && inte) begin
        status_out = 8'h23; // INTA
        inta_cycle_next = 1;
    end else begin
        status_out = 8'hA2; // M1 | MEMR | WO_n
        inta_cycle_next = 0;
    end
    next_t_state = 1;
end else if (t_state == 1) begin
    addr = pc;
    dbin = 1;
    next_t_state = 2;
end else if (t_state == 2) begin
    addr = pc; 
    dbin = 1; 
    ir_next = data_in;
    next_t_state = 3;
    if (inta_cycle) begin
        pc_next = pc; // Don't increment PC during interrupt acknowledge
    end else begin
        pc_next = pc + 1;
    end
end else if (t_state == 3) begin
    if (is_nop) begin
        next_state = S_FETCH;
        next_t_state = 0;
    end else if (is_hlt) begin
        pc_next = pc - 16'h0001;
        next_state = S_HALT; 
    end else if (is_alu_reg) begin
        if ((ir[2:0] == 3'd6) && (ir[7:6] == 2'b10)) begin
            maddr_next = {h, l};
            next_state = S_MEM_READ; 
            next_t_state = 0;
        end else begin
            a_next = alu_res;
            f_next = alu_flags;
            next_state = S_FETCH;
            next_t_state = 0;
        end
    end else if (is_jmp || is_call) begin
        maddr_next = pc;
        next_step = 1;
        next_state = S_MEM_READ;
        next_t_state = 0;
    end else if (is_alu_imm) begin
        maddr_next = pc;
        next_state = S_MEM_READ;
        next_t_state = 0;
    end else if (is_ret) begin
        if (cond_met) begin
            maddr_next = sp;
            next_step = 1;
            next_state = S_MEM_READ;
        end else begin
            next_state = S_EXECUTE;
        end
        next_t_state = 0;
    end else if (is_push) begin
        maddr_next = sp - 16'h0001;
        temp_reg_next = high_val;
        next_step = 1;
        next_state = S_MEM_WRITE;
        next_t_state = 0;
    end else if (is_pop) begin
        maddr_next = sp;
        next_step = 1;
        next_state = S_MEM_READ;
        next_t_state = 0;
    end else if (is_rst) begin
        maddr_next = sp - 16'h0001;
        temp_reg_next = pc_next[15:8];
        maddr_low_next = pc_next[7:0];
        next_step = 1;
        next_state = S_MEM_WRITE;
        next_t_state = 0;
    end else if (is_dad) begin
        next_state = S_EXECUTE;
        next_t_state = 0;
    end else if (is_inx || is_dcx) begin
        next_state = S_EXECUTE;
        next_t_state = 0;
    end else if (is_lhld || is_shld) begin
        maddr_next = pc;
        next_step = 1;
        next_state = S_MEM_READ;
        next_t_state = 0;
    end else if (is_xchg) begin
        h_next = d; l_next = e;
        d_next = h; e_next = l;
        next_state = S_FETCH;
        next_t_state = 0;
    end else if (is_lda || is_sta) begin
        maddr_next = pc;
        next_step = 1;
        next_state = S_MEM_READ;
        next_t_state = 0;
    end else if (is_ldax || is_stax) begin
        if (ir[4]) begin maddr_next = {d, e}; end
        else begin maddr_next = {b, c}; end
        if (is_ldax) begin next_state = S_MEM_READ; end
        else begin
            temp_reg_next = a;
            next_state = S_MEM_WRITE;
        end
        next_t_state = 0;
    end else if (is_lxi) begin
        maddr_next = pc;
        next_step = 1;
        next_state = S_MEM_READ;
        next_t_state = 0;
    end else if (is_mvi) begin
        if (ir[5:3] == 3'd6) begin
            maddr_next = pc;
            next_state = S_MEM_READ;
        end else begin
            maddr_next = pc; 
            next_state = S_MEM_READ;
        end
        next_t_state = 0;
    end else if (is_mov_r_m) begin
        maddr_next = {h, l};
        next_state = S_MEM_READ;
        next_t_state = 0;
    end else if (is_mov_m_r) begin
        maddr_next = {h, l};
        case (ir[2:0])
            3'd0: temp_reg_next = b;
            3'd1: temp_reg_next = c;
            3'd2: temp_reg_next = d;
            3'd3: temp_reg_next = e;
            3'd4: temp_reg_next = h;
            3'd5: temp_reg_next = l;
            3'd7: temp_reg_next = a;
            default: temp_reg_next = 0;
        endcase
        next_state = S_MEM_WRITE;
        next_t_state = 0;
    end else if (is_inr || is_dcr) begin
        if (ir[5:3] == 3'd6) begin
            maddr_next = {h, l};
            next_state = S_MEM_READ;
            next_t_state = 0;
        end else begin
            next_state = S_EXECUTE;
            next_t_state = 0;
        end
    end else if (is_in || is_out) begin
        maddr_next = pc;
        next_step = 1;
        next_state = S_MEM_READ;
        next_t_state = 0;
    end else if (is_ei || is_di) begin
        next_state = S_FETCH;
        next_t_state = 0;
    end else if (is_mov_r_r) begin
        case (ir[2:0])
            3'd0: src_val_f = b;
            3'd1: src_val_f = c;
            3'd2: src_val_f = d;
            3'd3: src_val_f = e;
            3'd4: src_val_f = h;
            3'd5: src_val_f = l;
            3'd7: src_val_f = a;
            default: src_val_f = 0;
        endcase
        case (ir[5:3])
            3'd0: b_next = src_val_f;
            3'd1: c_next = src_val_f;
            3'd2: d_next = src_val_f;
            3'd3: e_next = src_val_f;
            3'd4: h_next = src_val_f;
            3'd5: l_next = src_val_f;
            3'd7: a_next = src_val_f;
            default: ;
        endcase
        next_state = S_FETCH;
        next_t_state = 0;
    end else if (is_sphl) begin
        sp_next = {h, l};
        next_state = S_FETCH;
        next_t_state = 0;
    end else if (is_pchl) begin
        pc_next = {h, l};
        next_state = S_FETCH;
        next_t_state = 0;
    end else if (is_xthl) begin
        maddr_next = sp;
        next_step = 1;
        next_state = S_MEM_READ;
        next_t_state = 0;
    end else begin
        next_state = S_EXECUTE; 
        next_t_state = 0;
    end
end

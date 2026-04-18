// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Memory Read Cycle (M2/M3/M4/M5)
if (t_state == 0) begin
    addr = maddr;
    sync = 1;
    status_out = 8'h82; // MEMR
    if (is_in || is_out) begin
        if (step == 2) begin
            status_out = is_in ? 8'h42 : 8'h10;
        end
    end
    next_t_state = 1;
end else if (t_state == 1) begin
    addr = maddr;
    dbin = (is_out && step == 2) ? 1'b0 : 1'b1;
    next_t_state = 2;
end else if (t_state == 2) begin
    addr = maddr;
    dbin = (is_out && step == 2) ? 1'b0 : 1'b1;
    temp_reg_next = data_in;
    
    if (is_mvi) begin
        if (ir[5:3] == 3'd6) begin
            maddr_next = {h, l};
            temp_reg_next = data_in;
            pc_next = pc + 1;
            next_state = S_MEM_WRITE;
            next_t_state = 0;
        end else begin
            case (ir[5:3])
                3'd0: b_next = data_in;
                3'd1: c_next = data_in;
                3'd2: d_next = data_in;
                3'd3: e_next = data_in;
                3'd4: h_next = data_in;
                3'd5: l_next = data_in;
                3'd7: a_next = data_in;
                default: ;
            endcase
            pc_next = pc + 1;
            next_state = S_FETCH;
            next_t_state = 0;
        end
    end else if (is_lxi) begin
        if (step == 1) begin
            case (ir[5:4])
                2'd0: c_next = data_in;
                2'd1: e_next = data_in;
                2'd2: l_next = data_in;
                2'd3: sp_next[7:0] = data_in;
            endcase
            maddr_next = pc + 1;
            pc_next = pc + 1;
            next_step = 2;
            next_state = S_MEM_READ;
            next_t_state = 0;
        end else begin
            case (ir[5:4])
                2'd0: b_next = data_in;
                2'd1: d_next = data_in;
                2'd2: h_next = data_in;
                2'd3: sp_next[15:8] = data_in;
            endcase
            pc_next = pc + 1;
            next_state = S_FETCH;
            next_t_state = 0;
            next_step = 0;
        end
    end else if (is_lhld || is_shld) begin
        if (step == 1) begin
            maddr_low_next = data_in;
            maddr_next = pc + 1;
            pc_next = pc + 1;
            next_step = 2;
            next_state = S_MEM_READ;
            next_t_state = 0;
        end else if (step == 2) begin
            maddr_next = {data_in, maddr_low};
            pc_next = pc + 1;
            next_step = 3;
            if (is_lhld) begin
                next_state = S_MEM_READ;
            end else begin
                temp_reg_next = l;
                next_state = S_MEM_WRITE;
            end
            next_t_state = 0;
        end else if (step == 3) begin
            if (is_lhld) begin
                l_next = data_in;
                maddr_next = maddr + 16'h0001;
                next_step = 4;
                next_state = S_MEM_READ;
            end
            next_t_state = 0;
        end else begin
            if (is_lhld) begin
                h_next = data_in;
            end
            next_state = S_FETCH;
            next_t_state = 0;
            next_step = 0;
        end
    end else if (is_lda || is_sta) begin
        if (step == 1) begin
            maddr_low_next = data_in;
            maddr_next = pc + 1;
            pc_next = pc + 1;
            next_step = 2;
            next_state = S_MEM_READ;
            next_t_state = 0;
        end else if (step == 2) begin
            maddr_next = {data_in, maddr_low};
            pc_next = pc + 1;
            next_step = 3;
            if (is_lda) begin
                next_state = S_MEM_READ;
            end else begin
                temp_reg_next = a;
                next_state = S_MEM_WRITE;
            end
            next_t_state = 0;
        end else begin
            if (is_lda) begin
                a_next = data_in;
            end
            next_state = S_FETCH;
            next_t_state = 0;
            next_step = 0;
        end
    end else if (is_ldax) begin
        a_next = data_in;
        next_state = S_FETCH;
        next_t_state = 0;
    end else if (is_alu_reg && (ir[2:0] == 3'd6)) begin
        a_next = alu_res;
        f_next = alu_flags;
        next_state = S_FETCH;
        next_t_state = 0;
    end else if (is_alu_imm) begin
        a_next = alu_res;
        f_next = alu_flags;
        pc_next = pc + 1;
        next_state = S_FETCH;
        next_t_state = 0;
    end else if ((is_inr || is_dcr) && (ir[5:3] == 3'd6)) begin
        maddr_next = {h, l};
        temp_reg_next = alu_res;
        f_next = alu_flags;
        next_state = S_MEM_WRITE;
        next_t_state = 0;
    end else if (is_jmp || is_call) begin
        if (step == 1) begin
            maddr_low_next = data_in;
            maddr_next = pc + 1;
            pc_next = pc + 1;
            next_step = 2;
            next_state = S_MEM_READ;
            next_t_state = 0;
        end else if (step == 2) begin
            target_jmp = {data_in, maddr_low};
            pc_next = pc + 1;
            if (cond_met) begin
                if (is_jmp) begin
                    pc_next = target_jmp;
                    next_state = S_FETCH;
                end else begin
                    target_pc_next = target_jmp;
                    maddr_next = sp - 16'h0001;
                    temp_reg_next = pc_next[15:8];
                    maddr_low_next = pc_next[7:0];
                    next_step = 3;
                    next_state = S_MEM_WRITE;
                end
            end else begin
                next_state = S_FETCH;
            end
            next_t_state = 0;
        end
    end else if (is_ret) begin
        if (step == 1) begin
            maddr_low_next = data_in;
            maddr_next = sp + 16'h0001;
            next_step = 2;
            next_state = S_MEM_READ;
            next_t_state = 0;
        end else begin
            pc_next = {data_in, maddr_low};
            sp_next = sp + 16'h0002;
            next_state = S_FETCH;
            next_t_state = 0;
            next_step = 0;
        end
    end else if (is_pop) begin
        if (step == 1) begin
            maddr_low_next = data_in;
            maddr_next = sp + 16'h0001;
            next_step = 2;
            next_state = S_MEM_READ;
            next_t_state = 0;
        end else begin
            val_pop = {data_in, maddr_low};
            case (ir[5:4])
                2'd0: begin b_next = val_pop[15:8]; c_next = val_pop[7:0]; end
                2'd1: begin d_next = val_pop[15:8]; e_next = val_pop[7:0]; end
                2'd2: begin h_next = val_pop[15:8]; l_next = val_pop[7:0]; end
                2'd3: begin
                    a_next = val_pop[15:8];
                    f_next = (val_pop[7:0] & 8'hD5) | 8'h02;
                end
                default: ;
            endcase
            sp_next = sp + 16'h0002;
            next_state = S_FETCH;
            next_t_state = 0;
            next_step = 0;
        end
    end else if (is_xthl) begin
        if (step == 1) begin
            maddr_low_next = data_in;
            maddr_next = sp + 16'h0001;
            next_step = 2;
            next_state = S_MEM_READ;
            next_t_state = 0;
        end else begin
            target_pc_next = {data_in, maddr_low};
            maddr_next = sp + 16'h0001;
            temp_reg_next = h;
            maddr_low_next = l;
            next_step = 3;
            next_state = S_MEM_WRITE;
            next_t_state = 0;
        end
    end else if (is_in || is_out) begin
        if (step == 1) begin
            maddr_next = {8'h00, data_in};
            pc_next = pc + 1;
            next_step = 2;
            if (is_out) begin
                temp_reg_next = a;
                next_state = S_MEM_WRITE;
            end else begin
                next_state = S_MEM_READ;
            end
            next_t_state = 0;
        end else begin
            a_next = data_in;
            next_state = S_FETCH;
            next_t_state = 0;
            next_step = 0;
        end
    end else if (is_mov_r_m) begin
        case (ir[5:3])
            3'd0: b_next = data_in;
            3'd1: c_next = data_in;
            3'd2: d_next = data_in;
            3'd3: e_next = data_in;
            3'd4: h_next = data_in;
            3'd5: l_next = data_in;
            3'd7: a_next = data_in;
            default: ;
        endcase
        next_state = S_FETCH;
        next_t_state = 0;
    end else begin
        temp_reg_next = data_in;
        next_state = S_EXECUTE; 
        next_t_state = 0;
    end
end

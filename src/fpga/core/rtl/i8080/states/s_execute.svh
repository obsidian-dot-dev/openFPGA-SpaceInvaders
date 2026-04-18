// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Execute State Logic (Internal operations)

if (is_nop) begin
    next_state = S_FETCH;
    next_t_state = 0;
end else if (is_hlt) begin
    next_state = S_HALT;
end else if (is_alu_reg) begin
    if ((ir[2:0] == 3'd6) && (ir[7:6] == 2'b10)) begin
        next_state = S_FETCH;
        next_t_state = 0;
    end else begin
        a_next = alu_res;
        f_next = alu_flags;
        next_state = S_FETCH;
        next_t_state = 0;
    end
end else if (is_mvi) begin
    next_state = S_FETCH;
    next_t_state = 0;
end else if (is_mov_r_m) begin
    next_state = S_FETCH;
    next_t_state = 0;
end else if (is_mov_m_r) begin
    next_state = S_FETCH;
    next_t_state = 0;
end else if (is_inr || is_dcr) begin
    case (ir[5:3])
        3'd0: b_next = alu_res;
        3'd1: c_next = alu_res;
        3'd2: d_next = alu_res;
        3'd3: e_next = alu_res;
        3'd4: h_next = alu_res;
        3'd5: l_next = alu_res;
        3'd6: begin end
        3'd7: a_next = alu_res;
        default: ;
    endcase
    if (ir[5:3] != 3'd6) begin
        f_next = alu_flags;
        next_state = S_FETCH;
        next_t_state = 0;
    end
end else if (is_inx || is_dcx) begin
    case (ir[5:4])
        2'd0: rp_val = {b, c};
        2'd1: rp_val = {d, e};
        2'd2: rp_val = {h, l};
        2'd3: rp_val = sp;
        default: rp_val = 0;
    endcase
    if (is_inx) begin
        rp_res = rp_val + 16'h0001;
    end else begin
        rp_res = rp_val - 16'h0001;
    end
    case (ir[5:4])
        2'd0: begin b_next = rp_res[15:8]; c_next = rp_res[7:0]; end
        2'd1: begin d_next = rp_res[15:8]; e_next = rp_res[7:0]; end
        2'd2: begin h_next = rp_res[15:8]; l_next = rp_res[7:0]; end
        2'd3: begin sp_next = rp_res; end
        default: ;
    endcase
    next_state = S_FETCH;
    next_t_state = 0;
end else if (is_dad) begin
    if (t_state < 5) begin
        next_t_state = t_state + 4'd1;
    end else begin
        case (ir[5:4])
            2'd0: rp_val_dad = {b, c};
            2'd1: rp_val_dad = {d, e};
            2'd2: rp_val_dad = {h, l};
            2'd3: rp_val_dad = sp;
            default: rp_val_dad = 0;
        endcase
        dad_res = {1'b0, h, l} + {1'b0, rp_val_dad};
        h_next = dad_res[15:8];
        l_next = dad_res[7:0];
        f_next[0] = dad_res[16];
        next_state = S_FETCH;
        next_t_state = 0;
    end
end else begin
    next_state = S_FETCH;
    next_t_state = 0;
end

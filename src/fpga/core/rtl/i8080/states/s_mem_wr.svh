// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

// Memory Write Cycle
if (t_state == 0) begin
    addr = maddr;
    sync = 1;
    status_out = 8'h00; 
    if (is_out) begin
        status_out = 8'h10;
    end
    next_t_state = 1;
end else if (t_state == 1) begin
    addr = maddr;
    data_out = temp_reg; 
    data_out_en = 1;
    next_t_state = 2;
end else if (t_state == 2) begin
    addr = maddr;
    data_out = temp_reg;
    data_out_en = 1;
    wr_n = 0; 
    
    if (is_shld && (step == 3)) begin
        maddr_next = maddr + 16'h0001;
        temp_reg_next = h;
        next_step = 4;
        next_state = S_MEM_WRITE;
        next_t_state = 0;
    end else if (is_call && (step == 3)) begin
        maddr_next = sp - 16'h0002;
        temp_reg_next = maddr_low; 
        next_step = 4;
        next_state = S_MEM_WRITE;
        next_t_state = 0;
    end else if (is_call && (step == 4)) begin
        next_t_state = 3;
    end else if (is_push && (step == 1)) begin
        maddr_next = sp - 16'h0002;
        temp_reg_next = low_val;
        next_step = 2;
        next_state = S_MEM_WRITE;
        next_t_state = 0;
    end else if (is_push && (step == 2)) begin
        next_t_state = 3;
    end else if (is_rst && (step == 1)) begin
        maddr_next = sp - 16'h0002;
        temp_reg_next = maddr_low;
        next_step = 2;
        next_state = S_MEM_WRITE;
        next_t_state = 0;
    end else if (is_rst && (step == 2)) begin
        next_t_state = 3;
    end else if (is_xthl && (step == 3)) begin
        maddr_next = sp;
        temp_reg_next = maddr_low; 
        next_step = 4;
        next_state = S_MEM_WRITE;
        next_t_state = 0;
    end else if (is_xthl && (step == 4)) begin
        next_t_state = 3;
    end else if (is_out) begin
        next_state = S_FETCH;
        next_step = 0;
        next_t_state = 0;
    end else begin
        next_state = S_FETCH;
        next_step = 0;
        next_t_state = 0;
    end
end else if (t_state == 3) begin
    if (is_xthl) begin
        next_t_state = 4;
    end else begin
        if (is_call) begin
            pc_next = target_pc;
            sp_next = sp - 16'h0002;
        end else if (is_rst) begin
            pc_next = {10'h000, ir[5:3], 3'b000};
            sp_next = sp - 16'h0002;
        end else if (is_push) begin
            sp_next = sp - 16'h0002;
        end
        next_state = S_FETCH;
        next_step = 0;
        next_t_state = 0;
    end
end else if (t_state == 4) begin
    if (is_xthl) begin
        h_next = target_pc[15:8];
        l_next = target_pc[7:0];
    end
    next_state = S_FETCH;
    next_step = 0;
    next_t_state = 0;
end
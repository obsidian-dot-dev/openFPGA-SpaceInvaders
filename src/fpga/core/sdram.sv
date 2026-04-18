// SPDX-License-Identifier: MIT
// Copyright (c) 2026, Obsidian.dev

`timescale 1 ps / 1 ps

module sdram #(
    parameter int CLOCK_SPEED_MHZ = 93,
    parameter int BURST_TYPE      = 0,  // 0: Sequential, 1: Interleaved
    parameter int CAS_LATENCY     = 2,  // 2 or 3 cycle delays
    parameter int WRITE_BURST     = 0,  // 0: Single Word, 1: Burst
    parameter bit SIMULATION      = 1'b0
) (
    input wire clk,
    input wire reset,
    output wire init_complete,

    // --- High-Width Physical Port (to Arbiter) ---
    input wire [24:0]           addr_i,
    input wire [127:0]          data_i,      // Max 128-bit block
    input wire [15:0]           byte_en_i,   // 2 bits per 16-bit word
    input wire [3:0]            burst_len_i, // 1 to 8 words
    output reg [127:0]          q_o,

    input wire wr_req_i,
    input wire rd_req_i,

    output wire available_o,
    output reg  ready_o = 0,

    // --- SDRAM Pins ---
    inout  wire [15:0] SDRAM_DQ,
    
    (* fastout *) output reg  [12:0] SDRAM_A,
    (* fastout *) output reg  [ 1:0] SDRAM_DQM,
    (* fastout *) output reg  [ 1:0] SDRAM_BA,
    (* fastout *) output wire        SDRAM_nCS,
    (* fastout *) output wire        SDRAM_nRAS,
    (* fastout *) output wire        SDRAM_nCAS,
    (* fastout *) output wire        SDRAM_nWE,
    (* fastout *) output reg         SDRAM_CKE,
    output wire        SDRAM_CLK
);
  // Integer Timing Calculations (Quartus Compatible)
  localparam int PERIOD_PS = 1000000 / CLOCK_SPEED_MHZ;
  
  localparam int CYCLES_UNTIL_START_INHIBIT = (50000000 + PERIOD_PS - 1) / PERIOD_PS;
  localparam int CYCLES_UNTIL_CLEAR_INHIBIT = 100 + (100000000 + PERIOD_PS - 1) / PERIOD_PS;
  localparam int CYCLES_FOR_AUTOREFRESH     = (80000 + PERIOD_PS - 1) / PERIOD_PS;
  localparam int CYCLES_FOR_ACTIVE_ROW      = (18000 + PERIOD_PS - 1) / PERIOD_PS;
  localparam int CYCLES_AFTER_WRITE         = (33000 + PERIOD_PS - 1) / PERIOD_PS;
  localparam int CYCLES_PER_REFRESH         = (7500000 + PERIOD_PS - 1) / PERIOD_PS;
  
  localparam int CYCLES_INIT_PRECHARGE_END  = 10 + CYCLES_UNTIL_CLEAR_INHIBIT + CYCLES_FOR_ACTIVE_ROW;
  localparam int CYCLES_INIT_REFRESH1_END   = CYCLES_INIT_PRECHARGE_END + CYCLES_FOR_AUTOREFRESH;
  localparam int CYCLES_INIT_REFRESH2_END   = CYCLES_INIT_REFRESH1_END + CYCLES_FOR_AUTOREFRESH;

  // Single-word mode register config
  wire [12:0] configured_mode = {3'b0, ~WRITE_BURST[0], 2'b0, CAS_LATENCY[2:0], 1'b0, 3'b000};

  typedef enum bit [3:0] {
    COMMAND_NOP           = 4'b0111,
    COMMAND_ACTIVE        = 4'b0011,
    COMMAND_READ          = 4'b0101,
    COMMAND_WRITE         = 4'b0100,
    COMMAND_PRECHARGE     = 4'b0010,
    COMMAND_AUTO_REFRESH  = 4'b0001,
    COMMAND_LOAD_MODE_REG = 4'b0000
  } command_e;

  typedef enum bit [2:0] {
    ST_INIT,
    ST_IDLE,
    ST_DELAY,
    ST_WRITE,
    ST_READ,
    ST_READ_OUTPUT,
    ST_DONE
  } state_e;

  state_e state, delay_state;
  reg [31:0] delay_counter = 0;
  reg [3:0]  burst_counter = 0;
  reg [3:0]  capture_counter = 0;
  reg [15:0] refresh_counter = 0;
  
  command_e sdram_command;
  assign {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} = sdram_command;

  reg [24:0]  active_addr_q;
  reg [127:0] active_data_q;
  reg [15:0]  active_be_q;
  reg [3:0]   active_burst_len_q;

  // Accumulation shadow register
  reg [127:0] active_q_q;

  // DQ Tri-state control
  reg dq_output = 0;
  reg [15:0] sdram_data_q = 0;
  assign SDRAM_DQ = dq_output ? sdram_data_q : 16'hZZZZ;
  
  // Dedicated Input Pipeline Register (forces IOE packing for fast timing)
  (* fastin *) reg [15:0] sdram_dq_in;
  always @(posedge clk) sdram_dq_in <= SDRAM_DQ;

  assign init_complete = (state != ST_INIT);
  assign available_o   = (state == ST_IDLE);

  // Synchronous data selection for physical writes
  always @(posedge clk) begin
    if (reset) begin
      sdram_data_q <= 0;
      SDRAM_DQM    <= 2'b11;
    end else begin
      sdram_data_q <= 16'h0;
      SDRAM_DQM    <= 2'b00; 
      if (state == ST_WRITE) begin
          case (burst_counter)
              0: begin sdram_data_q <= active_data_q[15:0];   SDRAM_DQM <= ~active_be_q[1:0];   end
              1: begin sdram_data_q <= active_data_q[31:16];  SDRAM_DQM <= ~active_be_q[3:2];   end
              2: begin sdram_data_q <= active_data_q[47:32];  SDRAM_DQM <= ~active_be_q[5:4];   end
              3: begin sdram_data_q <= active_data_q[63:48];  SDRAM_DQM <= ~active_be_q[7:6];   end
              4: begin sdram_data_q <= active_data_q[79:64];  SDRAM_DQM <= ~active_be_q[9:8];   end
              5: begin sdram_data_q <= active_data_q[95:80];  SDRAM_DQM <= ~active_be_q[11:10]; end
              6: begin sdram_data_q <= active_data_q[111:96]; SDRAM_DQM <= ~active_be_q[13:12]; end
              7: begin sdram_data_q <= active_data_q[127:112];SDRAM_DQM <= ~active_be_q[15:14]; end
              default: ;
          endcase
      end else if (state == ST_INIT && delay_counter == 32'(CYCLES_UNTIL_CLEAR_INHIBIT)) begin
          SDRAM_DQM <= 2'b00; 
      end
    end
  end

  // Pipeline for physical read data capture
  reg [7:0] read_capture_pipe = 0;

  always @(posedge clk) begin
    if (reset) begin
      SDRAM_CKE <= 0;
      state <= ST_INIT;
      delay_counter <= 0;
      burst_counter <= 0;
      capture_counter <= 0;
      refresh_counter <= 0;
      ready_o <= 0;
      dq_output <= 0;
      q_o <= 0;
      active_q_q <= 0;
      active_addr_q <= 0;
      active_data_q <= 0;
      active_be_q <= 0;
      active_burst_len_q <= 0;
      SDRAM_A <= 0;
      SDRAM_BA <= 0;
      read_capture_pipe <= 0;
    end else begin
      sdram_command <= COMMAND_NOP;
      if (state != ST_INIT) refresh_counter <= refresh_counter + 16'h1;

      // Pipeline Shift
      read_capture_pipe <= {read_capture_pipe[6:0], (sdram_command == COMMAND_READ)};

      case (state)
        ST_INIT: begin
          delay_counter <= delay_counter + 32'h1;
          if (delay_counter == 32'(CYCLES_UNTIL_START_INHIBIT)) begin
            SDRAM_CKE <= 1;
          end else if (delay_counter == 32'(CYCLES_UNTIL_CLEAR_INHIBIT)) begin
            sdram_command <= COMMAND_PRECHARGE;
            SDRAM_A[10]   <= 1; // Precharge all
          end else if (delay_counter == 32'(CYCLES_INIT_PRECHARGE_END) || delay_counter == 32'(CYCLES_INIT_REFRESH1_END)) begin
            sdram_command <= COMMAND_AUTO_REFRESH;
          end else if (delay_counter == 32'(CYCLES_INIT_REFRESH2_END)) begin
            sdram_command <= COMMAND_LOAD_MODE_REG;
            SDRAM_BA <= 2'b0;
            SDRAM_A <= configured_mode;
          end else if (delay_counter == 32'(CYCLES_INIT_REFRESH2_END + 2)) begin
            state <= ST_IDLE;
          end
        end

        ST_IDLE: begin
          dq_output <= 0;
          ready_o <= 0;
          
          if (!ready_o && (wr_req_i || rd_req_i)) begin
            active_addr_q      <= addr_i;
            active_data_q      <= data_i;
            active_be_q        <= byte_en_i;
            active_burst_len_q <= burst_len_i;
            burst_counter      <= 0;
            capture_counter    <= 0;
            active_q_q         <= 0; 
            
            state <= ST_DELAY;
            delay_state <= wr_req_i ? ST_WRITE : ST_READ;
            delay_counter <= 32'(CYCLES_FOR_ACTIVE_ROW - 2);
            
            sdram_command <= COMMAND_ACTIVE;
            SDRAM_BA <= addr_i[24:23];
            SDRAM_A  <= addr_i[22:10]; // Row
          end else if (refresh_counter >= CYCLES_PER_REFRESH[15:0]) begin
            state <= ST_DELAY;
            delay_state <= ST_IDLE;
            delay_counter <= 32'(CYCLES_FOR_AUTOREFRESH - 2);
            refresh_counter <= 0;
            sdram_command <= COMMAND_AUTO_REFRESH;
          end
        end

        ST_DELAY: begin
          if (delay_counter > 0) begin
            delay_counter <= delay_counter - 32'h1;
          end else begin
            state <= delay_state;
          end
        end

        ST_WRITE: begin
          sdram_command <= COMMAND_WRITE;
          SDRAM_BA <= active_addr_q[24:23];
          // Auto-Precharge on final word
          SDRAM_A  <= {2'b0, (burst_counter == active_burst_len_q - 1), active_addr_q[9:0]} + 13'(burst_counter); 
          dq_output <= 1;
          
          if (burst_counter == active_burst_len_q - 1) begin
            state <= ST_DELAY;
            delay_state <= ST_DONE;
            delay_counter <= 32'(CYCLES_AFTER_WRITE - 2);
          end else begin
            burst_counter <= burst_counter + 1;
            state <= ST_WRITE; 
          end
        end

        ST_READ: begin
          sdram_command <= COMMAND_READ;
          SDRAM_BA <= active_addr_q[24:23];
          // Auto-Precharge on final word
          SDRAM_A  <= {2'b0, (burst_counter == active_burst_len_q - 1), active_addr_q[9:0]} + 13'(burst_counter);
          
          if (burst_counter == active_burst_len_q - 1) begin
            state <= ST_READ_OUTPUT;
            burst_counter <= 0;
          end else begin
            burst_counter <= burst_counter + 1;
            state <= ST_READ;
          end
        end

        ST_READ_OUTPUT: begin
          if (capture_counter == active_burst_len_q) begin
             state <= ST_DONE;
          end
        end

        ST_DONE: begin
          dq_output <= 0; // Ensure bus is released
          q_o <= active_q_q; 
          ready_o <= 1;
          state <= ST_IDLE;
        end
      endcase

      // Shadow Accumulation Logic (Bit-Accurate Burst Builder)
      // We use CAS_LATENCY (instead of CAS_LATENCY-1) because sdram_dq_in adds 1 cycle of delay
      if (read_capture_pipe[CAS_LATENCY]) begin
          case (capture_counter)
            0: active_q_q[15:0]   <= sdram_dq_in;
            1: active_q_q[31:16]  <= sdram_dq_in;
            2: active_q_q[47:32]  <= sdram_dq_in;
            3: active_q_q[63:48]  <= sdram_dq_in;
            4: active_q_q[79:64]  <= sdram_dq_in;
            5: active_q_q[95:80]  <= sdram_dq_in;
            6: active_q_q[111:96] <= sdram_dq_in;
            7: active_q_q[127:112]<= sdram_dq_in;
          endcase
          capture_counter <= capture_counter + 1;
      end
    end
  end

  // SDRAM Clock (Differential/Phase-aligned for Hardware)
  altddio_out #(.extend_oe_disable("OFF"),.intended_device_family("Cyclone V"),.invert_output("OFF"),.lpm_hint("UNUSED"),.lpm_type("altddio_out"),.oe_reg("UNREGISTERED"),.power_up_high("OFF"),.width(1)) sdramclk_ddr (.datain_h(1'b0),.datain_l(1'b1),.outclock(clk),.dataout(SDRAM_CLK),.oe(1'b1),.outclocken(1'b1));

endmodule

//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

//
// physical connections
//

///////////////////////////////////////////////////
// clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

input   wire            clk_74a, // mainclk1
input   wire            clk_74b, // mainclk1 

///////////////////////////////////////////////////
// cartridge interface
// switches between 3.3v and 5v mechanically
// output enable for multibit translators controlled by pic32

// GBA AD[15:8]
inout   wire    [7:0]   cart_tran_bank2,
output  wire            cart_tran_bank2_dir,

// GBA AD[7:0]
inout   wire    [7:0]   cart_tran_bank3,
output  wire            cart_tran_bank3_dir,

// GBA A[23:16]
inout   wire    [7:0]   cart_tran_bank1,
output  wire            cart_tran_bank1_dir,

// GBA [7] PHI#
// GBA [6] WR#
// GBA [5] RD#
// GBA [4] CS1#/CS#
//     [3:0] unwired
inout   wire    [7:4]   cart_tran_bank0,
output  wire            cart_tran_bank0_dir,

// GBA CS2#/RES#
inout   wire            cart_tran_pin30,
output  wire            cart_tran_pin30_dir,
// when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
// the goal is that when unconfigured, the FPGA weak pullups won't interfere.
// thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
// and general IO drive this pin.
output  wire            cart_pin30_pwroff_reset,

// GBA IRQ/DRQ
inout   wire            cart_tran_pin31,
output  wire            cart_tran_pin31_dir,

// infrared
input   wire            port_ir_rx,
output  wire            port_ir_tx,
output  wire            port_ir_rx_disable, 

// GBA link port
inout   wire            port_tran_si,
output  wire            port_tran_si_dir,
inout   wire            port_tran_so,
output  wire            port_tran_so_dir,
inout   wire            port_tran_sck,
output  wire            port_tran_sck_dir,
inout   wire            port_tran_sd,
output  wire            port_tran_sd_dir,
 
///////////////////////////////////////////////////
// cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

output  wire    [21:16] cram0_a,
inout   wire    [15:0]  cram0_dq,
input   wire            cram0_wait,
output  wire            cram0_clk,
output  wire            cram0_adv_n,
output  wire            cram0_cre,
output  wire            cram0_ce0_n,
output  wire            cram0_ce1_n,
output  wire            cram0_oe_n,
output  wire            cram0_we_n,
output  wire            cram0_ub_n,
output  wire            cram0_lb_n,

output  wire    [21:16] cram1_a,
inout   wire    [15:0]  cram1_dq,
input   wire            cram1_wait,
output  wire            cram1_clk,
output  wire            cram1_adv_n,
output  wire            cram1_cre,
output  wire            cram1_ce0_n,
output  wire            cram1_ce1_n,
output  wire            cram1_oe_n,
output  wire            cram1_we_n,
output  wire            cram1_ub_n,
output  wire            cram1_lb_n,

///////////////////////////////////////////////////
// sdram, 512mbit 16bit

output  wire    [12:0]  dram_a,
output  wire    [1:0]   dram_ba,
inout   wire    [15:0]  dram_dq,
output  wire    [1:0]   dram_dqm,
output  wire            dram_clk,
output  wire            dram_cke,
output  wire            dram_ras_n,
output  wire            dram_cas_n,
output  wire            dram_we_n,

///////////////////////////////////////////////////
// sram, 1mbit 16bit

output  wire    [16:0]  sram_a,
inout   wire    [15:0]  sram_dq,
output  wire            sram_oe_n,
output  wire            sram_we_n,
output  wire            sram_ub_n,
output  wire            sram_lb_n,

///////////////////////////////////////////////////
// vblank driven by dock for sync in a certain mode

input   wire            vblank,

///////////////////////////////////////////////////
// i/o to 6515D breakout usb uart

output  wire            dbg_tx,
input   wire            dbg_rx,

///////////////////////////////////////////////////
// i/o pads near jtag connector user can solder to

output  wire            user1,
input   wire            user2,

///////////////////////////////////////////////////
// RFU internal i2c bus 

inout   wire            aux_sda,
output  wire            aux_scl,

///////////////////////////////////////////////////
// RFU, do not use
output  wire            vpll_feed,


//
// logical connections
//

///////////////////////////////////////////////////
// video, audio output to scaler
output  wire    [23:0]  video_rgb,
output  wire            video_rgb_clock,
output  wire            video_rgb_clock_90,
output  wire            video_de,
output  wire            video_skip,
output  wire            video_vs,
output  wire            video_hs,
    
output  wire            audio_mclk,
input   wire            audio_adc,
output  wire            audio_dac,
output  wire            audio_lrck,

///////////////////////////////////////////////////
// bridge bus connection
// synchronous to clk_74a
output  wire            bridge_endian_little,
input   wire    [31:0]  bridge_addr,
input   wire            bridge_rd,
output  reg     [31:0]  bridge_rd_data,
input   wire            bridge_wr,
input   wire    [31:0]  bridge_wr_data,

///////////////////////////////////////////////////
// controller data
// 
// key bitmap:
//   [0]    dpad_up
//   [1]    dpad_down
//   [2]    dpad_left
//   [3]    dpad_right
//   [4]    face_a
//   [5]    face_b
//   [6]    face_x
//   [7]    face_y
//   [8]    trig_l1
//   [9]    trig_r1
//   [10]   trig_l2
//   [11]   trig_r2
//   [12]   trig_l3
//   [13]   trig_r3
//   [14]   face_select
//   [15]   face_start
// joy values - unsigned
//   [ 7: 0] lstick_x
//   [15: 8] lstick_y
//   [23:16] rstick_x
//   [31:24] rstick_y
// trigger values - unsigned
//   [ 7: 0] ltrig
//   [15: 8] rtrig
//
input   wire    [15:0]  cont1_key,
input   wire    [15:0]  cont2_key,
input   wire    [15:0]  cont3_key,
input   wire    [15:0]  cont4_key,
input   wire    [31:0]  cont1_joy,
input   wire    [31:0]  cont2_joy,
input   wire    [31:0]  cont3_joy,
input   wire    [31:0]  cont4_joy,
input   wire    [15:0]  cont1_trig,
input   wire    [15:0]  cont2_trig,
input   wire    [15:0]  cont3_trig,
input   wire    [15:0]  cont4_trig
    
);

localparam int SDRAM_ADDR_WIDTH    = 25;
localparam int SDRAM_DATA_WIDTH    = 16;

// Max width for top-level interface ports
localparam int MAX_PORT_WIDTH      = 128;

localparam logic [SDRAM_ADDR_WIDTH-1:0] SEGMENT_SIZE = 25'h080_0000;

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;

// bridge endianness
assign bridge_endian_little = 0;

// link port is input only
assign port_tran_so = 1'bz;
assign port_tran_so_dir = 1'b0;     // SO is output only
assign port_tran_si = 1'bz;
assign port_tran_si_dir = 1'b0;     // SI is input only
assign port_tran_sck = 1'bz;
assign port_tran_sck_dir = 1'b0;    // clock direction can change
assign port_tran_sd = 1'bz;
assign port_tran_sd_dir = 1'b0;     // SD is input and not used

// tie off the rest of the pins we are not using
assign cram0_a = 'h0;
assign cram0_dq = {16{1'bZ}};
assign cram0_clk = 0;
assign cram0_adv_n = 1;
assign cram0_cre = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n = 1;
assign cram0_we_n = 1;
assign cram0_ub_n = 1;
assign cram0_lb_n = 1;

assign cram1_a = 'h0;
assign cram1_dq = {16{1'bZ}};
assign cram1_clk = 0;
assign cram1_adv_n = 1;
assign cram1_cre = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n = 1;
assign cram1_we_n = 1;
assign cram1_ub_n = 1;
assign cram1_lb_n = 1;

assign sram_a = 'h0;
assign sram_dq = {16{1'bZ}};
assign sram_oe_n  = 1;
assign sram_we_n  = 1;
assign sram_ub_n  = 1;
assign sram_lb_n  = 1;

assign dbg_tx = 1'bZ;
assign user1 = 1'bZ;
assign aux_scl = 1'bZ;
assign vpll_feed = 1'bZ;


// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
always @(*) begin
    casex(bridge_addr)
    default: begin
        bridge_rd_data <= 0;
    end
    32'h60000000: bridge_rd_data <= {31'h0, cs_bg};
    32'h70000000: bridge_rd_data <= monochrome_scanlines;
    32'hF7000000: bridge_rd_data <= analogizer_settings;
    32'hF7000004: bridge_rd_data <= signed_hoff;
    32'hF7000008: bridge_rd_data <= signed_voff;
    32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
    end
    endcase
end


//
// host/target command handler
//
    wire            reset_n;                // driven by host commands, can be used as core-wide reset
    wire    [31:0]  cmd_bridge_rd_data;
    
// bridge host commands
// synchronous to clk_74a
    wire            status_boot_done = pll_core_locked; 
    wire            status_setup_done = pll_core_locked; // rising edge triggers a target command
    wire            status_running = reset_n; // we are running as soon as reset_n goes high

    wire            dataslot_requestread;
    wire    [15:0]  dataslot_requestread_id;
    wire            dataslot_requestread_ack = 1;
    wire            dataslot_requestread_ok = 1;

    wire            dataslot_requestwrite;
    wire    [15:0]  dataslot_requestwrite_id;
    wire            dataslot_requestwrite_ack = 1;
    wire            dataslot_requestwrite_ok = 1;

    wire            dataslot_allcomplete;

    wire            savestate_supported;
    wire    [31:0]  savestate_addr;
    wire    [31:0]  savestate_size;
    wire    [31:0]  savestate_maxloadsize;

    wire            savestate_start;
    wire            savestate_start_ack;
    wire            savestate_start_busy;
    wire            savestate_start_ok;
    wire            savestate_start_err;

    wire            savestate_load;
    wire            savestate_load_ack;
    wire            savestate_load_busy;
    wire            savestate_load_ok;
    wire            savestate_load_err;
    
    wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a


// bridge data slot access

    wire    [9:0]   datatable_addr;
    wire            datatable_wren;
    wire    [31:0]  datatable_data;
    wire    [31:0]  datatable_q;


	 
wire [15:0] p1_btn, p2_btn;
wire [31:0] p1_joy, p2_joy;

reg [15:0] p1_controls_s, p2_controls_s;
reg [31:0] p1_joypad_s, p2_joypad_s;

// ============================================================
// Analogizer adapter (optional, directly controls cart port)
// ============================================================

//Pocket Menu settings
reg [31:0] analogizer_settings = 32'h0;

reg       analogizer_ena;
reg [3:0] analogizer_video_type;
reg [4:0] snac_game_cont_type;
reg [3:0] snac_cont_assignment;
reg [2:0] analogizer_fx;

always @(*) begin
  snac_game_cont_type   = analogizer_settings[4:0];
  snac_cont_assignment  = analogizer_settings[9:6];
  analogizer_video_type = analogizer_settings[13:10];
  analogizer_ena        = analogizer_settings[15];
  analogizer_fx         = analogizer_settings[18:16];
end 

// H/V offset
reg [31:0] signed_hoff = 32'h0;
reg [31:0] signed_voff = 32'h0;

wire [5:0]	hoffset = signed_hoff[5:0];
wire [4:0]	voffset = signed_voff[4:0];


always @(posedge clk_74a) begin
    if((snac_game_cont_type == 5'h0) || (analogizer_ena == 1'b0)) begin //SNAC is disabled
        p1_controls_s <= cont1_key;
        p1_joypad_s   <= cont1_joy;
        p2_controls_s <= cont2_key;
        p2_joypad_s   <= cont2_joy;
    end
    else begin
        case(snac_cont_assignment[1:0])
        2'h0: begin  //SNAC P1 -> Pocket P1
            p1_controls_s <= p1_btn;
            p1_joypad_s   <= p1_joy;
            p2_controls_s <= cont2_key;
            p2_joypad_s   <= cont2_joy;
            end
        2'h1: begin  //SNAC P1 -> Pocket P2
            p1_controls_s <= cont1_key;
            p1_joypad_s   <= cont1_joy;
            p2_controls_s <= p1_btn;
            p2_joypad_s   <= p1_joy;
            end
        2'h2: begin //SNAC P1 -> Pocket P1, SNAC P2 -> Pocket P2
            p1_controls_s <= p1_btn;
            p1_joypad_s   <= p1_joy;
            p2_controls_s <= p2_btn;
            p2_joypad_s   <= p2_joy;
            end
        2'h3: begin //SNAC P1 -> Pocket P2, SNAC P2 -> Pocket P1
            p1_controls_s <= p2_btn;
            p1_joypad_s   <= p2_joy;
            p2_controls_s <= p1_btn;
            p2_joypad_s   <= p1_joy;
            end
        default: begin 
            p1_controls_s <= cont1_key;
            p1_joypad_s   <= cont1_joy;
            p2_controls_s <= cont2_key;
            p2_joypad_s   <= cont2_joy;
            end
        endcase
    end
end

///////////////////////////////////////////////
// System
///////////////////////////////////////////////

wire osnotify_inmenu_s;

synch_3 OSD_S (osnotify_inmenu, osnotify_inmenu_s, clk_sys);


///////////////////////////////////////////////
// ROM
///////////////////////////////////////////////

reg         ioctl_download = 0;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
reg   [7:0] ioctl_index = 0;

always @(posedge clk_74a) begin
    if (dataslot_requestwrite)     ioctl_download <= 1;
    else if (dataslot_allcomplete) ioctl_download <= 0;
end

reg cs_reset;
reg [7:0] cs_dips;

reg [1:0] cs_lives;
reg cs_coinage;
reg cs_bonus;
reg cs_cabinet;
reg cs_bg;
reg [31:0] monochrome_scanlines = 32'h0;
always @(posedge clk_74a) begin
  if(bridge_wr) begin
    casex(bridge_addr)
      32'h20000000: cs_lives		<= bridge_wr_data[1:0];
		32'h30000000: cs_coinage	<= bridge_wr_data[0];
		32'h40000000: cs_cabinet	<= bridge_wr_data[0];
		32'h50000000: cs_bonus		<= bridge_wr_data[0];
		32'h60000000: cs_bg			<= bridge_wr_data[0];
		32'h70000000: monochrome_scanlines <= bridge_wr_data;
	   32'h80000000: cs_reset		<= ~cs_reset;
	   32'hF7000000: analogizer_settings <= bridge_wr_data;
	   32'hF7000004: signed_hoff <= bridge_wr_data;
	   32'hF7000008: signed_voff <= bridge_wr_data;
    endcase
  end  
end

// -- reset circuit
reg last_do_reset;
reg manual_reset = 1'b0;
reg [24:0] reset_count = 25'b0;

always @(posedge clk_sys) begin
	last_do_reset <= cs_reset;
	if (~manual_reset && (cs_reset != last_do_reset) || ~reset_n) begin
		reset_count <= 25'd1;
		manual_reset <= 1'b1;
	end
	else begin
		if (reset_count == 25'b0000111111111111111111111) begin
			reset_count <= 25'b0;
			manual_reset <= 1'b0;
		end
		else begin
			reset_count <= reset_count + 25'd1;
		end
	end
end


wire init_complete;
wire init_complete_s;
synch_3 #(.WIDTH(1)) s_init_s (init_complete, init_complete_s, clk_74a);

// Capture the 1-cycle 74MHz pulse in the 74MHz domain
reg loading_done_74_q;
always @(posedge clk_74a or negedge reset_n) begin
    if (!reset_n) loading_done_74_q <= 1'b0;
    else if (dataslot_allcomplete) loading_done_74_q <= 1'b1;
end

// Synchronize the sticky register into the 20MHz client domain
wire loading_done_q;
synch_3 #(.WIDTH(1)) s_load_done (loading_done_74_q, loading_done_q, clk_client);

wire [2:0] scanline_strength_vid;
synch_3 #(.WIDTH(3)) s_scanlines (monochrome_scanlines[2:0], scanline_strength_vid, clk_vid);

core_bridge_cmd icb (
    .clk(clk_74a), .reset_n(reset_n), .bridge_endian_little(bridge_endian_little), .bridge_addr(bridge_addr), .bridge_rd(bridge_rd),
    .bridge_rd_data(cmd_bridge_rd_data), .bridge_wr(bridge_wr), .bridge_wr_data(bridge_wr_data),
    .status_boot_done(pll_core_locked), .status_setup_done(pll_core_locked), .status_running(reset_n),
    .dataslot_requestread(), .dataslot_requestread_id(), .dataslot_requestread_ack(init_complete_s), .dataslot_requestread_ok(1),
    .dataslot_requestwrite(), .dataslot_requestwrite_id(), .dataslot_requestwrite_ack(init_complete_s), .dataslot_requestwrite_ok(1),
    .dataslot_allcomplete(dataslot_allcomplete), .savestate_supported(1'b0), .osnotify_inmenu(),
    .datatable_addr(), .datatable_wren(), .datatable_data(), .datatable_q()
);

// --- Clock & Reset Domains ---
wire clk_root, pll_bridge_locked;
mf_pllbridge mp0 (.refclk(clk_74a), .rst(0), .outclk_0(clk_root), .locked(pll_bridge_locked));

wire clk_sys, pll_sdram_locked;
mf_pllsdram mp2 (.refclk(clk_root), .rst(~pll_bridge_locked), .outclk_0(clk_sys), .locked(pll_sdram_locked));

wire clk_vid, clk_vid_90, pll_core_locked;
mf_pllbase mp1 (.refclk(clk_root), .rst(~pll_bridge_locked), .outclk_0(), .outclk_1(clk_vid), .outclk_2(clk_vid_90), .locked(pll_core_locked));

assign video_rgb_clock = clk_vid;
assign video_rgb_clock_90 = clk_vid_90;

wire clk_client = clk_vid; // 20MHz
wire rst_client_n;
synch_3 #(.WIDTH(1)) s_rst_client (reset_n, rst_client_n, clk_client);

// --- Virtual Client Ports (Synchronous to clk_client) ---
wire [2:0]         port_wr_req;
wire [2:0]         port_rd_req;
wire [2:0][24:0]   port_addr;
wire [2:0][127:0]  port_wdata;
wire [2:0][127:0]  port_rdata;
wire [2:0][15:0]   port_byte_en;
wire [2:0]         port_available;
wire [2:0]         port_ready;
wire [2:0]         port_rvalid;

// --- Direct ROM Loader ---
wire        rom_loader_wr;
wire [24:0] rom_loader_addr;
wire [7:0]  rom_loader_data;

data_loader #(
    .ADDRESS_MASK_UPPER_4(4'h0),
    .ADDRESS_SIZE(25),    
    .OUTPUT_WORD_SIZE(1) // 8-bit
) rom_loader (
    .clk_74a(clk_74a),
    .clk_memory(clk_client),

    .bridge_wr(bridge_wr),
    .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr),
    .bridge_wr_data(bridge_wr_data),

    .write_en(rom_loader_wr),
    .write_addr(rom_loader_addr),
    .write_data(rom_loader_data)
);

// --- Direct SDRAM Loader Bypass ---
wire        loader_wr;
wire [24:0] loader_addr;
wire [15:0] loader_data;

data_loader #(
    .ADDRESS_MASK_UPPER_4(4'h1),
    .ADDRESS_SIZE(25),
    .WRITE_MEM_CLOCK_DELAY(8), // Safe delay for 100MHz writes
    .OUTPUT_WORD_SIZE(2) // 16-bit output
) backdrop_loader (
    .clk_74a(clk_74a),
    .clk_memory(clk_sys), // Run in 100MHz SDRAM domain

    .bridge_wr(bridge_wr && init_complete_s), // DROP writes if SDRAM is not ready
    .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr),
    .bridge_wr_data(bridge_wr_data),

    .write_en(loader_wr),
    .write_addr(loader_addr),
    .write_data(loader_data)
);

// --- Physical SDRAM Interface ---
wire [24:0]  sd_addr;
wire [127:0] sd_wdata;
wire [127:0] sd_rdata;
wire [15:0]  sd_be;
wire [3:0]   sd_burst;
wire         sd_wr_req, sd_rd_req, sd_available, sd_ready;

sdram #(.CLOCK_SPEED_MHZ(100), .SIMULATION(1'b0)) sdram_inst (
    .clk(clk_sys), .reset(~pll_sdram_locked), .init_complete(init_complete),
    .addr_i(sd_addr), .data_i(sd_wdata), .byte_en_i(sd_be), .burst_len_i(sd_burst),
    .q_o(sd_rdata), .wr_req_i(sd_wr_req), .rd_req_i(sd_rd_req),
    .available_o(sd_available), .ready_o(sd_ready),
    .SDRAM_DQ(dram_dq), .SDRAM_A(dram_a), .SDRAM_DQM(dram_dqm), .SDRAM_BA(dram_ba),
    .SDRAM_nCS(), .SDRAM_nWE(dram_we_n), .SDRAM_nRAS(dram_ras_n), .SDRAM_nCAS(dram_cas_n),
    .SDRAM_CKE(dram_cke), .SDRAM_CLK(dram_clk)
);

// --- Video Output ---
wire [23:0] v_pix;
wire        hsync_sys, vsync_sys, hblank_sys, vblank_sys;
wire [9:0]  sys_h_cnt, sys_v_cnt;

reg video_de_reg;
reg video_hs_reg;
reg video_vs_reg;
reg [23:0] video_rgb_reg;

always @(posedge clk_vid) begin
    video_hs_reg <= hsync_sys;
    video_vs_reg <= vsync_sys;
    video_de_reg <= ~hblank_sys && ~vblank_sys;

    if (~hblank_sys && ~vblank_sys && loading_done_q) begin
        video_rgb_reg <= v_pix;
    end else begin
        // Status Screen:
        // Red = Waiting for SDRAM Init
        // Blue = Waiting for Data Load
        // Black = Ready but Blanking
        if (!init_complete) video_rgb_reg <= 24'hFF0000;
        else if (!loading_done_q) video_rgb_reg <= 24'h0000FF;
        else video_rgb_reg <= 24'h000000;
    end
end

assign video_de = video_de_reg;
assign video_hs = video_hs_reg;
assign video_vs = video_vs_reg;
assign video_rgb = video_rgb_reg;
assign video_skip = 0;


///////////////////////////////////////////////
wire [15:0] audio_sample;
wire        audio_strobe;

// Delay core reset by 6 display lines (3 core rows) to account for pipeline
// and line buffer synchronization. This fixes the "too high" shift and 
// aligns gameplay with the cellophane bands.
reg frame_sync_q;
always @(posedge clk_client) begin
    frame_sync_q <= (sys_v_cnt == 519 && sys_h_cnt == 0);
end
wire frame_sync = frame_sync_q;

invaders_system core (
    .clk_i           (clk_client),
    .rst_ni          (reset_n),
    .sync_rst_i      (frame_sync),
    
    .dip_lives_i     (cs_lives),
    .dip_bonus_life_i(cs_bonus),
    .dip_coinage_i   (cs_coinage),
    .dip_cabinet_i   (cs_cabinet),
    .backdrop_en_i   (cs_bg), 
    .scanline_strength_i(scanline_strength_vid),

    // ROM Loading
    .load_rom_en_i   (rom_loader_wr),
    .load_rom_addr_i (rom_loader_addr),
    .load_rom_data_i (rom_loader_data),

    // BG Loading
    .load_bg_en_i    (loader_wr),
    .load_bg_addr_i  (loader_addr),
    .load_bg_data_i  (loader_data),

    .loading_done_i  (loading_done_q),

    // SDRAM Interface (Graphics Subsystem)
    .clk_sdram_i     (clk_sys),
    .rst_sdram_ni    (pll_sdram_locked),
    .sdram_addr_o    (sd_addr),
    .sdram_data_o    (sd_wdata),
    .sdram_byte_en_o (sd_be),
    .sdram_burst_len_o(sd_burst),
    .sdram_wr_req_o  (sd_wr_req),
    .sdram_rd_req_o  (sd_rd_req),
    .sdram_available_i(sd_available),
    .sdram_ready_i   (sd_ready),
    .sdram_rdata_i   (sd_rdata),

    .port0_i         (8'h0),
    .port1_i         (port1), 
    .port2_i         (port2),
    
    .audio_sample_o  (audio_sample),
    .audio_strobe_o  (audio_strobe),
    
    .vclk_o          (),
    .hsync_o         (hsync_sys),
    .vsync_o         (vsync_sys),
    .hblank_o        (hblank_sys),
    .vblank_o        (vblank_sys),
    .video_rgb_o     (v_pix),
    .frame_sync_o    (),
    .pc_o            (),
    .h_cnt_o         (sys_h_cnt),
    .v_cnt_o         (sys_v_cnt)
);


///////////////////////////////////////////////
// Control
///////////////////////////////////////////////
wire [15:0] joy, joy2;
synch_3 #(.WIDTH(16)) cont1_key_s (p1_controls_s, joy, clk_client);
synch_3 #(.WIDTH(16)) cont2_key_s (p2_controls_s, joy2, clk_client);

wire m_left   = joy[2];
wire m_right  = joy[3];
wire m_fire1   = joy[4];
wire m_start1 = joy[15];
wire m_coin1   = joy[14];

reg [7:0] port1, port2;
always_comb begin
    port1 = 8'h08; 
    port1[0] = ~m_coin1;
    port1[1] = 1'b0; // 2P
    port1[2] = m_start1;
    port1[4] = m_fire1;
    port1[5] = m_left;
    port1[6] = m_right;
    
    port2 = 8'h00;
    port2[1:0] = cs_lives;
    port2[3]   = cs_bonus;
    port2[7]   = cs_coinage;
end


///////////////////////////////////////////////
// Audio Output
///////////////////////////////////////////////
reg [15:0] current_sample;
always @(posedge audio_strobe) begin
	current_sample <= audio_sample;
end

sound_i2s #(
    .CHANNEL_WIDTH(16),
    .SIGNED_INPUT(1)
) audio_tx (
    .clk_74a(clk_74a),
    .clk_audio(clk_client),
    .audio_l(current_sample),
    .audio_r(current_sample),
    .audio_mclk(audio_mclk),
    .audio_lrck(audio_lrck),
    .audio_dac(audio_dac)
);


// ============================================================
// Analogizer
// ============================================================

wire HSync, VSync;
jtframe_resync jtframe_resync (
    .clk(clk_vid),
    .pxl_cen(1'b1),
    .hs_in(~hsync_sys), // Invert because invaders_graphics produces active-low syncs
    .vs_in(~vsync_sys), // but jtframe_resync expects active-high for edge detection
    .LVBL(vblank_sys),
    .LHBL(hblank_sys),
    .hoffset(hoffset),
    .voffset(voffset),
    .hs_out(HSync), // Produce active-high pulses
    .vs_out(VSync)
);

wire crt_csync = ~(HSync | VSync); // Active-low CSync from active-high HSync/VSync
wire crt_blankn = ~(hblank_sys | vblank_sys);

localparam [39:0] NTSC_PHASE_INC = 40'd196783852899; 
localparam [39:0] PAL_PHASE_INC =  40'd243729904257; 

wire [39:0] CHROMA_PHASE_INC = ((analogizer_video_type == 4'h4)|| (analogizer_video_type == 4'hC)) ? PAL_PHASE_INC : NTSC_PHASE_INC; 
wire PALFLAG = (analogizer_video_type == 4'h4) || (analogizer_video_type == 4'hC); 

openFPGA_Pocket_Analogizer #(
    .MASTER_CLK_FREQ(20_000_000),
    .LINE_LENGTH(640)
) analogizer (

.i_clk(clk_vid),
.i_rst(~reset_n),
.i_ena(analogizer_ena),
// Video interface
.video_clk(clk_vid),
.analog_video_type(analogizer_video_type),
.R(video_rgb_reg[23:16]),
.G(video_rgb_reg[15:8]),
.B(video_rgb_reg[7:0]),
.Hblank(hblank_sys), 
.Vblank(vblank_sys), 
.BLANKn(video_de_reg),

.Hsync(HSync),
.Vsync(VSync),
.Csync(crt_csync),

    // Y/C encoder
    .CHROMA_PHASE_INC(CHROMA_PHASE_INC),
    .PALFLAG(PALFLAG),
    // Scandoubler
    .ce_pix(1'b1),
    .scandoubler(1'b0), // Disabled: core is already 2x scaled (31kHz)
    .fx({1'b0, analogizer_fx[1:0]}), // Bits 1:0 are scanlines, bit 2 (hq2x) disabled
    // SNAC controller interface
    .conf_AB(snac_game_cont_type >= 5'd16),
    .game_cont_type(snac_game_cont_type),
    .p1_btn_state(p1_btn),
    .p1_joy_state(p1_joy),
    .p2_btn_state(p2_btn),
    .p2_joy_state(p2_joy),
    .p3_btn_state(),
    .p4_btn_state(),
    // Rumble
    .i_VIB_SW1(2'b0),
    .i_VIB_DAT1(8'h0),
    .i_VIB_SW2(2'b0),
    .i_VIB_DAT2(8'h0),
    // Status
    .busy(),
    // Cartridge port
    .cart_tran_bank2(cart_tran_bank2),
    .cart_tran_bank2_dir(cart_tran_bank2_dir),
    .cart_tran_bank3(cart_tran_bank3),
    .cart_tran_bank3_dir(cart_tran_bank3_dir),
    .cart_tran_bank1(cart_tran_bank1),
    .cart_tran_bank1_dir(cart_tran_bank1_dir),
    .cart_tran_bank0(cart_tran_bank0),
    .cart_tran_bank0_dir(cart_tran_bank0_dir),
    .cart_tran_pin30(cart_tran_pin30),
    .cart_tran_pin30_dir(cart_tran_pin30_dir),
    .cart_pin30_pwroff_reset(cart_pin30_pwroff_reset),
    .cart_tran_pin31(cart_tran_pin31),
    .cart_tran_pin31_dir(cart_tran_pin31_dir),
    // Debug
    .DBG_TX(),
    .o_stb()
);


endmodule

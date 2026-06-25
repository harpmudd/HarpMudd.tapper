// =============================================================================
// core_top.v - Tapper (Bally Midway, 1983) core for Analogue Pocket
//
// MiSTer source:  https://github.com/MiSTer-devel/Arcade-MCR3_MiSTer
// Hardware:       Midway MCR3 -- Z80 main @ 2.5 MHz, Z80 SSIO sound @ 2 MHz,
//                 dual AY-3-8910 (via YM2149), 512x480 @ 15 kHz horizontal,
//                 9-bit RGB output (3 bits per channel).
//
// ROM image (0x3A000 bytes, loaded via APF data slot 1 at bridge_addr 0):
//   0x00000-0x0DFFF  Z80 main program (cpu_rom dpram, 64 KB)
//   0x0E000-0x11FFF  SSIO sound prog  (snd_rom dpram, 16 KB)
//   0x12000-0x31FFF  Sprite graphics  (sprite_rom 32K x 32-bit, 128 KB)
//   0x32000-0x39FFF  Background tiles (mcr3.dl_addr internal BG BRAM, 32 KB)
//
// Reused load-bearing patterns from the pacman port:
//   - data_loader (dcfifo CDC for bridge -> clk_sys ROM writes)
//   - rom_loaded := dataslot_allcomplete (not dn_addr triggers)
//   - game_reset_n = reset_n_sys & rom_loaded & settle_counter==0
//   - box-filter decimator on audio bus (~39 kHz; never point-sample)
//   - 24-bit RGB gated to black during hblank | vblank
//
// MCR3-specific notes:
//   - mcr3 takes one 40 MHz input (clock_40); CPU/pixel enables are internal
//   - cpu_rom / snd_rom / sprite_rom are EXTERNAL dprams in this file
//   - mcr3.dl_addr is only for BG ROMs (0x32000+); other regions never touch it
//   - audio_out_l/r are 16-bit UNSIGNED (mcr2p5=0 path, separate_audio=0 mono)
// =============================================================================

`default_nettype none

module core_top (

// -- Physical connections -----------------------------------------------------

input  wire        clk_74a,
input  wire        clk_74b,

inout  wire [7:0]  cart_tran_bank2,    output wire cart_tran_bank2_dir,
inout  wire [7:0]  cart_tran_bank3,    output wire cart_tran_bank3_dir,
inout  wire [7:0]  cart_tran_bank1,    output wire cart_tran_bank1_dir,
inout  wire [7:4]  cart_tran_bank0,    output wire cart_tran_bank0_dir,
inout  wire        cart_tran_pin30,    output wire cart_tran_pin30_dir,
output wire        cart_pin30_pwroff_reset,
inout  wire        cart_tran_pin31,    output wire cart_tran_pin31_dir,

input  wire        port_ir_rx,
output wire        port_ir_tx,
output wire        port_ir_rx_disable,

inout  wire        port_tran_si,       output wire port_tran_si_dir,
inout  wire        port_tran_so,       output wire port_tran_so_dir,
inout  wire        port_tran_sck,      output wire port_tran_sck_dir,
inout  wire        port_tran_sd,       output wire port_tran_sd_dir,

output wire [21:16] cram0_a,    inout  wire [15:0] cram0_dq,
input  wire          cram0_wait, output wire        cram0_clk,
output wire          cram0_adv_n, output wire       cram0_cre,
output wire          cram0_ce0_n, output wire       cram0_ce1_n,
output wire          cram0_oe_n,  output wire       cram0_we_n,
output wire          cram0_ub_n,  output wire       cram0_lb_n,

output wire [21:16] cram1_a,    inout  wire [15:0] cram1_dq,
input  wire          cram1_wait, output wire        cram1_clk,
output wire          cram1_adv_n, output wire       cram1_cre,
output wire          cram1_ce0_n, output wire       cram1_ce1_n,
output wire          cram1_oe_n,  output wire       cram1_we_n,
output wire          cram1_ub_n,  output wire       cram1_lb_n,

output wire [12:0] dram_a,    output wire [1:0]  dram_ba,
inout  wire [15:0] dram_dq,   output wire [1:0]  dram_dqm,
output wire        dram_clk,  output wire        dram_cke,
output wire        dram_ras_n, output wire       dram_cas_n,
output wire        dram_we_n,

output wire [16:0] sram_a,    inout  wire [15:0] sram_dq,
output wire        sram_oe_n, output wire        sram_we_n,
output wire        sram_ub_n, output wire        sram_lb_n,

input  wire        vblank,
output wire        vpll_feed,
output wire        dbg_tx,
input  wire        dbg_rx,
output wire        user1,
input  wire        user2,
inout  wire        aux_sda,
output wire        aux_scl,

// -- Logical connections (to/from apf_top) -----------------------------------

output wire [23:0] video_rgb,
output wire        video_rgb_clock,
output wire        video_rgb_clock_90,
output wire        video_de,
output wire        video_skip,
output wire        video_vs,
output wire        video_hs,

output wire        audio_mclk,
input  wire        audio_adc,
output wire        audio_dac,
output wire        audio_lrck,

output wire        bridge_endian_little,
input  wire [31:0] bridge_addr,
input  wire        bridge_rd,
output reg  [31:0] bridge_rd_data,
input  wire        bridge_wr,
input  wire [31:0] bridge_wr_data,

input  wire [31:0] cont1_key,
input  wire [31:0] cont2_key,
input  wire [31:0] cont3_key,
input  wire [31:0] cont4_key,
input  wire [31:0] cont1_joy,
input  wire [31:0] cont2_joy,
input  wire [31:0] cont3_joy,
input  wire [31:0] cont4_joy,
input  wire [15:0] cont1_trig,
input  wire [15:0] cont2_trig,
input  wire [15:0] cont3_trig,
input  wire [15:0] cont4_trig

);

// -- Tie off unused physical ports --------------------------------------------
assign port_ir_tx              = 1'b0;
assign port_ir_rx_disable      = 1'b1;

assign cart_tran_bank3         = 8'hZZ;   assign cart_tran_bank3_dir     = 1'b0;
assign cart_tran_bank2         = 8'hZZ;   assign cart_tran_bank2_dir     = 1'b0;
assign cart_tran_bank1         = 8'hZZ;   assign cart_tran_bank1_dir     = 1'b0;
assign cart_tran_bank0         = 4'hF;    assign cart_tran_bank0_dir     = 1'b1;
assign cart_tran_pin30         = 1'b0;    assign cart_tran_pin30_dir     = 1'bZ;
assign cart_pin30_pwroff_reset = 1'b0;
assign cart_tran_pin31         = 1'bZ;    assign cart_tran_pin31_dir     = 1'b0;

assign port_tran_so            = 1'bZ;    assign port_tran_so_dir        = 1'b0;
assign port_tran_si            = 1'bZ;    assign port_tran_si_dir        = 1'b0;
assign port_tran_sck           = 1'bZ;    assign port_tran_sck_dir       = 1'b0;
assign port_tran_sd            = 1'bZ;    assign port_tran_sd_dir        = 1'b0;

assign cram0_a = 6'h0;  assign cram0_dq = 16'hZZZZ; assign cram0_clk = 1'b0;
assign cram0_adv_n = 1'b1; assign cram0_cre = 1'b0;
assign cram0_ce0_n = 1'b1; assign cram0_ce1_n = 1'b1;
assign cram0_oe_n = 1'b1; assign cram0_we_n = 1'b1;
assign cram0_ub_n = 1'b1; assign cram0_lb_n = 1'b1;

assign cram1_a = 6'h0;  assign cram1_dq = 16'hZZZZ; assign cram1_clk = 1'b0;
assign cram1_adv_n = 1'b1; assign cram1_cre = 1'b0;
assign cram1_ce0_n = 1'b1; assign cram1_ce1_n = 1'b1;
assign cram1_oe_n = 1'b1; assign cram1_we_n = 1'b1;
assign cram1_ub_n = 1'b1; assign cram1_lb_n = 1'b1;

assign dram_a = 13'h0; assign dram_ba = 2'h0; assign dram_dq = 16'hZZZZ;
assign dram_dqm = 2'h3; assign dram_clk = 1'b0; assign dram_cke = 1'b0;
assign dram_ras_n = 1'b1; assign dram_cas_n = 1'b1; assign dram_we_n = 1'b1;

assign sram_a = 17'h0; assign sram_dq = 16'hZZZZ;
assign sram_oe_n = 1'b1; assign sram_we_n = 1'b1;
assign sram_ub_n = 1'b1; assign sram_lb_n = 1'b1;

assign vpll_feed = 1'bZ;
assign dbg_tx    = 1'bZ;
assign user1     = 1'bZ;
assign aux_scl   = 1'bZ;

assign bridge_endian_little = 1'b0;

// -- PLL -- 74.25 MHz -> clk_sys (40 MHz) + clk_vid (10 MHz, 0 and 90 deg) ---
wire clk_sys;       // 40 MHz - mcr3.clock_40 + bridge/ROM loader/audio
wire clk_vid;       // 10 MHz - pixel clock (0 deg)
wire clk_vid_90;    // 10 MHz - pixel clock (90 deg, APF DDR encode edge)
wire pll_locked;
wire pll_locked_s;

mf_pllbase mp1 (
    .refclk   (clk_74a),
    .rst      (1'b0),
    .outclk_0 (clk_sys),
    .outclk_1 (clk_vid),
    .outclk_2 (clk_vid_90),
    .locked   (pll_locked)
);

synch_3 s_pll (pll_locked, pll_locked_s, clk_74a);

// -- APF bridge command handler ----------------------------------------------
wire        reset_n;
wire [31:0] cmd_bridge_rd_data;

wire        status_boot_done  = pll_locked_s;
wire        status_setup_done = rom_loaded_s;
wire        status_running    = 1'b1;

wire        dataslot_requestread;
wire [15:0] dataslot_requestread_id;
wire        dataslot_requestread_ack  = 1'b1;
wire        dataslot_requestread_ok   = 1'b1;

wire        dataslot_requestwrite;
wire [15:0] dataslot_requestwrite_id;
wire [31:0] dataslot_requestwrite_size;
wire        dataslot_requestwrite_ack = 1'b1;
wire        dataslot_requestwrite_ok  = 1'b1;

wire        dataslot_update;
wire [15:0] dataslot_update_id;
wire [31:0] dataslot_update_size;
wire        dataslot_allcomplete;

wire [31:0] rtc_epoch_seconds;
wire [31:0] rtc_date_bcd;
wire [31:0] rtc_time_bcd;
wire        rtc_valid;

wire        savestate_supported   = 1'b0;
wire [31:0] savestate_addr        = 32'h0;
wire [31:0] savestate_size        = 32'h0;
wire [31:0] savestate_maxloadsize = 32'h0;
wire        savestate_start;
wire        savestate_start_ack  = 1'b0;
wire        savestate_start_busy = 1'b0;
wire        savestate_start_ok   = 1'b0;
wire        savestate_start_err  = 1'b0;
wire        savestate_load;
wire        savestate_load_ack  = 1'b0;
wire        savestate_load_busy = 1'b0;
wire        savestate_load_ok   = 1'b0;
wire        savestate_load_err  = 1'b0;
wire        osnotify_inmenu;

reg         target_dataslot_read     = 1'b0;
reg         target_dataslot_write    = 1'b0;
reg         target_dataslot_getfile  = 1'b0;
reg         target_dataslot_openfile = 1'b0;
wire        target_dataslot_ack;
wire        target_dataslot_done;
wire [2:0]  target_dataslot_err;
reg  [15:0] target_dataslot_id         = 16'h0;
reg  [31:0] target_dataslot_slotoffset = 32'h0;
reg  [31:0] target_dataslot_bridgeaddr = 32'h0;
reg  [31:0] target_dataslot_length     = 32'h0;
wire [31:0] target_buffer_param_struct;
wire [31:0] target_buffer_resp_struct;

wire [9:0]  datatable_addr;
wire        datatable_wren;
wire [31:0] datatable_data;
wire [31:0] datatable_q;

core_bridge_cmd icb (
    .clk                       (clk_74a),
    .reset_n                   (reset_n),
    .bridge_endian_little      (bridge_endian_little),
    .bridge_addr               (bridge_addr),
    .bridge_rd                 (bridge_rd),
    .bridge_rd_data            (cmd_bridge_rd_data),
    .bridge_wr                 (bridge_wr),
    .bridge_wr_data            (bridge_wr_data),
    .status_boot_done          (status_boot_done),
    .status_setup_done         (status_setup_done),
    .status_running            (status_running),
    .dataslot_requestread      (dataslot_requestread),
    .dataslot_requestread_id   (dataslot_requestread_id),
    .dataslot_requestread_ack  (dataslot_requestread_ack),
    .dataslot_requestread_ok   (dataslot_requestread_ok),
    .dataslot_requestwrite     (dataslot_requestwrite),
    .dataslot_requestwrite_id  (dataslot_requestwrite_id),
    .dataslot_requestwrite_size(dataslot_requestwrite_size),
    .dataslot_requestwrite_ack (dataslot_requestwrite_ack),
    .dataslot_requestwrite_ok  (dataslot_requestwrite_ok),
    .dataslot_update           (dataslot_update),
    .dataslot_update_id        (dataslot_update_id),
    .dataslot_update_size      (dataslot_update_size),
    .dataslot_allcomplete      (dataslot_allcomplete),
    .rtc_epoch_seconds         (rtc_epoch_seconds),
    .rtc_date_bcd              (rtc_date_bcd),
    .rtc_time_bcd              (rtc_time_bcd),
    .rtc_valid                 (rtc_valid),
    .savestate_supported       (savestate_supported),
    .savestate_addr            (savestate_addr),
    .savestate_size            (savestate_size),
    .savestate_maxloadsize     (savestate_maxloadsize),
    .savestate_start           (savestate_start),
    .savestate_start_ack       (savestate_start_ack),
    .savestate_start_busy      (savestate_start_busy),
    .savestate_start_ok        (savestate_start_ok),
    .savestate_start_err       (savestate_start_err),
    .savestate_load            (savestate_load),
    .savestate_load_ack        (savestate_load_ack),
    .savestate_load_busy       (savestate_load_busy),
    .savestate_load_ok         (savestate_load_ok),
    .savestate_load_err        (savestate_load_err),
    .osnotify_inmenu           (osnotify_inmenu),
    .target_dataslot_read      (target_dataslot_read),
    .target_dataslot_write     (target_dataslot_write),
    .target_dataslot_getfile   (target_dataslot_getfile),
    .target_dataslot_openfile  (target_dataslot_openfile),
    .target_dataslot_ack       (target_dataslot_ack),
    .target_dataslot_done      (target_dataslot_done),
    .target_dataslot_err       (target_dataslot_err),
    .target_dataslot_id        (target_dataslot_id),
    .target_dataslot_slotoffset(target_dataslot_slotoffset),
    .target_dataslot_bridgeaddr(target_dataslot_bridgeaddr),
    .target_dataslot_length    (target_dataslot_length),
    .target_buffer_param_struct(target_buffer_param_struct),
    .target_buffer_resp_struct (target_buffer_resp_struct),
    .datatable_addr            (datatable_addr),
    .datatable_wren            (datatable_wren),
    .datatable_data            (datatable_data),
    .datatable_q               (datatable_q)
);

always @(*) begin
    casex (bridge_addr)
        32'hF8xxxxxx: bridge_rd_data = cmd_bridge_rd_data;
        default:      bridge_rd_data = 32'h0;
    endcase
end

// -- ROM loading via APF bridge ----------------------------------------------
// Tapper image is 0x3A000 bytes (232 KB) -> dn_addr needs 18 bits.

wire [17:0] dn_addr;
wire [7:0]  dn_data;
wire        dn_wr;
reg         rom_loaded_74 = 1'b0;
wire        rom_loaded;
wire        rom_loaded_s = rom_loaded_74;

synch_3 s_rom_to_sys (rom_loaded_74, rom_loaded, clk_sys);

data_loader #(
    .ADDRESS_MASK_UPPER_4 (4'h0),
    .ADDRESS_SIZE         (17),
    .OUTPUT_WORD_SIZE     (1)
) u_rom_loader (
    .clk_74a              (clk_74a),
    .clk_memory           (clk_sys),
    .bridge_wr            (bridge_wr),
    .bridge_endian_little (bridge_endian_little),
    .bridge_addr          (bridge_addr),
    .bridge_wr_data       (bridge_wr_data),
    .write_en             (dn_wr),
    .write_addr           (dn_addr),
    .write_data           (dn_data)
);

always @(posedge clk_74a) begin
    if (dataslot_allcomplete)
        rom_loaded_74 <= 1'b1;
end

// -- ROM region demux ---------------------------------------------------------
//   0x00000-0x0DFFF  CPU prog  -> cpu_rom (64 KB byte-addressed dpram)
//   0x0E000-0x11FFF  Sound     -> snd_rom (16 KB byte-addressed dpram)
//   0x12000-0x31FFF  Sprites   -> sprite_rom (32K x 32-bit, byte-laned)
//   0x32000-0x39FFF  BG tiles  -> mcr3.dl_addr (internal BG BRAM)

wire dn_is_cpu = (dn_addr <  18'h0E000);
wire dn_is_snd = (dn_addr >= 18'h0E000) && (dn_addr < 18'h12000);
wire dn_is_spr = (dn_addr >= 18'h12000) && (dn_addr < 18'h32000);
wire dn_is_bg  = (dn_addr >= 18'h32000) && (dn_addr < 18'h3A000);

wire cpu_rom_we    = dn_wr && dn_is_cpu;
wire snd_rom_we    = dn_wr && dn_is_snd;
wire sprite_rom_we = dn_wr && dn_is_spr;
wire bg_dl_wr      = dn_wr && dn_is_bg;

wire [17:0] sprite_byte_offset = dn_addr - 18'h12000;  // 0..0x1FFFF
// bg_dl_offset: dn_addr 0x32000 -> dl_addr 0x0000 (bg_graphics_1 = bg_1_6f),
//               dn_addr 0x36000 -> dl_addr 0x4000 (bg_graphics_2 = bg_0_5f).
// bits[15:0] of 0x32000 = 0x2000, so subtract 0x2000 from dn_addr[15:0].
wire [15:0] bg_dl_offset = dn_addr[15:0] - 16'h2000;

// -- Reset --------------------------------------------------------------------
wire reset_n_sys;
synch_3 s_resetn (reset_n, reset_n_sys, clk_sys);

reg [7:0] reset_ctr = 8'hFF;
wire      game_reset_n = (reset_ctr == 8'h0) && rom_loaded && reset_n_sys;

always @(posedge clk_sys) begin
    if (!pll_locked)
        reset_ctr <= 8'hFF;
    else if (reset_ctr != 8'h0)
        reset_ctr <= reset_ctr - 1'd1;
end

// -- CPU ROM (64 KB) -- explicit MiSTer dpram entity, true dual-port ---------
wire [15:0] cpu_rom_addr;
wire [7:0]  cpu_rom_do_r;
wire [7:0]  cpu_rom_do_to_mcr3;  // forwarded to mcr3.cpu_rom_do with byte-0 patch

// CPU ROM pre-initialized from cpu_rom.hex via $readmemh. Bypasses data_loader
// entirely for the CPU ROM contents -- the BRAM is loaded at FPGA configuration
// time. data_loader writes to this region are now ignored (silently overwritten
// by the same data, so harmless).
(* ramstyle = "M10K" *) reg [7:0] cpu_rom_mem [0:65535];
reg [7:0] cpu_rom_do_r_reg;
initial begin
    $readmemh("cpu_rom.hex", cpu_rom_mem);
end

always @(posedge clk_sys) begin
    cpu_rom_do_r_reg <= cpu_rom_mem[cpu_rom_addr];
end
assign cpu_rom_do_r        = cpu_rom_do_r_reg;
assign cpu_rom_do_to_mcr3  = cpu_rom_do_r;

// -- Sound ROM (16 KB) -- back to data_loader, plus .hex pre-init as backup
(* ramstyle = "M10K" *) reg [7:0] snd_rom_mem [0:16383];
reg  [7:0]  snd_rom_do_r;
wire [13:0] snd_rom_addr;
wire [13:0] snd_rom_waddr = dn_addr[13:0] - 14'h2000;
initial $readmemh("snd_rom.hex", snd_rom_mem);
always @(posedge clk_sys) begin
    if (snd_rom_we) snd_rom_mem[snd_rom_waddr] <= dn_data;
    snd_rom_do_r <= snd_rom_mem[snd_rom_addr];
end

// -- Sprite ROM (32K x 32-bit, 4 byte lanes) -- back to data_loader + .hex --
(* ramstyle = "M10K" *) reg [7:0] sprite_rom_b0 [0:32767];
(* ramstyle = "M10K" *) reg [7:0] sprite_rom_b1 [0:32767];
(* ramstyle = "M10K" *) reg [7:0] sprite_rom_b2 [0:32767];
(* ramstyle = "M10K" *) reg [7:0] sprite_rom_b3 [0:32767];
initial $readmemh("sprite_b0.hex", sprite_rom_b0);
initial $readmemh("sprite_b1.hex", sprite_rom_b1);
initial $readmemh("sprite_b2.hex", sprite_rom_b2);
initial $readmemh("sprite_b3.hex", sprite_rom_b3);
reg  [7:0]  spr_b0_r, spr_b1_r, spr_b2_r, spr_b3_r;
wire [14:0] sp_addr;
wire [31:0] sp_graphx32_do = {spr_b3_r, spr_b2_r, spr_b1_r, spr_b0_r};

// Lane assignment matches rebuild_hex.py: each lane is a contiguous 32 KB chunk
// of the sprite section. Lane = bits [16:15] of the sprite offset, row = [14:0].
wire [14:0] sprite_row     = sprite_byte_offset[14:0];
wire [1:0]  sprite_byte_ln = sprite_byte_offset[16:15];

always @(posedge clk_sys) begin
    if (sprite_rom_we) begin
        case (sprite_byte_ln)
            2'd0: sprite_rom_b0[sprite_row] <= dn_data;
            2'd1: sprite_rom_b1[sprite_row] <= dn_data;
            2'd2: sprite_rom_b2[sprite_row] <= dn_data;
            2'd3: sprite_rom_b3[sprite_row] <= dn_data;
        endcase
    end
    spr_b0_r <= sprite_rom_b0[sp_addr];
    spr_b1_r <= sprite_rom_b1[sp_addr];
    spr_b2_r <= sprite_rom_b2[sp_addr];
    spr_b3_r <= sprite_rom_b3[sp_addr];
end

// -- Controller mapping (HarpMudd convention) --------------------------------
//   cont1_key bits (APF standard):
//     [0] up  [1] down  [2] left  [3] right
//     [4] face A  [5] face B  [6] face X  [7] face Y
//     [14] select  [15] start
//
// MCR3 Tapper (per Arcade-MCR3.sv mod_tapper case):
//   input_0 = ~{service, 3'b000, start2, start1, 1'b0, coin1};
//   input_1 = ~{3'b000, fire_a, up, down, left, right};
//   input_2 = ~{3'b000, fire_a, up, down, left, right};  // mirrors input_1
//   input_3 = dipsw[7:0];

wire m_coin1   = cont1_key[14];   // SELECT  -> Coin (HarpMudd arcade convention)
wire m_start1  = cont1_key[15];   // START   -> 1P Start
wire m_start2  = cont2_key[15];   // P2 START -> 2P Start
wire m_service = 1'b0;
wire m_fire_a  = cont1_key[4];    // A        -> Fill mug
wire m_up      = cont1_key[0];
wire m_down    = cont1_key[1];
wire m_left    = cont1_key[2];
wire m_right   = cont1_key[3];

// MAME shows IPT_VBLANK on IP0 bit 7 for some MCR3 boards. Drive it from mcr3's
// vid_vblank so Z80's vblank-polling loop can break out. Active low (= 0 during vblank).
wire [7:0] input_0 = ~{vid_vblank, 3'b000, m_start2, m_start1, 1'b0, m_coin1};
wire [7:0] input_1 = ~{3'b000, m_fire_a, m_up, m_down, m_left, m_right};
wire [7:0] input_2 = ~{3'b000, m_fire_a, m_up, m_down, m_left, m_right};

// DIPs default per .mra "FF 00" -- all DIPs in their off/first state.
wire [7:0] input_3 = 8'hFF;
// input_4: active-LOW like the other inputs; default = all-inactive = 0xFF.
// (Was 8'h00, which made every bit look "pressed" and put Tapper into a
// test/diagnostic code path that polled the 0xE0 control port forever.)
wire [7:0] input_4 = 8'hFF;

// -- MCR3 game core ----------------------------------------------------------
wire [2:0] vid_r, vid_g, vid_b;
wire       vid_hs, vid_vs, vid_hblank, vid_vblank;
wire       vid_ce;
wire [15:0] audio_l_raw, audio_r_raw;
wire [7:0]  output_4_unused;

mcr3 mcr3_core (
    .clock_40       (clk_sys),
    .reset          (~game_reset_n),
    .tv15Khz_mode   (1'b1),                // 15 kHz (standard arcade)

    .video_r        (vid_r),
    .video_g        (vid_g),
    .video_b        (vid_b),
    .video_csync    (),
    .video_hblank   (vid_hblank),
    .video_Vblank   (vid_vblank),
    .video_hs       (vid_hs),
    .video_vs       (vid_vs),
    .video_ce       (vid_ce),
    .video_hflip    (1'b0),
    .video_vflip    (1'b0),

    .separate_audio (1'b0),                // mono mix on both channels
    .audio_out_l    (audio_l_raw),
    .audio_out_r    (audio_r_raw),

    .input_0        (input_0),
    .input_1        (input_1),
    .input_2        (input_2),
    .input_3        (input_3),
    .input_4        (input_4),
    .output_4       (output_4_unused),
    .mcr2p5         (1'b0),                // not super CPU board (Journey)
    .hcntout        (),

    .cpu_rom_addr   (cpu_rom_addr),
    .cpu_rom_do     (cpu_rom_do_to_mcr3),
    .snd_rom_addr   (snd_rom_addr),
    .snd_rom_do     (snd_rom_do_r),

    .sp_addr        (sp_addr),
    .sp_graphx32_do (sp_graphx32_do),

    .dl_addr        (bg_dl_offset),
    .dl_data        (dn_data),
    .dl_wr          (bg_dl_wr),
    .dl_din         (),
    .dl_nvram       (1'b0),
    .dl_nvram_wr    (1'b0)
);

// -- HARNESS #29: precise tracking of the stuck loop vs deep init ------------
// Canonical Tapper boot:
//   0x002C: CALL 0xC749   (deep init: ram test, palette init, etc.)
//   0x002F: JR Z, +4 -> 0x0035 (success continues)
//   0x0031: OUT (0xE0), A (watchdog kick) ; JR -4 -> tight loop FAIL
//   0xC749: routine that ultimately writes palette etc.
//
//   R = PC ever in 0x0031-0x0034 (the watchdog tight-loop / FAIL spin)
//   G = PC ever in 0xC749-0xC780 (entered the CALL 0xC749 sub)
//   B = palette_we OR ssio_io_write (deep init actually progressing)
//
//   black           -> Z80 dead early
//   R only          -> stuck at 0x0031 tight loop, never entered 0xC749
//   R+G (yellow)    -> entered 0xC749, returned, now stuck at 0x0031
//   G+B  (cyan)     -> entered 0xC749, never hit fail loop, palette/SSIO fired
//   R+G+B (white)   -> all three -> some progress + still hitting fail
// Real video output.
wire [7:0] rgb_r = {vid_r, vid_r, vid_r[2:1]};
wire [7:0] rgb_g = {vid_g, vid_g, vid_g[2:1]};
wire [7:0] rgb_b = {vid_b, vid_b, vid_b[2:1]};
wire [23:0] rgb_out = (vid_hblank | vid_vblank) ? 24'h0 : {rgb_r, rgb_g, rgb_b};

reg [23:0] vid_rgb_r;
reg        vid_hs_r, vid_vs_r, vid_de_r;

always @(posedge clk_vid) begin
    vid_rgb_r <= rgb_out;
    vid_hs_r  <= vid_hs;
    vid_vs_r  <= vid_vs;
    vid_de_r  <= ~(vid_hblank | vid_vblank);
end

assign video_rgb          = vid_rgb_r;
assign video_rgb_clock    = clk_vid;
assign video_rgb_clock_90 = clk_vid_90;
assign video_de           = vid_de_r;
assign video_skip         = 1'b0;
assign video_vs           = vid_vs_r;
assign video_hs           = vid_hs_r;

// -- Audio (16-bit stereo, box-filter decimate to ~39 kHz I2S) --------------
// audio_out_l/r are unsigned 16-bit from mcr3 (mcr2p5=0 mode).
// clk_sys 40 MHz / 1024 = 39.0625 kHz. Sum of 1024 x 16-bit fits in 26 bits.
reg  [9:0]  aud_div     = 10'd0;
reg  [25:0] aud_accum_l = 26'd0, aud_accum_r = 26'd0;
reg  [15:0] audio_l_s   = 16'd0,  audio_r_s  = 16'd0;

always @(posedge clk_sys) begin
    aud_div <= aud_div + 1'd1;
    if (aud_div == 10'd0) begin
        audio_l_s   <= aud_accum_l[25:10];
        audio_r_s   <= aud_accum_r[25:10];
        aud_accum_l <= {10'd0, audio_l_raw};
        aud_accum_r <= {10'd0, audio_r_raw};
    end else begin
        aud_accum_l <= aud_accum_l + {10'd0, audio_l_raw};
        aud_accum_r <= aud_accum_r + {10'd0, audio_r_raw};
    end
end

sound_i2s #(
    .CHANNEL_WIDTH (16),
    .SIGNED_INPUT  (0)
) u_sound_i2s (
    .clk_74a    (clk_74a),
    .clk_audio  (clk_sys),
    .audio_l    (audio_l_s),
    .audio_r    (audio_r_s),
    .audio_mclk (audio_mclk),
    .audio_dac  (audio_dac),
    .audio_lrck (audio_lrck)
);

endmodule

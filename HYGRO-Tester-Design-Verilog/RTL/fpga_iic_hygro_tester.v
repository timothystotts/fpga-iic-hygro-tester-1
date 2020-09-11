/*------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020 Timothy Stotts
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
------------------------------------------------------------------------------*/
/**-----------------------------------------------------------------------------
-- \file fpga_iic_hygro_tester.v
--
-- \brief A FPGA top-level design with the PMOD HYGRO custom driver.
-- This design operates the HDC1080 by retrieving Temperature and Relative
-- Humidity readings from the PMOD HYGRO via a I2C bus communication. The
-- Pmod CLS is are used to display the textual values for each of the two
-- HDC1080 16-bit readings registers. Refer to the HDC1080 datasheet.
-------------------------------------------------------------------------------*/
/* FIXME: The design top-level utilizes the default TECHNOLOGY, SLEW, and DRIVE. */
//Part 1: Module header:--------------------------------------------------------
module fpga_iic_hygro_tester(
	/* external clock and active-low reset */
	CLK100MHZ, i_resetn,
	/* PMOD HYGRO IIC bus 2-wire */
	eo_scl, eio_sda,
		/* blue LEDs of the multicolor */
	eo_led0_b, eo_led1_b, eo_led2_b, eo_led3_b,
	/* red LEDs of the multicolor */
	eo_led0_r, eo_led1_r, eo_led2_r, eo_led3_r,
	/* green LEDs of the multicolor */
	eo_led0_g, eo_led1_g, eo_led2_g, eo_led3_g,
	/* green LEDs of the regular LEDs */
	eo_led4, eo_led5, eo_led6, eo_led7,
	/* four switches */
	ei_sw0, ei_sw1, ei_sw2, ei_sw3,
	/* four buttons */
	ei_btn0, ei_btn1, ei_btn2, ei_btn3,
	/* PMOD CLS SPI bus 4-wire */
	eo_pmod_cls_csn, eo_pmod_cls_sck, eo_pmod_cls_dq0,
	ei_pmod_cls_dq1,
	/* Arty A7-100T UART TX and RX signals */
	eo_uart_tx, ei_uart_rx,
	/* PMOD SSD direct GPIO */
	eo_ssd_pmod0);

/* Disable or enable fast FSM delays for simulation instead of impelementation. */
parameter integer parm_fast_simulation = 0;
localparam integer c_FCLK = 20000000;

input wire CLK100MHZ;
input wire i_resetn;

output wire eo_scl;
inout wire eio_sda;

output wire eo_led0_b;
output wire eo_led1_b;
output wire eo_led2_b;
output wire eo_led3_b;

output wire eo_led0_r;
output wire eo_led1_r;
output wire eo_led2_r;
output wire eo_led3_r;

output wire eo_led0_g;
output wire eo_led1_g;
output wire eo_led2_g;
output wire eo_led3_g;

output wire eo_led4;
output wire eo_led5;
output wire eo_led6;
output wire eo_led7;

input wire ei_sw0;
input wire ei_sw1;
input wire ei_sw2;
input wire ei_sw3;

input wire ei_btn0;
input wire ei_btn1;
input wire ei_btn2;
input wire ei_btn3;

output wire eo_pmod_cls_csn;
output wire eo_pmod_cls_sck;
output wire eo_pmod_cls_dq0;
input wire ei_pmod_cls_dq1;

output wire eo_uart_tx;
input wire ei_uart_rx;

output wire [7:0] eo_ssd_pmod0;

// Part 2: Declarations---------------------------------------------------------

/* MMCM and Processor System Reset signals for PLL clock generation from the
   Clocking Wizard and Synchronous Reset generation from the Processor System
   Reset module. */
wire s_mmcm_locked;
wire s_clk_20mhz;
wire s_rst_20mhz;
wire s_clk_7_37mhz;
wire s_rst_7_37mhz;
wire s_ce_2_5mhz;

/* Definitions of the Standard SPI driver to pass to the CLS driver */
`define c_stand_spi_tx_fifo_count_bits 5
`define c_stand_spi_rx_fifo_count_bits 5
`define c_stand_spi_wait_count_bits 2

/* Pulse strobe to command the HYGRO driver to write the configuration register. */
wire s_hygro_wr;

/* Pulse strobe to command the HYGRO driver to read the temperature and relative
    humidity registers. */
wire s_hygro_rd;

/* Driver input of the CONFIGURATION REGISTER value to write to the PMOD HYGRO upon
   pulse strobe of the \ref s_hygro_wr . */
wire [15:0] s_hygro_config;

/* Driver outputs of the TEMPERATURE REGISTER and RELATIVE HUMIDITY REGISTER that
   contain those register values at the end of processing a \ref s_hygro_rd pulse
   strobe. */
wire [15:0] s_hygro_temp;
wire [15:0] s_hygro_humid;
wire s_hygro_valid;

/* IIC bi-directional and tri-stateable signal components for the IIC SDA trace,
   with three components: input, output, and tri-state enable. */
wire ei_sda_i;
reg ei_sda_i_meta;
reg ei_sda_i_sync;
wire eo_sda_o_comb;
reg eo_sda_o_sync;
wire eo_sda_t_comb;
reg eo_sda_t_sync;
wire eo_scl_o_comb;
reg eo_scl_o_sync;

/* Registers that hold the current humidity and temperature values; that update upon
   a pulse strobe of the driver's \ref s_hygro_valid output. These registers hold
   the two 16-bit values for display upon the driver producing a reading of these
   values; once ever iteration, which according to the datasheet recommendation,
   and this module's design, is once per second. */
wire [15:0] s_display_humid;
wire [15:0] s_display_temp;

/* Values that indicate the operation and display modes of the design */
wire [0:0] s_hygro_op_mode;
wire [2:0] s_hygro_display_mode;

/* switch inputs debounced */
wire [3:0] si_switches;
wire [3:0] s_sw_deb;

/* switch inputs debounced */
wire [3:0] si_buttons;
wire [3:0] s_btn_deb;

/* Connections and variables for controlling the PMOD CLS custom driver. */
wire s_cls_command_ready;
wire s_cls_wr_clear_display;
wire s_cls_wr_text_line1;
wire s_cls_wr_text_line2;
wire [(16*8-1):0] s_cls_txt_ascii_line1;
wire [(16*8-1):0] s_cls_txt_ascii_line2;
wire s_cls_feed_is_idle;

/* Signals for text and data ASCII lines */
wire [(16*8-1):0] s_hygro_txt_ascii_line1;
wire [(16*8-1):0] s_hygro_txt_ascii_line2;

/* Connections for inferring tri-state buffer for CLS SPI bus outputs. */
wire so_pmod_cls_sck_o;
wire so_pmod_cls_sck_t;
wire so_pmod_cls_csn_o;
wire so_pmod_cls_csn_t;
wire so_pmod_cls_copi_o;
wire so_pmod_cls_copi_t;

/* Extra MMCM signals for full port map to the MMCM primative,
   where these signals will remain disconnected. */
wire s_clk_ignore_clk0b;
wire s_clk_ignore_clk1b;
wire s_clk_ignore_clk2;
wire s_clk_ignore_clk2b;
wire s_clk_ignore_clk3;
wire s_clk_ignore_clk3b;
wire s_clk_ignore_clk4;
wire s_clk_ignore_clk5;
wire s_clk_ignore_clk6;
wire s_clk_ignore_clkfboutb;
wire s_clk_clkfbout;
wire s_clk_pwrdwn;
wire s_clk_resetin;

/* Color palette signals to connect \ref led_palette_pulser to \ref
   led_pwm_driver . */
wire [(4*8-1):0] s_color_led_red_value;
wire [(4*8-1):0] s_color_led_green_value;
wire [(4*8-1):0] s_color_led_blue_value;
wire [(4*8-1):0] s_basic_led_lumin_value;

/* UART TX signals to connect \ref uart_tx_only and \ref uart_tx_feed */
wire [(35*8-1):0] s_uart_dat_ascii_line;
wire s_uart_tx_go;
wire [7:0] s_uart_txdata;
wire s_uart_txvalid;
wire s_uart_txready;

/* Values for display on the Pmod SSD */
wire [3:0] s_display_index_value0;
wire [3:0] s_display_index_value1;

//Part 3: Statements------------------------------------------------------------
assign s_clk_pwrdwn = 1'b0;
assign s_clk_resetin = (~i_resetn);

// MMCME2_BASE: Base Mixed Mode Clock Manager
//              Artix-7
// Xilinx HDL Language Template, version 2019.1

MMCME2_BASE #(
  .BANDWIDTH("OPTIMIZED"),   // Jitter programming (OPTIMIZED, HIGH, LOW)
  .CLKFBOUT_MULT_F(36.125),  // Multiply value for all CLKOUT (2.000-64.000).
  .CLKFBOUT_PHASE(0.0),      // Phase offset in degrees of CLKFB (-360.000-360.000).
  .CLKIN1_PERIOD(10.0),      // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
  // CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
  .CLKOUT1_DIVIDE(98),
  .CLKOUT2_DIVIDE(1),
  .CLKOUT3_DIVIDE(1),
  .CLKOUT4_DIVIDE(1),
  .CLKOUT5_DIVIDE(1),
  .CLKOUT6_DIVIDE(1),
  .CLKOUT0_DIVIDE_F(36.125),  // Divide amount for CLKOUT0 (1.000-128.000).
  // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
  .CLKOUT0_DUTY_CYCLE(0.5),
  .CLKOUT1_DUTY_CYCLE(0.5),
  .CLKOUT2_DUTY_CYCLE(0.5),
  .CLKOUT3_DUTY_CYCLE(0.5),
  .CLKOUT4_DUTY_CYCLE(0.5),
  .CLKOUT5_DUTY_CYCLE(0.5),
  .CLKOUT6_DUTY_CYCLE(0.5),
  // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
  .CLKOUT0_PHASE(0.0),
  .CLKOUT1_PHASE(0.0),
  .CLKOUT2_PHASE(0.0),
  .CLKOUT3_PHASE(0.0),
  .CLKOUT4_PHASE(0.0),
  .CLKOUT5_PHASE(0.0),
  .CLKOUT6_PHASE(0.0),
  .CLKOUT4_CASCADE("FALSE"), // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
  .DIVCLK_DIVIDE(5),         // Master division value (1-106)
  .REF_JITTER1(0.010),       // Reference input jitter in UI (0.000-0.999).
  .STARTUP_WAIT("FALSE")     // Delays DONE until MMCM is locked (FALSE, TRUE)
)
MMCME2_BASE_inst (
  // Clock Outputs: 1-bit (each) output: User configurable clock outputs
  .CLKOUT0(s_clk_20mhz),              // 1-bit output: CLKOUT0
  .CLKOUT0B(s_clk_ignore_clk0b),      // 1-bit output: Inverted CLKOUT0
  .CLKOUT1(s_clk_7_37mhz),            // 1-bit output: CLKOUT1
  .CLKOUT1B(s_clk_ignore_clk1b),      // 1-bit output: Inverted CLKOUT1
  .CLKOUT2(s_clk_ignore_clk2),        // 1-bit output: CLKOUT2
  .CLKOUT2B(s_clk_ignore_clk2b),      // 1-bit output: Inverted CLKOUT2
  .CLKOUT3(s_clk_ignore_clk3),        // 1-bit output: CLKOUT3
  .CLKOUT3B(s_clk_ignore_clk3b),      // 1-bit output: Inverted CLKOUT3
  .CLKOUT4(s_clk_ignore_clk4),        // 1-bit output: CLKOUT4
  .CLKOUT5(s_clk_ignore_clk5),        // 1-bit output: CLKOUT5
  .CLKOUT6(s_clk_ignore_clk6),        // 1-bit output: CLKOUT6
  // Feedback Clocks: 1-bit (each) output: Clock feedback ports
  .CLKFBOUT(s_clk_clkfbout),          // 1-bit output: Feedback clock
  .CLKFBOUTB(s_clk_ignore_clkfboutb), // 1-bit output: Inverted CLKFBOUT
  // Status Ports: 1-bit (each) output: MMCM status ports
  .LOCKED(s_mmcm_locked),             // 1-bit output: LOCK
  // Clock Inputs: 1-bit (each) input: Clock input
  .CLKIN1(CLK100MHZ),                 // 1-bit input: Clock
  // Control Ports: 1-bit (each) input: MMCM control ports
  .PWRDWN(s_clk_pwrdwn),              // 1-bit input: Power-down
  .RST(s_clk_resetin),                // 1-bit input: Reset
  // Feedback Clocks: 1-bit (each) input: Clock feedback ports
  .CLKFBIN(s_clk_clkfbout)            // 1-bit input: Feedback clock
);

// End of MMCME2_BASE_inst instantiation

/* Reset Synchronization for 40 MHz clock. */
arty_reset_synchronizer #() u_reset_synch_20mhz(
	.i_clk_mhz(s_clk_20mhz),
	.i_rstn_global(i_resetn),
	.o_rst_mhz(s_rst_20mhz)
	);

/* Reset Synchronization for 7.37 MHz clock. */
arty_reset_synchronizer #() u_reset_synch_7_37mhz (
	.i_clk_mhz(s_clk_7_37mhz),
	.i_rstn_global(i_resetn),
	.o_rst_mhz(s_rst_7_37mhz)
	);

/* 4x spi clock enable divider for PMOD CLS SCK output. No
   generated clock constraint. The 20 MHz clock is divided
   down to 2.5 MHz; and later divided down to 625 KHz on
   the PMOD CLS bus. */
clock_enable_divider #(
  .par_ce_divisor(8)
  ) u_2_5mhz_ce_divider (
	.o_ce_div(s_ce_2_5mhz),
	.i_clk_mhz(s_clk_20mhz),
	.i_rst_mhz(s_rst_20mhz),
	.i_ce_mhz(1'b1));

// Synchronize and debounce the four input switches on the Arty A7 to be
// debounced and exclusive of each other (ignored if more than one
// selected at the same time).
assign si_switches = {ei_sw3, ei_sw2, ei_sw1, ei_sw0};

multi_input_debounce #(
  .FCLK(c_FCLK)
  ) u_switches_deb_0123 (
    .i_clk_mhz(s_clk_20mhz),
    .i_rst_mhz(s_rst_20mhz),
    .ei_buttons(si_switches),
    .o_btns_deb(s_sw_deb)
    );

// Synchronize and debounce the four input buttons on the Arty A7 to be
// debounced and exclusive of each other (ignored if more than one
// selected at the same time).
assign si_buttons = {ei_btn3, ei_btn2, ei_btn1, ei_btn0};

multi_input_debounce #(
  .FCLK(c_FCLK)
  ) u_buttons_deb_0123 (
    .i_clk_mhz(s_clk_20mhz),
    .i_rst_mhz(s_rst_20mhz),
    .ei_buttons(si_buttons),
    .o_btns_deb(s_btn_deb)
    );

/* LED PWM driver for color-mixed LED driving with variable intensity. */
led_pwm_driver #(
    .parm_color_led_count(4),
    .parm_basic_led_count(4),
    .parm_FCLK(c_FCLK),
    .parm_pwm_period_milliseconds(10)
    ) u_led_pwm_driver (
    .i_clk(s_clk_20mhz),
    .i_srst(s_rst_20mhz),
    .i_color_led_red_value(s_color_led_red_value),
    .i_color_led_green_value(s_color_led_green_value),
    .i_color_led_blue_value(s_color_led_blue_value),
    .i_basic_led_lumin_value(s_basic_led_lumin_value),
    .eo_color_leds_r({eo_led3_r, eo_led2_r, eo_led1_r, eo_led0_r}),
    .eo_color_leds_g({eo_led3_g, eo_led2_g, eo_led1_g, eo_led0_g}),
    .eo_color_leds_b({eo_led3_b, eo_led2_b, eo_led1_b, eo_led0_b}),
    .eo_basic_leds_l({eo_led7, eo_led6, eo_led5, eo_led4})
    );

/* LED palette pulser to manage the display of the LEDs */
led_palette_pulser #(
	.parm_color_led_count(4),
	.parm_basic_led_count(4),
	.parm_FCLK(c_FCLK),
	.parm_adjustments_per_second(85)
	) u_led_palette_pulser (
	.i_clk(s_clk_20mhz),
	.i_srst(s_rst_20mhz),
	.o_color_led_red_value(s_color_led_red_value),
	.o_color_led_green_value(s_color_led_green_value),
	.o_color_led_blue_value(s_color_led_blue_value),
	.o_basic_led_lumin_value(s_basic_led_lumin_value),
	.o_display_index_value0(s_display_index_value0),
	.o_display_index_value1(s_display_index_value1),
	.i_hygro_op_mode(s_hygro_op_mode),
	.i_hygro_display_mode(s_hygro_display_mode)
	);

/* contains clock_divider instance that requires
   XDC command create_generated_clock */
// TODO: Augment to pmod_hygro_custom_driver
pmod_hygro_i2c_solo #(
	.HOLD_I2C_BOTH_SCL_EDGES(1),
	.FCLK(c_FCLK),
	.DATA_RATE(100000)
	) u_pmod_hygro_i2c_solo (
	.i_clk(s_clk_20mhz),
	.i_rst(s_rst_20mhz),
	.i_wr(s_hygro_wr),
	.i_rd(s_hygro_rd),
	.eo_scl(eo_scl_o_comb),
	.eo_sda_o(eo_sda_o_comb),
	.ei_sda_i(ei_sda_i_sync),
	.eo_sda_t(eo_sda_t_comb),
	.i_config(s_hygro_config),
	.o_humid(s_hygro_humid),
	.o_temp(s_hygro_temp),
	.o_valid(s_hygro_valid));

/* Tri-state output/input of IIC SDA to connect to HYGRO PMOD */

/* Synchronize the input to mitigate meta-stability */
always @(posedge s_clk_20mhz)
begin: p_sync_iic_in
	ei_sda_i_sync <= ei_sda_i_meta;
	ei_sda_i_meta <= ei_sda_i;
end

/* Synchronize the output to mitigate glitches and provide IOBUF_inst/IBUF
   signal drive. */
always @(posedge s_clk_20mhz)
begin: p_sync_iic_out
	eo_scl_o_sync <= eo_scl_o_comb;
	eo_sda_o_sync <= eo_sda_o_comb;
	eo_sda_t_sync <= eo_sda_t_comb;
end

/* Output the synchronized SCL I2C clock signal. */
assign eo_scl = eo_scl_o_sync;

// IOBUF: Single-ended Bi-directional Buffer
//        All devices
// Xilinx HDL Language Template, version 2019.1
IOBUF #(
   .DRIVE(12), // Specify the output drive strength
   .IBUF_LOW_PWR("TRUE"),  // Low Power - "TRUE", High Performance = "FALSE"
   .IOSTANDARD("LVCMOS33"), // Specify the I/O standard
   .SLEW("SLOW") // Specify the output slew rate)
   )IOBUF_sda_inst(
   .O(ei_sda_i),     // Buffer output
   .IO(eio_sda),   // Buffer inout port (connect directly to top-level port)
   .I(eo_sda_o_sync),     // Buffer input
   .T(eo_sda_t_sync));      // 3-state enable input, high=input, low=output);
// End of IOBUF_inst instantiation

/* Tester FSM to operate the states of the Pmod HYGRO based on switch input */
hygro_tester_fsm #(
		.parm_fast_simulation(parm_fast_simulation)
	) u_hygro_tester_fsm (
		.i_clk_20mhz(s_clk_20mhz),
		.i_rst_20mhz(s_rst_20mhz),
		.i_switches_debounced(s_sw_deb),
		.i_buttons_debounced(s_btn_deb),
		.i_hygro_temp(s_hygro_temp),
		.i_hygro_humid(s_hygro_humid),
		.i_hygro_valid(s_hygro_valid),
		.o_hygro_rd(s_hygro_rd),
		.o_hygro_wr(s_hygro_wr),
		.o_display_temp(s_display_temp),
		.o_display_humid(s_display_humid),
		.o_hygro_op_mode(s_hygro_op_mode),
		.o_hygro_display_mode(s_hygro_display_mode)
	);

/* Hygro Configuration, static value: enable reading of both the temperature
   and relative humidity 16-bit register measurement reading values in a
   single I2C read sequence. */
assign s_hygro_config = 16'b0001000000000000;

/* Tri-state outputs of PMOD CLS custom driver. */
assign eo_pmod_cls_sck = so_pmod_cls_sck_t ? 1'bz : so_pmod_cls_sck_o;
assign eo_pmod_cls_csn = so_pmod_cls_csn_t ? 1'bz : so_pmod_cls_csn_o;
assign eo_pmod_cls_dq0 = so_pmod_cls_copi_t ? 1'bz : so_pmod_cls_copi_o;

/* Instance of the PMOD CLS driver for 16x2 character LCD display for purposes
   of an output display. */
pmod_cls_custom_driver #(
	.parm_fast_simulation(parm_fast_simulation),
	.FCLK(c_FCLK),
   .FCLK_ce(2500000),
	.parm_ext_spi_clk_ratio(32),
	.parm_wait_cyc_bits(`c_stand_spi_wait_count_bits)
	) u_pmod_cls_custom_driver (
	.i_clk_20mhz(s_clk_20mhz),
	.i_rst_20mhz(s_rst_20mhz),
	.i_ce_2_5mhz(s_ce_2_5mhz),
	.eo_sck_t(so_pmod_cls_sck_t),
	.eo_sck_o(so_pmod_cls_sck_o),
	.eo_csn_t(so_pmod_cls_csn_t),
	.eo_csn_o(so_pmod_cls_csn_o),
	.eo_copi_t(so_pmod_cls_copi_t),
	.eo_copi_o(so_pmod_cls_copi_o),
	.ei_cipo(ei_pmod_cls_dq1),
	.o_command_ready(s_cls_command_ready),
	.i_cmd_wr_clear_display(s_cls_wr_clear_display),
	.i_cmd_wr_text_line1(s_cls_wr_text_line1),
	.i_cmd_wr_text_line2(s_cls_wr_text_line2),
	.i_dat_ascii_line1(s_cls_txt_ascii_line1),
	.i_dat_ascii_line2(s_cls_txt_ascii_line2));

assign s_cls_txt_ascii_line1 = s_hygro_txt_ascii_line1;
assign s_cls_txt_ascii_line2 = s_hygro_txt_ascii_line2;

/* LCD Update FSM */
lcd_text_feed #(
  .parm_fast_simulation(parm_fast_simulation)
  ) u_lcd_text_feed (
  .i_clk_20mhz(s_clk_20mhz),
  .i_rst_20mhz(s_rst_20mhz),
  .i_ce_2_5mhz(s_ce_2_5mhz),
  .i_lcd_command_ready(s_cls_command_ready),
  .o_lcd_wr_clear_display(s_cls_wr_clear_display),
  .o_lcd_wr_text_line1(s_cls_wr_text_line1),
  .o_lcd_wr_text_line2(s_cls_wr_text_line2),
  .o_lcd_feed_is_idle(s_cls_feed_is_idle)
  );

/* Measurement Readings to ASCII conversion */
// TODO: create hdc1080_readings_to_ascii module
hdc1080_readings_to_ascii #(
	) u_hdc1080_readings_to_ascii (
      .i_clk(s_clk_20mhz),
      .i_srst(s_rst_20mhz),
		.i_display_temp(s_display_temp),
		.i_display_humid(s_display_humid),
      .i_hygro_op_mode(s_hygro_op_mode),
		.i_hygro_display_mode(s_hygro_display_mode),
    	.o_txt_ascii_line1(s_hygro_txt_ascii_line1),
		.o_txt_ascii_line2(s_hygro_txt_ascii_line2)
	);

/* The UART line contains a space between lines 1 and 2 */
assign s_uart_dat_ascii_line = {
	s_hygro_txt_ascii_line1,
	8'h20,
	s_hygro_txt_ascii_line2,
	8'h0D, 8'h0A};

assign s_uart_tx_go = s_cls_wr_clear_display;

/* UART driver for only the TX data */
uart_tx_only #(
	.BAUD(115200)
  ) u_uart_tx_only (
	.i_clk_20mhz  (s_clk_20mhz),
	.i_rst_20mhz  (s_rst_20mhz),
	.i_clk_7_37mhz(s_clk_7_37mhz),
	.i_rst_7_37mhz(s_rst_7_37mhz),
	.eo_uart_tx   (eo_uart_tx),
	.i_tx_data    (s_uart_txdata),
	.i_tx_valid   (s_uart_txvalid),
	.o_tx_ready   (s_uart_txready)
	);

/* FSM to feed a 34 character line upon trigger pulse to the TX ONLY driver */
uart_tx_feed #(
  ) u_uart_tx_feed (
  .i_clk_20mhz(s_clk_20mhz),
  .i_rst_20mhz(s_rst_20mhz),
  .o_tx_data(s_uart_txdata),
  .o_tx_valid(s_uart_txvalid),
  .i_tx_ready(s_uart_txready),
  .i_tx_go(s_uart_tx_go),
  .i_dat_ascii_line(s_uart_dat_ascii_line)
  );

/* A single PMOD SSD, two digit seven segment display */
one_pmod_ssd_display #() u_one_pmod_ssd_display (
  .i_clk_20mhz(s_clk_20mhz),
  .i_rst_20mhz(s_rst_20mhz),
  .i_value0(s_display_index_value0),
  .i_value1(s_display_index_value1),
  .o_ssd_pmod0(eo_ssd_pmod0)
  );

endmodule
//------------------------------------------------------------------------------

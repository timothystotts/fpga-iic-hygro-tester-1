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
-- \file led_palette_pulser.v
--
-- \brief A simple pulser to generate palette values for \ref led_pwm_driver.v .
------------------------------------------------------------------------------*/
//Recursive Moore Machine-------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module led_palette_pulser(i_clk, i_srst, o_color_led_red_value,
	o_color_led_green_value, o_color_led_blue_value, o_basic_led_lumin_value,
	o_display_index_value0, o_display_index_value1,
	i_hygro_op_mode, i_hygro_display_mode);

parameter integer parm_color_led_count = 4;
parameter integer parm_basic_led_count = 4;
parameter integer parm_FCLK = 40_000_000;
parameter integer parm_adjustments_per_second = 128;

localparam integer c_color_value_upper = 8 * parm_color_led_count - 1;
localparam integer c_basic_value_upper = 8 * parm_basic_led_count - 1;
localparam integer c_color_count_upper = parm_color_led_count - 1;
localparam integer c_basic_count_upper = parm_basic_led_count - 1;

// clock and reset
input wire i_clk;
input wire i_srst;

// palette out values
output wire [c_color_value_upper:0] o_color_led_red_value;
output wire [c_color_value_upper:0] o_color_led_green_value;
output wire [c_color_value_upper:0] o_color_led_blue_value;
output wire [c_basic_value_upper:0] o_basic_led_lumin_value;

// 7sd output values
output reg [3:0] o_display_index_value0;
output reg [3:0] o_display_index_value1;

// system statuses to adjust LEDs by
input wire [0:0] i_hygro_op_mode;
input wire [2:0] i_hygro_display_mode;

//Part 2: Declarations----------------------------------------------------------
// Color LED PWM driver input scale signals for 8-bit color mixing that
// makes the color LEDs appear to pulse in luminostiry and hue.
`include "hygro_tester_fsm_include.vh"

wire s_tester_led_ce;

wire [7:0] s_ld0_red_value;
wire [7:0] s_ld1_red_value;
wire [7:0] s_ld2_red_value;
wire [7:0] s_ld3_red_value;
wire [7:0] s_ld0_green_value;
wire [7:0] s_ld1_green_value;
wire [7:0] s_ld2_green_value;
wire [7:0] s_ld3_green_value;
wire [7:0] s_ld0_blue_value;
wire [7:0] s_ld1_blue_value;
wire [7:0] s_ld2_blue_value;
wire [7:0] s_ld3_blue_value;
reg [7:0] s_ld4_basic_value;
reg [7:0] s_ld5_basic_value;
reg [7:0] s_ld6_basic_value;
reg [7:0] s_ld7_basic_value;

reg [5:0] s_ld0_red_pulse;
reg [5:0] s_ld0_green_pulse;
reg [5:0] s_ld0_blue_pulse;
reg s_ld0_dir_pulse;
reg [5:0] s_ld0_led_pulse;

reg [5:0] s_ld1_red_pulse;
reg [5:0] s_ld1_green_pulse;
reg [5:0] s_ld1_blue_pulse;
reg s_ld1_dir_pulse;
reg [5:0] s_ld1_led_pulse;

reg [5:0] s_ld2_red_pulse;
reg [5:0] s_ld2_green_pulse;
reg [5:0] s_ld2_blue_pulse;
reg s_ld2_dir_pulse;
reg [5:0] s_ld2_led_pulse;

reg [5:0] s_ld3_red_pulse;
reg [5:0] s_ld3_green_pulse;
reg [5:0] s_ld3_blue_pulse;
reg s_ld3_dir_pulse;
reg [5:0] s_ld3_led_pulse;

//Part 3: Statements------------------------------------------------------------
// A clock enable divider for the process \ref p_tester_fsm_display .
// Divides the 20 MHz clock down to 128 enables per 1.5 seconds.
clock_enable_divider #(
	.par_ce_divisor(parm_FCLK / parm_adjustments_per_second)
	) u_clock_enable_led_pulse (
	.o_ce_div(s_tester_led_ce),
	.i_clk_mhz(i_clk),
	.i_rst_mhz(i_srst),
	.i_ce_mhz(1'b1)
	);

/* Tester FSM registered outputs to multicolor LED 0:3 to indicate the
   execution state of \ref p_tester_fsm_state and \ref p_tester_comb and also
   the status register Activity and Inactivity. Also displayed on LED 4
   is the AWAKE state of the PMOD ACL2; and on LED 6,7 the Switch 0
   and Switch 1 debounced positions. */
assign o_color_led_red_value = {s_ld3_red_value, s_ld2_red_value, s_ld1_red_value, s_ld0_red_value};
assign o_color_led_green_value = {s_ld3_green_value, s_ld2_green_value, s_ld1_green_value, s_ld0_green_value};
assign o_color_led_blue_value = {s_ld3_blue_value, s_ld2_blue_value, s_ld1_blue_value, s_ld0_blue_value};
assign o_basic_led_lumin_value = {s_ld7_basic_value, s_ld6_basic_value, s_ld5_basic_value, s_ld4_basic_value};

assign s_ld0_red_value = {s_ld0_red_pulse, 2'b11};
assign s_ld0_green_value = {s_ld0_green_pulse, 2'b11};
assign s_ld0_blue_value = {s_ld0_blue_pulse, 2'b11};

assign s_ld1_red_value = {s_ld1_red_pulse, 2'b11};
assign s_ld1_green_value = {s_ld1_green_pulse, 2'b11};
assign s_ld1_blue_value = {s_ld1_blue_pulse, 2'b11};

assign s_ld2_red_value = {s_ld2_red_pulse, 2'b11};
assign s_ld2_green_value = {s_ld2_green_pulse, 2'b11};
assign s_ld2_blue_value = {s_ld2_blue_pulse, 2'b11};

assign s_ld3_red_value = {s_ld3_red_pulse, 2'b11};
assign s_ld3_green_value = {s_ld3_green_pulse, 2'b11};
assign s_ld3_blue_value = {s_ld3_blue_pulse, 2'b11};

always @(posedge i_clk)
begin: p_tester_led_pulse
	if (i_srst) begin
		s_ld0_dir_pulse <= 1'b0;
		s_ld0_led_pulse <= 6'b000001;
		s_ld1_dir_pulse <= 1'b0;
		s_ld1_led_pulse <= 6'b010101;
		s_ld2_dir_pulse <= 1'b0;
		s_ld2_led_pulse <= 6'b101010;
		s_ld3_dir_pulse <= 1'b0;
		s_ld3_led_pulse <= 6'b111111;
	end else if (s_tester_led_ce) begin
		// Rotate up and down a pulse value to be used for LD0
		if (s_ld0_dir_pulse)
			if (s_ld0_led_pulse == 6'b111111)
				s_ld0_dir_pulse <= 1'b0;
			else
				s_ld0_led_pulse <= s_ld0_led_pulse + 1;
		else
			if (s_ld0_led_pulse == 6'b000001)
				s_ld0_dir_pulse <= 1'b1;
			else
				s_ld0_led_pulse <= s_ld0_led_pulse - 1;
		// Rotate up and down a pulse value to be used for LD1
		if (s_ld1_dir_pulse)
			if (s_ld1_led_pulse == 6'b111111)
				s_ld1_dir_pulse <= 1'b0;
			else
				s_ld1_led_pulse <= s_ld1_led_pulse + 1;
		else
			if (s_ld1_led_pulse == 6'b000001)
				s_ld1_dir_pulse <= 1'b1;
			else
				s_ld1_led_pulse <= s_ld1_led_pulse - 1;
		// Rotate up and down a pulse value to be used for LD2
		if (s_ld2_dir_pulse)
			if (s_ld2_led_pulse == 6'b111111)
				s_ld2_dir_pulse <= 1'b0;
			else
				s_ld2_led_pulse <= s_ld2_led_pulse + 1;
		else
			if (s_ld2_led_pulse == 6'b000001)
				s_ld2_dir_pulse <= 1'b1;
			else
				s_ld2_led_pulse <= s_ld2_led_pulse - 1;
		// Rotate up and down a pulse value to be used for LD3
		if (s_ld3_dir_pulse)
			if (s_ld3_led_pulse == 6'b111111)
				s_ld3_dir_pulse <= 1'b0;
			else
				s_ld3_led_pulse <= s_ld3_led_pulse + 1;
		else
			if (s_ld3_led_pulse == 6'b000001)
				s_ld3_dir_pulse <= 1'b1;
			else
				s_ld3_led_pulse <= s_ld3_led_pulse - 1;
	end
end

always @(posedge i_clk)
begin: p_tester_led_display
	// If OP NONE mode, turn LED0 red,
	// else if DISPLAY BOTH FARH, turn LED0 blue,
	// else if DISPLAY BOTH CELCIUS, turn LED0 green,
	// else turn LED0 low white
	if (i_hygro_op_mode == OP_NONE) begin
		// LED 0 will be red when op mode is NONE
		s_ld0_red_pulse <= s_ld0_led_pulse;
		s_ld0_green_pulse <= 6'b000001;
		s_ld0_blue_pulse <= 6'b000001;
	end else if (i_hygro_display_mode == DISP_BOTH_FARH) begin
		// LED 0 will be green when tester is running.
		s_ld0_red_pulse <= 6'b000001;
		s_ld0_green_pulse <= 6'b000001;
		s_ld0_blue_pulse <= s_ld0_led_pulse;
	end else if (i_hygro_display_mode == DISP_BOTH_CELCIUS) begin
		// LED 0 will be blue when tester is not working at all.
		s_ld0_red_pulse <= 6'b000001;
		s_ld0_green_pulse <= s_ld0_led_pulse;
		s_ld0_blue_pulse <= 6'b000001;
	end else begin
		s_ld0_red_pulse <= 6'b000001;
		s_ld0_green_pulse <= 6'b000001;
		s_ld0_blue_pulse <= 6'b000001;
	end

	// If OP NONE mode, turn LED1 red,
	// else if DISPLAY ONLY TEMP C, turn LED1 green,
	// else turn LED1 low white
	if (i_hygro_op_mode == OP_NONE) begin
		s_ld1_red_pulse <= s_ld1_led_pulse;
		s_ld1_green_pulse <= 6'b000001;
		s_ld1_blue_pulse <= 6'b000001;
	end else if (i_hygro_display_mode == DISP_ONLY_TEMP_C) begin
		s_ld1_red_pulse <= 6'b000001;
		s_ld1_green_pulse <= s_ld1_led_pulse;
		s_ld1_blue_pulse <= 6'b000001;
	end else begin
		s_ld1_red_pulse <= 6'b000001;
		s_ld1_green_pulse <= 6'b000001;
		s_ld1_blue_pulse <= 6'h000001;
	end

	// If OP NONE mode, turn LED2 red,
	// else if DISPLAY ONLY TEMP F, turn LED2 blue,
	// else turn LED2 low white
	if (i_hygro_op_mode == OP_NONE) begin
		s_ld2_red_pulse <= s_ld2_led_pulse;
		s_ld2_green_pulse <= 6'b000001;
		s_ld2_blue_pulse <= 6'b000001;
	end else if (i_hygro_display_mode == DISP_ONLY_TEMP_F) begin
		s_ld2_red_pulse <= 6'b000001;
		s_ld2_green_pulse <= 6'b000001;
		s_ld2_blue_pulse <= s_ld2_led_pulse;
	end else begin
		s_ld2_red_pulse <= 6'b000001;
		s_ld2_green_pulse <= 6'b000001;
		s_ld2_blue_pulse <= 6'b000001;
	end

	// If OP NONE mode, turn LED3 red,
	// else if DISPLAY ONLY HUMID, turn LED3 green,
	// else turn LED3 low white
	if (i_hygro_op_mode == OP_NONE) begin
		s_ld3_red_pulse <= s_ld3_led_pulse;
		s_ld3_green_pulse <= 6'b000001;
		s_ld3_blue_pulse <= 6'b000001;
	end else if (i_hygro_display_mode == DISP_ONLY_HUMID) begin
		s_ld3_red_pulse <= 6'b000001;
		s_ld3_green_pulse <= s_ld3_led_pulse;
		s_ld3_blue_pulse <= 6'b000001;
	end else begin
		s_ld3_red_pulse <= 6'b000001;
		s_ld3_green_pulse <= 6'b000001;
		s_ld3_blue_pulse <= 6'b000001;
	end

	// If OP NONE mode, turn off the basic LEDs, 4-7
	// else, turn on the basic LEDs, 4-7.
	if (i_hygro_op_mode == OP_NONE) begin
		s_ld4_basic_value <= 8'h00;
		s_ld5_basic_value <= 8'h00;
		s_ld6_basic_value <= 8'h00;
		s_ld7_basic_value <= 8'h00;
	end else begin
		s_ld4_basic_value <= 8'hFF;
		s_ld5_basic_value <= 8'hFF;
		s_ld6_basic_value <= 8'hFF;
		s_ld7_basic_value <= 8'hFF;
	end
end

always @(posedge i_clk)
begin: p_tester_7sd_display
	case (i_hygro_display_mode)
		DISP_BOTH_CELCIUS: begin
			o_display_index_value0 <= 1;
			o_display_index_value1 <= 1;
		end
		DISP_BOTH_FARH: begin
			o_display_index_value0 <= 1;
			o_display_index_value1 <= 2;
		end
		DISP_ONLY_TEMP_C: begin
			o_display_index_value0 <= 0;
			o_display_index_value1 <= 1;
		end
		DISP_ONLY_TEMP_F: begin
			o_display_index_value0 <= 0;
			o_display_index_value1 <= 2;
		end
		DISP_ONLY_HUMID: begin
			o_display_index_value0 <= 1;
			o_display_index_value1 <= 0;
		end
		default: begin
			o_display_index_value0 <= 0;
			o_display_index_value1 <= 0;
		end
	endcase
end

endmodule
//------------------------------------------------------------------------------

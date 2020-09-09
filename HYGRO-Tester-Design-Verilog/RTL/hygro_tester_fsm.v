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
-- \file hygro_tester_fsm.v
--
-- \brief A simple pulser to generate palette values for \ref led_pwm_driver.v .
------------------------------------------------------------------------------*/
//Recursive Moore Machine-------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module hygro_tester_fsm(
    /* clock and reset */
    i_clk_20mhz, i_rst_20mhz,
    /* user inputs */
    i_switches_debounced, i_buttons_debounced,
    /* value inputs */
    i_hygro_temp, i_hygro_humid, i_hygro_valid,
    /* control output pulses */
    o_hygro_rd, o_hygro_wr,
    /* display values changing on valid strobe */
    o_display_temp, o_display_humid,
    /* display mode value based on buttons */
    o_hygro_op_mode, o_hygro_display_mode);

parameter integer parm_fast_simulation = 0;

input wire i_clk_20mhz;
input wire i_rst_20mhz;

input wire [3:0] i_switches_debounced;
input wire [3:0] i_buttons_debounced;

input wire [15:0] i_hygro_temp;
input wire [15:0] i_hygro_humid;
input wire i_hygro_valid;

output reg o_hygro_rd;
output reg o_hygro_wr;

output reg [15:0] o_display_temp;
output reg [15:0] o_display_humid;

output reg [0:0] o_hygro_op_mode;
output reg [2:0] o_hygro_display_mode;

//Part 2: Declarations----------------------------------------------------------
`include "hygro_tester_fsm_include.vh"

localparam integer c_wr_rd_cycle_duration_clk = 10000000;

/* This constant is set to loop device access every 40 ms for simulation, */
/* and for synthesized results, to loop device access every 1 seconds, which
   according to the PMOD HYGRO datasheet, is the fastest poll time to not
   overheat the temperature sensor and thus produce invalid readings. */
localparam integer c_wr_rd_cycle_duration_time = (parm_fast_simulation) ?
	(c_wr_rd_cycle_duration_clk / 250) : (c_wr_rd_cycle_duration_clk / 10);

/* LUT-lookup FSM variables for process \ref p_run_hygro */
integer v_counter1;
reg [3:0] v_counter2;
reg v_configured;

reg [3:0] s_prev_switches;
reg [3:0] s_prev_buttons;

//Part 3: Statements------------------------------------------------------------
/* A synchronous counter with LUT-lookup FSM to initialize the HYGRO via
   communication with the HYGRO driver; and then to poll for HYGRO
   measurements on a timer, which is set to once per second. */
always @(posedge i_clk_20mhz)
begin: p_run_hygro
	/* Syncrhonous reset */
	if (i_rst_20mhz) begin
		v_counter1 <= 0;
		v_counter2 <= 0;
		v_configured <= 1'b0;
    end else if (i_switches_debounced != 4'b0001) begin
		v_counter1 <= 0;
		v_counter2 <= 0;
		v_configured <= 1'b0;        
	end else begin
		/* Synchronous processing of Counter 1 and divided Counter 2. */
		if (v_counter1 < c_wr_rd_cycle_duration_time) begin
			v_counter1 <= v_counter1 + 1;
		end else begin
			v_counter1 <= 0;

			if (v_counter2 < 9) begin
				v_counter2 <= v_counter2 + 1;
			end else begin
				v_counter2 <= 0;
			end
		end

		if (v_counter2 == 8) v_configured <= 1'b1;
	end
end

/* LUT-lookup FSM, Where the divided Counter 2 operates the outputs
   of the FSM: WR pulse strobe, RD pulse strobe. It only generates
   the WR pulse strobe at State 7 upon the first time that state
   is visited. Afterword, only State 9 outputs a pulse (RD). */
always @(v_counter2, v_configured)
begin: p_run_hygro_lut
	case (v_counter2)
		7: begin
			if (~ v_configured) o_hygro_wr = 1'b1;
			else o_hygro_wr = 1'b0;
			o_hygro_rd = 1'b0;
		end
		8: begin
			o_hygro_wr = 1'b0;
			o_hygro_rd = 1'b0;
		end
		9: begin
			o_hygro_wr = 1'b0;
			o_hygro_rd = 1'b1;
		end
		default: begin /* cases 0, 1, 2, 3, 4, 5, 6 */
			o_hygro_wr = 1'b0;
			o_hygro_rd = 1'b0;
		end
	endcase
end

/* Capture completed reading of HYGRO temperature and humidity for display
   No fix required. The valid pulse is assigned at x4 clock enable on the
   400_000 Hz clock, thus extending the valid pulse for more than one clock
   cycle of the 10 MHz clock. */
always @(posedge i_clk_20mhz)
begin: p_capture_hygro
	if (i_rst_20mhz) begin
		o_display_temp <= 16'h0000;
		o_display_humid <= 16'h0000;
	end else
		if (i_hygro_valid) begin
			o_display_temp <= i_hygro_temp;
			o_display_humid <= i_hygro_humid;
		end
end

/* Process basd on user inputs what mode the display is in. */
always @(posedge i_clk_20mhz)
begin: p_process_userio
    if (i_rst_20mhz) begin
        o_hygro_op_mode <= OP_NONE;
        o_hygro_display_mode <= DISP_NONE;
        s_prev_buttons <= 4'b0000;
    end else begin
        s_prev_buttons <= i_buttons_debounced;

        if (i_switches_debounced == 4'b0001)
            o_hygro_op_mode <= OP_POLL_HYGRO;
        else
            o_hygro_op_mode <= OP_NONE;

        if ((s_prev_buttons == 4'b0000) && (i_buttons_debounced == 4'b0001))
            if ((o_hygro_display_mode == DISP_BOTH_FARH) || (o_hygro_display_mode == DISP_ONLY_TEMP_F))
                o_hygro_display_mode <= DISP_BOTH_CELCIUS;
            else
                o_hygro_display_mode <= DISP_BOTH_FARH;
        
        if ((s_prev_buttons == 4'b0000) && (i_buttons_debounced == 4'b0010))
            o_hygro_display_mode <= DISP_ONLY_TEMP_C;

        if ((s_prev_buttons == 4'b0000) && (i_buttons_debounced == 4'b0100))
            o_hygro_display_mode <= DISP_ONLY_TEMP_F;

        if ((s_prev_buttons == 4'b0000) && (i_buttons_debounced == 4'b1000))
            o_hygro_display_mode <= DISP_ONLY_HUMID;
    end
end

endmodule
//------------------------------------------------------------------------------

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
-- \file hdc1080_readings_to_ascii.v
--
-- \brief A combinatorial block to convert HDC1080 Readings to ASCII text
-- representations.
------------------------------------------------------------------------------*/
//Recursive Moore Machine-------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module hdc1080_readings_to_ascii(
    // Clock and reset
    i_clk, i_srst,
    // 16-bit raw values of temperature and humidity
    i_display_temp, i_display_humid,
    // system statuses to adjust text diplay by
    i_hygro_op_mode, i_hygro_display_mode,
    // output two lines of text
    o_txt_ascii_line1, o_txt_ascii_line2);

input wire i_clk;
input wire i_srst;

input wire [15:0] i_display_temp;
input wire [15:0] i_display_humid;

input wire [0:0] i_hygro_op_mode;
input wire [2:0] i_hygro_display_mode;

output reg [(16*8-1):0] o_txt_ascii_line1;
output reg [(16*8-1):0] o_txt_ascii_line2;

//Part 2: Declarations----------------------------------------------------------
`include "hygro_tester_fsm_include.vh"

/* A re-entrant function that converts a 4-bit part-select to an 8-bit ASCII
   hexadecimal character. */
function automatic [7:0] ascii_of_hdigit(input [3:0] bchex_val);
	begin
		if (bchex_val < 10) ascii_of_hdigit = 8'h30 + {4'h0, bchex_val};
		else ascii_of_hdigit = 8'h37 + {4'h0, bchex_val};
	end
endfunction

integer s_temperature_c;
integer s_temperature_f;
integer s_humidity_p;

wire [15:0] s_val_tempc_m2;
wire [15:0] s_val_tempc_m1;
wire [15:0] s_val_tempc_m0;
wire [15:0] s_val_tempc_f0;
wire [15:0] s_val_tempc_f1;

wire [15:0] s_val_tempf_m2;
wire [15:0] s_val_tempf_m1;
wire [15:0] s_val_tempf_m0;
wire [15:0] s_val_tempf_f0;
wire [15:0] s_val_tempf_f1;

wire [15:0] s_val_humidp_m2;
wire [15:0] s_val_humidp_m1;
wire [15:0] s_val_humidp_m0;
wire [15:0] s_val_humidp_f0;
wire [15:0] s_val_humidp_f1;

wire [(16*8-1):0] s_txt_ascii_line1_no_op;
wire [(16*8-1):0] s_txt_ascii_line1_no_display;
wire [(16*8-1):0] s_txt_ascii_line1_tempc;
wire [(16*8-1):0] s_txt_ascii_line1_tempf;
wire [(16*8-1):0] s_txt_ascii_line1_blank;

wire [(16*8-1):0] s_txt_ascii_line2_no_op;
wire [(16*8-1):0] s_txt_ascii_line2_no_display;
wire [(16*8-1):0] s_txt_ascii_line2_humidp;
wire [(16*8-1):0] s_txt_ascii_line2_blank;

//Part 3: Statements------------------------------------------------------------
always @(posedge i_clk)
begin: p_calc_temp_c
    /* Simple fixed-point form of:
        deg_c = 256.0 * bytes[0] + 1.0 * bytes[1];
        deg_c /= 65536.0;
        deg_c *= 160.0;
        deg_c -= 40.0; // Conversion provided in reference manual
        deg_c *= 100.0;
    */
    s_temperature_c <= (((i_display_temp - 16384) * 125) >> 9);
end

assign s_val_tempc_m2 = (s_temperature_c / 10000) % 10;
assign s_val_tempc_m1 = (s_temperature_c / 1000) % 10;
assign s_val_tempc_m0 = (s_temperature_c / 100) % 10;
assign s_val_tempc_f0 = (s_temperature_c / 10) % 10;
assign s_val_tempc_f1 = (s_temperature_c / 1) % 10;

/* ASCII Text String of sprintf: "Temp : % 3.2f00C" */
assign s_txt_ascii_line1_tempc = {
    8'h54, 8'h65, 8'h6D, 8'h70, 8'h20, 8'h3A, 8'h20,
    (s_val_tempc_m2[3-:4] == 4'h0) ? 8'h20 : ascii_of_hdigit(s_val_tempc_m2[3-:4]),
    ((s_val_tempc_m2[3-:4] == 4'h0) && (s_val_tempc_m1[3-:4] == 4'h0)) ? 8'h20 : ascii_of_hdigit(s_val_tempc_m1[3-:4]),
    ascii_of_hdigit(s_val_tempc_m0[3-:4]),
    8'h2E,
    ascii_of_hdigit(s_val_tempc_f0[3-:4]),
    ascii_of_hdigit(s_val_tempc_f1[3-:4]),
    8'h30, 8'h30, 8'h43
    };

always @(posedge i_clk)
begin: p_calc_temp_f
    /* Simple fixed-point form of:
    deg_f = deg_c * 1.8 + 32;
    */
    //s_temperature_f <= (s_temperature_c * 9 / 5 + 3200);
    s_temperature_f <= ((225 * i_display_temp) >> 9) - 4000;
end

assign s_val_tempf_m2 = (s_temperature_f / 10000) % 10;
assign s_val_tempf_m1 = (s_temperature_f / 1000) % 10;
assign s_val_tempf_m0 = (s_temperature_f / 100) % 10;
assign s_val_tempf_f0 = (s_temperature_f / 10) % 10;
assign s_val_tempf_f1 = (s_temperature_f / 1) % 10;

/* ASCII Text String of sprintf: "Temp : % 3.2f00F" */
assign s_txt_ascii_line1_tempf = {
    8'h54, 8'h65, 8'h6D, 8'h70, 8'h20, 8'h3A, 8'h20,
    (s_val_tempf_m2[3-:4] == 4'h0) ? 8'h20 : ascii_of_hdigit(s_val_tempf_m2[3-:4]),
    ((s_val_tempf_m2[3-:4] == 4'h0) && (s_val_tempf_m1[3-:4] == 4'h0)) ? 8'h20 : ascii_of_hdigit(s_val_tempf_m1[3-:4]),
    ascii_of_hdigit(s_val_tempf_m0[3-:4]),
    8'h2E,
    ascii_of_hdigit(s_val_tempf_f0[3-:4]),
    ascii_of_hdigit(s_val_tempf_f1[3-:4]),
    8'h30, 8'h30, 8'h46
    };

/* Blank Line 1 */
assign s_txt_ascii_line1_blank = {
    8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20,
    8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20};

/* Line 1: "Idle. Enable    " */
assign s_txt_ascii_line1_no_op = {
    8'h49, 8'h64, 8'h6C, 8'h65, 8'h2E,
    8'h20,
    8'h45, 8'h6E, 8'h61, 8'h62, 8'h6C, 8'h65,
    8'h20, 8'h20, 8'h20, 8'h20
};

/* Line 1: "Idle. Press     " */
assign s_txt_ascii_line1_no_display = {
    8'h49, 8'h64, 8'h6C, 8'h65, 8'h2E,
    8'h20,
    8'h50, 8'h72, 8'h65, 8'h73, 8'h73,
    8'h20, 8'h20, 8'h20, 8'h20, 8'h20
};

/* Pass combinatorial Line 1 based on hygro op and display */
/*
assign o_txt_ascii_line1 =
    (i_hygro_op_mode != OP_POLL_HYGRO) ? s_txt_ascii_line1_no_op :
    ((i_hygro_display_mode == DISP_BOTH_CELCIUS) || (i_hygro_display_mode == DISP_ONLY_TEMP_C)) ? s_txt_ascii_line1_tempc :
    ((i_hygro_display_mode == DISP_BOTH_FARH) || (i_hygro_display_mode == DISP_ONLY_TEMP_F)) ? s_txt_ascii_line1_tempf :
    (i_hygro_display_mode == DISP_ONLY_HUMID) ? s_txt_ascii_line1_blank :
    s_txt_ascii_line1_no_display;
*/
always @(posedge i_clk)
begin: p_choose_line1
    if (i_hygro_op_mode != OP_POLL_HYGRO)
        o_txt_ascii_line1 <= s_txt_ascii_line1_no_op;
    else
        case (i_hygro_display_mode)
            DISP_BOTH_CELCIUS: o_txt_ascii_line1 <= s_txt_ascii_line1_tempc;
            DISP_ONLY_TEMP_C: o_txt_ascii_line1 <= s_txt_ascii_line1_tempc;
            DISP_BOTH_FARH: o_txt_ascii_line1 <= s_txt_ascii_line1_tempf;
            DISP_ONLY_TEMP_F: o_txt_ascii_line1 <= s_txt_ascii_line1_tempf;
            DISP_ONLY_HUMID: o_txt_ascii_line1 <= s_txt_ascii_line1_blank;
            default: o_txt_ascii_line1 <= s_txt_ascii_line1_no_display;
        endcase
end

always @(posedge i_clk)
begin: p_calc_humidp
    /* Simple fixed-point form of:
    per_rh = 256.0 * bytes[0] + 1.0 * bytes[1];
    per_rh /= 65536.0;
    per_rh *= 10000.0; // Conversion provided in reference manual
    */
    s_humidity_p <= ((i_display_humid * 625) >> 12);
end

assign s_val_humidp_m2 = (s_humidity_p / 10000) % 10;
assign s_val_humidp_m1 = (s_humidity_p / 1000) % 10;
assign s_val_humidp_m0 = (s_humidity_p / 100) % 10;
assign s_val_humidp_f0 = (s_humidity_p / 10) % 10;
assign s_val_humidp_f1 = (s_humidity_p / 1) % 10;

/* ASCII Text String of sprintf: "Humid: % 3.2f00%%" */
assign s_txt_ascii_line2_humidp = {
    8'h48, 8'h75, 8'h6D, 8'h69, 8'h64, 8'h3A, 8'h20,
    (s_val_humidp_m2[3-:4] == 4'h0) ? 8'h20 : ascii_of_hdigit(s_val_humidp_m2[3-:4]),
    ((s_val_humidp_m2[3-:4] == 4'h0) && (s_val_humidp_m1[3-:4] == 4'h0)) ? 8'h20 : ascii_of_hdigit(s_val_humidp_m1[3-:4]),
    ascii_of_hdigit(s_val_humidp_m0[3-:4]),
    8'h2E,
    ascii_of_hdigit(s_val_humidp_f0[3-:4]),
    ascii_of_hdigit(s_val_humidp_f1[3-:4]),
    8'h30, 8'h30, 8'h25
    };

/* Blank Line 1 */
assign s_txt_ascii_line2_blank = {
    8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20,
    8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20};

/* Line 2: "switch zero.    " */
assign s_txt_ascii_line2_no_op = {
    8'h73, 8'h77, 8'h69, 8'h74, 8'h63, 8'h68,
    8'h20,
    8'h7A, 8'h65, 8'h72, 8'h6F, 8'h2E,
    8'h20, 8'h20, 8'h20, 8'h20};

/* Line 2: "a button.       " */
assign s_txt_ascii_line2_no_display = {
    8'h61,
    8'h20,
    8'h62, 8'h75, 8'h74, 8'h74, 8'h6F, 8'h6E, 8'h2E,
    8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20};

/* Pass combinatorial Line 2 based on hygro op and display */
// assign o_txt_ascii_line2 =
//     (i_hygro_op_mode != OP_POLL_HYGRO) ? s_txt_ascii_line2_no_op :
//     ((i_hygro_display_mode == DISP_BOTH_CELCIUS) || (i_hygro_display_mode == DISP_BOTH_FARH) || (i_hygro_display_mode == DISP_ONLY_HUMID)) ? s_txt_ascii_line2_humidp :
//     ((i_hygro_display_mode == DISP_ONLY_TEMP_C) || (i_hygro_display_mode == DISP_ONLY_TEMP_F)) ? s_txt_ascii_line2_blank :
//     s_txt_ascii_line2_no_display;

always @(posedge i_clk)
begin: p_choose_line2
    if (i_hygro_op_mode != OP_POLL_HYGRO)
        o_txt_ascii_line2 <= s_txt_ascii_line2_no_op;
    else
        case (i_hygro_display_mode)
            DISP_BOTH_CELCIUS: o_txt_ascii_line2 <= s_txt_ascii_line2_humidp;
            DISP_ONLY_TEMP_C: o_txt_ascii_line2 <= s_txt_ascii_line2_blank;
            DISP_BOTH_FARH: o_txt_ascii_line2 <= s_txt_ascii_line2_humidp;
            DISP_ONLY_TEMP_F: o_txt_ascii_line2 <= s_txt_ascii_line2_blank;
            DISP_ONLY_HUMID: o_txt_ascii_line2 <= s_txt_ascii_line2_humidp;
            default: o_txt_ascii_line2 <= s_txt_ascii_line2_no_display;
        endcase
end

endmodule
//------------------------------------------------------------------------------

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
    i_display_temp, i_display_humid,
    o_txt_ascii_line1, o_txt_ascii_line2);

input wire [15:0] i_display_temp;
input wire [15:0] i_display_humid;

output wire [(16*8-1):0] o_txt_ascii_line1;
output wire [(16*8-1):0] o_txt_ascii_line2;

//Part 2: Declarations----------------------------------------------------------
/* A re-entrant function that converts a 4-bit part-select to an 8-bit ASCII
   hexadecimal character. */
function automatic [7:0] ascii_of_hdigit(input [3:0] bchex_val);
	begin
		if (bchex_val < 10) ascii_of_hdigit = 8'h30 + {4'h0, bchex_val};
		else ascii_of_hdigit = 8'h37 + {4'h0, bchex_val};
	end
endfunction

wire integer s_temperature_c;
wire integer s_humidity_p;

wire [15:0] s_val_tempc_m2;
wire [15:0] s_val_tempc_m1;
wire [15:0] s_val_tempc_m0;
wire [15:0] s_val_tempc_f0;
wire [15:0] s_val_tempc_f1;

wire [15:0] s_val_humidp_m2;
wire [15:0] s_val_humidp_m1;
wire [15:0] s_val_humidp_m0;
wire [15:0] s_val_humidp_f0;
wire [15:0] s_val_humidp_f1;

//Part 3: Statements------------------------------------------------------------
/* Simple fixed-point form of:
    deg_c = 256.0 * bytes[0] + 1.0 * bytes[1];
    deg_c /= 65536.0;
    deg_c *= 160.0;
    deg_c -= 40.0; // Conversion provided in reference manual
    deg_c *= 100.0;
*/
assign s_temperature_c = (((i_display_temp - 16384) * 125) >> 9);

assign s_val_tempc_m2 = (s_temperature_c / 10000) % 10;
assign s_val_tempc_m1 = (s_temperature_c / 1000) % 10;
assign s_val_tempc_m0 = (s_temperature_c / 100) % 10;
assign s_val_tempc_f0 = (s_temperature_c / 10) % 10;
assign s_val_tempc_f1 = (s_temperature_c / 1) % 10;

/* ASCII Text String of sprintf: "Temp : % 3.2f00C" */
assign o_txt_ascii_line1 = {
    8'h54, 8'h65, 8'h6D, 8'h70, 8'h20, 8'h3A, 8'h20,
    (s_val_tempc_m2[3-:4] == 4'h0) ? 8'h20 : ascii_of_hdigit(s_val_tempc_m2[3-:4]),
    ((s_val_tempc_m2[3-:4] == 4'h0) && (s_val_tempc_m1[3-:4] == 4'h0)) ? 8'h20 : ascii_of_hdigit(s_val_tempc_m1[3-:4]),
    ascii_of_hdigit(s_val_tempc_m0[3-:4]),
    8'h2E,
    ascii_of_hdigit(s_val_tempc_f0[3-:4]),
    ascii_of_hdigit(s_val_tempc_f1[3-:4]),
    8'h30, 8'h30, 8'h43
    };

/* Simple fixed-point form of:
   per_rh = 256.0 * bytes[0] + 1.0 * bytes[1];
   per_rh /= 65536.0;
   per_rh *= 10000.0; // Conversion provided in reference manual
*/
assign s_humidity_p = ((i_display_humid * 625) >> 12);

assign s_val_humidp_m2 = (s_humidity_p / 10000) % 10;
assign s_val_humidp_m1 = (s_humidity_p / 1000) % 10;
assign s_val_humidp_m0 = (s_humidity_p / 100) % 10;
assign s_val_humidp_f0 = (s_humidity_p / 10) % 10;
assign s_val_humidp_f1 = (s_humidity_p / 1) % 10;

/* ASCII Text String of sprintf: "Humid: % 3.2f00%%" */
assign o_txt_ascii_line2 = {
    8'h48, 8'h75, 8'h6D, 8'h69, 8'h64, 8'h3A, 8'h20,
    (s_val_humidp_m2[3-:4] == 4'h0) ? 8'h20 : ascii_of_hdigit(s_val_humidp_m2[3-:4]),
    ((s_val_humidp_m2[3-:4] == 4'h0) && (s_val_humidp_m1[3-:4] == 4'h0)) ? 8'h20 : ascii_of_hdigit(s_val_humidp_m1[3-:4]),
    ascii_of_hdigit(s_val_humidp_m0[3-:4]),
    8'h2E,
    ascii_of_hdigit(s_val_humidp_f0[3-:4]),
    ascii_of_hdigit(s_val_humidp_f1[3-:4]),
    8'h30, 8'h30, 8'h25
    };

endmodule
//------------------------------------------------------------------------------

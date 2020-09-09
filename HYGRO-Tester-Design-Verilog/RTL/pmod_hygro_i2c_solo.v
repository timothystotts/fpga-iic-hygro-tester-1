/*------------------------------------------------------------------------------
-- \file pmod_hygro_i2c_solo.vhd
--
-- \brief Interface to the PMOD HYGRO via I2C protocol with only the one unit
-- on the I2C bus (no pass-through).
--
-- \description This exercise is based upon Finite State Machines in Hardware:
-- Theory and Design by Volnei A. Pedroni, Exercise 14.5 for the I2C control
-- of a temperature sensor. The PMOD HYGRO from Digilent Inc is a temperature
-- and relative humidity sensor board with I2C communication protocol.
--
-- \copyright (c) 2019-2020 Timothy Stotts as self-employment unbilled consulting
-- studies; rights for the author to reuse in employment designs or instruction
-- as a coding starting point. The copyright of derivative works will transfer
-- to employer.
------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------
-- \module pmod_hygro_i2c_solo
--
-- \brief An I2C Master interface for communicating with the PMOD HYGRO board
-- from a FPGA, and no other I2C slave on the bus.
--
-- \description None
------------------------------------------------------------------------------*/
//Part 1: Module header:--------------------------------------------------------
module pmod_hygro_i2c_solo(i_clk, i_rst, i_wr, i_rd, eo_scl, eo_sda_o, ei_sda_i,
	eo_sda_t, i_config, o_humid, o_temp, o_valid);

parameter integer HOLD_I2C_BOTH_SCL_EDGES = 0;
parameter integer FCLK = 20000000;
parameter integer DATA_RATE = 100000;
parameter [7:0] HYGRO_ADDR_FOR_WR = 8'h80;
parameter [7:0] HYGRO_ADDR_FOR_RD = 8'h81;
parameter [7:0] HYGRO_CONFIG_REG_ADDR = 8'h02;
parameter [7:0] HYGRO_TEMP_REG_ADDR = 8'h00;
parameter [7:0] HYGRO_HUMID_REG_ADDR = 8'h81;

/* FPGA system interface control */
input wire i_clk;
input wire i_rst;
input wire i_wr;
input wire i_rd;

/* I2C Ports */
output reg eo_scl;
output reg eo_sda_o;
input wire ei_sda_i;
output reg eo_sda_t;

/* FPGA system access to HYGRO registers */
input wire [15:0] i_config;
output wire [15:0] o_humid;
output wire [15:0] o_temp;
output reg o_valid;

// Part 2: Declarations---------------------------------------------------------
`define c_hygro_drv_state_len 5
/* Common States */
localparam [(`c_hygro_drv_state_len - 1):0] ST_IDLE = 0;
localparam [(`c_hygro_drv_state_len - 1):0] ST_START = 1;
localparam [(`c_hygro_drv_state_len - 1):0] ST_SLAVE_ADDR_WR = 2;
localparam [(`c_hygro_drv_state_len - 1):0] ST_ACK1 = 3;
localparam [(`c_hygro_drv_state_len - 1):0] ST_STOP = 4;
localparam [(`c_hygro_drv_state_len - 1):0] ST_HOLD = 5;

/* Write-only states */
localparam [(`c_hygro_drv_state_len - 1):0] ST_INITIAL_ADDR_WR = 6;
localparam [(`c_hygro_drv_state_len - 1):0] ST_ACK2 = 7;
localparam [(`c_hygro_drv_state_len - 1):0] ST_WR_CONFIG_HI = 8;
localparam [(`c_hygro_drv_state_len - 1):0] ST_ACK3 = 9;
localparam [(`c_hygro_drv_state_len - 1):0] ST_WR_CONFIG_LO = 10;
localparam [(`c_hygro_drv_state_len - 1):0] ST_ACK4 = 11;

/* Read-only states */
localparam [(`c_hygro_drv_state_len - 1):0] ST_INITIAL_ADDR_RD = 12;
localparam [(`c_hygro_drv_state_len - 1):0] ST_ACK5 = 13;
localparam [(`c_hygro_drv_state_len - 1):0] ST_STOP_READING = 14;
localparam [(`c_hygro_drv_state_len - 1):0] ST_HOLD_READING = 15;
localparam [(`c_hygro_drv_state_len - 1):0] ST_START_READING = 16;
localparam [(`c_hygro_drv_state_len - 1):0] ST_SLAVE_ADDR_RD = 17;
localparam [(`c_hygro_drv_state_len - 1):0] ST_ACK6 = 18;
localparam [(`c_hygro_drv_state_len - 1):0] ST_RD_TEMP_HI = 19;
localparam [(`c_hygro_drv_state_len - 1):0] ST_ACK7 = 20;
localparam [(`c_hygro_drv_state_len - 1):0] ST_RD_TEMP_LO = 21;
localparam [(`c_hygro_drv_state_len - 1):0] ST_ACK8 = 22;
localparam [(`c_hygro_drv_state_len - 1):0] ST_RD_HUMID_HI = 23;
localparam [(`c_hygro_drv_state_len - 1):0] ST_ACK9 = 24;
localparam [(`c_hygro_drv_state_len - 1):0] ST_RD_HUMID_LO = 25;
localparam [(`c_hygro_drv_state_len - 1):0] ST_NO_ACK = 26;

(* fsm_encoding = "gray" *)
(* fsm_safe_state = "default_state" *)
reg [(`c_hygro_drv_state_len - 1):0] s_hygro_drv_pr_state = ST_IDLE;
reg [(`c_hygro_drv_state_len - 1):0] s_hygro_drv_nx_state = ST_IDLE;

/* Auxiliary registers */
reg [3:0] s_i_val;
reg [3:0] s_i_aux;
reg [15:0] s_humid_aux;
reg [15:0] s_temp_aux;
reg [15:0] s_config_val;
reg [15:0] s_config_aux;

/* Timer for 20 millisecond delay between Writing a READ Pointer, and then
   performing a READ Instruction of both the temperature and realtive
   humidity registers. Without this delay, the HDC1080 will not be ready
   for a new measurement to be read.*/
`define c_hold_counter_width 11
localparam [(`c_hold_counter_width - 1):0] c_hold_read_duration = DATA_RATE / 1000 * 20;

/* Auxiliary register for counting the timer of the HOLD READ while
   waiting for the HDC1080 to prepare its read registers with updated
   measurement data. */
reg [(`c_hold_counter_width - 1):0] s_hold_read_val;
reg [(`c_hold_counter_width - 1):0] s_hold_read_aux;

/* Other internal variables and connections */
wire s_i2c_clk_1x;
wire s_i2c_rst_1x;
wire s_i2c_clk_4x;
wire s_i2c_rst_4x;
reg s_i2c_clk_ce0;
// reg s_i2c_clk_ce1;
reg s_i2c_clk_ce2;
reg s_i2c_clk_ce3;
wire s_hold_scl_ce_start;
wire s_hold_scl_ce_stop;

//Part 3: Statements------------------------------------------------------------
/* Note that clock \ref s_i2c_clk_4x is exactly four timer the clock frequency
   of \ref s_i2c_clk_1x; both having the same phase as \ref i_clk . */

/* i2c clock for FSM, generated clock
   requires create_generated_clock constraint in XDC */
clock_divider #(
	.par_clk_divisor(FCLK / (4 * DATA_RATE))
	) u_i2c_4x_clock_divider (
	.i_clk_mhz(i_clk),
	.i_rst_mhz(i_rst),
	.o_clk_div(s_i2c_clk_4x),
	.o_rst_div(s_i2c_rst_4x)
	);

/* i2c clock for SCL output, generated clock
   requires create_generated_clock constraint in XDC */
clock_divider #(
	.par_clk_divisor(FCLK / DATA_RATE)
	) u_i2c_1x_clock_divider (
	.i_clk_mhz(i_clk),
	.i_rst_mhz(i_rst),
	.o_clk_div(s_i2c_clk_1x),
	.o_rst_div(s_i2c_rst_1x)
	);

/* The clock enables are timed for the I2C SDA line to change by the
   master at 25% clock period after the falling edge of SCL. This allows
   sufficient setup and hold time on both clock edges, as indicated by
   the HDC1080 datasheet. It was tested experimentally that the HDC1080
   does in fact require this alignment of the SDA line for its I2C bus
   to function, per the timing diagrams of the datasheet. The FSM textbook
   suggested with its example that some I2C buses have this requirement;
   but the textbook example only demonstrated an implementation of SDA
   changing at the falling edge of SCL without delay. */

generate if (HOLD_I2C_BOTH_SCL_EDGES != 0) begin
	/* Generate 25% clock period clock enables */
	always @(posedge s_i2c_clk_4x)
	begin: p_i2c_clk_edges
		reg [1:0] v_counter1;

		if (s_i2c_rst_4x)
			v_counter1 <= 2'd0;
		else
			if (v_counter1 < 2'd3) v_counter1 <= v_counter1 + 1;
			else v_counter1 <= 2'd0;

		/* Note that \ref v_counter1 is updated with delta delay after this
		   processing of the counter. Thus, counter at value zero causes
		   Clock Enable 1 to assert, couter at value one causes Clock Enable
		   2 to assert, and so forth. */
		case (v_counter1)
			0: begin
				s_i2c_clk_ce0 <= 1'b0;
				// s_i2c_clk_ce1 <= 1'b1;
				s_i2c_clk_ce2 <= 1'b0;
				s_i2c_clk_ce3 <= 1'b0;
			end
			1: begin
				s_i2c_clk_ce0 <= 1'b0;
				// s_i2c_clk_ce1 <= 1'b0;
				s_i2c_clk_ce2 <= 1'b1;
				s_i2c_clk_ce3 <= 1'b0;
			end
			2: begin
				s_i2c_clk_ce0 <= 1'b0;
				// s_i2c_clk_ce1 <= 1'b0;
				s_i2c_clk_ce2 <= 1'b0;
				s_i2c_clk_ce3 <= 1'b1;
			end
			3: begin
				s_i2c_clk_ce0 <= 1'b1;
				// s_i2c_clk_ce1 <= 1'b0;
				s_i2c_clk_ce2 <= 1'b0;
				s_i2c_clk_ce3 <= 1'b0;
			end
		endcase
	end

	assign s_hold_scl_ce_start = s_i2c_clk_1x || s_i2c_clk_ce3;
	assign s_hold_scl_ce_stop = s_i2c_clk_1x || s_i2c_clk_ce2;
end endgenerate

/* The clock enables are timed for the I2C SDA line to change by the
   master at 25% clock period after the falling edge of SCL. This allows
   sufficient setup and hold time on both clock edges, as indicated by
   the HDC1080 datasheet. It was tested experimentally that the HDC1080
   does in fact require this alignment of the SDA line for its I2C bus
   to function, per the timing diagrams of the datasheet. The FSM textbook
   suggested with its example that some I2C buses have this requirement;
   but the textbook example only demonstrated an implementation of SDA
   changing at the falling edge of SCL without delay. */
generate if (HOLD_I2C_BOTH_SCL_EDGES == 0) begin
	/* Generate 25% clock period clock enables */
	always @(posedge s_i2c_clk_4x)
	begin: p_i2c_clk_edges
		reg [1:0] v_counter1;

		if (s_i2c_rst_4x)
			v_counter1 <= 2'd0;
		else
			if (v_counter1 < 2'd3) v_counter1 <= v_counter1 + 1;
			else v_counter1 <= 2'd0;

		/* Note that \ref v_counter1 is updated with delta delay after this
		   processing of the counter. Thus, counter at value zero causes
		   Clock Enable 1 to assert, couter at value one causes Clock Enable
		   2 to assert, and so forth. */
		case (v_counter1)
			0: begin
				s_i2c_clk_ce0 <= 1'b1;
				// s_i2c_clk_ce1 <= 1'b0;
				s_i2c_clk_ce2 <= 1'b0;
				s_i2c_clk_ce3 <= 1'b0;
			end
			1: begin
				s_i2c_clk_ce0 <= 1'b0;
				// s_i2c_clk_ce1 <= 1'b1;
				s_i2c_clk_ce2 <= 1'b0;
				s_i2c_clk_ce3 <= 1'b0;
			end
			2: begin
				s_i2c_clk_ce0 <= 1'b0;
				// s_i2c_clk_ce1 <= 1'b0;
				s_i2c_clk_ce2 <= 1'b1;
				s_i2c_clk_ce3 <= 1'b0;
			end
			3: begin
				s_i2c_clk_ce0 <= 1'b0;
				// s_i2c_clk_ce1 <= 1'b0;
				s_i2c_clk_ce2 <= 1'b0;
				s_i2c_clk_ce3 <= 1'b1;
			end
		endcase
	end

	assign s_hold_scl_ce_start = s_i2c_clk_1x || s_i2c_clk_ce3;
	assign s_hold_scl_ce_stop = s_i2c_clk_1x || s_i2c_clk_ce2;
end endgenerate

/* FSM state register plus auxiliary registers.
   PR State and NX State are the synchronous present
   state and combinatorial next state, respectively.
   I is the auxliary register for counting write and
   read bits for states that write or read a byte.
   CONFIG is the auxiliary register that captures
   the HDC1080 configuration value synchronously
   one clock enable after a Write Pulse is received
   on the system interface. It is used to write
   the configuration register on the HDC1080 after
   the capture of the FSM input.
   HOLD READ is the auxiliary register for counting
   the timed delay after writing a READ register
   pointer, before issuing a READ command of the
   measurement data (without a READ RESTART). This
   is per the HDC1080 datasheet. */
always @(posedge s_i2c_clk_4x)
begin: p_fsm_state_aux
	if (s_i2c_rst_4x) begin
		s_hygro_drv_pr_state <= ST_IDLE;
		s_i_aux <= 0;
		s_config_aux <= 16'd0;
		s_hold_read_aux <= 0;
	end else if (s_i2c_clk_ce2) begin
		s_hygro_drv_pr_state <= s_hygro_drv_nx_state;
		s_i_aux <= s_i_val;
		s_config_aux <= s_config_val;
		s_hold_read_aux <= s_hold_read_val;
	end
end

/* FSM combinatorial logic.
   The sensitivity list requries for _val and _aux for all recursive
   auxiliary registers that process _val for reading and not only
   assignment. */
always @(s_hygro_drv_pr_state, i_wr, i_rd, s_i2c_clk_1x, s_i_val, s_i_aux,
			i_config, s_config_aux, s_hold_read_aux, s_hold_read_val,
			s_hold_scl_ce_start, s_hold_scl_ce_stop)
begin: p_fsm_comb
	case (s_hygro_drv_pr_state)
		/* Common States */
		ST_START: begin /* Start the I2C sequence with the start bit and start clock */
			eo_scl = s_hold_scl_ce_start;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_SLAVE_ADDR_WR;
		end

		ST_SLAVE_ADDR_WR: begin /* Write the address of the I2C slave device, with WRITE mode bit */
			eo_scl = s_i2c_clk_1x;
			eo_sda_t = 1'b0;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val > 0) eo_sda_o = HYGRO_ADDR_FOR_WR[8 - s_i_val];
			else eo_sda_o = HYGRO_ADDR_FOR_WR[7];

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_ACK1;
			else s_hygro_drv_nx_state = ST_SLAVE_ADDR_WR;
		end

		ST_ACK1: begin /* Ignore the slave device ACK bit for simplicity,
						  and transition to either a WRITE or READ register
						  address value. */
			eo_scl = s_i2c_clk_1x;
			eo_sda_t = 1'b1;
			s_i_val = 0;
			s_hold_read_val = s_hold_read_aux;
			eo_sda_o = 1'b0;

			if (i_wr) begin
				s_config_val = i_config;
				s_hygro_drv_nx_state = ST_INITIAL_ADDR_WR;
			end else begin
				s_config_val = s_config_aux;
				s_hygro_drv_nx_state = ST_INITIAL_ADDR_RD;
			end
		end

		ST_STOP: begin /* Stop the WRITE or READ command sequence with a STOP bit
						  and STOP clock */
			eo_scl = s_hold_scl_ce_stop;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_HOLD;
		end

		ST_HOLD: begin /* After stopping, hold the clock and a hold bit; return
						  to IDLE based on READ and WRITE command inputs */
			eo_scl = 1'b1;
			eo_sda_o = 1'b1;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (i_wr || i_rd) s_hygro_drv_nx_state = ST_HOLD;
			else s_hygro_drv_nx_state = ST_IDLE;			
		end

		/* Data-write states */
		ST_INITIAL_ADDR_WR: begin /* WRITE the initiate WRITE ADDRESS, which for the
									 HDC1080 driver will only be the Configuration
									 Register HYGRO_CONFIG_REG_ADDR */
			eo_scl = s_i2c_clk_1x;
			eo_sda_t = 1'b0;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val > 0) eo_sda_o = HYGRO_CONFIG_REG_ADDR[8 - s_i_val];
			else eo_sda_o = HYGRO_CONFIG_REG_ADDR[7];

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_ACK2;
			else s_hygro_drv_nx_state = ST_INITIAL_ADDR_WR;
		end

		ST_ACK2: begin /* Ignore the slave device ACK for simplicity */
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b1;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			s_hygro_drv_nx_state = ST_WR_CONFIG_HI;
		end

		ST_WR_CONFIG_HI: begin /* Write the MSByte value of the 16-bit Configuration
								  Register */
			eo_scl = s_i2c_clk_1x;
			eo_sda_t = 1'b0;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val > 0) eo_sda_o = s_config_aux[16 - s_i_val];
			else eo_sda_o = s_config_aux[15];

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_ACK3;
			else s_hygro_drv_nx_state = ST_WR_CONFIG_HI;
		end

		ST_ACK3: begin /* Ignore the slave device ACK for simplicity */
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b1;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_WR_CONFIG_LO;
		end

		ST_WR_CONFIG_LO: begin /* Write the LSByte value of the 16-bit Configuration
								  Register */
			eo_scl = s_i2c_clk_1x;
			eo_sda_t = 1'b0;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val > 0) eo_sda_o = s_config_aux[8 - s_i_val];
			else eo_sda_o = s_config_aux[7];

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_ACK4;
			else s_hygro_drv_nx_state = ST_WR_CONFIG_LO;
		end

		ST_ACK4: begin /* Ignore the slave device ACK for simplicity */
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b1;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_STOP;
		end

		/* Data-read states */
		ST_INITIAL_ADDR_RD: begin /* WRITE the initiate READ ADDRESS, which for the
									 HDC1080 driver will only be the Temperature
									 Register HYGRO_TEMP_REG_ADDR */
			eo_scl = s_i2c_clk_1x;
			eo_sda_t = 1'b0;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val > 0) eo_sda_o = HYGRO_TEMP_REG_ADDR[8 - s_i_val];
			else eo_sda_o = HYGRO_TEMP_REG_ADDR[7];

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_ACK5;
			else s_hygro_drv_nx_state = ST_INITIAL_ADDR_RD;
		end

		ST_ACK5: begin /* Ignore the slave device ACK for simplicity */
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b1;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = 0;
			s_hygro_drv_nx_state = ST_STOP_READING;
		end

		ST_STOP_READING: begin /* Write a STOP bit and STOP clock to end the WRITE
								  of the READ register pointer, per HDC1080 datasheet. */
			eo_scl = s_hold_scl_ce_stop;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_HOLD_READING;
		end

		ST_HOLD_READING: begin
			eo_scl = 1'b1;
			eo_sda_o = 1'b1;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux + 1;

			if (s_hold_read_val == c_hold_read_duration)
				s_hygro_drv_nx_state = ST_START_READING;
			else s_hygro_drv_nx_state = ST_HOLD_READING;			
		end

		ST_START_READING: begin /* Write the START bit and START clock to start a reading
								   of the HDC1080 measurement registers. */
			eo_scl = s_hold_scl_ce_start;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_SLAVE_ADDR_RD;
		end

		ST_SLAVE_ADDR_RD: begin /* Write the slave device address with a READ bit */
			eo_scl = s_i2c_clk_1x;
			eo_sda_t = 1'b0;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val > 0) eo_sda_o = HYGRO_ADDR_FOR_RD[8 - s_i_val];
			else eo_sda_o = HYGRO_ADDR_FOR_RD[7];

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_ACK6;
			else s_hygro_drv_nx_state = ST_SLAVE_ADDR_RD;
		end

		ST_ACK6: begin /* Ignore the ACK from the slave device for simplicity */
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b1;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_RD_TEMP_HI;
		end

		ST_RD_TEMP_HI: begin /* Track a Read Temperature register MSByte and
								index it for the other process to capture that
								value, bit-at-a-time. */
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b1;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_ACK7;
			else s_hygro_drv_nx_state = ST_RD_TEMP_HI;
		end

		ST_ACK7: begin /* Write a Master Device ACK*/
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_RD_TEMP_LO;
		end

		ST_RD_TEMP_LO: begin /* Track a Read Temperature register LSByte and
								index it for the other process to capture that
								value, bit-at-a-time. */
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b1;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_ACK8;
			else s_hygro_drv_nx_state = ST_RD_TEMP_LO;
		end

		ST_ACK8: begin /* Write a Master Device ACK*/
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_RD_HUMID_HI;
		end

		ST_RD_HUMID_HI: begin /* Track a Read Relative Humidity register MSByte
								 index it for the other process to capture that
								 value, bit-at-a-time. */
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b1;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_ACK9;
			else s_hygro_drv_nx_state = ST_RD_HUMID_HI;
		end

		ST_ACK9: begin /* Write a Master Device ACK*/
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_RD_HUMID_LO;
		end

		ST_RD_HUMID_LO: begin /* Track a Read Relative Humidity register LSByte
								 index it for the other process to capture that
								 value, bit-at-a-time. */
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b0;
			eo_sda_t = 1'b1;
			s_i_val = s_i_aux + 1;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;

			if (s_i_val == 8) s_hygro_drv_nx_state = ST_NO_ACK;
			else s_hygro_drv_nx_state = ST_RD_HUMID_LO;
		end

		ST_NO_ACK: begin /* Write a Master Device No-ACK*/
			eo_scl = s_i2c_clk_1x;
			eo_sda_o = 1'b1;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			s_hygro_drv_nx_state = ST_STOP;
		end

		default: begin /* The default state is wait for a READ or WRITE strobe
						  while in IDLE state ST_IDLE */
			eo_scl = 1'b1;
			eo_sda_o = 1'b1;
			eo_sda_t = 1'b0;
			s_i_val = 0;
			s_config_val = s_config_aux;
			s_hold_read_val = s_hold_read_aux;
			
			if (i_wr || i_rd) s_hygro_drv_nx_state = ST_START;
			else s_hygro_drv_nx_state = ST_IDLE;
		end
	endcase
end

/* Store data read from the HYGRO sensor and export it.
   The capture of the data is clock-enabled and indexed
   based upon the Clock Enable of the SCL, the value of
   the recursive index I, and the Preset State value being
   one of the four BYTE captures. */
/*
always @(posedge s_i2c_clk_4x)
begin: p_fsm_data_out
	if (s_i2c_clk_4x) begin
		if (s_i2c_clk_ce0) begin
			o_valid <= 1'b0;

			if (s_i_val > 0) begin
				if (s_hygro_drv_pr_state == ST_RD_TEMP_HI) begin
					s_temp_aux[16 - s_i_val] <= ei_sda_i;
				end else if (s_hygro_drv_pr_state == ST_RD_TEMP_LO) begin
					s_temp_aux[8 - s_i_val] <= ei_sda_i;
				end else if (s_hygro_drv_pr_state == ST_RD_HUMID_HI) begin
					s_humid_aux[16 - s_i_val] <= ei_sda_i;
				end else if (s_hygro_drv_pr_state == ST_RD_HUMID_LO) begin
					s_humid_aux[8 - s_i_val] <= ei_sda_i;
					if (s_i_val == 8) o_valid <= 1'b1;
				end
			end
		end
	end
end
*/

/* Store data read from the HYGRO sensor and export it.
   The capture of the data is clock-enabled and indexed
   based upon the Clock Enable of the SCL, the value of
   the recursive index I, and the Preset State value being
   one of the four BYTE captures. */
always @(posedge s_i2c_clk_4x)
begin: p_fsm_data_out
	if (s_i2c_rst_4x) begin
		s_temp_aux <= 16'h0000;
		s_humid_aux <= 16'h0000;
		o_valid <= 1'b0;

	end else if (s_i2c_clk_ce0) begin
		o_valid <= 1'b0;

		if (s_i_aux < 8) begin
			if (s_hygro_drv_pr_state == ST_RD_TEMP_HI)
				s_temp_aux[15-:16] <= {s_temp_aux[14-:15], ei_sda_i};
			else if (s_hygro_drv_pr_state == ST_RD_TEMP_LO)
				s_temp_aux[15-:16] <= {s_temp_aux[14-:15], ei_sda_i};
			else if (s_hygro_drv_pr_state == ST_RD_HUMID_HI)
				s_humid_aux[15-:16] <= {s_humid_aux[14-:15], ei_sda_i};
			else if (s_hygro_drv_pr_state == ST_RD_HUMID_LO) begin
				s_humid_aux[15-:16] <= {s_humid_aux[14-:15], ei_sda_i};
				if (s_i_aux == 7) o_valid <= 1'b1;
			end
		end
	end
end

/* The current temperature and relative humidity exported values
   are those captured in the auxiliary register and data-valid
   tracked with a pulse on signal \ref o_valid . */
assign o_temp = s_temp_aux;
assign o_humid = s_humid_aux;

endmodule
//------------------------------------------------------------------------------

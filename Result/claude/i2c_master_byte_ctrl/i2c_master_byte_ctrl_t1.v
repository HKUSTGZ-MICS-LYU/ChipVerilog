module i2c_master_byte_ctrl (
	clk, rst, nReset, ena, clk_cnt, start, stop, read, write, ack_in, din,
	cmd_ack, ack_out, dout, i2c_busy, i2c_al, scl_i, scl_o, scl_oen, sda_i, sda_o, sda_oen
);

	// ===== Port Declarations =====
	input             clk;
	input             rst;
	input             nReset;
	input             ena;
	input      [15:0] clk_cnt;
	
	input             start;
	input             stop;
	input             read;
	input             write;
	input             ack_in;
	input      [7:0]  din;
	
	output            cmd_ack;
	output            ack_out;
	output     [7:0]  dout;
	output            i2c_busy;
	output            i2c_al;
	
	input             scl_i;
	output            scl_o;
	output            scl_oen;
	input             sda_i;
	output            sda_o;
	output            sda_oen;

	// ===== Bit-Level Command Definitions =====
	localparam I2C_CMD_NOP    = 4'b0000;
	localparam I2C_CMD_START  = 4'b0001;
	localparam I2C_CMD_STOP   = 4'b0010;
	localparam I2C_CMD_READ   = 4'b0100;
	localparam I2C_CMD_WRITE  = 4'b1000;

	// ===== FSM State Definitions =====
	localparam ST_IDLE  = 3'b000;
	localparam ST_START = 3'b001;
	localparam ST_READ  = 3'b010;
	localparam ST_WRITE = 3'b011;
	localparam ST_ACK   = 3'b100;
	localparam ST_STOP  = 3'b101;

	// ===== Internal Registers =====
	reg [7:0]  sr;           // 8-bit shift register for data
	reg [2:0]  dcnt;         // 3-bit bit counter (0-7 bits)
	reg [2:0]  state;        // FSM state register
	reg        cmd_ack_r;    // Registered command acknowledge
	reg        ack_out_r;    // Registered ACK/NACK output

	// ===== Bit-Level Controller Interface Signals =====
	reg [3:0]  core_cmd;     // Command to bit controller
	wire       core_ack;     // Command acknowledge from bit controller
	wire       core_rxd;     // Received bit from bit controller
	reg        core_txd;     // Transmit bit to bit controller

	// ===== Control Signals =====
	wire       go;           // Launch condition for byte operation
	wire       ld;           // Load shift register
	wire       shift;        // Shift operation enable
	wire       cnt_done;     // Bit counter done flag

	// ===== Instantiate Bit-Level Controller =====
	i2c_master_bit_ctrl bit_controller (
		.clk      (clk),
		.rst      (rst),
		.nReset   (nReset),
		.ena      (ena),
		.clk_cnt  (clk_cnt),
		
		.cmd      (core_cmd),
		.cmd_ack  (core_ack),
		.busy     (i2c_busy),
		.al       (i2c_al),
		
		.din      (core_txd),
		.dout     (core_rxd),
		
		.scl_i    (scl_i),
		.scl_o    (scl_o),
		.scl_oen  (scl_oen),
		.sda_i    (sda_i),
		.sda_o    (sda_o),
		.sda_oen  (sda_oen)
	);

	// ===== Combinational Logic =====

	// Launch condition: read, write, or stop requested, and not asserting cmd_ack
	assign go = (read | write | stop) & ~cmd_ack_r;

	// Bit counter done flag: asserted when all 8 bits have been transferred
	assign cnt_done = (dcnt == 3'b000);

	// Transmit data bit: for writes, transmit MSB; for reads, transmit ACK value
	always @(*) begin
		if (state == ST_WRITE) begin
			core_txd = sr[7];       // MSB first during write
		end
		else if (state == ST_ACK) begin
			core_txd = ack_in;      // Drive ACK/NACK value during ACK phase
		end
		else begin
			core_txd = 1'b1;        // Default idle value
		end
	end

	// Load and shift control signals
	assign ld    = go;
	assign shift = core_ack & ((state == ST_READ) | (state == ST_WRITE));

	// Output assignments
	assign cmd_ack = cmd_ack_r;
	assign ack_out = ack_out_r;
	assign dout = sr;

	// ===== Shift Register and Bit Counter Logic =====

	always @(negedge nReset or posedge clk) begin
		if (!nReset) begin
			// Asynchronous reset
			sr <= 8'h00;
			dcnt <= 3'b000;
		end
		else if (rst | i2c_al) begin
			// Synchronous reset or arbitration lost abort
			sr <= 8'h00;
			dcnt <= 3'b000;
		end
		else begin
			if (ld) begin
				// Load new byte from din
				sr <= din;
				dcnt <= 3'b111;  // Initialize counter to 7
			end
			else if (shift) begin
				// Shift operation: left shift and insert core_rxd at LSB
				sr <= {sr[6:0], core_rxd};
				dcnt <= dcnt - 1'b1;
			end
		end
	end

	// ===== FSM Logic =====

	always @(negedge nReset or posedge clk) begin
		if (!nReset) begin
			// Asynchronous reset
			state <= ST_IDLE;
			core_cmd <= I2C_CMD_NOP;
			cmd_ack_r <= 1'b0;
			ack_out_r <= 1'b0;
		end
		else if (rst | i2c_al) begin
			// Synchronous reset or arbitration lost abort
			state <= ST_IDLE;
			core_cmd <= I2C_CMD_NOP;
			cmd_ack_r <= 1'b0;
			ack_out_r <= 1'b0;
		end
		else begin
			// Default: clear cmd_ack
			cmd_ack_r <= 1'b0;

			case (state)
				ST_IDLE: begin
					core_cmd <= I2C_CMD_NOP;
					if (go) begin
						// Priority: start > read > write > stop
						if (start) begin
							state <= ST_START;
							core_cmd <= I2C_CMD_START;
						end
						else if (read) begin
							state <= ST_READ;
							core_cmd <= I2C_CMD_READ;
						end
						else if (write) begin
							state <= ST_WRITE;
							core_cmd <= I2C_CMD_WRITE;
						end
						else if (stop) begin
							state <= ST_STOP;
							core_cmd <= I2C_CMD_STOP;
						end
					end
				end

				ST_START: begin
					// Wait for START condition to complete
					if (core_ack) begin
						// START completed; decide next state based on command priority
						if (read) begin
							state <= ST_READ;
							core_cmd <= I2C_CMD_READ;
						end
						else begin
							state <= ST_WRITE;
							core_cmd <= I2C_CMD_WRITE;
						end
					end
					else begin
						core_cmd <= I2C_CMD_START;
					end
				end

				ST_WRITE: begin
					// Transmit byte bits
					if (core_ack) begin
						if (cnt_done) begin
							// All 8 bits transmitted; move to ACK phase
							state <= ST_ACK;
							core_cmd <= I2C_CMD_READ;
						end
						else begin
							// Continue with next bit
							core_cmd <= I2C_CMD_WRITE;
						end
					end
					else begin
						core_cmd <= I2C_CMD_WRITE;
					end
				end

				ST_READ: begin
					// Receive byte bits
					if (core_ack) begin
						if (cnt_done) begin
							// All 8 bits received; move to ACK phase
							state <= ST_ACK;
							core_cmd <= I2C_CMD_WRITE;
						end
						else begin
							// Continue with next bit
							core_cmd <= I2C_CMD_READ;
						end
					end
					else begin
						core_cmd <= I2C_CMD_READ;
					end
				end

				ST_ACK: begin
					// Handle ACK/NACK phase
					if (core_ack) begin
						// ACK phase completed
						// For writes: ack_out captures the slave's ACK/NACK
						// For reads: core_txd drove the master's ACK/NACK
						ack_out_r <= core_rxd;
						
						if (stop) begin
							// STOP requested; enter STOP state
							state <= ST_STOP;
							core_cmd <= I2C_CMD_STOP;
						end
						else begin
							// No STOP; return to idle and complete command
							state <= ST_IDLE;
							core_cmd <= I2C_CMD_NOP;
							cmd_ack_r <= 1'b1;
						end
					end
					else begin
						// During write, read slave ACK; during read, write master ACK
						if (write) begin
							core_cmd <= I2C_CMD_READ;
						end
						else begin
							core_cmd <= I2C_CMD_WRITE;
						end
					end
				end

				ST_STOP: begin
					// Wait for STOP condition to complete
					if (core_ack) begin
						// STOP completed; return to idle and complete command
						state <= ST_IDLE;
						core_cmd <= I2C_CMD_NOP;
						cmd_ack_r <= 1'b1;
					end
					else begin
						core_cmd <= I2C_CMD_STOP;
					end
				end

				default: begin
					state <= ST_IDLE;
					core_cmd <= I2C_CMD_NOP;
				end
			endcase
		end
	end

endmodule
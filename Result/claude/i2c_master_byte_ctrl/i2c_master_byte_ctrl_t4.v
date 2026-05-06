module i2c_master_byte_ctrl (
	clk, rst, nReset, ena, clk_cnt, start, stop, read, write, ack_in, din,
	cmd_ack, ack_out, dout, i2c_busy, i2c_al, scl_i, scl_o, scl_oen, sda_i, sda_o, sda_oen
);

	// ===== Input Port Declarations =====
	input				clk;			// Master clock
	input				rst;			// Synchronous active-high reset
	input				nReset;			// Asynchronous active-low reset
	input				ena;			// I2C core enable (passed to bit controller)
	input	[15:0]		clk_cnt;		// SCL timing/prescale count (passed to bit controller)
	input				start;			// START/repeated START request
	input				stop;			// STOP request
	input				read;			// Read byte request
	input				write;			// Write byte request
	input				ack_in;			// Master ACK/NACK bit (0=ACK, 1=NACK)
	input	[7:0]		din;			// Input byte for transmission

	input				scl_i;			// SCL pad input
	input				sda_i;			// SDA pad input

	// ===== Output Port Declarations =====
	output				cmd_ack;		// Byte command completion pulse
	output	reg			ack_out;		// Sampled slave ACK/NACK bit
	output	[7:0]		dout;			// Shift register output (received byte)
	output				i2c_busy;		// I2C bus busy status
	output				i2c_al;			// Arbitration lost status

	output				scl_o;			// SCL output drive value
	output				scl_oen;		// SCL output enable/release
	output				sda_o;			// SDA output drive value
	output				sda_oen;		// SDA output enable/release

	// ===== Internal Bit-Level Controller Interface =====
	wire	[2:0]		core_cmd;		// Bit-level command to bit controller
	wire				core_ack;		// Bit-level command completion
	wire				core_rxd;		// Sampled bit from I2C bus
	wire				core_txd;		// Bit to transmit to I2C bus

	// ===== I2C Bit-Level Commands =====
	localparam I2C_CMD_NOP   = 3'b000;	// No operation
	localparam I2C_CMD_START = 3'b001;	// START condition
	localparam I2C_CMD_STOP  = 3'b010;	// STOP condition
	localparam I2C_CMD_READ  = 3'b011;	// Read bit
	localparam I2C_CMD_WRITE = 3'b100;	// Write bit

	// ===== FSM State Definitions =====
	localparam ST_IDLE  = 3'b000;		// Idle state, waiting for command
	localparam ST_START = 3'b001;		// START condition in progress
	localparam ST_READ  = 3'b010;		// Read byte in progress
	localparam ST_WRITE = 3'b011;		// Write byte in progress
	localparam ST_ACK   = 3'b100;		// ACK/NACK phase
	localparam ST_STOP  = 3'b101;		// STOP condition in progress

	// ===== Internal State Registers =====
	reg		[2:0]		state;			// Current FSM state
	reg		[7:0]		sr;				// Shift register for byte data
	reg		[2:0]		dcnt;			// Bit counter (3 bits for 0-7)
	reg					cmd_ack_r;		// cmd_ack register (for one-cycle pulse)

	// ===== Derived Signals =====
	wire				go;				// Command launch condition
	wire				cnt_done;		// All bits transmitted/received
	wire				ack_bit;		// ACK/NACK bit to transmit during ACK phase

	// ===== dout Assignment =====
	// dout directly reflects sr for immediate visibility of received data
	assign dout = sr;

	// ===== Command Launch Condition =====
	// FSM starts from idle only when read, write, or stop is active
	// and cmd_ack is not currently asserted
	assign go = (read | write | stop) & ~cmd_ack_r;

	// ===== Bit Counter Done Signal =====
	// All 8 bits have been processed when dcnt reaches 0
	assign cnt_done = (dcnt == 3'b000);

	// ===== ACK/NACK Bit Selection =====
	// During ACK phase in read operation, transmit ack_in bit to slave
	// During ACK phase in write operation, core_txd is not used (read the ACK)
	assign ack_bit = ack_in;

	// ===== Transmit Data Path =====
	// core_txd carries:
	// - sr[7] during write operations (MSB-first transmission)
	// - ack_in during ACK phase of read operation
	assign core_txd = (state == ST_ACK && read) ? ack_bit : sr[7];

	// ===== Instantiate I2C Bit-Level Controller =====
	i2c_master_bit_ctrl bit_controller (
		.clk       (clk),
		.rst       (rst),
		.nReset    (nReset),
		.ena       (ena),
		.clk_cnt   (clk_cnt),
		.cmd       (core_cmd),
		.cmd_ack   (core_ack),
		.din       (core_txd),
		.dout      (core_rxd),
		.scl_i     (scl_i),
		.scl_o     (scl_o),
		.scl_oen   (scl_oen),
		.sda_i     (sda_i),
		.sda_o     (sda_o),
		.sda_oen   (sda_oen),
		.i2c_busy  (i2c_busy),
		.i2c_al    (i2c_al)
	);

	// ===== Output Decode: cmd_ack Pulse =====
	// cmd_ack is asserted for one clock cycle at end of byte sequence
	assign cmd_ack = cmd_ack_r;

	// ===== FSM and Data Control Logic =====
	// This always block contains the state machine and command sequencing
	always @(posedge clk or negedge nReset) begin
		if (~nReset) begin
			// Asynchronous reset (active-low)
			state <= ST_IDLE;
			sr <= 8'h00;
			dcnt <= 3'b000;
			ack_out <= 1'b0;
			cmd_ack_r <= 1'b0;
		end
		else if (rst || i2c_al) begin
			// Synchronous reset or arbitration lost (abort condition)
			state <= ST_IDLE;
			sr <= 8'h00;
			dcnt <= 3'b000;
			ack_out <= 1'b0;
			cmd_ack_r <= 1'b0;
		end
		else begin
			// Default: no command acknowledge this cycle
			cmd_ack_r <= 1'b0;

			case (state)
				// ===== ST_IDLE: Waiting for Byte Command =====
				ST_IDLE: begin
					if (go) begin
						// Load data byte and initialize bit counter
						sr <= din;
						dcnt <= 3'b111;  // Load with 7 (8 bits: 0-7)

						// Decode command priority: start > read > write > stop
						if (start) begin
							// Issue START condition, then continue with read/write
							state <= ST_START;
						end
						else if (read) begin
							// Direct to read (no START)
							state <= ST_READ;
						end
						else if (write) begin
							// Direct to write (no START)
							state <= ST_WRITE;
						end
						else begin
							// Only stop is active
							state <= ST_STOP;
						end
					end
				end

				// ===== ST_START: START Condition Generation =====
				ST_START: begin
					if (core_ack) begin
						// START condition completed, continue with read or write
						sr <= din;
						dcnt <= 3'b111;  // Reload bit counter

						if (read) begin
							state <= ST_READ;
						end
						else begin
							state <= ST_WRITE;
						end
					end
				end

				// ===== ST_WRITE: Transmit Byte Operation =====
				ST_WRITE: begin
					if (core_ack) begin
						// One bit write completed
						if (cnt_done) begin
							// All 8 bits sent, move to ACK phase
							state <= ST_ACK;
							dcnt <= 3'b000;  // Prepare for ACK bit
						end
						else begin
							// More bits to send, shift register and decrement counter
							sr <= {sr[6:0], 1'b0};  // Shift left for next bit
							dcnt <= dcnt - 1'b1;
						end
					end
				end

				// ===== ST_READ: Receive Byte Operation =====
				ST_READ: begin
					if (core_ack) begin
						// One bit read completed, shift received bit into sr
						sr <= {sr[6:0], core_rxd};  // Shift left, insert RX bit at LSB
						
						if (cnt_done) begin
							// All 8 bits received, move to ACK phase
							state <= ST_ACK;
							dcnt <= 3'b000;  // Prepare for ACK bit
						end
						else begin
							// More bits to receive, decrement counter
							dcnt <= dcnt - 1'b1;
						end
					end
				end

				// ===== ST_ACK: ACK/NACK Bit Phase =====
				ST_ACK: begin
					if (core_ack) begin
						// ACK phase completed
						// For write: capture slave ACK/NACK bit
						if (write || start) begin
							ack_out <= core_rxd;
						end
						// For read: ack_in was already sent via core_txd

						if (stop) begin
							// Stop requested, issue STOP condition
							state <= ST_STOP;
						end
						else begin
							// No STOP, return to idle and assert cmd_ack
							state <= ST_IDLE;
							cmd_ack_r <= 1'b1;
						end
					end
				end

				// ===== ST_STOP: STOP Condition Generation =====
				ST_STOP: begin
					if (core_ack) begin
						// STOP condition completed, return to idle
						state <= ST_IDLE;
						cmd_ack_r <= 1'b1;  // Assert completion after STOP
					end
				end

				default: begin
					state <= ST_IDLE;
				end
			endcase
		end
	end

	// ===== Command Output Decoder =====
	// Combinational logic to generate core_cmd based on current state
	always @(*) begin
		case (state)
			ST_START: core_cmd = I2C_CMD_START;
			ST_STOP:  core_cmd = I2C_CMD_STOP;
			ST_READ:  core_cmd = I2C_CMD_READ;
			ST_WRITE: core_cmd = I2C_CMD_WRITE;
			ST_ACK: begin
				// ACK phase: read or write depending on command
				if (read) begin
					core_cmd = I2C_CMD_WRITE;  // Master sends ACK/NACK
				end
				else begin
					core_cmd = I2C_CMD_READ;   // Master reads slave ACK/NACK
				end
			end
			default:  core_cmd = I2C_CMD_NOP;
		endcase
	end

endmodule
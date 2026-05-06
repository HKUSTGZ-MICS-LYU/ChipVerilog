module i2c_master_top(
	wb_clk_i, wb_rst_i, arst_i, wb_adr_i, wb_dat_i, wb_dat_o,
	wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_inta_o,
	scl_pad_i, scl_pad_o, scl_padoen_o, sda_pad_i, sda_pad_o, sda_padoen_o
);

	// ===== Parameter Definitions =====
	parameter ARST_LVL = 1'b0;  // Asynchronous reset active level

	// ===== Input Port Declarations =====
	input				wb_clk_i;		// Wishbone clock
	input				wb_rst_i;		// Synchronous active-high reset
	input				arst_i;			// Asynchronous reset (active level: ARST_LVL)
	input	[2:0]		wb_adr_i;		// Wishbone address input
	input	[7:0]		wb_dat_i;		// Wishbone write data input
	input				wb_we_i;		// Wishbone write enable
	input				wb_stb_i;		// Wishbone strobe
	input				wb_cyc_i;		// Wishbone cycle
	
	input				scl_pad_i;		// SCL line input from I2C bus
	input				sda_pad_i;		// SDA line input from I2C bus

	// ===== Output Port Declarations =====
	output	reg	[7:0]	wb_dat_o;		// Wishbone read data output
	output	reg			wb_ack_o;		// Wishbone acknowledge output
	output	reg			wb_inta_o;		// Wishbone interrupt output
	
	output				scl_pad_o;		// SCL line output to I2C bus
	output				scl_padoen_o;	// SCL output enable (active-low)
	output				sda_pad_o;		// SDA line output to I2C bus
	output				sda_padoen_o;	// SDA output enable (active-low)

	// ===== Internal Reset Signal =====
	// Normalize asynchronous reset to active-low
	wire				rst_i;
	assign rst_i = arst_i ^ ARST_LVL;

	// ===== Internal Register Declarations =====
	reg		[15:0]		prer;			// Prescale register (16-bit)
	reg		[7:0]		ctr;			// Control register
	reg		[7:0]		txr;			// Transmit register
	reg		[7:0]		rxr;			// Receive register (connected to byte controller output)
	reg		[7:0]		cr;				// Command register (auto-clearing)

	// ===== Status Bits =====
	reg					rxack;			// Receive acknowledge status
	reg					al;				// Arbitration lost (latched)
	reg					tip;			// Transfer in progress
	reg					irq_flag;		// Interrupt flag

	// ===== Wishbone Interface Signals =====
	wire				wb_wacc;		// Qualified write-access signal
	wire				wb_ack_next;	// Next value of wb_ack_o

	// ===== Command Decode Signals =====
	wire				sta;			// START command
	wire				sto;			// STOP command
	wire				rd;				// READ command
	wire				wr;				// WRITE command
	wire				ack;			// ACK/NACK control
	wire				iack;			// Interrupt acknowledge

	// ===== Byte Controller Interface Signals =====
	wire				core_en;		// Core enable (ctr[7])
	wire				ien;			// Interrupt enable (ctr[6])
	wire				done;			// Byte command completion from byte controller
	wire				i2c_al;			// Arbitration lost from byte controller
	wire				irxack;			// Receive acknowledge from byte controller
	wire	[7:0]		irxr;			// Receive data from byte controller
	wire				i2c_busy;		// I2C bus busy status from byte controller

	// ===== Decode Control Register Bits =====
	assign core_en = ctr[7];		// Core enable
	assign ien = ctr[6];			// Interrupt enable

	// ===== Decode Command Register Bits =====
	assign sta = cr[7];				// START command
	assign sto = cr[6];				// STOP command
	assign rd = cr[5];				// READ command
	assign wr = cr[4];				// WRITE command
	assign ack = cr[3];				// ACK/NACK control
	assign iack = cr[0];			// Interrupt acknowledge

	// ===== Wishbone Acknowledge Generation =====
	// Registered acknowledge: asserted for one cycle when valid access occurs
	assign wb_ack_next = wb_cyc_i & wb_stb_i & ~wb_ack_o;
	
	// ===== Qualified Write Signal =====
	// Write only occurs during acknowledged write cycle
	assign wb_wacc = wb_we_i & wb_ack_o;

	// ===== Instantiate I2C Byte-Level Controller =====
	i2c_master_byte_ctrl byte_controller (
		.clk        (wb_clk_i),
		.rst        (wb_rst_i),
		.nReset     (rst_i),
		.ena        (core_en),
		.clk_cnt    (prer),
		.start      (sta),
		.stop       (sto),
		.read       (rd),
		.write      (wr),
		.ack_in     (ack),
		.din        (txr),
		.cmd_ack    (done),
		.ack_out    (irxack),
		.dout       (irxr),
		.i2c_busy   (i2c_busy),
		.i2c_al     (i2c_al),
		.scl_i      (scl_pad_i),
		.scl_o      (scl_pad_o),
		.scl_oen    (scl_padoen_o),
		.sda_i      (sda_pad_i),
		.sda_o      (sda_pad_o),
		.sda_oen    (sda_padoen_o)
	);

	// ===== Wishbone Synchronous Logic =====
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			// Asynchronous reset (active-low)
			prer <= 16'hffff;
			ctr <= 8'h00;
			txr <= 8'h00;
			cr <= 8'h00;
			rxack <= 1'b0;
			al <= 1'b0;
			tip <= 1'b0;
			irq_flag <= 1'b0;
			wb_ack_o <= 1'b0;
			wb_inta_o <= 1'b0;
		end
		else if (wb_rst_i) begin
			// Synchronous reset (active-high)
			prer <= 16'hffff;
			ctr <= 8'h00;
			txr <= 8'h00;
			cr <= 8'h00;
			rxack <= 1'b0;
			al <= 1'b0;
			tip <= 1'b0;
			irq_flag <= 1'b0;
			wb_ack_o <= 1'b0;
			wb_inta_o <= 1'b0;
		end
		else begin
			// Normal operation

			// ===== Wishbone Acknowledge =====
			wb_ack_o <= wb_ack_next;

			// ===== Register Writes (Qualified by wb_wacc) =====
			if (wb_wacc) begin
				case (wb_adr_i)
					3'b000: prer[7:0] <= wb_dat_i;		// Prescale low byte
					3'b001: prer[15:8] <= wb_dat_i;		// Prescale high byte
					3'b010: ctr <= wb_dat_i;			// Control register
					3'b011: txr <= wb_dat_i;			// Transmit register
					3'b100: begin						// Command register
						// Command write accepted only when core is enabled
						if (core_en) begin
							cr <= wb_dat_i;
						end
					end
					default: begin
						// Other addresses are read-only or undefined
					end
				endcase
			end

			// ===== Automatic Command-Register Clearing =====
			// STA, STO, RD, WR bits are cleared after completion or arbitration loss
			if (done || i2c_al) begin
				cr[7:4] <= 4'h0;	// Clear STA, STO, RD, WR bits
				cr[2:1] <= 2'h0;	// Clear reserved bits
				cr[0] <= 1'b0;		// Clear IACK bit
			end
			else if (wb_wacc && wb_adr_i == 3'b100 && core_en) begin
				// On command register write, clear bits after one cycle
				// (Handled by the write above; bits are cleared by the register update)
			end

			// ===== Receive Register Update =====
			// rxr captures the byte received from the I2C byte controller
			// In RTL, this is typically connected directly, but can be latched
			rxr <= irxr;

			// ===== Transfer In Progress =====
			// TIP is set when read or write command is active
			tip <= rd | wr;

			// ===== Receive Acknowledge Status =====
			// rxack samples the byte controller acknowledge output
			rxack <= irxack;

			// ===== Arbitration Lost Latch =====
			// Once arbitration loss occurs, al remains set until a new START command
			al <= i2c_al | (al & ~sta);

			// ===== Interrupt Flag Logic =====
			// irq_flag is set by byte completion or arbitration loss
			// irq_flag is cleared by interrupt acknowledge (iack) command
			if (done || i2c_al) begin
				irq_flag <= 1'b1;
			end
			else if (wb_wacc && wb_adr_i == 3'b100 && iack && core_en) begin
				irq_flag <= 1'b0;
			end

			// ===== Interrupt Output =====
			// wb_inta_o is asserted when interrupt flag is set and interrupt enable is high
			wb_inta_o <= irq_flag & ien;
		end
	end

	// ===== Wishbone Read Data Output (Registered) =====
	// Updated on every clock cycle based on current address
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			wb_dat_o <= 8'h00;
		end
		else if (wb_rst_i) begin
			wb_dat_o <= 8'h00;
		end
		else begin
			case (wb_adr_i)
				3'b000: wb_dat_o <= prer[7:0];		// Prescale low byte
				3'b001: wb_dat_o <= prer[15:8];		// Prescale high byte
				3'b010: wb_dat_o <= ctr;			// Control register
				3'b011: wb_dat_o <= rxr;			// Receive register
				3'b100: wb_dat_o <= sr;				// Status register
				3'b101: wb_dat_o <= txr;			// Transmit register (non-standard read)
				3'b110: wb_dat_o <= cr;				// Command register (non-standard read)
				3'b111: wb_dat_o <= 8'h00;			// Reserved address
				default: wb_dat_o <= 8'h00;
			endcase
		end
	end

	// ===== Status Register (Combinational) =====
	// Assembled from status bits for address 0x04 read
	wire	[7:0]		sr;
	assign sr[7] = rxack;			// Bit 7: RxACK (acknowledge status)
	assign sr[6] = i2c_busy;		// Bit 6: Busy (bus busy status)
	assign sr[5] = al;				// Bit 5: AL (arbitration lost)
	assign sr[4:2] = 3'h0;			// Bits 4:2: Reserved (always zero)
	assign sr[1] = tip;				// Bit 1: TIP (transfer in progress)
	assign sr[0] = irq_flag;		// Bit 0: IF (interrupt flag)

endmodule
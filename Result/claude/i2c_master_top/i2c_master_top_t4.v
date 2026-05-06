module i2c_master_top(
	wb_clk_i, wb_rst_i, arst_i, wb_adr_i, wb_dat_i, wb_dat_o,
	wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_inta_o,
	scl_pad_i, scl_pad_o, scl_padoen_o, sda_pad_i, sda_pad_o, sda_padoen_o
);

	// ===== Parameters =====
	parameter ARST_LVL = 1'b0;  // Asynchronous reset active level

	// ===== Wishbone Clock and Reset Inputs =====
	input				wb_clk_i;		// Wishbone clock
	input				wb_rst_i;		// Synchronous active-high reset
	input				arst_i;			// Asynchronous reset input

	// ===== Wishbone Address and Data Interface =====
	input	[2:0]		wb_adr_i;		// Register address selector
	input	[7:0]		wb_dat_i;		// Write data from host
	output	reg	[7:0]	wb_dat_o;		// Read data to host
	input				wb_we_i;		// Write enable
	input				wb_stb_i;		// Strobe (this core selected)
	input				wb_cyc_i;		// Cycle active
	output	reg			wb_ack_o;		// Acknowledge response

	// ===== Wishbone Interrupt Output =====
	output	reg			wb_inta_o;		// Interrupt request output

	// ===== I2C Pad Interface =====
	input				scl_pad_i;		// SCL pad input (external bus observation)
	output				scl_pad_o;		// SCL pad output (from byte controller)
	output				scl_padoen_o;	// SCL pad output enable (from byte controller)
	input				sda_pad_i;		// SDA pad input (external bus observation)
	output				sda_pad_o;		// SDA pad output (from byte controller)
	output				sda_padoen_o;	// SDA pad output enable (from byte controller)

	// ===== Normalized Asynchronous Reset =====
	wire				rst_i;			// Active-low asynchronous reset
	assign rst_i = arst_i ^ ARST_LVL;

	// ===== Internal Registers =====
	reg		[15:0]		prer;			// Prescale register (clock timing)
	reg		[7:0]		ctr;			// Control register (EN, IEN, reserved)
	reg		[7:0]		txr;			// Transmit register (byte to send)
	reg		[7:0]		cr;				// Command register (STA, STO, RD, WR, ACK, IACK)
	reg		[7:0]		rxr;			// Receive register (received byte)

	// ===== Status Registers =====
	reg					rxack;			// Acknowledge status from last transfer
	reg					al;				// Arbitration lost (latched)
	reg					tip;			// Transfer in progress
	reg					irq_flag;		// Interrupt pending flag

	// ===== Decoded Command Signals (from cr) =====
	wire				sta;			// START condition request
	wire				sto;			// STOP condition request
	wire				rd;				// READ byte request
	wire				wr;				// WRITE byte request
	wire				ack;			// ACK/NACK bit control
	wire				iack;			// Interrupt acknowledge

	assign sta = cr[7];
	assign sto = cr[6];
	assign rd  = cr[5];
	assign wr  = cr[4];
	assign ack = cr[3];
	assign iack = cr[0];

	// ===== Control Register Bit Extraction =====
	wire				core_en;		// Core enable from ctr[7]
	wire				ien;			// Interrupt enable from ctr[6]

	assign core_en = ctr[7];
	assign ien = ctr[6];

	// ===== Wishbone Write Qualification =====
	wire				wb_wacc;		// Qualified write access
	assign wb_wacc = wb_we_i & wb_ack_o;

	// ===== Wishbone Acknowledge Generation =====
	// Registered acknowledge: pulse when both strobe and cycle are active
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			wb_ack_o <= 1'b0;
		end
		else if (wb_rst_i) begin
			wb_ack_o <= 1'b0;
		end
		else begin
			wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
		end
	end

	// ===== Byte-Level Command Controller Instance =====
	i2c_master_byte_ctrl byte_ctrl (
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
		.dout       (rxr),
		.i2c_busy   (i2c_busy),
		.i2c_al     (i2c_al),
		.scl_i      (scl_pad_i),
		.scl_o      (scl_pad_o),
		.scl_oen    (scl_padoen_o),
		.sda_i      (sda_pad_i),
		.sda_o      (sda_pad_o),
		.sda_oen    (sda_padoen_o)
	);

	// ===== Byte Controller Outputs (locally named for clarity) =====
	wire				done;			// Byte command completed (cmd_ack)
	wire				irxack;			// Received acknowledge bit from byte controller
	wire				i2c_busy;		// I2C bus busy status
	wire				i2c_al;			// Arbitration lost status

	// ===== Prescale Register (PRER) Writes =====
	// Addresses 0x00 (low byte) and 0x01 (high byte)
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			prer <= 16'hFFFF;  // Default prescale value
		end
		else if (wb_rst_i) begin
			prer <= 16'hFFFF;
		end
		else if (wb_wacc) begin
			case (wb_adr_i)
				3'b000: prer[7:0] <= wb_dat_i;   // PRER[7:0] at address 0x00
				3'b001: prer[15:8] <= wb_dat_i;  // PRER[15:8] at address 0x01
				default: begin
					// No action for other addresses
				end
			endcase
		end
	end

	// ===== Control Register (CTR) Writes =====
	// Address 0x02
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			ctr <= 8'h00;
		end
		else if (wb_rst_i) begin
			ctr <= 8'h00;
		end
		else if (wb_wacc && wb_adr_i == 3'b010) begin
			ctr <= wb_dat_i;  // CTR = {EN, IEN, reserved[5:0]}
		end
	end

	// ===== Transmit Register (TXR) Writes =====
	// Address 0x03 (write-only; read returns RXR)
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			txr <= 8'h00;
		end
		else if (wb_rst_i) begin
			txr <= 8'h00;
		end
		else if (wb_wacc && wb_adr_i == 3'b011) begin
			txr <= wb_dat_i;  // Load transmit byte
		end
	end

	// ===== Command Register (CR) Writes and Auto-Clear =====
	// Address 0x04 (write-only; read returns SR)
	// Command register accepts writes only when core is enabled
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			cr <= 8'h00;
		end
		else if (wb_rst_i) begin
			cr <= 8'h00;
		end
		else begin
			// Auto-clear command bits when done or arbitration lost
			if (done || i2c_al) begin
				cr[7:4] <= 4'b0000;  // Clear STA, STO, RD, WR
				cr[2:1] <= 2'b00;    // Clear reserved bits
				cr[0]   <= 1'b0;     // Clear IACK
			end
			// Host write to command register (only when core enabled)
			else if (wb_wacc && wb_adr_i == 3'b100 && core_en) begin
				cr <= wb_dat_i;
			end
		end
	end

	// ===== Status: RxACK (Acknowledge Received) =====
	// Latches the slave acknowledge bit from the byte controller
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			rxack <= 1'b0;
		end
		else if (wb_rst_i) begin
			rxack <= 1'b0;
		end
		else begin
			// Latch the acknowledge bit after each byte transfer
			rxack <= irxack;
		end
	end

	// ===== Status: TIP (Transfer In Progress) =====
	// Indicates that a read or write command is active
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			tip <= 1'b0;
		end
		else if (wb_rst_i) begin
			tip <= 1'b0;
		end
		else begin
			// Set when read or write is active, cleared when command completes
			tip <= rd | wr;
		end
	end

	// ===== Status: AL (Arbitration Lost - Latched) =====
	// Once arbitration loss is detected, remains set until new START command
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			al <= 1'b0;
		end
		else if (wb_rst_i) begin
			al <= 1'b0;
		end
		else begin
			// Set when arbitration is lost, cleared by new START command
			al <= i2c_al | (al & ~sta);
		end
	end

	// ===== Interrupt Flag (IRQ_FLAG) =====
	// Set by command completion or arbitration loss, cleared by IACK
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			irq_flag <= 1'b0;
		end
		else if (wb_rst_i) begin
			irq_flag <= 1'b0;
		end
		else begin
			// Set on done or arbitration loss, cleared on IACK
			irq_flag <= (done | i2c_al | irq_flag) & ~iack;
		end
	end

	// ===== Wishbone Interrupt Output =====
	// Asserted when interrupt pending flag is set AND interrupt enable is high
	always @(posedge wb_clk_i or negedge rst_i) begin
		if (~rst_i) begin
			wb_inta_o <= 1'b0;
		end
		else if (wb_rst_i) begin
			wb_inta_o <= 1'b0;
		end
		else begin
			wb_inta_o <= irq_flag & ien;
		end
	end

	// ===== Wishbone Read Data Output (wb_dat_o) =====
	// Registered output updated on every clock cycle according to address
	always @(posedge wb_clk_i) begin
		case (wb_adr_i)
			3'b000: wb_dat_o <= prer[7:0];      // PRER[7:0]
			3'b001: wb_dat_o <= prer[15:8];     // PRER[15:8]
			3'b010: wb_dat_o <= ctr;            // Control register
			3'b011: wb_dat_o <= rxr;            // Receive data register
			3'b100: begin
				// Status register (standard address for read)
				// sr[7] = rxack, sr[6] = i2c_busy, sr[5] = al
				// sr[4:2] = 0, sr[1] = tip, sr[0] = irq_flag
				wb_dat_o <= {rxack, i2c_busy, al, 3'b000, tip, irq_flag};
			end
			3'b101: wb_dat_o <= txr;            // Transmit register (non-standard readback)
			3'b110: wb_dat_o <= cr;             // Command register (non-standard readback)
			3'b111: wb_dat_o <= 8'h00;          // Reserved address reads as 0x00
			default: wb_dat_o <= 8'h00;
		endcase
	end

endmodule
module i2c_master_top(
	wb_clk_i, wb_rst_i, arst_i, wb_adr_i, wb_dat_i, wb_dat_o,
	wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_inta_o,
	scl_pad_i, scl_pad_o, scl_padoen_o, sda_pad_i, sda_pad_o, sda_padoen_o
);

	// ===== Parameter =====
	parameter ARST_LVL = 1'b1;  // Asynchronous reset active level

	// ===== Port Declarations =====
	input             wb_clk_i;
	input             wb_rst_i;
	input             arst_i;
	input      [2:0]  wb_adr_i;
	input      [7:0]  wb_dat_i;
	output reg [7:0]  wb_dat_o;
	input             wb_we_i;
	input             wb_stb_i;
	input             wb_cyc_i;
	output reg        wb_ack_o;
	output reg        wb_inta_o;

	input             scl_pad_i;
	output            scl_pad_o;
	output            scl_padoen_o;
	input             sda_pad_i;
	output            sda_pad_o;
	output            sda_padoen_o;

	// ===== Internal Signals =====
	wire              rst_i;              // Active-low asynchronous reset
	wire              core_en;            // Core enable (ctr[7])
	wire              ien;                // Interrupt enable (ctr[6])

	// Wishbone interface control
	wire              wb_wacc;            // Qualified write access
	wire              wb_ack_next;        // Next state of wb_ack_o

	// Internal registers
	reg [15:0]        prer;               // Prescale register
	reg [7:0]         ctr;                // Control register
	reg [7:0]         txr;                // Transmit register
	reg [7:0]         rxr;                // Receive register (from byte controller)
	reg [7:0]         cr;                 // Command register

	// Status and control flags
	reg               rxack;              // Received acknowledge flag
	reg               tip;                // Transfer in progress
	reg               irq_flag;           // Interrupt flag
	reg               al;                 // Arbitration lost flag

	// Byte controller interface signals
	wire              done;               // Command complete from byte controller
	wire              irxack;             // Acknowledge status from byte controller
	wire [7:0]        irxr;               // Receive data from byte controller
	wire              i2c_busy;           // Bus busy from byte controller
	wire              i2c_al;             // Arbitration lost from byte controller

	// Command signals decoded from cr
	wire              sta;                // START command (cr[7])
	wire              sto;                // STOP command (cr[6])
	wire              rd;                 // READ command (cr[5])
	wire              wr;                 // WRITE command (cr[4])
	wire              ack;                // ACK/NACK value (cr[3])
	wire              iack;               // Interrupt acknowledge (cr[0])

	// ===== Normalize Asynchronous Reset =====
	assign rst_i = arst_i ^ ARST_LVL;

	// ===== Wishbone Interface =====

	// Acknowledge generation: pulse for valid bus cycle
	assign wb_ack_next = wb_cyc_i & wb_stb_i & ~wb_ack_o;

	// Qualified write access
	assign wb_wacc = wb_we_i & wb_ack_o;

	// Core enable and interrupt enable
	assign core_en = ctr[7];
	assign ien = ctr[6];

	// ===== Decode Command Register Bits =====
	assign sta = cr[7];
	assign sto = cr[6];
	assign rd = cr[5];
	assign wr = cr[4];
	assign ack = cr[3];
	assign iack = cr[0];

	// ===== Instantiate Byte-Level Controller =====
	i2c_master_byte_ctrl byte_controller (
		.clk      (wb_clk_i),
		.rst      (wb_rst_i),
		.nReset   (~rst_i),
		.ena      (core_en),
		.clk_cnt  (prer),

		.start    (sta),
		.stop     (sto),
		.read     (rd),
		.write    (wr),
		.ack_in   (ack),
		.din      (txr),

		.cmd_ack  (done),
		.ack_out  (irxack),
		.dout     (irxr),
		.i2c_busy (i2c_busy),
		.i2c_al   (i2c_al),

		.scl_i    (scl_pad_i),
		.scl_o    (scl_pad_o),
		.scl_oen  (scl_padoen_o),
		.sda_i    (sda_pad_i),
		.sda_o    (sda_pad_o),
		.sda_oen  (sda_padoen_o)
	);

	// ===== Register Write Logic =====

	always @(negedge rst_i or posedge wb_clk_i) begin
		if (!rst_i) begin
			// Asynchronous reset
			prer  <= 16'hffff;
			ctr   <= 8'h00;
			txr   <= 8'h00;
			cr    <= 8'h00;
			rxack <= 1'b0;
			al    <= 1'b0;
			tip   <= 1'b0;
			irq_flag <= 1'b0;
		end
		else if (wb_rst_i) begin
			// Synchronous reset
			prer  <= 16'hffff;
			ctr   <= 8'h00;
			txr   <= 8'h00;
			cr    <= 8'h00;
			rxack <= 1'b0;
			al    <= 1'b0;
			tip   <= 1'b0;
			irq_flag <= 1'b0;
		end
		else begin
			// Regular operation

			// Wishbone acknowledge generation
			wb_ack_o <= wb_ack_next;

			// Regular register writes (when wb_wacc is high)
			if (wb_wacc) begin
				case (wb_adr_i)
					3'b000: prer[7:0]   <= wb_dat_i;   // PRER[7:0]
					3'b001: prer[15:8]  <= wb_dat_i;   // PRER[15:8]
					3'b010: ctr         <= wb_dat_i;   // CTR
					3'b011: txr         <= wb_dat_i;   // TXR (address 0x03 write)
					3'b100: begin                       // CR (address 0x04 write)
						if (core_en) begin
							cr <= wb_dat_i;
						end
					end
					default: begin
						// Other addresses do not support writes
					end
				endcase
			end

			// Update rxr with received data when byte controller completes
			if (done | i2c_al) begin
				rxr <= irxr;
			end

			// Update rxack with slave acknowledge status
			rxack <= irxack;

			// Update tip based on active read/write commands
			tip <= rd | wr;

			// Update interrupt flag
			irq_flag <= (done | i2c_al | irq_flag) & ~iack;

			// Update arbitration-lost flag
			al <= i2c_al | (al & ~sta);

			// Clear command bits when command completes or arbitration is lost
			if (done | i2c_al) begin
				cr[7:4] <= 4'h0;  // Clear STA, STO, RD, WR
				cr[2:1] <= 2'h0;  // Clear reserved bits
				cr[0]   <= 1'b0;  // Clear IACK
			end
			else if (wb_wacc & (wb_adr_i == 3'b100)) begin
				// Command register write clears reserved and IACK bits after command acceptance
				cr[2:1] <= 2'h0;
				cr[0]   <= 1'b0;
			end

			// Interrupt output generation
			wb_inta_o <= irq_flag & ien;
		end
	end

	// ===== Register Read Logic (Combinational) =====

	always @(*) begin
		case (wb_adr_i)
			3'b000: wb_dat_o = prer[7:0];        // PRER[7:0]
			3'b001: wb_dat_o = prer[15:8];       // PRER[15:8]
			3'b010: wb_dat_o = ctr;              // CTR
			3'b011: wb_dat_o = rxr;              // RXR (read) or TXR (write)
			3'b100: begin                        // SR (read) or CR (write)
				wb_dat_o = {rxack, i2c_busy, al, 3'h0, tip, irq_flag};
			end
			3'b101: wb_dat_o = txr;              // TXR (non-standard readback)
			3'b110: wb_dat_o = cr;               // CR (non-standard readback)
			3'b111: wb_dat_o = 8'h00;            // Reserved
		endcase
	end

endmodule
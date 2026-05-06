module or1200_dc_top(
    // Rst, clk and clock control
    input clk,
    input rst,

    // External i/f
    output [31:0] dcsb_dat_o,
    output [31:0] dcsb_adr_o,
    output dcsb_cyc_o,
    output dcsb_stb_o,
    output dcsb_we_o,
    output [3:0] dcsb_sel_o,
    output dcsb_cab_o,
    input [31:0] dcsb_dat_i,
    input dcsb_ack_i,
    input dcsb_err_i,

    // Internal i/f
    input dc_en,
    input [31:0] dcqmem_adr_i,
    input dcqmem_cycstb_i,
    input dcqmem_ci_i,
    input dcqmem_we_i,
    input [3:0] dcqmem_sel_i,
    input [3:0] dcqmem_tag_i,
    input [31:0] dcqmem_dat_i,
    output [31:0] dcqmem_dat_o,
    output dcqmem_ack_o,
    output dcqmem_rty_o,
    output dcqmem_err_o,
    output [3:0] dcqmem_tag_o,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // SPRs
    input spr_cs,
    input spr_write,
    input [31:0] spr_dat_i
);

	// ===== Internal Wire Declarations =====
	
	// Tag RAM signals
	wire				tag_v;				// Tag valid bit
	wire	[18:0]		tag;				// Tag value from tag RAM
	wire	[12:4]		dctag_addr;			// Tag RAM address
	wire				dctag_we;			// Tag RAM write enable
	wire				dctag_en;			// Tag RAM enable
	wire				dctag_v;			// Tag RAM valid bit input
	
	// Data RAM signals
	wire	[31:0]		to_dcram;			// Write data to DCRAM
	wire	[31:0]		from_dcram;			// Read data from DCRAM
	wire	[3:0]		dcram_we;			// DCRAM write enable
	
	// Address and control signals
	wire	[31:0]		saved_addr;			// Saved address for tag comparison
	wire	[31:0]		dc_addr;			// Cache address from FSM
	
	// FSM signals
	wire				dcfsm_biu_read;		// BIU read control from FSM
	wire				dcfsm_biu_write;	// BIU write control from FSM
	wire				dcfsm_first_hit_ack;	// First hit acknowledge
	wire				dcfsm_first_miss_ack;	// First miss acknowledge
	wire				dcfsm_first_miss_err;	// First miss error
	wire				dcfsm_burst;		// Burst control
	wire				dcfsm_tag_we;		// Tag write enable from FSM
	
	// Cache invalidation
	wire				dc_inv;				// Cache invalidation signal
	
	// Tag comparison
	reg					tagcomp_miss;		// Tag compare miss flag
	
	// BIST signals
	`ifdef OR1200_BIST
	wire				mbist_ram_so;		// BIST RAM serial output
	wire				mbist_tag_so;		// BIST tag serial output
	wire				mbist_ram_si;		// BIST RAM serial input
	wire				mbist_tag_si;		// BIST tag serial input
	`endif

	// ===== Cache Invalidation Control =====
	assign dc_inv = spr_cs & spr_write;
	
	// ===== Tag RAM Address Selection =====
	// During invalidation, use SPR address; otherwise use FSM-generated address
	assign dctag_addr = dc_inv ? spr_dat_i[12:4] : dc_addr[12:4];
	
	// ===== Tag RAM Valid Bit Control =====
	// During invalidation, clear valid bit; during normal writes, set it
	assign dctag_v = ~dc_inv;
	
	// ===== Tag RAM Write Enable =====
	// Write enable from FSM OR'd with invalidation signal
	assign dctag_we = dcfsm_tag_we | dc_inv;
	
	// ===== External Bus Write Data =====
	// Always driven directly from LSU/QMEM write data
	assign dcsb_dat_o = dcqmem_dat_i;
	
	// ===== External Bus Address =====
	// Address from FSM-generated dc_addr
	assign dcsb_adr_o = dc_addr;
	
	// ===== DCRAM Write Data Selection =====
	// During BIU reads: external bus data
	// Otherwise: LSU/QMEM write data
	assign to_dcram = dcfsm_biu_read ? dcsb_dat_i : dcqmem_dat_i;
	
	// ===== Tag Comparison Logic (Combinational) =====
	// Compare tag with saved address and check valid bit
	always @(*) begin
		if ((tag != saved_addr[31:13]) || !tag_v) begin
			tagcomp_miss = 1'b1;
		end
		else begin
			tagcomp_miss = 1'b0;
		end
	end

	// ===== Cache Enabled / Bypass Mode Selection =====
	
	// --- External Bus Control Signals ---
	// When cache disabled, pass through LSU/QMEM; when enabled, use FSM signals
	assign dcsb_cyc_o = dc_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
	assign dcsb_stb_o = dc_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
	assign dcsb_we_o  = dc_en ? dcfsm_biu_write : dcqmem_we_i;
	
	// --- Byte Select Control ---
	// For cache-enabled, non-inhibited BIU reads, force full 32-bit select
	wire				cache_inhibit;
	assign cache_inhibit = dcqmem_ci_i;
	
	assign dcsb_sel_o = (dc_en & dcfsm_biu_read & ~cache_inhibit) ? 4'b1111 : dcqmem_sel_i;
	
	// --- Burst Control ---
	assign dcsb_cab_o = dc_en ? dcfsm_burst : 1'b0;
	
	// --- LSU/QMEM Acknowledge Control ---
	// Cached mode: use FSM first-hit or first-miss acknowledge
	// Bypass mode: use external bus acknowledge
	assign dcqmem_ack_o = dc_en ? (dcfsm_first_hit_ack | dcfsm_first_miss_ack) : dcsb_ack_i;
	
	// --- LSU/QMEM Error Control ---
	// Cached mode: use FSM first-miss error
	// Bypass mode: use external bus error
	assign dcqmem_err_o = dc_en ? dcfsm_first_miss_err : dcsb_err_i;
	
	// --- LSU/QMEM Retry Control ---
	// Retry is inverse of acknowledge
	assign dcqmem_rty_o = ~dcqmem_ack_o;
	
	// --- LSU/QMEM Tag Control ---
	// Return input tag unless error occurs
	wire	[3:0]		error_tag;
	localparam OR1200_DTAG_BE = 4'hf;  // Bus error tag
	
	assign error_tag = (dcqmem_err_o) ? OR1200_DTAG_BE : dcqmem_tag_i;
	assign dcqmem_tag_o = error_tag;
	
	// --- LSU/QMEM Read Data Selection ---
	// Cached mode:
	//   - First miss: return external bus data
	//   - Otherwise: return DCRAM data
	// Bypass mode: return external bus data
	assign dcqmem_dat_o = (dc_en & ~dcfsm_first_miss_ack) ? from_dcram : dcsb_dat_i;

	// ===== Instantiate Data-Cache FSM =====
	or1200_dc_fsm dcfsm(
		.clk               (clk),
		.rst               (rst),
		.dc_en             (dc_en),
		.dcqmem_adr_i      (dcqmem_adr_i),
		.dcqmem_cycstb_i   (dcqmem_cycstb_i),
		.dcqmem_ci_i       (dcqmem_ci_i),
		.dcqmem_we_i       (dcqmem_we_i),
		.tagcomp_miss      (tagcomp_miss),
		.dcsb_ack_i        (dcsb_ack_i),
		.dcsb_err_i        (dcsb_err_i),
		.dc_addr           (dc_addr),
		.saved_addr        (saved_addr),
		.dcfsm_biu_read    (dcfsm_biu_read),
		.dcfsm_biu_write   (dcfsm_biu_write),
		.dcram_we          (dcram_we),
		.dcfsm_tag_we      (dcfsm_tag_we),
		.dcfsm_first_hit_ack (dcfsm_first_hit_ack),
		.dcfsm_first_miss_ack (dcfsm_first_miss_ack),
		.dcfsm_first_miss_err (dcfsm_first_miss_err),
		.dcfsm_burst       (dcfsm_burst)
	);

	// ===== Instantiate Data-Cache RAM =====
	or1200_dc_ram dcram(
		.clk               (clk),
		.rst               (rst),
		.dc_adr            (dc_addr[11:2]),  // Cache index address
		.we                (dcram_we),       // Write enable
		.din               (to_dcram),       // Write data
		.dout              (from_dcram)      // Read data
		`ifdef OR1200_BIST
		,
		.mbist_si_i        (mbist_ram_si),
		.mbist_so_o        (mbist_ram_so),
		.mbist_ctrl_i      (mbist_ctrl_i)
		`endif
	);

	// ===== Instantiate Tag RAM =====
	or1200_dc_tag dctag(
		.clk               (clk),
		.rst               (rst),
		.dc_adr            (dctag_addr),     // Tag address
		.we                (dctag_we),       // Write enable
		.din               (saved_addr[31:13]), // Write data (tag + valid)
		.tag_v_in          (dctag_v),        // Valid bit input
		.tag_v_out         (tag_v),          // Valid bit output
		.tag_out           (tag)             // Tag output
		`ifdef OR1200_BIST
		,
		.mbist_si_i        (mbist_tag_si),
		.mbist_so_o        (mbist_tag_so),
		.mbist_ctrl_i      (mbist_ctrl_i)
		`endif
	);

	// ===== BIST Mux Logic =====
	`ifdef OR1200_BIST
	assign mbist_ram_si = mbist_si_i;
	assign mbist_tag_si = mbist_ram_so;
	assign mbist_so_o = mbist_tag_so;
	`endif

endmodule
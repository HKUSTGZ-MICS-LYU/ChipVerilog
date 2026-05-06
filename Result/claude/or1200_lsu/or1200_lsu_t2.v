module or1200_lsu(
    // Internal i/f
    input [31:0] addrbase,
    input [31:0] addrofs,
    input [3:0] lsu_op,
    input [31:0] lsu_datain,
    output [31:0] lsu_dataout,
    output lsu_stall,
    output lsu_unstall,
    input du_stall,
    output except_align,
    output except_dtlbmiss,
    output except_dmmufault,
    output except_dbuserr,

    // External i/f to DC
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i,
    input [3:0] dcpu_tag_i
);

    // LSU operation type encoding
    localparam [3:0] LSUOP_SB = 4'b0001;  // Store byte
    localparam [3:0] LSUOP_SH = 4'b0010;  // Store half-word
    localparam [3:0] LSUOP_SW = 4'b0100;  // Store word
    localparam [3:0] LSUOP_LBZ = 4'b1001; // Load byte zero-extended
    localparam [3:0] LSUOP_LBS = 4'b1000; // Load byte sign-extended
    localparam [3:0] LSUOP_LHZ = 4'b1011; // Load half-word zero-extended
    localparam [3:0] LSUOP_LHS = 4'b1010; // Load half-word sign-extended
    localparam [3:0] LSUOP_LWZ = 4'b1101; // Load word zero-extended
    localparam [3:0] LSUOP_LWS = 4'b1100; // Load word sign-extended

    localparam [3:0] DTAG_IDLE = 4'b0000;
    localparam [3:0] DTAG_ND = 4'b0011;
    localparam [3:0] DTAG_TE = 4'b0110;  // DTLB miss
    localparam [3:0] DTAG_PE = 4'b0111;  // DMMU fault
    localparam [3:0] DTAG_BE = 4'b1010;  // Bus error

    // Computed address
    wire [31:0] ea;
    assign ea = addrbase + addrofs;

    // Address low bits
    wire [1:0] ea_align = ea[1:0];

    // Address alignment exceptions
    wire align_error_half;
    wire align_error_word;
    wire is_half_access;
    wire is_word_access;

    // Determine operation type
    wire is_load = ~lsu_op[3];
    wire is_store = lsu_op[3];

    assign is_half_access = (lsu_op[3:0] == LSUOP_SH) || 
                            (lsu_op[3:0] == LSUOP_LHZ) || 
                            (lsu_op[3:0] == LSUOP_LHS);

    assign is_word_access = (lsu_op[3:0] == LSUOP_SW) || 
                            (lsu_op[3:0] == LSUOP_LWZ) || 
                            (lsu_op[3:0] == LSUOP_LWS);

    // Half-word access requires address bit 0 to be 0
    assign align_error_half = is_half_access & ea_align[0];

    // Word access requires address bits [1:0] to be all 0
    assign align_error_word = is_word_access & (|ea_align);

    // Combined alignment exception
    assign except_align = align_error_half | align_error_word;

    // Data side exceptions
    wire dcpu_error = dcpu_err_i & (dcpu_tag_i == DTAG_TE);
    wire dcpu_mmu_fault = dcpu_err_i & (dcpu_tag_i == DTAG_PE);
    wire dcpu_bus_error = dcpu_err_i & (dcpu_tag_i == DTAG_BE);

    assign except_dtlbmiss = dcpu_error;
    assign except_dmmufault = dcpu_mmu_fault;
    assign except_dbuserr = dcpu_bus_error;

    // Output address
    assign dcpu_adr_o = ea;

    // Write enable: determined by lsu_op[3] (bit 3 indicates store operation)
    assign dcpu_we_o = lsu_op[3];

    // Byte select logic based on address alignment and operation type
    wire [3:0] byte_sel;

    assign byte_sel = (lsu_op[3:0] == LSUOP_SB || lsu_op[3:0] == LSUOP_LBZ || lsu_op[3:0] == LSUOP_LBS) ? 
                      (ea_align == 2'b00 ? 4'b0001 : 
                       ea_align == 2'b01 ? 4'b0010 : 
                       ea_align == 2'b10 ? 4'b0100 : 
                       4'b1000) :
                      (is_half_access && ea_align == 2'b00) ? 4'b0011 :
                      (is_half_access && ea_align == 2'b10) ? 4'b1100 :
                      (is_word_access && ea_align == 2'b00) ? 4'b1111 :
                      4'b0000;

    assign dcpu_sel_o = byte_sel;

    // Data side tag output
    wire request_valid = |lsu_op;  // Request is valid if lsu_op is non-zero

    // DCycstb logic: suppress if du_stall, alignment error, or already received response
    assign dcpu_cycstb_o = request_valid & ~du_stall & ~except_align;

    // Tag output: DTAG_ND for normal data access, DTAG_IDLE otherwise
    assign dcpu_tag_o = dcpu_cycstb_o ? DTAG_ND : DTAG_IDLE;

    // Pipeline stall control
    // lsu_stall is asserted when dcpu_rty_i is returned and cycstb is active
    assign lsu_stall = dcpu_cycstb_o & dcpu_rty_i;

    // lsu_unstall is directly equal to dcpu_ack_i
    assign lsu_unstall = dcpu_ack_i;

    // Write data alignment: register data arranged to bus byte lanes
    wire [31:0] write_data_aligned;

    assign write_data_aligned = (ea_align == 2'b00) ? lsu_datain :
                                (ea_align == 2'b01) ? {lsu_datain[23:0], 8'b0} :
                                (ea_align == 2'b10) ? {lsu_datain[15:0], 16'b0} :
                                {lsu_datain[7:0], 24'b0};

    assign dcpu_dat_o = write_data_aligned;

    // Read data path: or1200_mem2reg conversion
    // Convert dcpu_dat_i into sign/zero extended register value
    wire [31:0] mem2reg_data;

    wire sign_bit;
    wire [31:0] extended_data;

    // Extract appropriate byte/half-word and apply sign/zero extension
    assign mem2reg_data = (lsu_op[3:0] == LSUOP_LBZ) ?
                          (ea_align == 2'b00 ? {24'b0, dcpu_dat_i[7:0]} :
                           ea_align == 2'b01 ? {24'b0, dcpu_dat_i[15:8]} :
                           ea_align == 2'b10 ? {24'b0, dcpu_dat_i[23:16]} :
                           {24'b0, dcpu_dat_i[31:24]}) :
                          (lsu_op[3:0] == LSUOP_LBS) ?
                          (ea_align == 2'b00 ? {{24{dcpu_dat_i[7]}}, dcpu_dat_i[7:0]} :
                           ea_align == 2'b01 ? {{24{dcpu_dat_i[15]}}, dcpu_dat_i[15:8]} :
                           ea_align == 2'b10 ? {{24{dcpu_dat_i[23]}}, dcpu_dat_i[23:16]} :
                           {{24{dcpu_dat_i[31]}}, dcpu_dat_i[31:24]}) :
                          (lsu_op[3:0] == LSUOP_LHZ) ?
                          (ea_align == 2'b00 ? {16'b0, dcpu_dat_i[15:0]} :
                           {16'b0, dcpu_dat_i[31:16]}) :
                          (lsu_op[3:0] == LSUOP_LHS) ?
                          (ea_align == 2'b00 ? {{16{dcpu_dat_i[15]}}, dcpu_dat_i[15:0]} :
                           {{16{dcpu_dat_i[31]}}, dcpu_dat_i[31:16]}) :
                          (lsu_op[3:0] == LSUOP_LWZ) ?
                          dcpu_dat_i :
                          (lsu_op[3:0] == LSUOP_LWS) ?
                          dcpu_dat_i :
                          32'h0;

    assign lsu_dataout = mem2reg_data;

endmodule

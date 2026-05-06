module or1200_lsu (
    input  [31:0] addrbase,
    input  [31:0] addrofs,
    input  [3:0]  lsu_op,
    input  [31:0] lsu_datain,
    output [31:0] lsu_dataout,
    output lsu_stall,
    output lsu_unstall,
    input  du_stall,
    output except_align,
    output except_dtlbmiss,
    output except_dmmufault,
    output except_dbuserr,
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output [3:0]  dcpu_sel_o,
    output [3:0]  dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input  [31:0] dcpu_dat_i,
    input  dcpu_ack_i,
    input  dcpu_rty_i,
    input  dcpu_err_i,
    input  [3:0]  dcpu_tag_i
);

    // Tag constants (from or1200_defines.v)
    localparam [3:0] OR1200_DTAG_ND   = 4'd0;
    localparam [3:0] OR1200_DTAG_IDLE = 4'd1;
    localparam [3:0] OR1200_DTAG_TE   = 4'd2;
    localparam [3:0] OR1200_DTAG_PE   = 4'd3;
    localparam [3:0] OR1200_DTAG_BE   = 4'd4;

    // Internal wires
    wire [1:0] mem2reg_addr;   // low two bits of address
    wire [31:0] effective_addr;
    wire is_byte;
    wire is_halfword;
    wire is_word;

    // Address generation
    assign effective_addr = addrbase + addrofs;
    assign dcpu_adr_o = effective_addr;
    assign mem2reg_addr = effective_addr[1:0];

    // Operation type decoding (lsu_op[2:1] encodes size: 00 byte, 01 halfword, 10 word)
    assign is_byte     = (lsu_op[2:1] == 2'b00);
    assign is_halfword = (lsu_op[2:1] == 2'b01);
    assign is_word     = (lsu_op[2:1] == 2'b10);

    // Alignment exception
    assign except_align = (is_halfword & mem2reg_addr[0]) | (is_word & (|mem2reg_addr));

    // Byte select logic
    reg [3:0] sel;
    always @(*) begin
        if (is_byte) begin
            case (mem2reg_addr)
                2'b00:   sel = 4'b1000;
                2'b01:   sel = 4'b0100;
                2'b10:   sel = 4'b0010;
                2'b11:   sel = 4'b0001;
                default: sel = 4'b0000;
            endcase
        end else if (is_halfword) begin
            case (mem2reg_addr)
                2'b00:   sel = 4'b1100;
                2'b10:   sel = 4'b0011;
                default: sel = 4'b0000;
            endcase
        end else if (is_word) begin
            if (mem2reg_addr == 2'b00)
                sel = 4'b1111;
            else
                sel = 4'b0000;
        end else begin
            sel = 4'b0000;
        end
    end
    assign dcpu_sel_o = sel;

    // Write enable
    assign dcpu_we_o = lsu_op[3];

    // Request generation
    // lsu_unstall is assertion of dcpu_ack_i (combinational)
    assign lsu_unstall = dcpu_ack_i;
    assign dcpu_cycstb_o = (|lsu_op) & ~(du_stall | lsu_unstall | except_align);

    // Tag output
    assign dcpu_tag_o = dcpu_cycstb_o ? OR1200_DTAG_ND : OR1200_DTAG_IDLE;

    // Stall output
    assign lsu_stall = dcpu_rty_i & dcpu_cycstb_o;

    // Exception classification from data side
    assign except_dtlbmiss  = dcpu_err_i & (dcpu_tag_i == OR1200_DTAG_TE);
    assign except_dmmufault = dcpu_err_i & (dcpu_tag_i == OR1200_DTAG_PE);
    assign except_dbuserr   = dcpu_err_i & (dcpu_tag_i == OR1200_DTAG_BE);

    // Instantiate load data alignment submodule
    or1200_mem2reg u_mem2reg (
        .addr_low (mem2reg_addr),
        .op       (lsu_op),
        .data_in  (dcpu_dat_i),
        .data_out (lsu_dataout)
    );

    // Instantiate store data alignment submodule
    or1200_reg2mem u_reg2mem (
        .addr_low (mem2reg_addr),
        .op       (lsu_op),
        .data_in  (lsu_datain),
        .data_out (dcpu_dat_o)
    );

endmodule

module or1200_lsu(
    input  [31:0] addrbase,
    input  [31:0] addrofs,
    input  [3:0]  lsu_op,
    input  [31:0] lsu_datain,
    output [31:0] lsu_dataout,
    output        lsu_stall,
    output        lsu_unstall,
    input         du_stall,
    output        except_align,
    output        except_dtlbmiss,
    output        except_dmmufault,
    output        except_dbuserr,

    output [31:0] dcpu_adr_o,
    output        dcpu_cycstb_o,
    output        dcpu_we_o,
    output [3:0]  dcpu_sel_o,
    output [3:0]  dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input  [31:0] dcpu_dat_i,
    input         dcpu_ack_i,
    input         dcpu_rty_i,
    input         dcpu_err_i,
    input  [3:0]  dcpu_tag_i
);

    // Tag constants matching OR1200 definitions
    localparam [3:0] OR1200_DTAG_IDLE = 4'b0000;
    localparam [3:0] OR1200_DTAG_ND   = 4'b0001;
    localparam [3:0] OR1200_DTAG_TE   = 4'b0010;
    localparam [3:0] OR1200_DTAG_PE   = 4'b0100;
    localparam [3:0] OR1200_DTAG_BE   = 4'b1000;

    wire [31:0] effective_addr;
    wire [1:0]  addr_low;
    wire        is_byte;
    wire        is_half;
    wire        is_word;

    // Effective address (combinational adder)
    assign effective_addr = addrbase + addrofs;
    assign addr_low = effective_addr[1:0];

    // Decode operation size from lsu_op[2:1] (encoding: 00=byte, 01=half, 10=word)
    assign is_byte = (lsu_op[2:1] == 2'b00);
    assign is_half = (lsu_op[2:1] == 2'b01);
    assign is_word = (lsu_op[2:1] == 2'b10);

    // Alignment check
    assign except_align = (is_half & effective_addr[0]) | (is_word & (|effective_addr[1:0]));

    // Write enable: lsu_op[3] set for stores
    assign dcpu_we_o = lsu_op[3];

    // dcpu_cycstb_o: valid request only when lsu_op != 0 and no blocking conditions
    assign dcpu_cycstb_o = (|lsu_op) & ~(du_stall | lsu_unstall | except_align);

    // dcpu_sel_o: byte lane select based on operation size and address low bits
    reg [3:0] sel;
    always @(*) begin
        if (is_byte) begin
            case (addr_low)
                2'b00:   sel = 4'b1000;
                2'b01:   sel = 4'b0100;
                2'b10:   sel = 4'b0010;
                2'b11:   sel = 4'b0001;
                default: sel = 4'b0000;
            endcase
        end else if (is_half) begin
            case (addr_low)
                2'b00:   sel = 4'b1100;
                2'b10:   sel = 4'b0011;
                default: sel = 4'b0000; // misaligned addresses produce 0000
            endcase
        end else if (is_word) begin
            if (addr_low == 2'b00)
                sel = 4'b1111;
            else
                sel = 4'b0000; // misaligned
        end else begin
            sel = 4'b0000;
        end
    end
    assign dcpu_sel_o = sel;

    // dcpu_adr_o is the effective address
    assign dcpu_adr_o = effective_addr;

    // dcpu_tag_o: active request tag or idle tag
    assign dcpu_tag_o = dcpu_cycstb_o ? OR1200_DTAG_ND : OR1200_DTAG_IDLE;

    // Stall and unstall signals
    assign lsu_stall   = dcpu_rty_i & dcpu_cycstb_o;
    assign lsu_unstall = dcpu_ack_i;

    // Exception classification from data side error response
    assign except_dtlbmiss = dcpu_err_i & (dcpu_tag_i == OR1200_DTAG_TE);
    assign except_dmmufault = dcpu_err_i & (dcpu_tag_i == OR1200_DTAG_PE);
    assign except_dbuserr   = dcpu_err_i & (dcpu_tag_i == OR1200_DTAG_BE);

    // Instantiate load data alignment submodule
    or1200_mem2reg u_mem2reg (
        .addr_low   (addr_low),
        .lsu_op     (lsu_op),
        .dcpu_dat_i (dcpu_dat_i),
        .lsu_dataout(lsu_dataout)
    );

    // Instantiate store data alignment submodule
    or1200_reg2mem u_reg2mem (
        .addr_low   (addr_low),
        .lsu_op     (lsu_op),
        .lsu_datain (lsu_datain),
        .dcpu_dat_o (dcpu_dat_o)
    );

endmodule

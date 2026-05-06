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

    // OR1200 defines
    `include "or1200_defines.v"

    // Effective address
    wire [31:0] eff_addr;
    assign eff_addr = addrbase + addrofs;
    assign dcpu_adr_o = eff_addr;

    // Low address bits for alignment and data steering
    wire [1:0] mem2reg_addr;
    assign mem2reg_addr = eff_addr[1:0];

    // Operation decode
    wire is_store;
    wire is_load;
    assign is_store = lsu_op[3];
    assign is_load  = ~is_store && (|lsu_op);

    // Alignment checking
    reg except_align;
    always @* begin
        case (lsu_op)
            `OR1200_LSU_OP_SH, `OR1200_LSU_OP_LHZ, `OR1200_LSU_OP_LHS: begin
                except_align = eff_addr[0];
            end
            `OR1200_LSU_OP_SW, `OR1200_LSU_OP_LWZ, `OR1200_LSU_OP_LWS: begin
                except_align = |eff_addr[1:0];
            end
            default: begin
                except_align = 1'b0;
            end
        endcase
    end

    // Request generation
    assign dcpu_cycstb_o = (|lsu_op) && ~du_stall && ~lsu_unstall && ~except_align;

    // Write enable
    assign dcpu_we_o = lsu_op[3];

    // Byte select generation
    always @* begin
        case (lsu_op)
            `OR1200_LSU_OP_SB, `OR1200_LSU_OP_LBZ, `OR1200_LSU_OP_LBS: begin
                case (eff_addr[1:0])
                    2'b00: dcpu_sel_o = 4'b1000;
                    2'b01: dcpu_sel_o = 4'b0100;
                    2'b10: dcpu_sel_o = 4'b0010;
                    2'b11: dcpu_sel_o = 4'b0001;
                endcase
            end
            `OR1200_LSU_OP_SH, `OR1200_LSU_OP_LHZ, `OR1200_LSU_OP_LHS: begin
                case (eff_addr[1:0])
                    2'b00: dcpu_sel_o = 4'b1100;
                    2'b10: dcpu_sel_o = 4'b0011;
                    default: dcpu_sel_o = 4'b0000;
                endcase
            end
            `OR1200_LSU_OP_SW, `OR1200_LSU_OP_LWZ, `OR1200_LSU_OP_LWS: begin
                if (eff_addr[1:0] == 2'b00)
                    dcpu_sel_o = 4'b1111;
                else
                    dcpu_sel_o = 4'b0000;
            end
            default: begin
                dcpu_sel_o = 4'b0000;
            end
        endcase
    end

    // Tag generation
    assign dcpu_tag_o = dcpu_cycstb_o ? `OR1200_DTAG_ND : `OR1200_DTAG_IDLE;

    // Stall / Unstall
    assign lsu_stall   = dcpu_rty_i & dcpu_cycstb_o;
    assign lsu_unstall = dcpu_ack_i;

    // Exception classification
    assign except_dtlbmiss  = dcpu_err_i && (dcpu_tag_i == `OR1200_DTAG_TE);
    assign except_dmmufault = dcpu_err_i && (dcpu_tag_i == `OR1200_DTAG_PE);
    assign except_dbuserr   = dcpu_err_i && (dcpu_tag_i == `OR1200_DTAG_BE);

    // Data alignment submodules
    or1200_mem2reg u_mem2reg (
        .addr     (mem2reg_addr),
        .lsu_op   (lsu_op),
        .memdata  (dcpu_dat_i),
        .regdata  (lsu_dataout)
    );

    or1200_reg2mem u_reg2mem (
        .addr     (mem2reg_addr),
        .lsu_op   (lsu_op),
        .regdata  (lsu_datain),
        .memdata  (dcpu_dat_o)
    );

endmodule

module or1200_sprs (
    input clk,
    input rst,
    input flagforw,
    input flag_we,
    output flag,
    input cyforw,
    input cy_we,
    output carry,
    input [31:0] addrbase,
    input [15:0] addrofs,
    input [31:0] dat_i,
    input [3:0] alu_op,
    input [2:0] branch_op,
    input [31:0] epcr,
    input [31:0] eear,
    input [15:0] esr,
    input except_started,
    output reg [31:0] to_wbmux,
    output epcr_we,
    output eear_we,
    output esr_we,
    output pc_we,
    output sr_we,
    output [15:0] to_sr,
    output reg [15:0] sr,
    input [31:0] spr_dat_cfgr,
    input [31:0] spr_dat_rf,
    input [31:0] spr_dat_npc,
    input [31:0] spr_dat_ppc,
    input [31:0] spr_dat_mac,
    input [31:0] spr_dat_pic,
    input [31:0] spr_dat_tt,
    input [31:0] spr_dat_pm,
    input [31:0] spr_dat_dmmu,
    input [31:0] spr_dat_immu,
    input [31:0] spr_dat_du,
    output reg [31:0] spr_addr,
    output reg [31:0] spr_dat_o,
    output reg [31:0] spr_cs,
    output spr_we,
    input [31:0] du_addr,
    input [31:0] du_dat_du,
    input du_read,
    input du_write,
    output reg [31:0] du_dat_cpu
);

    // localparam for ALU operations and branch opcodes
    localparam OR1200_ALUOP_MTSR = 4'b1101;
    localparam OR1200_ALUOP_MFSR = 4'b1100;
    localparam OR1200_BRANCHOP_RFE = 3'b101;  // typical OR1k RFE opcode

    // Internal wires
    wire du_access;
    wire [3:0] sprs_op;
    wire write_spr, read_spr;
    wire [31:0] unqualified_cs;
    wire cfgr_sel, rf_sel, npc_sel, ppc_sel, sr_sel, epcr_sel, eear_sel, esr_sel;
    wire [31:0] sys_data;
    reg [31:0] sys_data_comb;
    integer i;

    // Debug Unit access
    assign du_access = du_read | du_write;

    // SPR operation type
    assign sprs_op = (du_write) ? OR1200_ALUOP_MTSR :
                     (du_read)  ? OR1200_ALUOP_MFSR : alu_op;

    // SPR address
    always @(*) begin
        if (du_access)
            spr_addr = du_addr;
        else
            spr_addr = addrbase | {16'h0000, addrofs};
    end

    // SPR write data
    always @(*) begin
        if (du_write)
            spr_dat_o = du_dat_du;
        else
            spr_dat_o = dat_i;
    end

    // Decode SPR operation into read_spr/write_spr
    assign write_spr = (sprs_op == OR1200_ALUOP_MTSR);
    assign read_spr  = (sprs_op == OR1200_ALUOP_MFSR);

    // SPR write enable
    assign spr_we = du_write | write_spr;

    // Group decode: one-hot for spr_addr[15:11]
    always @(*) begin
        unqualified_cs = 32'd0;
        unqualified_cs[spr_addr[15:11]] = 1'b1;
    end

    // Qualified chip select
    always @(*) begin
        spr_cs = unqualified_cs & {32{(read_spr | write_spr)}};
    end

    // System group internal decode (group 0)
    assign cfgr_sel = spr_cs[0] & (spr_addr[11:4] == 8'h00);  // addresses 0x00-0x0F? but fine for coarser
    assign rf_sel   = spr_cs[0] & (spr_addr[11:4] == 8'h01);  // addresses 0x10-0x1F
    assign npc_sel  = spr_cs[0] & (spr_addr[11:0] == 12'h002);
    assign ppc_sel  = spr_cs[0] & (spr_addr[11:0] == 12'h004);
    assign sr_sel   = spr_cs[0] & (spr_addr[11:0] == 12'h003);
    assign epcr_sel = spr_cs[0] & (spr_addr[11:0] == 12'h005);
    assign eear_sel = spr_cs[0] & (spr_addr[11:0] == 12'h006);
    assign esr_sel  = spr_cs[0] & (spr_addr[11:0] == 12'h007);

    // System group write enables
    assign pc_we   = write_spr & (npc_sel | ppc_sel);
    assign epcr_we = write_spr & epcr_sel;
    assign eear_we = write_spr & eear_sel;
    assign esr_we  = write_spr & esr_sel;
    assign sr_we   = (write_spr & sr_sel) | (branch_op == OR1200_BRANCHOP_RFE) | flag_we | cy_we;

    // to_sr combinational generation
    assign to_sr[15:11] = (branch_op == OR1200_BRANCHOP_RFE) ? esr[15:11] :
                          (write_spr & sr_sel) ? {1'b1, spr_dat_o[14:11]} : sr[15:11];

    assign to_sr[10] = (branch_op == OR1200_BRANCHOP_RFE) ? esr[10] :
                       (cy_we) ? cyforw :
                       (write_spr & sr_sel) ? spr_dat_o[10] : sr[10];

    assign to_sr[9] = (branch_op == OR1200_BRANCHOP_RFE) ? esr[9] :
                      (flag_we) ? flagforw :
                      (write_spr & sr_sel) ? spr_dat_o[9] : sr[9];

    assign to_sr[8:0] = (branch_op == OR1200_BRANCHOP_RFE) ? esr[8:0] :
                        (write_spr & sr_sel) ? spr_dat_o[8:0] : sr[8:0];

    // SR sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst)
            sr <= 16'h0001;  // initial supervisor mode etc.
        else if (except_started) begin
            sr[0] <= 1'b1;
            sr[1] <= 1'b0;
            sr[2] <= 1'b0;
            sr[5] <= 1'b0;
            sr[6] <= 1'b0;
        end else if (sr_we) begin
            sr <= to_sr;
        end
    end

    // flag and carry outputs
    assign flag  = sr[9];
    assign carry = sr[10];

    // System group read data
    always @(*) begin
        sys_data_comb = 32'd0;
        if (cfgr_sel) sys_data_comb = spr_dat_cfgr;
        else if (rf_sel) sys_data_comb = spr_dat_rf;
        else if (npc_sel) sys_data_comb = spr_dat_npc;
        else if (ppc_sel) sys_data_comb = spr_dat_ppc;
        else if (sr_sel) sys_data_comb = {16'd0, sr};
        else if (epcr_sel) sys_data_comb = epcr;
        else if (eear_sel) sys_data_comb = eear;
        else if (esr_sel) sys_data_comb = {16'd0, esr};
    end
    assign sys_data = sys_data_comb;

    // to_wbmux: read result
    always @(*) begin
        if (!read_spr)
            to_wbmux = 32'd0;
        else begin
            case (spr_addr[15:11])
                5'd0  : to_wbmux = sys_data;
                5'd1  : to_wbmux = spr_dat_tt;   // tick timer
                5'd2  : to_wbmux = spr_dat_pic;  // PIC
                5'd3  : to_wbmux = spr_dat_pm;   // power management
                5'd4  : to_wbmux = spr_dat_dmmu; // DMMU
                5'd5  : to_wbmux = spr_dat_immu; // IMMU
                5'd6  : to_wbmux = spr_dat_mac;  // MAC
                5'd7  : to_wbmux = spr_dat_du;   // Debug Unit
                default: to_wbmux = 32'd0;        // reserved groups
            endcase
        end
    end

    // du_dat_cpu
    always @(*) begin
        if (du_write)
            du_dat_cpu = du_dat_du;
        else if (du_read)
            du_dat_cpu = to_wbmux;
        else
            du_dat_cpu = dat_i;
    end

endmodule

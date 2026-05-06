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
    output [31:0] to_wbmux,
    output epcr_we,
    output eear_we,
    output esr_we,
    output pc_we,
    output sr_we,
    output [15:0] to_sr,
    output [15:0] sr,
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
    output [31:0] spr_addr,
    output [31:0] spr_dat_o,
    output [31:0] spr_cs,
    output spr_we,
    input [31:0] du_addr,
    input [31:0] du_dat_du,
    input du_read,
    input du_write,
    output [31:0] du_dat_cpu
);

    // SPR opcodes
    localparam OR1200_ALUOP_MTSR = 4'b0011;
    localparam OR1200_ALUOP_MFSR = 4'b0100;

    // Debug Unit access
    wire du_access;
    wire [3:0] sprs_op;
    wire write_spr, read_spr;

    assign du_access = du_read | du_write;
    assign sprs_op = du_access ? 
                     (du_write ? OR1200_ALUOP_MTSR : OR1200_ALUOP_MFSR) :
                     alu_op;

    assign write_spr = (sprs_op == OR1200_ALUOP_MTSR);
    assign read_spr  = (sprs_op == OR1200_ALUOP_MFSR);

    // SPR address
    wire [31:0] cpu_spr_addr;
    assign cpu_spr_addr = addrbase | {16'h0000, addrofs};
    assign spr_addr = du_access ? du_addr : cpu_spr_addr;

    // SPR write data
    assign spr_dat_o = (du_access & du_write) ? du_dat_du : dat_i;

    // SPR write enable
    assign spr_we = du_write | write_spr;

    // SPR group decode (raw one-hot)
    wire [31:0] unqualified_cs;
    assign unqualified_cs = (1 << spr_addr[15:11]);
    assign spr_cs = {32{read_spr | write_spr}} & unqualified_cs;

    // System group internal selects (spr_cs[0] must be active)
    wire sys_cs;
    assign sys_cs = spr_cs[0];

    wire cfgr_sel, rf_sel;
    wire npc_sel, ppc_sel, sr_sel, epcr_sel, eear_sel, esr_sel;

    // Coarse selects
    assign cfgr_sel = sys_cs & (spr_addr[10:8] == 3'b000);
    assign rf_sel   = sys_cs & (spr_addr[10:8] == 3'b001);

    // Full address match selects
    assign npc_sel  = sys_cs & (spr_addr == 32'h0000_0010);
    assign ppc_sel  = sys_cs & (spr_addr == 32'h0000_0011);
    assign sr_sel   = sys_cs & (spr_addr == 32'h0000_0012);
    assign epcr_sel = sys_cs & (spr_addr == 32'h0000_0020);
    assign eear_sel = sys_cs & (spr_addr == 32'h0000_0030);
    assign esr_sel  = sys_cs & (spr_addr == 32'h0000_0040);

    // System write enables
    assign pc_we   = (npc_sel | ppc_sel) & write_spr;
    assign epcr_we = epcr_sel & write_spr;
    assign eear_we = eear_sel & write_spr;
    assign esr_we  = esr_sel & write_spr;

    // SR write enable
    wire rfe_op;
    assign rfe_op = (alu_op == 4'b1111); // RFE operation
    assign sr_we = (sr_sel & write_spr) | rfe_op | flag_we | cy_we;

    // to_sr combinational logic
    reg [15:0] to_sr;

    always @* begin
        // Default: preserve current value (sr will be connected)
        to_sr = sr;

        // Bits 15:11
        if (rfe_op)
            to_sr[15:11] = esr[15:11];
        else if (sr_sel & write_spr) begin
            to_sr[15]   = 1'b1;
            to_sr[14:11] = spr_dat_o[14:11];
        end

        // Carry bit 10
        if (rfe_op)
            to_sr[10] = esr[10];
        else if (cy_we)
            to_sr[10] = cyforw;
        else if (sr_sel & write_spr)
            to_sr[10] = spr_dat_o[10];

        // Flag bit 9
        if (rfe_op)
            to_sr[9] = esr[9];
        else if (flag_we)
            to_sr[9] = flagforw;
        else if (sr_sel & write_spr)
            to_sr[9] = spr_dat_o[9];

        // Bits 8:0
        if (rfe_op)
            to_sr[8:0] = esr[8:0];
        else if (sr_sel & write_spr)
            to_sr[8:0] = spr_dat_o[8:0];
    end

    // SR register
    reg [15:0] sr;
    always @(posedge clk or posedge rst) begin
        if (rst)
            sr <= 16'h8001; // supervisor mode, default prefix
        else if (except_started) begin
            sr[0] <= 1'b1;
            sr[1] <= 1'b0;
            sr[2] <= 1'b0;
            sr[5] <= 1'b0;
            sr[6] <= 1'b0;
        end else if (sr_we)
            sr <= to_sr;
    end

    // Exported flag/carry
    assign flag  = sr[9];
    assign carry = sr[10];

    // System read data mux
    wire [31:0] sys_data;
    assign sys_data = ({32{cfgr_sel & read_spr}} & spr_dat_cfgr) |
                      ({32{rf_sel   & read_spr}} & spr_dat_rf)   |
                      ({32{npc_sel  & read_spr}} & spr_dat_npc)  |
                      ({32{ppc_sel  & read_spr}} & spr_dat_ppc)  |
                      ({32{sr_sel   & read_spr}} & {16'h0000, sr}) |
                      ({32{epcr_sel & read_spr}} & epcr)         |
                      ({32{eear_sel & read_spr}} & eear)         |
                      ({32{esr_sel  & read_spr}} & {16'h0000, esr});

    // Group read data mux
    reg [31:0] to_wbmux;
    always @* begin
        if (read_spr) begin
            case (spr_addr[15:11])
                5'd0:  to_wbmux = sys_data;
                5'd1:  to_wbmux = spr_dat_tt;
                5'd2:  to_wbmux = spr_dat_pic;
                5'd3:  to_wbmux = spr_dat_pm;
                5'd4:  to_wbmux = spr_dat_dmmu;
                5'd5:  to_wbmux = spr_dat_immu;
                5'd6:  to_wbmux = spr_dat_mac;
                5'd16: to_wbmux = spr_dat_du;
                default: to_wbmux = 32'd0;
            endcase
        end else
            to_wbmux = 32'd0;
    end

    // Debug Unit return data
    assign du_dat_cpu = du_write ? du_dat_du :
                        du_read  ? to_wbmux :
                        dat_i;

endmodule

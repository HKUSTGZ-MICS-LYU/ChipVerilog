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
    localparam OR1200_ALUOP_MTSR = 4'd?;
    localparam OR1200_ALUOP_MFSR = 4'd?;
    localparam OR1200_ALUOP_RFE  = 4'd?;

    wire du_access;
    wire [3:0] sprs_op;
    wire write_spr, read_spr;
    wire [31:0] unqualified_cs;
    wire [31:0] sys_data;
    wire cfgr_sel, rf_sel, npc_sel, ppc_sel, sr_sel, epcr_sel, eear_sel, esr_sel;

    assign du_access = du_read | du_write;

    assign sprs_op = du_write ? OR1200_ALUOP_MTSR :
                     du_read  ? OR1200_ALUOP_MFSR :
                                alu_op;

    assign spr_addr = du_access ? du_addr :
                                  (addrbase | {16'h0000, addrofs});

    assign spr_dat_o = du_write ? du_dat_du : dat_i;

    assign write_spr = (sprs_op == OR1200_ALUOP_MTSR);
    assign read_spr  = (sprs_op == OR1200_ALUOP_MFSR);

    assign spr_we = du_write | write_spr;

    wire [31:0] decode_addr = spr_addr[15:11];
    assign unqualified_cs = (decode_addr == 5'd0)  ? 32'h00000001 :
                            (decode_addr == 5'd1)  ? 32'h00000002 :
                            (decode_addr == 5'd2)  ? 32'h00000004 :
                            (decode_addr == 5'd3)  ? 32'h00000008 :
                            (decode_addr == 5'd4)  ? 32'h00000010 :
                            (decode_addr == 5'd5)  ? 32'h00000020 :
                            (decode_addr == 5'd6)  ? 32'h00000040 :
                            (decode_addr == 5'd7)  ? 32'h00000080 :
                            (decode_addr == 5'd8)  ? 32'h00000100 :
                            (decode_addr == 5'd9)  ? 32'h00000200 :
                            (decode_addr == 5'd10) ? 32'h00000400 :
                            (decode_addr == 5'd11) ? 32'h00000800 :
                            (decode_addr == 5'd12) ? 32'h00001000 :
                            (decode_addr == 5'd13) ? 32'h00002000 :
                            (decode_addr == 5'd14) ? 32'h00004000 :
                            (decode_addr == 5'd15) ? 32'h00008000 :
                            (decode_addr == 5'd16) ? 32'h00010000 :
                            (decode_addr == 5'd17) ? 32'h00020000 :
                            (decode_addr == 5'd18) ? 32'h00040000 :
                            (decode_addr == 5'd19) ? 32'h00080000 :
                            (decode_addr == 5'd20) ? 32'h00100000 :
                            (decode_addr == 5'd21) ? 32'h00200000 :
                            (decode_addr == 5'd22) ? 32'h00400000 :
                            (decode_addr == 5'd23) ? 32'h00800000 :
                            (decode_addr == 5'd24) ? 32'h01000000 :
                            (decode_addr == 5'd25) ? 32'h02000000 :
                            (decode_addr == 5'd26) ? 32'h04000000 :
                            (decode_addr == 5'd27) ? 32'h08000000 :
                            (decode_addr == 5'd28) ? 32'h10000000 :
                            (decode_addr == 5'd29) ? 32'h20000000 :
                            (decode_addr == 5'd30) ? 32'h40000000 :
                            (decode_addr == 5'd31) ? 32'h80000000 :
                                                     32'h00000000;

    assign spr_cs = {32{read_spr | write_spr}} & unqualified_cs;

    assign cfgr_sel = spr_cs[0] & (spr_addr[10:0] >= 11'd0) & (spr_addr[10:0] < 11'd512);
    assign rf_sel   = spr_cs[0] & (spr_addr[10:0] >= 11'd1024);
    assign npc_sel  = spr_cs[0] & (spr_addr == 32'd16);
    assign ppc_sel  = spr_cs[0] & (spr_addr == 32'd18);
    assign sr_sel   = spr_cs[0] & (spr_addr == 32'd17);
    assign epcr_sel = spr_cs[0] & (spr_addr == 32'd32);
    assign eear_sel = spr_cs[0] & (spr_addr == 32'd48);
    assign esr_sel  = spr_cs[0] & (spr_addr == 32'd64);

    assign epcr_we = write_spr & epcr_sel;
    assign eear_we = write_spr & eear_sel;
    assign esr_we  = write_spr & esr_sel;
    assign pc_we   = write_spr & (npc_sel | ppc_sel);

    wire rfe_op = (sprs_op == OR1200_ALUOP_RFE);

    assign sr_we = write_spr & sr_sel | rfe_op | flag_we | cy_we;

    reg [15:0] sr_reg;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sr_reg <= 16'h8001;
        end else if (except_started) begin
            sr_reg[0] <= 1'b1;
            sr_reg[1] <= 1'b0;
            sr_reg[2] <= 1'b0;
            sr_reg[5] <= 1'b0;
            sr_reg[6] <= 1'b0;
        end else if (sr_we) begin
            sr_reg <= to_sr;
        end
    end
    assign sr = sr_reg;

    wire [15:0] mtsr_data = spr_dat_o[15:0];
    wire [15:0] to_sr_15_11 = rfe_op ? esr[15:11] :
                              write_spr & sr_sel ? {1'b1, mtsr_data[14:11]} :
                              sr[15:11];
    wire to_sr_10 = rfe_op ? esr[10] :
                    cy_we  ? cyforw :
                    write_spr & sr_sel ? mtsr_data[10] :
                    sr[10];
    wire to_sr_9 = rfe_op ? esr[9] :
                   flag_we ? flagforw :
                   write_spr & sr_sel ? mtsr_data[9] :
                   sr[9];
    wire [8:0] to_sr_8_0 = rfe_op ? esr[8:0] :
                          write_spr & sr_sel ? mtsr_data[8:0] :
                          sr[8:0];
    assign to_sr = {to_sr_15_11, to_sr_10, to_sr_9, to_sr_8_0};

    assign sys_data = ({32{cfgr_sel}} & spr_dat_cfgr) |
                      ({32{rf_sel}}   & spr_dat_rf)   |
                      ({32{npc_sel}}  & spr_dat_npc)  |
                      ({32{ppc_sel}}  & spr_dat_ppc)  |
                      ({32{sr_sel}}   & {16'h0000, sr}) |
                      ({32{epcr_sel}} & epcr)         |
                      ({32{eear_sel}} & eear)         |
                      ({32{esr_sel}}  & {16'h0000, esr});

    wire [31:0] group_data;
    assign group_data = (decode_addr == 5'd0)  ? sys_data :
                        (decode_addr == 5'd1)  ? spr_dat_mac :
                        (decode_addr == 5'd2)  ? spr_dat_dmmu :
                        (decode_addr == 5'd3)  ? spr_dat_immu :
                        (decode_addr == 5'd4)  ? spr_dat_pic :
                        (decode_addr == 5'd5)  ? spr_dat_tt :
                        (decode_addr == 5'd6)  ? spr_dat_pm :
                        (decode_addr == 5'd7)  ? spr_dat_du :
                        32'h00000000;

    assign to_wbmux = read_spr ? group_data : 32'h00000000;

    assign du_dat_cpu = du_write ? du_dat_du :
                        du_read  ? to_wbmux :
                        dat_i;

    assign flag  = sr[9];
    assign carry = sr[10];

endmodule

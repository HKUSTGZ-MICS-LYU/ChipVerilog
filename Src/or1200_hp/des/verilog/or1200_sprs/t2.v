`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_sprs (
    input         clk,
    input         rst,

    // CPU datapath
    input         flagforw,
    input         flag_we,
    output        flag,
    input         cyforw,
    input         cy_we,
    output        carry,
    input  [31:0] addrbase,
    input  [15:0] addrofs,
    input  [31:0] dat_i,
    input  [3:0]  alu_op,
    input  [2:0]  branch_op,
    input  [31:0] epcr,
    input  [31:0] eear,
    input  [15:0] esr,
    input         except_started,
    output [31:0] to_wbmux,
    output        epcr_we,
    output        eear_we,
    output        esr_we,
    output        pc_we,
    output        sr_we,
    output [15:0] to_sr,
    output [15:0] sr,
    input  [31:0] spr_dat_cfgr,
    input  [31:0] spr_dat_rf,
    input  [31:0] spr_dat_npc,
    input  [31:0] spr_dat_ppc,
    input  [31:0] spr_dat_mac,

    // Other units
    input  [31:0] spr_dat_pic,
    input  [31:0] spr_dat_tt,
    input  [31:0] spr_dat_pm,
    input  [31:0] spr_dat_dmmu,
    input  [31:0] spr_dat_immu,
    input  [31:0] spr_dat_du,
    output [31:0] spr_addr,
    output [31:0] spr_dat_o,
    output [31:0] spr_cs,
    output        spr_we,

    // Debug unit
    input  [31:0] du_addr,
    input  [31:0] du_dat_du,
    input         du_read,
    input         du_write,
    output [31:0] du_dat_cpu
);

    //--------------------------------------------------------------------------
    // Debug Unit access arbitration
    //--------------------------------------------------------------------------
    wire du_access = du_read | du_write;

    // Effective SPR operation: DU overrides CPU alu_op
    wire [3:0] sprs_op = du_write ? `OR1200_ALUOP_MTSR :
                         du_read  ? `OR1200_ALUOP_MFSR :
                                    alu_op;

    // SPR address: DU overrides CPU-formed address
    // CPU address: addrbase | {16'h0, addrofs}  (bitwise OR, not add)
    assign spr_addr = du_access ? du_addr : (addrbase | {16'h0000, addrofs});

    // SPR write data: DU overrides CPU data
    assign spr_dat_o = du_write ? du_dat_du : dat_i;

    //--------------------------------------------------------------------------
    // SPR operation decode
    //--------------------------------------------------------------------------
    wire write_spr = (sprs_op == `OR1200_ALUOP_MTSR);
    wire read_spr  = (sprs_op == `OR1200_ALUOP_MFSR);

    // RFE operation
    wire rfe = (branch_op == `OR1200_BRANCHOP_RFE);

    //--------------------------------------------------------------------------
    // SPR group one-hot decode from spr_addr[15:11]
    // Qualified by actual SPR read or write in progress
    //--------------------------------------------------------------------------
    reg [31:0] unqualified_cs;

    always @(*) begin
        unqualified_cs = 32'h0;
        unqualified_cs[spr_addr[15:11]] = 1'b1;
    end

    assign spr_cs = unqualified_cs & {32{read_spr | write_spr}};
    assign spr_we = du_write | write_spr;

    //--------------------------------------------------------------------------
    // System group (group 0) internal register select
    // All qualified by spr_cs[0]
    //--------------------------------------------------------------------------
    wire sys_cs = spr_cs[`OR1200_SPRGRP_SYS];

    wire cfgr_sel = sys_cs & (spr_addr[10:4] == `OR1200_SPR_CFGR);
    wire rf_sel   = sys_cs & (spr_addr[10:5] == `OR1200_SPR_RF);
    wire npc_sel  = sys_cs & (spr_addr[10:0] == `OR1200_SPR_NPC);
    wire ppc_sel  = sys_cs & (spr_addr[10:0] == `OR1200_SPR_PPC);
    wire sr_sel   = sys_cs & (spr_addr[10:0] == `OR1200_SPR_SR);
    wire epcr_sel = sys_cs & (spr_addr[10:0] == `OR1200_SPR_EPCR);
    wire eear_sel = sys_cs & (spr_addr[10:0] == `OR1200_SPR_EEAR);
    wire esr_sel  = sys_cs & (spr_addr[10:0] == `OR1200_SPR_ESR);

    //--------------------------------------------------------------------------
    // System-group write enables
    //--------------------------------------------------------------------------
    assign pc_we   = (npc_sel | ppc_sel) & write_spr;
    assign epcr_we = epcr_sel & write_spr;
    assign eear_we = eear_sel & write_spr;
    assign esr_we  = esr_sel  & write_spr;

    // SR write enable: MTSR to SR, RFE, flag update, carry update
    assign sr_we   = (sr_sel & write_spr) | rfe | flag_we | cy_we;

    //--------------------------------------------------------------------------
    // to_sr: next value for SR (combinational; exception_started handled in seq)
    //
    // SR bit layout (OR1200-specific, 16-bit):
    //   [15:11] DSX/EXR/EPH/DME/SME or similar upper control
    //   [10]    carry (CY)
    //   [9]     flag (F)
    //   [8:0]   SUMRA/IEE/TEE/DME/IME/ICE/DCE/SUPV/SM
    //--------------------------------------------------------------------------
    reg [15:0] to_sr_r;

    // Bits [15:11]
    always @(*) begin
        if (rfe)
            to_sr_r[15:11] = esr[15:11];
        else if (sr_sel & write_spr) begin
            to_sr_r[15]    = 1'b1;          // bit 15 forced to 1 on MTSR
            to_sr_r[14:11] = spr_dat_o[14:11];
        end else
            to_sr_r[15:11] = sr_r[15:11];
    end

    // Bit [10]: carry
    always @(*) begin
        if (rfe)
            to_sr_r[10] = esr[10];
        else if (cy_we)
            to_sr_r[10] = cyforw;
        else if (sr_sel & write_spr)
            to_sr_r[10] = spr_dat_o[10];
        else
            to_sr_r[10] = sr_r[10];
    end

    // Bit [9]: flag
    always @(*) begin
        if (rfe)
            to_sr_r[9] = esr[9];
        else if (flag_we)
            to_sr_r[9] = flagforw;
        else if (sr_sel & write_spr)
            to_sr_r[9] = spr_dat_o[9];
        else
            to_sr_r[9] = sr_r[9];
    end

    // Bits [8:0]
    always @(*) begin
        if (rfe)
            to_sr_r[8:0] = esr[8:0];
        else if (sr_sel & write_spr)
            to_sr_r[8:0] = spr_dat_o[8:0];
        else
            to_sr_r[8:0] = sr_r[8:0];
    end

    assign to_sr = to_sr_r;

    //--------------------------------------------------------------------------
    // SR register: sequential state, stored locally
    // Reset → architecture-defined default
    // except_started → highest priority: partial update
    // sr_we → ordinary update via to_sr
    //--------------------------------------------------------------------------
    reg [15:0] sr_r;

    assign sr    = sr_r;
    assign flag  = sr_r[9];
    assign carry = sr_r[10];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sr_r <= `OR1200_SR_DEF;
        end else if (except_started) begin
            // Exception entry: partial SR modification
            // Set supervisor mode, clear IEE/TEE/DME/IME
            sr_r[0]   <= 1'b1;  // supervisor mode
            sr_r[2]   <= 1'b0;  // IEE = 0
            sr_r[1]   <= 1'b0;  // TEE = 0
            sr_r[5]   <= 1'b0;  // DME = 0
            sr_r[6]   <= 1'b0;  // IME = 0
        end else if (sr_we) begin
            sr_r <= to_sr_r;
        end
    end

    //--------------------------------------------------------------------------
    // System-group read data: mask-and-OR approach
    //--------------------------------------------------------------------------
    wire [31:0] sys_data =
        ({32{cfgr_sel}} & spr_dat_cfgr)         |
        ({32{rf_sel}}   & spr_dat_rf)            |
        ({32{npc_sel}}  & spr_dat_npc)           |
        ({32{ppc_sel}}  & spr_dat_ppc)           |
        ({32{sr_sel}}   & {16'h0000, sr_r})      |
        ({32{epcr_sel}} & epcr)                  |
        ({32{eear_sel}} & eear)                  |
        ({32{esr_sel}}  & {16'h0000, esr});

    //--------------------------------------------------------------------------
    // to_wbmux: SPR read result for write-back mux
    // Only valid when read_spr; zero for write_spr and other ops
    //--------------------------------------------------------------------------
    reg [31:0] to_wbmux_r;

    always @(*) begin
        if (write_spr) begin
            to_wbmux_r = 32'h0;
        end else if (read_spr) begin
            case (spr_addr[15:11])
                `OR1200_SPRGRP_TT:   to_wbmux_r = spr_dat_tt;
                `OR1200_SPRGRP_PIC:  to_wbmux_r = spr_dat_pic;
                `OR1200_SPRGRP_PM:   to_wbmux_r = spr_dat_pm;
                `OR1200_SPRGRP_DMMU: to_wbmux_r = spr_dat_dmmu;
                `OR1200_SPRGRP_IMMU: to_wbmux_r = spr_dat_immu;
                `OR1200_SPRGRP_MAC:  to_wbmux_r = spr_dat_mac;
                `OR1200_SPRGRP_DU:   to_wbmux_r = spr_dat_du;
                `OR1200_SPRGRP_SYS:  to_wbmux_r = sys_data;
                default:             to_wbmux_r = 32'h0;
            endcase
        end else begin
            to_wbmux_r = 32'h0;
        end
    end

    assign to_wbmux = to_wbmux_r;

    //--------------------------------------------------------------------------
    // du_dat_cpu: DU read data path
    // du_write → echo du_dat_du
    // du_read  → return to_wbmux (same as ordinary SPR read path)
    // otherwise → dat_i
    //--------------------------------------------------------------------------
    assign du_dat_cpu = du_write ? du_dat_du :
                        du_read  ? to_wbmux_r :
                                   dat_i;

endmodule
// or1200_cfgr.v - OR1200 Configuration Registers (Read-Only SPRs)
// Assembly from compile-time constants, combinational decode.

module or1200_cfgr (
    input  [31:0] spr_addr,
    output [31:0] spr_dat_o
);

    reg [31:0] spr_dat_o;

    // Internal address decode
    wire [3:0] addr = spr_addr[3:0];

    // Local enable after optional full decode
    wire enable;
`ifdef OR1200_SYS_FULL_DECODE
    assign enable = (spr_addr[31:4] == 28'h0000000);
`else
    assign enable = 1'b1;
`endif

`ifdef OR1200_CFGR_IMPLEMENTED
    // ---------------- Full CFGR implementation ----------------
    // Assemble VR
    wire [31:0] vr = {OR1200_VR_VER, OR1200_VR_CFG, OR1200_VR_RES1, OR1200_VR_REV};

    // Assemble UPR
    wire [31:0] upr = {OR1200_UPR_UP, OR1200_UPR_DCP, OR1200_UPR_ICP,
                       OR1200_UPR_DMP, OR1200_UPR_IMP, OR1200_UPR_MP,
                       OR1200_UPR_DUP, OR1200_UPR_PCUP, OR1200_UPR_PMP,
                       OR1200_UPR_PICP, OR1200_UPR_TTP, OR1200_UPR_CUP,
                       OR1200_UPR_RES1};

    // Assemble CPUCFGR
    wire [31:0] cpucfgr = {OR1200_CPUCFGR_OV, OR1200_CPUCFGR_OF32S,
                           OR1200_CPUCFGR_OFP, OR1200_CPUCFGR_OV64P,
                           OR1200_CPUCFGR_RES1, OR1200_CPUCFGR_ND,
                           OR1200_CPUCFGR_NSGF, OR1200_CPUCFGR_CGF,
                           OR1200_CPUCFGR_OB64P, OR1200_CPUCFGR_OB32P,
                           OR1200_CPUCFGR_OBJP, OR1200_CPUCFGR_OBEP,
                           OR1200_CPUCFGR_OP32P, OR1200_CPUCFGR_RES2,
                           OR1200_CPUCFGR_NSGR, OR1200_CPUCFGR_CGR,
                           OR1200_CPUCFGR_OB32S, OR1200_CPUCFGR_OB64S,
                           OR1200_CPUCFGR_OP32S, OR1200_CPUCFGR_OP64S,
                           OR1200_CPUCFGR_PS, OR1200_CPUCFGR_RES3};

    // Assemble DMMUCFGR
    wire [31:0] dmmucfgr = {OR1200_DMMUCFGR_HTW, OR1200_DMMUCFGR_RES1,
                            OR1200_DMMUCFGR_PNTR, OR1200_DMMUCFGR_CRI,
                            OR1200_DMMUCFGR_PRI, OR1200_DMMUCFGR_TEIRI,
                            OR1200_DMMUCFGR_RES2, OR1200_DMMUCFGR_NTS,
                            OR1200_DMMUCFGR_RES3, OR1200_DMMUCFGR_NTW,
                            OR1200_DMMUCFGR_RES4, OR1200_DMMUCFGR_NTR,
                            OR1200_DMMUCFGR_RES5, OR1200_DMMUCFGR_NTE,
                            OR1200_DMMUCFGR_RES6};

    // Assemble IMMUCFGR
    wire [31:0] immucfgr = {OR1200_IMMUCFGR_HTW, OR1200_IMMUCFGR_RES1,
                            OR1200_IMMUCFGR_PNTR, OR1200_IMMUCFGR_CRI,
                            OR1200_IMMUCFGR_PRI, OR1200_IMMUCFGR_TEIRI,
                            OR1200_IMMUCFGR_RES2, OR1200_IMMUCFGR_NTS,
                            OR1200_IMMUCFGR_RES3, OR1200_IMMUCFGR_NTW,
                            OR1200_IMMUCFGR_RES4, OR1200_IMMUCFGR_NTR,
                            OR1200_IMMUCFGR_RES5, OR1200_IMMUCFGR_NTE,
                            OR1200_IMMUCFGR_RES6};

    // Assemble DCCFGR
    wire [31:0] dccfgr = {OR1200_DCCFGR_CP, OR1200_DCCFGR_CCS,
                          OR1200_DCCFGR_CBS, OR1200_DCCFGR_CWS,
                          OR1200_DCCFGR_CPS, OR1200_DCCFGR_CSS,
                          OR1200_DCCFGR_CKS, OR1200_DCCFGR_CBS,
                          OR1200_DCCFGR_CWS, OR1200_DCCFGR_RES1,
                          OR1200_DCCFGR_CS, OR1200_DCCFGR_CLS,
                          OR1200_DCCFGR_CR, OR1200_DCCFGR_CW,
                          OR1200_DCCFGR_CPISA, OR1200_DCCFGR_RES2};

    // Assemble ICCFGR
    wire [31:0] iccfgr = {OR1200_ICCFGR_CP, OR1200_ICCFGR_CCS,
                          OR1200_ICCFGR_CBS, OR1200_ICCFGR_CWS,
                          OR1200_ICCFGR_CPS, OR1200_ICCFGR_CSS,
                          OR1200_ICCFGR_CKS, OR1200_ICCFGR_CBS,
                          OR1200_ICCFGR_CWS, OR1200_ICCFGR_RES1,
                          OR1200_ICCFGR_CS, OR1200_ICCFGR_CLS,
                          OR1200_ICCFGR_CR, OR1200_ICCFGR_CW,
                          OR1200_ICCFGR_CPISA, OR1200_ICCFGR_RES2};

    // Assemble DCFGR
    wire [31:0] dcfgr = {OR1200_DCFGR_NDP, OR1200_DCFGR_DPI,
                         OR1200_DCFGR_RES1, OR1200_DCFGR_NDWT,
                         OR1200_DCFGR_RES2, OR1200_DCFGR_WPCI,
                         OR1200_DCFGR_RES3};

    // Address decode table for all 16 possible nibble values
    always @(spr_addr) begin
        if (!enable) begin
            spr_dat_o = 32'h00000000;
        end else begin
            case (addr)
                4'h0: spr_dat_o = vr;
                4'h1: spr_dat_o = upr;
                4'h2: spr_dat_o = cpucfgr;
                4'h3: spr_dat_o = dmmucfgr;
                4'h4: spr_dat_o = immucfgr;
                4'h5: spr_dat_o = dccfgr;
                4'h6: spr_dat_o = iccfgr;
                4'h7: spr_dat_o = dcfgr;
                default: spr_dat_o = 32'h00000000;
            endcase
        end
    end

`else
    // ---------------- Minimal VR/UPR implementation ----------------
    // Assemble VR
    wire [31:0] vr = {OR1200_VR_VER, OR1200_VR_CFG, OR1200_VR_RES1, OR1200_VR_REV};

    // Assemble UPR
    wire [31:0] upr = {OR1200_UPR_UP, OR1200_UPR_DCP, OR1200_UPR_ICP,
                       OR1200_UPR_DMP, OR1200_UPR_IMP, OR1200_UPR_MP,
                       OR1200_UPR_DUP, OR1200_UPR_PCUP, OR1200_UPR_PMP,
                       OR1200_UPR_PICP, OR1200_UPR_TTP, OR1200_UPR_CUP,
                       OR1200_UPR_RES1};

    always @(spr_addr) begin
        if (!enable) begin
            spr_dat_o = 32'h00000000;
        end else begin
            case (addr)
                4'h0: spr_dat_o = vr;
                4'h1: spr_dat_o = upr;
                default: spr_dat_o = 32'h00000000;
            endcase
        end
    end

`endif

endmodule

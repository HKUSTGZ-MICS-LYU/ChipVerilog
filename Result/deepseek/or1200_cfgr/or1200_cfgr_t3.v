module or1200_cfgr(
    input  [31:0] spr_addr,
    output [31:0] spr_dat_o
);

reg [31:0] spr_dat_o;

always @(*) begin
    // Default output is 0
    spr_dat_o = 32'h0000_0000;
    
`ifdef OR1200_SYS_FULL_DECODE
    // Full decode: only respond when spr_addr[31:4] is all zero
    if (spr_addr[31:4] == 28'h0) begin
`endif
        // Address bits [3:0] select the register
        case (spr_addr[3:0])
`ifdef OR1200_CFGR_IMPLEMENTED
            4'h0: spr_dat_o = {OR1200_VR_REV, OR1200_VR_RES1, OR1200_VR_CFG, OR1200_VR_VER};
            4'h1: spr_dat_o = {OR1200_UPR_UP, OR1200_UPR_DCP, OR1200_UPR_ICP, OR1200_UPR_DMP,
                               OR1200_UPR_IMP, OR1200_UPR_MP, OR1200_UPR_DUP, OR1200_UPR_PCUP,
                               OR1200_UPR_PMP, OR1200_UPR_PICP, OR1200_UPR_TTP, OR1200_UPR_CUP,
                               OR1200_UPR_RES};
            4'h2: spr_dat_o = {OR1200_CPUCFGR_ND, OR1200_CPUCFGR_RES, OR1200_CPUCFGR_NSA, OR1200_CPUCFGR_SPR_FP,
                               OR1200_CPUCFGR_OB32S, OR1200_CPUCFGR_OB64S, OR1200_CPUCFGR_OB64D,
                               OR1200_CPUCFGR_RES1, OR1200_CPUCFGR_RFR, OR1200_CPUCFGR_RES2,
                               OR1200_CPUCFGR_AVR, OR1200_CPUCFGR_RES3, OR1200_CPUCFGR_CGR,
                               OR1200_CPUCFGR_RES4};
            4'h3: spr_dat_o = {OR1200_DMMUCFGR_NTW, OR1200_DMMUCFGR_NAE, OR1200_DMMUCFGR_CRI, OR1200_DMMUCFGR_RES};
            4'h4: spr_dat_o = {OR1200_IMMUCFGR_NTW, OR1200_IMMUCFGR_NAE, OR1200_IMMUCFGR_CRI, OR1200_IMMUCFGR_RES};
            4'h5: spr_dat_o = {OR1200_DCCFGR_NCW, OR1200_DCCFGR_NCA, OR1200_DCCFGR_NCB, OR1200_DCCFGR_CREP,
                               OR1200_DCCFGR_CREP_RES, OR1200_DCCFGR_RES};
            4'h6: spr_dat_o = {OR1200_ICCFGR_NCW, OR1200_ICCFGR_NCA, OR1200_ICCFGR_NCB, OR1200_ICCFGR_CREP,
                               OR1200_ICCFGR_CREP_RES, OR1200_ICCFGR_RES};
            4'h7: spr_dat_o = {OR1200_DCFGR_NDP, OR1200_DCFGR_NDBS, OR1200_DCFGR_NJ, OR1200_DCFGR_NPON,
                               OR1200_DCFGR_RES};
`else
            // Fallback: only VR and UPR
            4'h0: spr_dat_o = {OR1200_VR_REV, OR1200_VR_RES1, OR1200_VR_CFG, OR1200_VR_VER};
            4'h1: spr_dat_o = {OR1200_UPR_UP, OR1200_UPR_DCP, OR1200_UPR_ICP, OR1200_UPR_DMP,
                               OR1200_UPR_IMP, OR1200_UPR_MP, OR1200_UPR_DUP, OR1200_UPR_PCUP,
                               OR1200_UPR_PMP, OR1200_UPR_PICP, OR1200_UPR_TTP, OR1200_UPR_CUP,
                               OR1200_UPR_RES};
            default: spr_dat_o = 32'h0000_0000;
`endif
        endcase
`ifdef OR1200_SYS_FULL_DECODE
    end
`endif
end

endmodule

`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_cfgr (
    input  [31:0] spr_addr,
    output [31:0] spr_dat_o
);

    reg [31:0] spr_dat_o;

    always @(spr_addr) begin
`ifdef OR1200_SYS_FULL_DECODE
        if (spr_addr[31:4] == 28'h0000000) begin
`endif

`ifdef OR1200_CFGR_IMPLEMENTED
            casex (spr_addr[3:0])
                // VR - Version Register
                4'h0: spr_dat_o = {
                    `OR1200_VR_VER,
                    `OR1200_VR_CFG,
                    `OR1200_VR_RES1,
                    `OR1200_VR_REV
                };
                // UPR - Unit Present Register
                4'h1: spr_dat_o = {
                    `OR1200_UPR_RES1,
                    `OR1200_UPR_CUP,
                    `OR1200_UPR_TTP,
                    `OR1200_UPR_PICP,
                    `OR1200_UPR_PMP,
                    `OR1200_UPR_PCUP,
                    `OR1200_UPR_DUP,
                    `OR1200_UPR_MP,
                    `OR1200_UPR_IMP,
                    `OR1200_UPR_DMP,
                    `OR1200_UPR_ICP,
                    `OR1200_UPR_DCP,
                    `OR1200_UPR_UP
                };
                // CPUCFGR - CPU Configuration Register
                4'h2: spr_dat_o = {
                    `OR1200_CPUCFGR_RES1,
                    `OR1200_CPUCFGR_NSGF,
                    `OR1200_CPUCFGR_CGF,
                    `OR1200_CPUCFGR_OB32S,
                    `OR1200_CPUCFGR_OB64S,
                    `OR1200_CPUCFGR_OF32S,
                    `OR1200_CPUCFGR_OF64S,
                    `OR1200_CPUCFGR_OV64S
                };
                // DMMUCFGR - Data MMU Configuration Register
                4'h3: spr_dat_o = {
                    `OR1200_DMMUCFGR_RES1,
                    `OR1200_DMMUCFGR_HTR,
                    `OR1200_DMMUCFGR_TEBITW,
                    `OR1200_DMMUCFGR_NTWS,
                    `OR1200_DMMUCFGR_NTS
                };
                // IMMUCFGR - Instruction MMU Configuration Register
                4'h4: spr_dat_o = {
                    `OR1200_IMMUCFGR_RES1,
                    `OR1200_IMMUCFGR_HTR,
                    `OR1200_IMMUCFGR_TEBITW,
                    `OR1200_IMMUCFGR_NTWS,
                    `OR1200_IMMUCFGR_NTS
                };
                // DCCFGR - Data Cache Configuration Register
                4'h5: spr_dat_o = {
                    `OR1200_DCCFGR_RES1,
                    `OR1200_DCCFGR_CWS,
                    `OR1200_DCCFGR_CCRI,
                    `OR1200_DCCFGR_CBIRI,
                    `OR1200_DCCFGR_CBPRI,
                    `OR1200_DCCFGR_CBLRI,
                    `OR1200_DCCFGR_CBWBRI,
                    `OR1200_DCCFGR_CBFRI,
                    `OR1200_DCCFGR_NCW,
                    `OR1200_DCCFGR_NCS,
                    `OR1200_DCCFGR_CBS
                };
                // ICCFGR - Instruction Cache Configuration Register
                4'h6: spr_dat_o = {
                    `OR1200_ICCFGR_RES1,
                    `OR1200_ICCFGR_CWS,
                    `OR1200_ICCFGR_CCRI,
                    `OR1200_ICCFGR_CBIRI,
                    `OR1200_ICCFGR_CBPRI,
                    `OR1200_ICCFGR_CBLRI,
                    `OR1200_ICCFGR_CBWBRI,
                    `OR1200_ICCFGR_CBFRI,
                    `OR1200_ICCFGR_NCW,
                    `OR1200_ICCFGR_NCS,
                    `OR1200_ICCFGR_CBS
                };
                // DCFGR - Debug Configuration Register
                4'h7: spr_dat_o = {
                    `OR1200_DCFGR_RES1,
                    `OR1200_DCFGR_WPCI,
                    `OR1200_DCFGR_NDP,
                    `OR1200_DCFGR_NWP
                };
                default: spr_dat_o = 32'h0000_0000;
            endcase
`else
            // OR1200_CFGR_IMPLEMENTED not defined: only VR and UPR
            casex (spr_addr[3:0])
                // VR - Version Register
                4'h0: spr_dat_o = {
                    `OR1200_VR_VER,
                    `OR1200_VR_CFG,
                    `OR1200_VR_RES1,
                    `OR1200_VR_REV
                };
                // UPR - Unit Present Register
                4'h1: spr_dat_o = {
                    `OR1200_UPR_RES1,
                    `OR1200_UPR_CUP,
                    `OR1200_UPR_TTP,
                    `OR1200_UPR_PICP,
                    `OR1200_UPR_PMP,
                    `OR1200_UPR_PCUP,
                    `OR1200_UPR_DUP,
                    `OR1200_UPR_MP,
                    `OR1200_UPR_IMP,
                    `OR1200_UPR_DMP,
                    `OR1200_UPR_ICP,
                    `OR1200_UPR_DCP,
                    `OR1200_UPR_UP
                };
                default: spr_dat_o = 32'h0000_0000;
            endcase
`endif

`ifdef OR1200_SYS_FULL_DECODE
        end else begin
            spr_dat_o = 32'h0000_0000;
        end
`endif
    end

endmodule
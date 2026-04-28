`include "timescale.v"
`include "or1200_defines.v"

module or1200_cfgr(
    spr_addr,
    spr_dat_o
);

input  [31:0] spr_addr;
output [31:0] spr_dat_o;

reg [31:0] spr_dat_o;

always @(spr_addr) begin
`ifdef OR1200_SYS_FULL_DECODE
    if (spr_addr[31:4] != 28'h0000000) begin
        spr_dat_o = 32'h0000_0000;
    end else
`endif
    case (spr_addr[3:0])

`ifdef OR1200_CFGR_IMPLEMENTED

        `OR1200_SPRGRP_SYS_VR: begin
            spr_dat_o = {
                `OR1200_VR_REV,
                `OR1200_VR_RES1,
                `OR1200_VR_CFG,
                `OR1200_VR_VER
            };
        end

        `OR1200_SPRGRP_SYS_UPR: begin
            spr_dat_o = {
                `OR1200_UPR_CUP,
                `OR1200_UPR_RES1,
                `OR1200_UPR_TTP,
                `OR1200_UPR_PMP,
                `OR1200_UPR_PICP,
                `OR1200_UPR_DUP,
                `OR1200_UPR_PCUP,
                `OR1200_UPR_MP,
                `OR1200_UPR_IMP,
                `OR1200_UPR_DMP,
                `OR1200_UPR_ICP,
                `OR1200_UPR_DCP,
                `OR1200_UPR_UP
            };
        end

        `OR1200_SPRGRP_SYS_CPUCFGR: begin
            spr_dat_o = {
                `OR1200_CPUCFGR_RES1,
                `OR1200_CPUCFGR_NSGF,
                `OR1200_CPUCFGR_CGF,
                `OR1200_CPUCFGR_OB32S,
                `OR1200_CPUCFGR_OB64S,
                `OR1200_CPUCFGR_OF32S,
                `OR1200_CPUCFGR_OF64S,
                `OR1200_CPUCFGR_OV64S
            };
        end

        `OR1200_SPRGRP_SYS_DMMUCFGR: begin
            spr_dat_o = {
                `OR1200_DMMUCFGR_RES1,
                `OR1200_DMMUCFGR_HTW,
                `OR1200_DMMUCFGR_TEIRI,
                `OR1200_DMMUCFGR_HTWI,
                `OR1200_DMMUCFGR_NTW,
                `OR1200_DMMUCFGR_NTS
            };
        end

        `OR1200_SPRGRP_SYS_IMMUCFGR: begin
            spr_dat_o = {
                `OR1200_IMMUCFGR_RES1,
                `OR1200_IMMUCFGR_HTW,
                `OR1200_IMMUCFGR_TEIRI,
                `OR1200_IMMUCFGR_HTWI,
                `OR1200_IMMUCFGR_NTW,
                `OR1200_IMMUCFGR_NTS
            };
        end

        `OR1200_SPRGRP_SYS_DCCFGR: begin
            spr_dat_o = {
                `OR1200_DCCFGR_RES1,
                `OR1200_DCCFGR_CBWBRI,
                `OR1200_DCCFGR_CBFRI,
                `OR1200_DCCFGR_CBLRI,
                `OR1200_DCCFGR_CBPRI,
                `OR1200_DCCFGR_CBIRI,
                `OR1200_DCCFGR_CCRI,
                `OR1200_DCCFGR_CWS,
                `OR1200_DCCFGR_CBS,
                `OR1200_DCCFGR_NCS
            };
        end

        `OR1200_SPRGRP_SYS_ICCFGR: begin
            spr_dat_o = {
                `OR1200_ICCFGR_RES1,
                `OR1200_ICCFGR_CBWBRI,
                `OR1200_ICCFGR_CBFRI,
                `OR1200_ICCFGR_CBLRI,
                `OR1200_ICCFGR_CBPRI,
                `OR1200_ICCFGR_CBIRI,
                `OR1200_ICCFGR_CCRI,
                `OR1200_ICCFGR_CWS,
                `OR1200_ICCFGR_CBS,
                `OR1200_ICCFGR_NCS
            };
        end

        `OR1200_SPRGRP_SYS_DCFGR: begin
            spr_dat_o = {
                `OR1200_DCFGR_RES1,
                `OR1200_DCFGR_WPCI,
                `OR1200_DCFGR_NDP
            };
        end

        default: spr_dat_o = 32'h0000_0000;

`else // !OR1200_CFGR_IMPLEMENTED

        `OR1200_SPRGRP_SYS_VR: begin
            spr_dat_o = {
                `OR1200_VR_REV,
                `OR1200_VR_RES1,
                `OR1200_VR_CFG,
                `OR1200_VR_VER
            };
        end

        `OR1200_SPRGRP_SYS_UPR: begin
            spr_dat_o = {
                `OR1200_UPR_CUP,
                `OR1200_UPR_RES1,
                `OR1200_UPR_TTP,
                `OR1200_UPR_PMP,
                `OR1200_UPR_PICP,
                `OR1200_UPR_DUP,
                `OR1200_UPR_PCUP,
                `OR1200_UPR_MP,
                `OR1200_UPR_IMP,
                `OR1200_UPR_DMP,
                `OR1200_UPR_ICP,
                `OR1200_UPR_DCP,
                `OR1200_UPR_UP
            };
        end

        default: spr_dat_o = 32'h0000_0000;

`endif // OR1200_CFGR_IMPLEMENTED

    endcase
end

endmodule
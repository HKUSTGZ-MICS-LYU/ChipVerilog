`timescale 1ns/1ps
`include "or1200_defines.v"
module or1200_cfgr(
    input [31:0] spr_addr,
    output reg [31:0] spr_dat_o
);
    wire sys_hit =
`ifdef OR1200_SYS_FULL_DECODE
        (spr_addr[31:4] == 28'd0);
`else
        1'b1;
`endif
    always @* begin
        spr_dat_o = 32'd0;
        if (sys_hit) begin
            case (spr_addr[3:0])
                `OR1200_SPRGRP_SYS_VR: begin
                    spr_dat_o[`OR1200_VR_REV_BITS]  = `OR1200_VR_REV;
                    spr_dat_o[`OR1200_VR_RES1_BITS] = `OR1200_VR_RES1;
                    spr_dat_o[`OR1200_VR_CFG_BITS]  = `OR1200_VR_CFG;
                    spr_dat_o[`OR1200_VR_VER_BITS]  = `OR1200_VR_VER;
                end
                `OR1200_SPRGRP_SYS_UPR: begin
                    spr_dat_o[`OR1200_UPR_UP_BITS]   = `OR1200_UPR_UP;
                    spr_dat_o[`OR1200_UPR_DCP_BITS]  = `OR1200_UPR_DCP;
                    spr_dat_o[`OR1200_UPR_ICP_BITS]  = `OR1200_UPR_ICP;
                    spr_dat_o[`OR1200_UPR_DMP_BITS]  = `OR1200_UPR_DMP;
                    spr_dat_o[`OR1200_UPR_IMP_BITS]  = `OR1200_UPR_IMP;
                    spr_dat_o[`OR1200_UPR_MP_BITS]   = `OR1200_UPR_MP;
                    spr_dat_o[`OR1200_UPR_DUP_BITS]  = `OR1200_UPR_DUP;
                    spr_dat_o[`OR1200_UPR_PCUP_BITS] = `OR1200_UPR_PCUP;
                    spr_dat_o[`OR1200_UPR_PMP_BITS]  = `OR1200_UPR_PMP;
                    spr_dat_o[`OR1200_UPR_PICP_BITS] = `OR1200_UPR_PICP;
                    spr_dat_o[`OR1200_UPR_TTP_BITS]  = `OR1200_UPR_TTP;
                    spr_dat_o[`OR1200_UPR_RES1_BITS] = `OR1200_UPR_RES1;
                    spr_dat_o[`OR1200_UPR_CUP_BITS]  = `OR1200_UPR_CUP;
                end
`ifdef OR1200_CFGR_IMPLEMENTED
                `OR1200_SPRGRP_SYS_CPUCFGR: begin
                    spr_dat_o[`OR1200_CPUCFGR_NSGF_BITS] = `OR1200_CPUCFGR_NSGF;
                    spr_dat_o[`OR1200_CPUCFGR_HGF_BITS]  = `OR1200_CPUCFGR_HGF;
                    spr_dat_o[`OR1200_CPUCFGR_OB32S_BITS]= `OR1200_CPUCFGR_OB32S;
                    spr_dat_o[`OR1200_CPUCFGR_OB64S_BITS]= `OR1200_CPUCFGR_OB64S;
                    spr_dat_o[`OR1200_CPUCFGR_OF32S_BITS]= `OR1200_CPUCFGR_OF32S;
                    spr_dat_o[`OR1200_CPUCFGR_OF64S_BITS]= `OR1200_CPUCFGR_OF64S;
                    spr_dat_o[`OR1200_CPUCFGR_OV64S_BITS]= `OR1200_CPUCFGR_OV64S;
                    spr_dat_o[`OR1200_CPUCFGR_RES1_BITS] = `OR1200_CPUCFGR_RES1;
                end
                `OR1200_SPRGRP_SYS_DMMUCFGR: begin
                    spr_dat_o[`OR1200_DMMUCFGR_NTW_BITS]=`OR1200_DMMUCFGR_NTW; spr_dat_o[`OR1200_DMMUCFGR_NTS_BITS]=`OR1200_DMMUCFGR_NTS;
                    spr_dat_o[`OR1200_DMMUCFGR_NAE_BITS]=`OR1200_DMMUCFGR_NAE; spr_dat_o[`OR1200_DMMUCFGR_CRI_BITS]=`OR1200_DMMUCFGR_CRI;
                    spr_dat_o[`OR1200_DMMUCFGR_PRI_BITS]=`OR1200_DMMUCFGR_PRI; spr_dat_o[`OR1200_DMMUCFGR_TEIRI_BITS]=`OR1200_DMMUCFGR_TEIRI;
                    spr_dat_o[`OR1200_DMMUCFGR_HTR_BITS]=`OR1200_DMMUCFGR_HTR; spr_dat_o[`OR1200_DMMUCFGR_RES1_BITS]=`OR1200_DMMUCFGR_RES1;
                end
                `OR1200_SPRGRP_SYS_IMMUCFGR: begin
                    spr_dat_o[`OR1200_IMMUCFGR_NTW_BITS]=`OR1200_IMMUCFGR_NTW; spr_dat_o[`OR1200_IMMUCFGR_NTS_BITS]=`OR1200_IMMUCFGR_NTS;
                    spr_dat_o[`OR1200_IMMUCFGR_NAE_BITS]=`OR1200_IMMUCFGR_NAE; spr_dat_o[`OR1200_IMMUCFGR_CRI_BITS]=`OR1200_IMMUCFGR_CRI;
                    spr_dat_o[`OR1200_IMMUCFGR_PRI_BITS]=`OR1200_IMMUCFGR_PRI; spr_dat_o[`OR1200_IMMUCFGR_TEIRI_BITS]=`OR1200_IMMUCFGR_TEIRI;
                    spr_dat_o[`OR1200_IMMUCFGR_HTR_BITS]=`OR1200_IMMUCFGR_HTR; spr_dat_o[`OR1200_IMMUCFGR_RES1_BITS]=`OR1200_IMMUCFGR_RES1;
                end
                `OR1200_SPRGRP_SYS_DCCFGR: begin
                    spr_dat_o[`OR1200_DCCFGR_NCW_BITS]=`OR1200_DCCFGR_NCW; spr_dat_o[`OR1200_DCCFGR_NCS_BITS]=`OR1200_DCCFGR_NCS;
                    spr_dat_o[`OR1200_DCCFGR_CBS_BITS]=`OR1200_DCCFGR_CBS; spr_dat_o[`OR1200_DCCFGR_CWS_BITS]=`OR1200_DCCFGR_CWS;
                    spr_dat_o[`OR1200_DCCFGR_CCRI_BITS]=`OR1200_DCCFGR_CCRI; spr_dat_o[`OR1200_DCCFGR_CBIRI_BITS]=`OR1200_DCCFGR_CBIRI;
                    spr_dat_o[`OR1200_DCCFGR_CBPRI_BITS]=`OR1200_DCCFGR_CBPRI; spr_dat_o[`OR1200_DCCFGR_CBLRI_BITS]=`OR1200_DCCFGR_CBLRI;
                    spr_dat_o[`OR1200_DCCFGR_CBFRI_BITS]=`OR1200_DCCFGR_CBFRI; spr_dat_o[`OR1200_DCCFGR_CBWBRI_BITS]=`OR1200_DCCFGR_CBWBRI;
                    spr_dat_o[`OR1200_DCCFGR_RES1_BITS]=`OR1200_DCCFGR_RES1;
                end
                `OR1200_SPRGRP_SYS_ICCFGR: begin
                    spr_dat_o[`OR1200_ICCFGR_NCW_BITS]=`OR1200_ICCFGR_NCW; spr_dat_o[`OR1200_ICCFGR_NCS_BITS]=`OR1200_ICCFGR_NCS;
                    spr_dat_o[`OR1200_ICCFGR_CBS_BITS]=`OR1200_ICCFGR_CBS; spr_dat_o[`OR1200_ICCFGR_CWS_BITS]=`OR1200_ICCFGR_CWS;
                    spr_dat_o[`OR1200_ICCFGR_CCRI_BITS]=`OR1200_ICCFGR_CCRI; spr_dat_o[`OR1200_ICCFGR_CBIRI_BITS]=`OR1200_ICCFGR_CBIRI;
                    spr_dat_o[`OR1200_ICCFGR_CBPRI_BITS]=`OR1200_ICCFGR_CBPRI; spr_dat_o[`OR1200_ICCFGR_CBLRI_BITS]=`OR1200_ICCFGR_CBLRI;
                    spr_dat_o[`OR1200_ICCFGR_CBFRI_BITS]=`OR1200_ICCFGR_CBFRI; spr_dat_o[`OR1200_ICCFGR_CBWBRI_BITS]=`OR1200_ICCFGR_CBWBRI;
                    spr_dat_o[`OR1200_ICCFGR_RES1_BITS]=`OR1200_ICCFGR_RES1;
                end
                `OR1200_SPRGRP_SYS_DCFGR: begin
                    spr_dat_o[`OR1200_DCFGR_NDP_BITS]=`OR1200_DCFGR_NDP;
                    spr_dat_o[`OR1200_DCFGR_WPCI_BITS]=`OR1200_DCFGR_WPCI;
                    spr_dat_o[`OR1200_DCFGR_RES1_BITS]=`OR1200_DCFGR_RES1;
                end
`endif
                default: spr_dat_o = 32'd0;
            endcase
        end
    end
endmodule

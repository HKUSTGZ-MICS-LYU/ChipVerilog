`include "timescale.v"
`include "or1200_defines.v"

module or1200_cfgr(
    spr_addr,
    spr_dat_o
);

input  [31:0] spr_addr;
output [31:0] spr_dat_o;

reg [31:0] spr_dat_o;

`ifdef OR1200_CFGR_IMPLEMENTED

always @(spr_addr)
`ifdef OR1200_SYS_FULL_DECODE
    if (~|spr_addr[31:4])
`endif
        case (spr_addr[3:0])
            `OR1200_SPRGRP_SYS_VR: begin
                spr_dat_o[5:0]   = `OR1200_VR_REV;
                spr_dat_o[15:6]  = `OR1200_VR_RES1;
                spr_dat_o[23:16] = `OR1200_VR_CFG;
                spr_dat_o[31:24] = `OR1200_VR_VER;
            end
            `OR1200_SPRGRP_SYS_UPR: begin
                spr_dat_o[0]     = `OR1200_UPR_UP;
                spr_dat_o[1]     = `OR1200_UPR_DCP;
                spr_dat_o[2]     = `OR1200_UPR_ICP;
                spr_dat_o[3]     = `OR1200_UPR_DMP;
                spr_dat_o[4]     = `OR1200_UPR_IMP;
                spr_dat_o[5]     = `OR1200_UPR_MP;
                spr_dat_o[6]     = `OR1200_UPR_DUP;
                spr_dat_o[7]     = `OR1200_UPR_PCUP;
                spr_dat_o[8]     = `OR1200_UPR_PMP;
                spr_dat_o[9]     = `OR1200_UPR_PICP;
                spr_dat_o[10]    = `OR1200_UPR_TTP;
                spr_dat_o[23:11] = `OR1200_UPR_RES1;
                spr_dat_o[31:24] = `OR1200_UPR_CUP;
            end
            `OR1200_SPRGRP_SYS_CPUCFGR: begin
                spr_dat_o[3:0]   = `OR1200_CPUCFGR_NSGF;
                spr_dat_o[4]     = `OR1200_CPUCFGR_HGF;
                spr_dat_o[5]     = `OR1200_CPUCFGR_OB32S;
                spr_dat_o[6]     = `OR1200_CPUCFGR_OB64S;
                spr_dat_o[7]     = `OR1200_CPUCFGR_OF32S;
                spr_dat_o[8]     = `OR1200_CPUCFGR_OF64S;
                spr_dat_o[9]     = `OR1200_CPUCFGR_OV64S;
                spr_dat_o[31:10] = `OR1200_CPUCFGR_RES1;
            end
            `OR1200_SPRGRP_SYS_DMMUCFGR: begin
                spr_dat_o[1:0]   = `OR1200_DMMUCFGR_NTW;
                spr_dat_o[4:2]   = `OR1200_DMMUCFGR_NTS;
                spr_dat_o[7:5]   = `OR1200_DMMUCFGR_NAE;
                spr_dat_o[8]     = `OR1200_DMMUCFGR_CRI;
                spr_dat_o[9]     = `OR1200_DMMUCFGR_PRI;
                spr_dat_o[10]    = `OR1200_DMMUCFGR_TEIRI;
                spr_dat_o[11]    = `OR1200_DMMUCFGR_HTR;
                spr_dat_o[31:12] = `OR1200_DMMUCFGR_RES1;
            end
            `OR1200_SPRGRP_SYS_IMMUCFGR: begin
                spr_dat_o[1:0]   = `OR1200_IMMUCFGR_NTW;
                spr_dat_o[4:2]   = `OR1200_IMMUCFGR_NTS;
                spr_dat_o[7:5]   = `OR1200_IMMUCFGR_NAE;
                spr_dat_o[8]     = `OR1200_IMMUCFGR_CRI;
                spr_dat_o[9]     = `OR1200_IMMUCFGR_PRI;
                spr_dat_o[10]    = `OR1200_IMMUCFGR_TEIRI;
                spr_dat_o[11]    = `OR1200_IMMUCFGR_HTR;
                spr_dat_o[31:12] = `OR1200_IMMUCFGR_RES1;
            end
            `OR1200_SPRGRP_SYS_DCCFGR: begin
                spr_dat_o[2:0]   = `OR1200_DCCFGR_NCW;
                spr_dat_o[6:3]   = `OR1200_DCCFGR_NCS;
                spr_dat_o[7]     = `OR1200_DCCFGR_CBS;
                spr_dat_o[8]     = `OR1200_DCCFGR_CWS;
                spr_dat_o[9]     = `OR1200_DCCFGR_CCRI;
                spr_dat_o[10]    = `OR1200_DCCFGR_CBIRI;
                spr_dat_o[11]    = `OR1200_DCCFGR_CBPRI;
                spr_dat_o[12]    = `OR1200_DCCFGR_CBLRI;
                spr_dat_o[13]    = `OR1200_DCCFGR_CBFRI;
                spr_dat_o[14]    = `OR1200_DCCFGR_CBWBRI;
                spr_dat_o[31:15] = `OR1200_DCCFGR_RES1;
            end
            `OR1200_SPRGRP_SYS_ICCFGR: begin
                spr_dat_o[2:0]   = `OR1200_ICCFGR_NCW;
                spr_dat_o[6:3]   = `OR1200_ICCFGR_NCS;
                spr_dat_o[7]     = `OR1200_ICCFGR_CBS;
                spr_dat_o[8]     = `OR1200_ICCFGR_CWS;
                spr_dat_o[9]     = `OR1200_ICCFGR_CCRI;
                spr_dat_o[10]    = `OR1200_ICCFGR_CBIRI;
                spr_dat_o[11]    = `OR1200_ICCFGR_CBPRI;
                spr_dat_o[12]    = `OR1200_ICCFGR_CBLRI;
                spr_dat_o[13]    = `OR1200_ICCFGR_CBFRI;
                spr_dat_o[14]    = `OR1200_ICCFGR_CBWBRI;
                spr_dat_o[31:15] = `OR1200_ICCFGR_RES1;
            end
            `OR1200_SPRGRP_SYS_DCFGR: begin
                spr_dat_o[2:0]   = `OR1200_DCFGR_NDP;
                spr_dat_o[3]     = `OR1200_DCFGR_WPCI;
                spr_dat_o[31:4]  = `OR1200_DCFGR_RES1;
            end
            default: spr_dat_o = 32'h0000_0000;
        endcase
`ifdef OR1200_SYS_FULL_DECODE
    else
        spr_dat_o = 32'h0000_0000;
`endif

`else

always @(spr_addr)
`ifdef OR1200_SYS_FULL_DECODE
    if (!spr_addr[31:4])
`endif
        case (spr_addr[3:0])
            `OR1200_SPRGRP_SYS_VR: begin
                spr_dat_o[5:0]   = `OR1200_VR_REV;
                spr_dat_o[15:6]  = `OR1200_VR_RES1;
                spr_dat_o[23:16] = `OR1200_VR_CFG;
                spr_dat_o[31:24] = `OR1200_VR_VER;
            end
            `OR1200_SPRGRP_SYS_UPR: begin
                spr_dat_o[0]     = `OR1200_UPR_UP;
                spr_dat_o[1]     = `OR1200_UPR_DCP;
                spr_dat_o[2]     = `OR1200_UPR_ICP;
                spr_dat_o[3]     = `OR1200_UPR_DMP;
                spr_dat_o[4]     = `OR1200_UPR_IMP;
                spr_dat_o[5]     = `OR1200_UPR_MP;
                spr_dat_o[6]     = `OR1200_UPR_DUP;
                spr_dat_o[7]     = `OR1200_UPR_PCUP;
                spr_dat_o[10]    = `OR1200_UPR_TTP;
                spr_dat_o[23:11] = `OR1200_UPR_RES1;
                spr_dat_o[31:24] = `OR1200_UPR_CUP;
            end
            default: spr_dat_o = 32'h0000_0000;
        endcase
`ifdef OR1200_SYS_FULL_DECODE
    else
        spr_dat_o = 32'h0000_0000;
`endif

`endif

endmodule

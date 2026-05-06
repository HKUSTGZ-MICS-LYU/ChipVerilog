// Generated from: Description/or1200_cfgr_description.txt
// Read-only OR1200 configuration registers (VR/UPR/CFGRs) on SPR read.
module or1200_cfgr(
    input  [31:0] spr_addr,
    output [31:0] spr_dat_o
);

`include "or1200_defines.v"

  reg [31:0] spr_dat;
  assign spr_dat_o = spr_dat;

  wire sys_hit = 1'b1;
`ifdef OR1200_SYS_FULL_DECODE
  wire sys_full_ok = (spr_addr[31:4] == 28'd0);
  wire sys_hit_full = sys_full_ok;
`else
  wire sys_hit_full = 1'b1;
`endif

  always @* begin
    spr_dat = 32'h0000_0000;
    if (sys_hit_full) begin
`ifdef OR1200_CFGR_IMPLEMENTED
      case (spr_addr[3:0])
        `OR1200_SPRGRP_SYS_VR: begin
          spr_dat = {`OR1200_VR_VER, `OR1200_VR_CFG, `OR1200_VR_RES1, `OR1200_VR_REV};
        end
        `OR1200_SPRGRP_SYS_UPR: begin
          spr_dat = {`OR1200_UPR_CUP,
                     `OR1200_UPR_RES1,
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
                     `OR1200_UPR_UP};
        end
        `OR1200_SPRGRP_SYS_CPUCFGR: begin
          spr_dat = 32'h0000_0000;
          spr_dat[`OR1200_CPUCFGR_NSGF_BITS]  = `OR1200_CPUCFGR_NSGF;
          spr_dat[`OR1200_CPUCFGR_HGF_BITS]   = `OR1200_CPUCFGR_HGF;
          spr_dat[`OR1200_CPUCFGR_OB32S_BITS] = `OR1200_CPUCFGR_OB32S;
          spr_dat[`OR1200_CPUCFGR_OB64S_BITS] = `OR1200_CPUCFGR_OB64S;
          spr_dat[`OR1200_CPUCFGR_OF32S_BITS] = `OR1200_CPUCFGR_OF32S;
          spr_dat[`OR1200_CPUCFGR_OF64S_BITS] = `OR1200_CPUCFGR_OF64S;
          spr_dat[`OR1200_CPUCFGR_OV64S_BITS] = `OR1200_CPUCFGR_OV64S;
          spr_dat[`OR1200_CPUCFGR_RES1_BITS]  = `OR1200_CPUCFGR_RES1;
        end
        `OR1200_SPRGRP_SYS_DMMUCFGR: begin
          spr_dat = 32'h0000_0000;
          spr_dat[`OR1200_DMMUCFGR_NTW_BITS]   = `OR1200_DMMUCFGR_NTW;
          spr_dat[`OR1200_DMMUCFGR_NTS_BITS]   = `OR1200_DMMUCFGR_NTS;
          spr_dat[`OR1200_DMMUCFGR_NAE_BITS]   = `OR1200_DMMUCFGR_NAE;
          spr_dat[`OR1200_DMMUCFGR_CRI_BITS]   = `OR1200_DMMUCFGR_CRI;
          spr_dat[`OR1200_DMMUCFGR_PRI_BITS]   = `OR1200_DMMUCFGR_PRI;
          spr_dat[`OR1200_DMMUCFGR_TEIRI_BITS] = `OR1200_DMMUCFGR_TEIRI;
          spr_dat[`OR1200_DMMUCFGR_HTR_BITS]   = `OR1200_DMMUCFGR_HTR;
          spr_dat[`OR1200_DMMUCFGR_RES1_BITS]  = `OR1200_DMMUCFGR_RES1;
        end
        `OR1200_SPRGRP_SYS_IMMUCFGR: begin
          spr_dat = 32'h0000_0000;
          spr_dat[`OR1200_IMMUCFGR_NTW_BITS]   = `OR1200_IMMUCFGR_NTW;
          spr_dat[`OR1200_IMMUCFGR_NTS_BITS]   = `OR1200_IMMUCFGR_NTS;
          spr_dat[`OR1200_IMMUCFGR_NAE_BITS]   = `OR1200_IMMUCFGR_NAE;
          spr_dat[`OR1200_IMMUCFGR_CRI_BITS]   = `OR1200_IMMUCFGR_CRI;
          spr_dat[`OR1200_IMMUCFGR_PRI_BITS]   = `OR1200_IMMUCFGR_PRI;
          spr_dat[`OR1200_IMMUCFGR_TEIRI_BITS] = `OR1200_IMMUCFGR_TEIRI;
          spr_dat[`OR1200_IMMUCFGR_HTR_BITS]   = `OR1200_IMMUCFGR_HTR;
          spr_dat[`OR1200_IMMUCFGR_RES1_BITS]  = `OR1200_IMMUCFGR_RES1;
        end
        `OR1200_SPRGRP_SYS_DCCFGR: begin
          spr_dat = 32'h0000_0000;
          spr_dat[`OR1200_DCCFGR_NCW_BITS]   = `OR1200_DCCFGR_NCW;
          spr_dat[`OR1200_DCCFGR_NCS_BITS]   = `OR1200_DCCFGR_NCS;
          spr_dat[`OR1200_DCCFGR_CBS_BITS]   = `OR1200_DCCFGR_CBS;
          spr_dat[`OR1200_DCCFGR_CWS_BITS]   = `OR1200_DCCFGR_CWS;
          spr_dat[`OR1200_DCCFGR_CCRI_BITS]  = `OR1200_DCCFGR_CCRI;
          spr_dat[`OR1200_DCCFGR_CBIRI_BITS] = `OR1200_DCCFGR_CBIRI;
          spr_dat[`OR1200_DCCFGR_CBPRI_BITS] = `OR1200_DCCFGR_CBPRI;
          spr_dat[`OR1200_DCCFGR_CBLRI_BITS] = `OR1200_DCCFGR_CBLRI;
          spr_dat[`OR1200_DCCFGR_CBFRI_BITS] = `OR1200_DCCFGR_CBFRI;
          spr_dat[`OR1200_DCCFGR_CBWBRI_BITS]= `OR1200_DCCFGR_CBWBRI;
          spr_dat[`OR1200_DCCFGR_RES1_BITS]  = `OR1200_DCCFGR_RES1;
        end
        `OR1200_SPRGRP_SYS_ICCFGR: begin
          spr_dat = 32'h0000_0000;
          spr_dat[`OR1200_ICCFGR_NCW_BITS]   = `OR1200_ICCFGR_NCW;
          spr_dat[`OR1200_ICCFGR_NCS_BITS]   = `OR1200_ICCFGR_NCS;
          spr_dat[`OR1200_ICCFGR_CBS_BITS]   = `OR1200_ICCFGR_CBS;
          spr_dat[`OR1200_ICCFGR_CWS_BITS]   = `OR1200_ICCFGR_CWS;
          spr_dat[`OR1200_ICCFGR_CCRI_BITS]  = `OR1200_ICCFGR_CCRI;
          spr_dat[`OR1200_ICCFGR_CBIRI_BITS] = `OR1200_ICCFGR_CBIRI;
          spr_dat[`OR1200_ICCFGR_CBPRI_BITS] = `OR1200_ICCFGR_CBPRI;
          spr_dat[`OR1200_ICCFGR_CBLRI_BITS] = `OR1200_ICCFGR_CBLRI;
          spr_dat[`OR1200_ICCFGR_CBFRI_BITS] = `OR1200_ICCFGR_CBFRI;
          spr_dat[`OR1200_ICCFGR_CBWBRI_BITS]= `OR1200_ICCFGR_CBWBRI;
          spr_dat[`OR1200_ICCFGR_RES1_BITS]  = `OR1200_ICCFGR_RES1;
        end
        `OR1200_SPRGRP_SYS_DCFGR: begin
          spr_dat = 32'h0000_0000;
          spr_dat[`OR1200_DCFGR_NDP_BITS]  = `OR1200_DCFGR_NDP;
          spr_dat[`OR1200_DCFGR_WPCI_BITS] = `OR1200_DCFGR_WPCI;
          spr_dat[`OR1200_DCFGR_RES1_BITS] = `OR1200_DCFGR_RES1;
        end
        default: spr_dat = 32'h0000_0000;
      endcase
`else
      case (spr_addr[3:0])
        `OR1200_SPRGRP_SYS_VR:  spr_dat = {`OR1200_VR_VER, `OR1200_VR_CFG, `OR1200_VR_RES1, `OR1200_VR_REV};
        `OR1200_SPRGRP_SYS_UPR: spr_dat = {`OR1200_UPR_CUP,
                                           `OR1200_UPR_RES1,
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
                                           `OR1200_UPR_UP};
        default: spr_dat = 32'h0000_0000;
      endcase
`endif
    end else begin
      spr_dat = 32'h0000_0000;
    end
  end
endmodule


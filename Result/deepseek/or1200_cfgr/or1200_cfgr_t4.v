`include "or1200_defines.v"

module or1200_cfgr(
    input  [31:0] spr_addr,
    output [31:0] spr_dat_o
);

reg [31:0] spr_dat_o;

always @(*) begin
`ifdef OR1200_SYS_FULL_DECODE
    if (spr_addr[31:4] != {28{1'b0}}) begin
        spr_dat_o = 32'h00000000;
    end else
`endif
    begin
        case (spr_addr[3:0])
`ifdef OR1200_CFGR_IMPLEMENTED
            4'h0: spr_dat_o = {OR1200_VR_VER, OR1200_VR_CFG, OR1200_VR_RES1, OR1200_VR_REV};
            4'h1: spr_dat_o = {OR1200_UPR_UP, OR1200_UPR_DCP, OR1200_UPR_ICP,
                               OR1200_UPR_DMP, OR1200_UPR_IMP, OR1200_UPR_MP,
                               OR1200_UPR_DUP, OR1200_UPR_PCUP, OR1200_UPR_PMP,
                               OR1200_UPR_PICP, OR1200_UPR_TTP, OR1200_UPR_CUP,
                               OR1200_UPR_RES};
            4'h2: spr_dat_o = OR1200_CPUCFGR;
            4'h3: spr_dat_o = OR1200_DMMUCFGR;
            4'h4: spr_dat_o = OR1200_IMMUCFGR;
            4'h5: spr_dat_o = OR1200_DCCFGR;
            4'h6: spr_dat_o = OR1200_ICCFGR;
            4'h7: spr_dat_o = OR1200_DCFGR;
`else   // OR1200_CFGR_IMPLEMENTED not defined
            4'h0: spr_dat_o = {OR1200_VR_VER, OR1200_VR_CFG, OR1200_VR_RES1, OR1200_VR_REV};
            4'h1: spr_dat_o = {OR1200_UPR_UP, OR1200_UPR_DCP, OR1200_UPR_ICP,
                               OR1200_UPR_DMP, OR1200_UPR_IMP, OR1200_UPR_MP,
                               OR1200_UPR_DUP, OR1200_UPR_PCUP, OR1200_UPR_PMP,
                               OR1200_UPR_PICP, OR1200_UPR_TTP, OR1200_UPR_CUP,
                               OR1200_UPR_RES};
`endif  // OR1200_CFGR_IMPLEMENTED
            default: spr_dat_o = 32'h00000000;
        endcase
    end
end

endmodule

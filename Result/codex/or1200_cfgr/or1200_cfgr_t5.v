module or1200_cfgr(
    input [31:0] spr_addr,
    output [31:0] spr_dat_o
);

reg [31:0] spr_dat_o;

always @(spr_addr) begin
    spr_dat_o = 32'h0000_0000;
`ifdef OR1200_SYS_FULL_DECODE
    if (spr_addr[31:4] == 28'h0000000) begin
`endif
        case (spr_addr[3:0])
            4'h0: begin
                spr_dat_o = {`OR1200_VR_REV, `OR1200_VR_RES1, `OR1200_VR_CFG, `OR1200_VR_VER};
            end
            4'h1: begin
                spr_dat_o = {`OR1200_UPR_CUP,
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
`ifdef OR1200_CFGR_IMPLEMENTED
            4'h2: begin
                spr_dat_o = `OR1200_CPUCFGR;
            end
            4'h3: begin
                spr_dat_o = `OR1200_DMMUCFGR;
            end
            4'h4: begin
                spr_dat_o = `OR1200_IMMUCFGR;
            end
            4'h5: begin
                spr_dat_o = `OR1200_DCCFGR;
            end
            4'h6: begin
                spr_dat_o = `OR1200_ICCFGR;
            end
            4'h7: begin
                spr_dat_o = `OR1200_DCFGR;
            end
`endif
            default: begin
                spr_dat_o = 32'h0000_0000;
            end
        endcase
`ifdef OR1200_SYS_FULL_DECODE
    end
`endif
end

endmodule

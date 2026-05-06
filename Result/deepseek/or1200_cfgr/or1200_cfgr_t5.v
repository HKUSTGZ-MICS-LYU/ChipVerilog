module or1200_cfgr(
    input [31:0] spr_addr,
    output reg [31:0] spr_dat_o
);

`include "or1200_defines.v"

always @(*) begin
`ifdef OR1200_SYS_FULL_DECODE
    if (spr_addr[31:4] != 0) begin
        spr_dat_o = 32'd0;
    end else begin
`endif
`ifdef OR1200_CFGR_IMPLEMENTED
        case (spr_addr[3:0])
            4'h0: spr_dat_o = `OR1200_VR;
            4'h1: spr_dat_o = `OR1200_UPR;
            4'h2: spr_dat_o = `OR1200_CPUCFGR;
            4'h3: spr_dat_o = `OR1200_DMMUCFGR;
            4'h4: spr_dat_o = `OR1200_IMMUCFGR;
            4'h5: spr_dat_o = `OR1200_DCCFGR;
            4'h6: spr_dat_o = `OR1200_ICCFGR;
            4'h7: spr_dat_o = `OR1200_DCFGR;
            default: spr_dat_o = 32'd0;
        endcase
`else
        case (spr_addr[3:0])
            4'h0: spr_dat_o = `OR1200_VR;
            4'h1: spr_dat_o = `OR1200_UPR;
            default: spr_dat_o = 32'd0;
        endcase
`endif
`ifdef OR1200_SYS_FULL_DECODE
    end
`endif
end

endmodule

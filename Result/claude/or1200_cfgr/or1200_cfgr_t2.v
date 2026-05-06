module or1200_cfgr(
    input  [31:0] spr_addr,
    output reg [31:0] spr_dat_o
);

function [31:0] build_vr;
begin
    build_vr = 32'h0000_0000;
`ifdef OR1200_VR
    build_vr = `OR1200_VR;
`else
`ifdef OR1200_VR_REV
`ifdef OR1200_VR_RES1
`ifdef OR1200_VR_CFG
`ifdef OR1200_VR_VER
    build_vr = {`OR1200_VR_REV, `OR1200_VR_RES1, `OR1200_VR_CFG, `OR1200_VR_VER};
`endif
`endif
`endif
`endif
`endif
end
endfunction

function [31:0] build_upr;
begin
    build_upr = 32'h0000_0000;
`ifdef OR1200_UPR
    build_upr = `OR1200_UPR;
`else
`ifdef OR1200_UPR_RES
`ifdef OR1200_UPR_CUP
`ifdef OR1200_UPR_TTP
`ifdef OR1200_UPR_PICP
`ifdef OR1200_UPR_PMP
`ifdef OR1200_UPR_PCUP
`ifdef OR1200_UPR_DUP
`ifdef OR1200_UPR_MP
`ifdef OR1200_UPR_IMP
`ifdef OR1200_UPR_DMP
`ifdef OR1200_UPR_ICP
`ifdef OR1200_UPR_DCP
`ifdef OR1200_UPR_UP
    build_upr = {
        `OR1200_UPR_RES,
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
`endif
`endif
`endif
`endif
`endif
`endif
`endif
`endif
`endif
`endif
`endif
`endif
`endif
`endif
end
endfunction

wire [31:0] vr_word;
wire [31:0] upr_word;
wire [31:0] cpucfgr_word;
wire [31:0] dmmucfgr_word;
wire [31:0] immucfgr_word;
wire [31:0] dccfgr_word;
wire [31:0] iccfgr_word;
wire [31:0] dcfgr_word;
wire        sys_addr_hit;

assign vr_word  = build_vr();
assign upr_word = build_upr();

`ifdef OR1200_CPUCFGR
assign cpucfgr_word = `OR1200_CPUCFGR;
`else
assign cpucfgr_word = 32'h0000_0000;
`endif

`ifdef OR1200_DMMUCFGR
assign dmmucfgr_word = `OR1200_DMMUCFGR;
`else
assign dmmucfgr_word = 32'h0000_0000;
`endif

`ifdef OR1200_IMMUCFGR
assign immucfgr_word = `OR1200_IMMUCFGR;
`else
assign immucfgr_word = 32'h0000_0000;
`endif

`ifdef OR1200_DCCFGR
assign dccfgr_word = `OR1200_DCCFGR;
`else
assign dccfgr_word = 32'h0000_0000;
`endif

`ifdef OR1200_ICCFGR
assign iccfgr_word = `OR1200_ICCFGR;
`else
assign iccfgr_word = 32'h0000_0000;
`endif

`ifdef OR1200_DCFGR
assign dcfgr_word = `OR1200_DCFGR;
`else
assign dcfgr_word = 32'h0000_0000;
`endif

`ifdef OR1200_SYS_FULL_DECODE
assign sys_addr_hit = (spr_addr[31:4] == 28'h000_0000);
`else
assign sys_addr_hit = 1'b1;
`endif

always @* begin
    spr_dat_o = 32'h0000_0000;

    if (sys_addr_hit) begin
`ifdef OR1200_CFGR_IMPLEMENTED
        case (spr_addr[3:0])
            4'h0: spr_dat_o = vr_word;
            4'h1: spr_dat_o = upr_word;
            4'h2: spr_dat_o = cpucfgr_word;
            4'h3: spr_dat_o = dmmucfgr_word;
            4'h4: spr_dat_o = immucfgr_word;
            4'h5: spr_dat_o = dccfgr_word;
            4'h6: spr_dat_o = iccfgr_word;
            4'h7: spr_dat_o = dcfgr_word;
            default: spr_dat_o = 32'h0000_0000;
        endcase
`else
        case (spr_addr[3:0])
            4'h0: spr_dat_o = vr_word;
            4'h1: spr_dat_o = upr_word;
            default: spr_dat_o = 32'h0000_0000;
        endcase
`endif
    end
end

endmodule

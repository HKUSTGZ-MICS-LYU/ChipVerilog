module or1200_du(
    input clk,
    input rst,
    input dcpu_cycstb_i,
    input dcpu_we_i,
    input [31:0] dcpu_adr_i,
    input [31:0] dcpu_dat_lsu,
    input [31:0] dcpu_dat_dc,
    input icpu_cycstb_i,
    input ex_freeze,
    input [2:0] branch_op,
    input [31:0] ex_insn,
    input [31:0] id_pc,
    input [31:0] spr_dat_npc,
    input [31:0] rf_dataw,
    output [13:0] du_dsr,
    output du_stall,
    output [31:0] du_addr,
    input [31:0] du_dat_i,
    output [31:0] du_dat_o,
    output du_read,
    output du_write,
    input [12:0] du_except,
    output du_hwbkpt,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    input dbg_stall_i,
    input dbg_ewt_i,
    output [3:0] dbg_lss_o,
    output [1:0] dbg_is_o,
    output [10:0] dbg_wp_o,
    output dbg_bp_o,
    input dbg_stb_i,
    input dbg_we_i,
    input [31:0] dbg_adr_i,
    input [31:0] dbg_dat_i,
    output [31:0] dbg_dat_o,
    output dbg_ack_o
);

localparam [10:0] SPR_ADDR_DMR1     = 11'h000;
localparam [10:0] SPR_ADDR_DMR2     = 11'h001;
localparam [10:0] SPR_ADDR_DSR      = 11'h002;
localparam [10:0] SPR_ADDR_DRR      = 11'h003;
localparam [10:0] SPR_ADDR_DVR0     = 11'h010;
localparam [10:0] SPR_ADDR_DVR1     = 11'h011;
localparam [10:0] SPR_ADDR_DVR2     = 11'h012;
localparam [10:0] SPR_ADDR_DVR3     = 11'h013;
localparam [10:0] SPR_ADDR_DVR4     = 11'h014;
localparam [10:0] SPR_ADDR_DVR5     = 11'h015;
localparam [10:0] SPR_ADDR_DVR6     = 11'h016;
localparam [10:0] SPR_ADDR_DVR7     = 11'h017;
localparam [10:0] SPR_ADDR_DCR0     = 11'h020;
localparam [10:0] SPR_ADDR_DCR1     = 11'h021;
localparam [10:0] SPR_ADDR_DCR2     = 11'h022;
localparam [10:0] SPR_ADDR_DCR3     = 11'h023;
localparam [10:0] SPR_ADDR_DCR4     = 11'h024;
localparam [10:0] SPR_ADDR_DCR5     = 11'h025;
localparam [10:0] SPR_ADDR_DCR6     = 11'h026;
localparam [10:0] SPR_ADDR_DCR7     = 11'h027;
localparam [10:0] SPR_ADDR_DWCR0    = 11'h030;
localparam [10:0] SPR_ADDR_DWCR1    = 11'h031;
localparam [10:0] SPR_ADDR_TB_ADDR  = 11'h040;
localparam [10:0] SPR_ADDR_TB_DATA0 = 11'h041;
localparam [10:0] SPR_ADDR_TB_DATA1 = 11'h042;
localparam [10:0] SPR_ADDR_TB_DATA2 = 11'h043;
localparam [10:0] SPR_ADDR_TB_DATA3 = 11'h044;

function [31:0] du_sign_adj;
    input [31:0] val;
    input sgn;
    begin
        du_sign_adj = {val[31] ^ sgn, val[30:0]};
    end
endfunction

function du_cmp_hit;
    input [2:0] rel;
    input [31:0] lhs;
    input [31:0] rhs;
    begin
        case (rel)
            3'b001: du_cmp_hit = (lhs == rhs);
            3'b010: du_cmp_hit = (lhs < rhs);
            3'b011: du_cmp_hit = (lhs <= rhs);
            3'b100: du_cmp_hit = (lhs > rhs);
            3'b101: du_cmp_hit = (lhs >= rhs);
            3'b110: du_cmp_hit = (lhs != rhs);
            default: du_cmp_hit = 1'b0;
        endcase
    end
endfunction

assign du_stall = dbg_stall_i;
assign du_addr  = dbg_adr_i;
assign du_dat_o = dbg_dat_i;
assign du_read  = dbg_stb_i & ~dbg_we_i;
assign du_write = dbg_stb_i &  dbg_we_i;
assign dbg_dat_o = du_dat_i;

reg dbg_ack_r;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dbg_ack_r <= 1'b0;
    end else begin
        dbg_ack_r <= dbg_stb_i;
    end
end
assign dbg_ack_o = dbg_ack_r;

assign dbg_wp_o = 11'b000_0000_0000;

`ifdef OR1200_DU_STATUS_UNIMPLEMENTED
reg dbg_is_tgl;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dbg_is_tgl <= 1'b0;
    end else if (icpu_cycstb_i[0]) begin
        dbg_is_tgl <= ~dbg_is_tgl;
    end
end
assign dbg_lss_o = 4'b0000;
assign dbg_is_o  = {dbg_is_tgl, ~dbg_is_tgl};
`else
assign dbg_lss_o = {2'b00, dcpu_we_i, dcpu_cycstb_i};
assign dbg_is_o  = {1'b0, icpu_cycstb_i[0]};
`endif

`ifdef OR1200_DU_IMPLEMENTED
wire [10:0] spr_addr11 = spr_addr[10:0];
wire [13:0] except_stop = {1'b0, du_except};

`ifdef OR1200_DU_DMR1
wire dmr1_sel = spr_cs & (spr_addr11 == SPR_ADDR_DMR1);
reg [24:0] dmr1;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dmr1 <= 25'd0;
    end else if (dmr1_sel & spr_write) begin
        dmr1 <= spr_dat_i[24:0];
    end
end
wire [24:0] dmr1_val = dmr1;
`else
wire [24:0] dmr1_val = 25'd0;
`endif

`ifdef OR1200_DU_DMR2
wire dmr2_sel = spr_cs & (spr_addr11 == SPR_ADDR_DMR2);
reg [31:0] dmr2;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dmr2 <= 32'd0;
    end else if (dmr2_sel & spr_write) begin
        dmr2 <= spr_dat_i;
    end
end
wire [31:0] dmr2_val = dmr2;
`else
wire [31:0] dmr2_val = 32'd0;
`endif

`ifdef OR1200_DU_DSR
wire dsr_sel = spr_cs & (spr_addr11 == SPR_ADDR_DSR);
reg [13:0] dsr;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dsr <= 14'd0;
    end else if (dsr_sel & spr_write) begin
        dsr <= spr_dat_i[13:0];
    end
end
wire [13:0] dsr_val = dsr;
`else
wire [13:0] dsr_val = 14'd0;
`endif
assign du_dsr = dsr_val;

`ifdef OR1200_DU_DRR
wire drr_sel = spr_cs & (spr_addr11 == SPR_ADDR_DRR);
reg [13:0] drr;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        drr <= 14'd0;
    end else if (drr_sel & spr_write) begin
        drr <= spr_dat_i[13:0];
    end else begin
        drr <= drr | except_stop;
    end
end
wire [13:0] drr_val = drr;
`else
wire [13:0] drr_val = 14'd0;
`endif

`ifdef OR1200_DU_DVR0
wire dvr0_sel = spr_cs & (spr_addr11 == SPR_ADDR_DVR0);
reg [31:0] dvr0;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dvr0 <= 32'd0;
    end else if (dvr0_sel & spr_write) begin
        dvr0 <= spr_dat_i;
    end
end
wire [31:0] dvr0_val = dvr0;
`else
wire [31:0] dvr0_val = 32'd0;
`endif

`ifdef OR1200_DU_DVR1
wire dvr1_sel = spr_cs & (spr_addr11 == SPR_ADDR_DVR1);
reg [31:0] dvr1;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dvr1 <= 32'd0;
    end else if (dvr1_sel & spr_write) begin
        dvr1 <= spr_dat_i;
    end
end
wire [31:0] dvr1_val = dvr1;
`else
wire [31:0] dvr1_val = 32'd0;
`endif

`ifdef OR1200_DU_DVR2
wire dvr2_sel = spr_cs & (spr_addr11 == SPR_ADDR_DVR2);
reg [31:0] dvr2;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dvr2 <= 32'd0;
    end else if (dvr2_sel & spr_write) begin
        dvr2 <= spr_dat_i;
    end
end
wire [31:0] dvr2_val = dvr2;
`else
wire [31:0] dvr2_val = 32'd0;
`endif

`ifdef OR1200_DU_DVR3
wire dvr3_sel = spr_cs & (spr_addr11 == SPR_ADDR_DVR3);
reg [31:0] dvr3;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dvr3 <= 32'd0;
    end else if (dvr3_sel & spr_write) begin
        dvr3 <= spr_dat_i;
    end
end
wire [31:0] dvr3_val = dvr3;
`else
wire [31:0] dvr3_val = 32'd0;
`endif

`ifdef OR1200_DU_DVR4
wire dvr4_sel = spr_cs & (spr_addr11 == SPR_ADDR_DVR4);
reg [31:0] dvr4;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dvr4 <= 32'd0;
    end else if (dvr4_sel & spr_write) begin
        dvr4 <= spr_dat_i;
    end
end
wire [31:0] dvr4_val = dvr4;
`else
wire [31:0] dvr4_val = 32'd0;
`endif

`ifdef OR1200_DU_DVR5
wire dvr5_sel = spr_cs & (spr_addr11 == SPR_ADDR_DVR5);
reg [31:0] dvr5;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dvr5 <= 32'd0;
    end else if (dvr5_sel & spr_write) begin
        dvr5 <= spr_dat_i;
    end
end
wire [31:0] dvr5_val = dvr5;
`else
wire [31:0] dvr5_val = 32'd0;
`endif

`ifdef OR1200_DU_DVR6
wire dvr6_sel = spr_cs & (spr_addr11 == SPR_ADDR_DVR6);
reg [31:0] dvr6;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dvr6 <= 32'd0;
    end else if (dvr6_sel & spr_write) begin
        dvr6 <= spr_dat_i;
    end
end
wire [31:0] dvr6_val = dvr6;
`else
wire [31:0] dvr6_val = 32'd0;
`endif

`ifdef OR1200_DU_DVR7
wire dvr7_sel = spr_cs & (spr_addr11 == SPR_ADDR_DVR7);
reg [31:0] dvr7;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dvr7 <= 32'd0;
    end else if (dvr7_sel & spr_write) begin
        dvr7 <= spr_dat_i;
    end
end
wire [31:0] dvr7_val = dvr7;
`else
wire [31:0] dvr7_val = 32'd0;
`endif

`ifdef OR1200_DU_DCR0
wire dcr0_sel = spr_cs & (spr_addr11 == SPR_ADDR_DCR0);
reg [7:0] dcr0;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dcr0 <= 8'd0;
    end else if (dcr0_sel & spr_write) begin
        dcr0 <= spr_dat_i[7:0];
    end
end
wire [7:0] dcr0_val = dcr0;
`else
wire [7:0] dcr0_val = 8'd0;
`endif

`ifdef OR1200_DU_DCR1
wire dcr1_sel = spr_cs & (spr_addr11 == SPR_ADDR_DCR1);
reg [7:0] dcr1;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dcr1 <= 8'd0;
    end else if (dcr1_sel & spr_write) begin
        dcr1 <= spr_dat_i[7:0];
    end
end
wire [7:0] dcr1_val = dcr1;
`else
wire [7:0] dcr1_val = 8'd0;
`endif

`ifdef OR1200_DU_DCR2
wire dcr2_sel = spr_cs & (spr_addr11 == SPR_ADDR_DCR2);
reg [7:0] dcr2;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dcr2 <= 8'd0;
    end else if (dcr2_sel & spr_write) begin
        dcr2 <= spr_dat_i[7:0];
    end
end
wire [7:0] dcr2_val = dcr2;
`else
wire [7:0] dcr2_val = 8'd0;
`endif

`ifdef OR1200_DU_DCR3
wire dcr3_sel = spr_cs & (spr_addr11 == SPR_ADDR_DCR3);
reg [7:0] dcr3;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dcr3 <= 8'd0;
    end else if (dcr3_sel & spr_write) begin
        dcr3 <= spr_dat_i[7:0];
    end
end
wire [7:0] dcr3_val = dcr3;
`else
wire [7:0] dcr3_val = 8'd0;
`endif

`ifdef OR1200_DU_DCR4
wire dcr4_sel = spr_cs & (spr_addr11 == SPR_ADDR_DCR4);
reg [7:0] dcr4;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dcr4 <= 8'd0;
    end else if (dcr4_sel & spr_write) begin
        dcr4 <= spr_dat_i[7:0];
    end
end
wire [7:0] dcr4_val = dcr4;
`else
wire [7:0] dcr4_val = 8'd0;
`endif

`ifdef OR1200_DU_DCR5
wire dcr5_sel = spr_cs & (spr_addr11 == SPR_ADDR_DCR5);
reg [7:0] dcr5;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dcr5 <= 8'd0;
    end else if (dcr5_sel & spr_write) begin
        dcr5 <= spr_dat_i[7:0];
    end
end
wire [7:0] dcr5_val = dcr5;
`else
wire [7:0] dcr5_val = 8'd0;
`endif

`ifdef OR1200_DU_DCR6
wire dcr6_sel = spr_cs & (spr_addr11 == SPR_ADDR_DCR6);
reg [7:0] dcr6;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dcr6 <= 8'd0;
    end else if (dcr6_sel & spr_write) begin
        dcr6 <= spr_dat_i[7:0];
    end
end
wire [7:0] dcr6_val = dcr6;
`else
wire [7:0] dcr6_val = 8'd0;
`endif

`ifdef OR1200_DU_DCR7
wire dcr7_sel = spr_cs & (spr_addr11 == SPR_ADDR_DCR7);
reg [7:0] dcr7;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dcr7 <= 8'd0;
    end else if (dcr7_sel & spr_write) begin
        dcr7 <= spr_dat_i[7:0];
    end
end
wire [7:0] dcr7_val = dcr7;
`else
wire [7:0] dcr7_val = 8'd0;
`endif

wire non_nop_ex = (ex_insn != 32'h1500_0000);
wire branch_ex  = (branch_op != 3'b000);

reg dbg_bp_r;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dbg_bp_r <= 1'b0;
    end else if (ex_freeze) begin
        dbg_bp_r <= |except_stop;
    end else begin
        dbg_bp_r <= (|except_stop) | (dmr1_val[22] & non_nop_ex) | (dmr1_val[23] & non_nop_ex & branch_ex);
    end
end
assign dbg_bp_o = dbg_bp_r;

`ifdef OR1200_DU_HWBKPTS
wire [2:0] src0 = dcr0_val[7:5];
wire [2:0] src1 = dcr1_val[7:5];
wire [2:0] src2 = dcr2_val[7:5];
wire [2:0] src3 = dcr3_val[7:5];
wire [2:0] src4 = dcr4_val[7:5];
wire [2:0] src5 = dcr5_val[7:5];
wire [2:0] src6 = dcr6_val[7:5];
wire [2:0] src7 = dcr7_val[7:5];

wire [2:0] rel0 = dcr0_val[4:2];
wire [2:0] rel1 = dcr1_val[4:2];
wire [2:0] rel2 = dcr2_val[4:2];
wire [2:0] rel3 = dcr3_val[4:2];
wire [2:0] rel4 = dcr4_val[4:2];
wire [2:0] rel5 = dcr5_val[4:2];
wire [2:0] rel6 = dcr6_val[4:2];
wire [2:0] rel7 = dcr7_val[4:2];

wire sgn0 = dcr0_val[1];
wire sgn1 = dcr1_val[1];
wire sgn2 = dcr2_val[1];
wire sgn3 = dcr3_val[1];
wire sgn4 = dcr4_val[1];
wire sgn5 = dcr5_val[1];
wire sgn6 = dcr6_val[1];
wire sgn7 = dcr7_val[1];

wire [31:0] cmp_tgt0 = (src0 == 3'd1) ? id_pc :
                       (src0 == 3'd2) ? dcpu_adr_i :
                       (src0 == 3'd3) ? dcpu_adr_i :
                       (src0 == 3'd4) ? dcpu_dat_dc :
                       (src0 == 3'd5) ? dcpu_dat_lsu :
                       (src0 == 3'd6) ? dcpu_adr_i :
                       (src0 == 3'd7) ? (dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc) :
                                        32'd0;
wire [31:0] cmp_tgt1 = (src1 == 3'd1) ? id_pc :
                       (src1 == 3'd2) ? dcpu_adr_i :
                       (src1 == 3'd3) ? dcpu_adr_i :
                       (src1 == 3'd4) ? dcpu_dat_dc :
                       (src1 == 3'd5) ? dcpu_dat_lsu :
                       (src1 == 3'd6) ? dcpu_adr_i :
                       (src1 == 3'd7) ? (dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc) :
                                        32'd0;
wire [31:0] cmp_tgt2 = (src2 == 3'd1) ? id_pc :
                       (src2 == 3'd2) ? dcpu_adr_i :
                       (src2 == 3'd3) ? dcpu_adr_i :
                       (src2 == 3'd4) ? dcpu_dat_dc :
                       (src2 == 3'd5) ? dcpu_dat_lsu :
                       (src2 == 3'd6) ? dcpu_adr_i :
                       (src2 == 3'd7) ? (dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc) :
                                        32'd0;
wire [31:0] cmp_tgt3 = (src3 == 3'd1) ? id_pc :
                       (src3 == 3'd2) ? dcpu_adr_i :
                       (src3 == 3'd3) ? dcpu_adr_i :
                       (src3 == 3'd4) ? dcpu_dat_dc :
                       (src3 == 3'd5) ? dcpu_dat_lsu :
                       (src3 == 3'd6) ? dcpu_adr_i :
                       (src3 == 3'd7) ? (dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc) :
                                        32'd0;
wire [31:0] cmp_tgt4 = (src4 == 3'd1) ? id_pc :
                       (src4 == 3'd2) ? dcpu_adr_i :
                       (src4 == 3'd3) ? dcpu_adr_i :
                       (src4 == 3'd4) ? dcpu_dat_dc :
                       (src4 == 3'd5) ? dcpu_dat_lsu :
                       (src4 == 3'd6) ? dcpu_adr_i :
                       (src4 == 3'd7) ? (dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc) :
                                        32'd0;
wire [31:0] cmp_tgt5 = (src5 == 3'd1) ? id_pc :
                       (src5 == 3'd2) ? dcpu_adr_i :
                       (src5 == 3'd3) ? dcpu_adr_i :
                       (src5 == 3'd4) ? dcpu_dat_dc :
                       (src5 == 3'd5) ? dcpu_dat_lsu :
                       (src5 == 3'd6) ? dcpu_adr_i :
                       (src5 == 3'd7) ? (dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc) :
                                        32'd0;
wire [31:0] cmp_tgt6 = (src6 == 3'd1) ? id_pc :
                       (src6 == 3'd2) ? dcpu_adr_i :
                       (src6 == 3'd3) ? dcpu_adr_i :
                       (src6 == 3'd4) ? dcpu_dat_dc :
                       (src6 == 3'd5) ? dcpu_dat_lsu :
                       (src6 == 3'd6) ? dcpu_adr_i :
                       (src6 == 3'd7) ? (dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc) :
                                        32'd0;
wire [31:0] cmp_tgt7 = (src7 == 3'd1) ? id_pc :
                       (src7 == 3'd2) ? dcpu_adr_i :
                       (src7 == 3'd3) ? dcpu_adr_i :
                       (src7 == 3'd4) ? dcpu_dat_dc :
                       (src7 == 3'd5) ? dcpu_dat_lsu :
                       (src7 == 3'd6) ? dcpu_adr_i :
                       (src7 == 3'd7) ? (dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc) :
                                        32'd0;

wire cmp_stb0 = (src0 == 3'd0) ? 1'b0 :
                (src0 == 3'd1) ? 1'b1 :
                (src0 == 3'd2) ? (dcpu_cycstb_i & ~dcpu_we_i) :
                (src0 == 3'd3) ? (dcpu_cycstb_i &  dcpu_we_i) :
                                 dcpu_cycstb_i;
wire cmp_stb1 = (src1 == 3'd0) ? 1'b0 :
                (src1 == 3'd1) ? 1'b1 :
                (src1 == 3'd2) ? (dcpu_cycstb_i & ~dcpu_we_i) :
                (src1 == 3'd3) ? (dcpu_cycstb_i &  dcpu_we_i) :
                                 dcpu_cycstb_i;
wire cmp_stb2 = (src2 == 3'd0) ? 1'b0 :
                (src2 == 3'd1) ? 1'b1 :
                (src2 == 3'd2) ? (dcpu_cycstb_i & ~dcpu_we_i) :
                (src2 == 3'd3) ? (dcpu_cycstb_i &  dcpu_we_i) :
                                 dcpu_cycstb_i;
wire cmp_stb3 = (src3 == 3'd0) ? 1'b0 :
                (src3 == 3'd1) ? 1'b1 :
                (src3 == 3'd2) ? (dcpu_cycstb_i & ~dcpu_we_i) :
                (src3 == 3'd3) ? (dcpu_cycstb_i &  dcpu_we_i) :
                                 dcpu_cycstb_i;
wire cmp_stb4 = (src4 == 3'd0) ? 1'b0 :
                (src4 == 3'd1) ? 1'b1 :
                (src4 == 3'd2) ? (dcpu_cycstb_i & ~dcpu_we_i) :
                (src4 == 3'd3) ? (dcpu_cycstb_i &  dcpu_we_i) :
                                 dcpu_cycstb_i;
wire cmp_stb5 = (src5 == 3'd0) ? 1'b0 :
                (src5 == 3'd1) ? 1'b1 :
                (src5 == 3'd2) ? (dcpu_cycstb_i & ~dcpu_we_i) :
                (src5 == 3'd3) ? (dcpu_cycstb_i &  dcpu_we_i) :
                                 dcpu_cycstb_i;
wire cmp_stb6 = (src6 == 3'd0) ? 1'b0 :
                (src6 == 3'd1) ? 1'b1 :
                (src6 == 3'd2) ? (dcpu_cycstb_i & ~dcpu_we_i) :
                (src6 == 3'd3) ? (dcpu_cycstb_i &  dcpu_we_i) :
                                 dcpu_cycstb_i;
wire cmp_stb7 = (src7 == 3'd0) ? 1'b0 :
                (src7 == 3'd1) ? 1'b1 :
                (src7 == 3'd2) ? (dcpu_cycstb_i & ~dcpu_we_i) :
                (src7 == 3'd3) ? (dcpu_cycstb_i &  dcpu_we_i) :
                                 dcpu_cycstb_i;

wire match0 = cmp_stb0 & du_cmp_hit(rel0, du_sign_adj(cmp_tgt0, sgn0), du_sign_adj(dvr0_val, sgn0));
wire match1 = cmp_stb1 & du_cmp_hit(rel1, du_sign_adj(cmp_tgt1, sgn1), du_sign_adj(dvr1_val, sgn1));
wire match2 = cmp_stb2 & du_cmp_hit(rel2, du_sign_adj(cmp_tgt2, sgn2), du_sign_adj(dvr2_val, sgn2));
wire match3 = cmp_stb3 & du_cmp_hit(rel3, du_sign_adj(cmp_tgt3, sgn3), du_sign_adj(dvr3_val, sgn3));
wire match4 = cmp_stb4 & du_cmp_hit(rel4, du_sign_adj(cmp_tgt4, sgn4), du_sign_adj(dvr4_val, sgn4));
wire match5 = cmp_stb5 & du_cmp_hit(rel5, du_sign_adj(cmp_tgt5, sgn5), du_sign_adj(dvr5_val, sgn5));
wire match6 = cmp_stb6 & du_cmp_hit(rel6, du_sign_adj(cmp_tgt6, sgn6), du_sign_adj(dvr6_val, sgn6));
wire match7 = cmp_stb7 & du_cmp_hit(rel7, du_sign_adj(cmp_tgt7, sgn7), du_sign_adj(dvr7_val, sgn7));

wire wp0 = dmr1_val[0] ? match0 : 1'b0;
wire [1:0] wp1_ctl = dmr1_val[3:2];
wire [1:0] wp2_ctl = dmr1_val[5:4];
wire [1:0] wp3_ctl = dmr1_val[7:6];
wire [1:0] wp4_ctl = dmr1_val[9:8];
wire [1:0] wp5_ctl = dmr1_val[11:10];
wire [1:0] wp6_ctl = dmr1_val[13:12];
wire [1:0] wp7_ctl = dmr1_val[15:14];

wire wp1 = (wp1_ctl == 2'b01) ? match1 :
           (wp1_ctl == 2'b10) ? (match1 & wp0) :
           (wp1_ctl == 2'b11) ? (match1 | wp0) : 1'b0;
wire wp2 = (wp2_ctl == 2'b01) ? match2 :
           (wp2_ctl == 2'b10) ? (match2 & wp1) :
           (wp2_ctl == 2'b11) ? (match2 | wp1) : 1'b0;
wire wp3 = (wp3_ctl == 2'b01) ? match3 :
           (wp3_ctl == 2'b10) ? (match3 & wp2) :
           (wp3_ctl == 2'b11) ? (match3 | wp2) : 1'b0;
wire wp4 = (wp4_ctl == 2'b01) ? match4 :
           (wp4_ctl == 2'b10) ? (match4 & wp3) :
           (wp4_ctl == 2'b11) ? (match4 | wp3) : 1'b0;
wire wp5 = (wp5_ctl == 2'b01) ? match5 :
           (wp5_ctl == 2'b10) ? (match5 & wp4) :
           (wp5_ctl == 2'b11) ? (match5 | wp4) : 1'b0;
wire wp6 = (wp6_ctl == 2'b01) ? match6 :
           (wp6_ctl == 2'b10) ? (match6 & wp5) :
           (wp6_ctl == 2'b11) ? (match6 | wp5) : 1'b0;
wire wp7 = (wp7_ctl == 2'b01) ? match7 :
           (wp7_ctl == 2'b10) ? (match7 & wp6) :
           (wp7_ctl == 2'b11) ? (match7 | wp6) : 1'b0;

wire [7:0] wp_base = {wp7, wp6, wp5, wp4, wp3, wp2, wp1, wp0};

wire [7:0] cnt0_sel = dmr2_val[20:13];
wire [7:0] cnt1_sel = dmr2_val[28:21];
wire cnt0_evt = |(wp_base & cnt0_sel);
wire cnt1_evt = |(wp_base & cnt1_sel);

`ifdef OR1200_DU_DWCR0
wire dwcr0_sel = spr_cs & (spr_addr11 == SPR_ADDR_DWCR0);
reg [31:0] dwcr0;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dwcr0 <= 32'd0;
    end else if (dwcr0_sel & spr_write) begin
        dwcr0 <= spr_dat_i;
    end else if (dmr2_val[11] & cnt0_evt) begin
        dwcr0[15:0] <= dwcr0[15:0] + 16'd1;
    end
end
wire [31:0] dwcr0_val = dwcr0;
wire wp8 = (dwcr0_val[31:16] == dwcr0_val[15:0]);
`else
wire [31:0] dwcr0_val = 32'd0;
wire wp8 = 1'b0;
`endif

`ifdef OR1200_DU_DWCR1
wire dwcr1_sel = spr_cs & (spr_addr11 == SPR_ADDR_DWCR1);
reg [31:0] dwcr1;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dwcr1 <= 32'd0;
    end else if (dwcr1_sel & spr_write) begin
        dwcr1 <= spr_dat_i;
    end else if (dmr2_val[12] & cnt1_evt) begin
        dwcr1[15:0] <= dwcr1[15:0] + 16'd1;
    end
end
wire [31:0] dwcr1_val = dwcr1;
wire wp9 = (dwcr1_val[31:16] == dwcr1_val[15:0]);
`else
wire [31:0] dwcr1_val = 32'd0;
wire wp9 = 1'b0;
`endif

wire wp10 = dbg_ewt_i;
wire [10:0] wp_int = {wp10, wp9, wp8, wp_base};
assign du_hwbkpt = |(wp_int & dmr2_val[10:0]);

`else
wire [31:0] dwcr0_val = 32'd0;
wire [31:0] dwcr1_val = 32'd0;
assign du_hwbkpt = 1'b0;
`endif

`ifdef OR1200_DU_TB_IMPLEMENTED
wire tb_addr_sel = spr_cs & (spr_addr11 == SPR_ADDR_TB_ADDR);
reg [7:0] tb_radr;
reg [7:0] tb_wadr;
reg [31:0] tb_timstmp;
reg [31:0] tb_mem_npc [0:255];
reg [31:0] tb_mem_insn [0:255];
reg [31:0] tb_mem_wb [0:255];
reg [31:0] tb_mem_ts [0:255];

wire tb_store = ~ex_freeze & non_nop_ex;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        tb_radr    <= 8'd0;
        tb_wadr    <= 8'd0;
        tb_timstmp <= 32'd0;
    end else begin
        tb_timstmp <= tb_timstmp + 32'd1;
        if (tb_addr_sel & spr_write) begin
            tb_radr <= spr_dat_i[7:0];
        end
        if (tb_store) begin
            tb_mem_npc[tb_wadr]  <= spr_dat_npc;
            tb_mem_insn[tb_wadr] <= ex_insn;
            tb_mem_wb[tb_wadr]   <= rf_dataw;
            tb_mem_ts[tb_wadr]   <= tb_timstmp;
            tb_wadr <= tb_wadr + 8'd1;
        end
    end
end

wire [31:0] tb_data0 = tb_mem_npc[tb_radr];
wire [31:0] tb_data1 = tb_mem_insn[tb_radr];
wire [31:0] tb_data2 = tb_mem_wb[tb_radr];
wire [31:0] tb_data3 = tb_mem_ts[tb_radr];
`else
wire [7:0] tb_wadr = 8'd0;
wire [31:0] tb_data0 = 32'd0;
wire [31:0] tb_data1 = 32'd0;
wire [31:0] tb_data2 = 32'd0;
wire [31:0] tb_data3 = 32'd0;
`endif

`ifdef OR1200_DU_READREGS
reg [31:0] spr_dat_r;
always @* begin
    spr_dat_r = 32'd0;
    case (spr_addr11)
`ifdef OR1200_DU_DMR1
        SPR_ADDR_DMR1: spr_dat_r = {7'd0, dmr1_val};
`endif
`ifdef OR1200_DU_DMR2
        SPR_ADDR_DMR2: spr_dat_r = dmr2_val;
`endif
`ifdef OR1200_DU_DSR
        SPR_ADDR_DSR: spr_dat_r = {18'd0, dsr_val};
`endif
`ifdef OR1200_DU_DRR
        SPR_ADDR_DRR: spr_dat_r = {18'd0, drr_val};
`endif
`ifdef OR1200_DU_DVR0
        SPR_ADDR_DVR0: spr_dat_r = dvr0_val;
`endif
`ifdef OR1200_DU_DVR1
        SPR_ADDR_DVR1: spr_dat_r = dvr1_val;
`endif
`ifdef OR1200_DU_DVR2
        SPR_ADDR_DVR2: spr_dat_r = dvr2_val;
`endif
`ifdef OR1200_DU_DVR3
        SPR_ADDR_DVR3: spr_dat_r = dvr3_val;
`endif
`ifdef OR1200_DU_DVR4
        SPR_ADDR_DVR4: spr_dat_r = dvr4_val;
`endif
`ifdef OR1200_DU_DVR5
        SPR_ADDR_DVR5: spr_dat_r = dvr5_val;
`endif
`ifdef OR1200_DU_DVR6
        SPR_ADDR_DVR6: spr_dat_r = dvr6_val;
`endif
`ifdef OR1200_DU_DVR7
        SPR_ADDR_DVR7: spr_dat_r = dvr7_val;
`endif
`ifdef OR1200_DU_DCR0
        SPR_ADDR_DCR0: spr_dat_r = {24'd0, dcr0_val};
`endif
`ifdef OR1200_DU_DCR1
        SPR_ADDR_DCR1: spr_dat_r = {24'd0, dcr1_val};
`endif
`ifdef OR1200_DU_DCR2
        SPR_ADDR_DCR2: spr_dat_r = {24'd0, dcr2_val};
`endif
`ifdef OR1200_DU_DCR3
        SPR_ADDR_DCR3: spr_dat_r = {24'd0, dcr3_val};
`endif
`ifdef OR1200_DU_DCR4
        SPR_ADDR_DCR4: spr_dat_r = {24'd0, dcr4_val};
`endif
`ifdef OR1200_DU_DCR5
        SPR_ADDR_DCR5: spr_dat_r = {24'd0, dcr5_val};
`endif
`ifdef OR1200_DU_DCR6
        SPR_ADDR_DCR6: spr_dat_r = {24'd0, dcr6_val};
`endif
`ifdef OR1200_DU_DCR7
        SPR_ADDR_DCR7: spr_dat_r = {24'd0, dcr7_val};
`endif
`ifdef OR1200_DU_DWCR0
        SPR_ADDR_DWCR0: spr_dat_r = dwcr0_val;
`endif
`ifdef OR1200_DU_DWCR1
        SPR_ADDR_DWCR1: spr_dat_r = dwcr1_val;
`endif
`ifdef OR1200_DU_TB_IMPLEMENTED
        SPR_ADDR_TB_ADDR:  spr_dat_r = {24'd0, tb_wadr};
        SPR_ADDR_TB_DATA0: spr_dat_r = tb_data0;
        SPR_ADDR_TB_DATA1: spr_dat_r = tb_data1;
        SPR_ADDR_TB_DATA2: spr_dat_r = tb_data2;
        SPR_ADDR_TB_DATA3: spr_dat_r = tb_data3;
`endif
        default: spr_dat_r = 32'd0;
    endcase
end
assign spr_dat_o = spr_dat_r;
`else
assign spr_dat_o = 32'd0;
`endif

`else
assign du_dsr = 14'd0;
assign du_hwbkpt = 1'b0;
assign dbg_bp_o = 1'b0;
assign spr_dat_o = 32'd0;
`endif

endmodule

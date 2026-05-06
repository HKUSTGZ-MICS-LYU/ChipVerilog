`include "or1200_defines.v"


module or1200_dmmu_tlb(
    input clk,
    input rst,
    input tlb_en,
    input [31:0] vaddr,
    output hit,
    output [31:13] ppn,
    output uwe,
    output ure,
    output swe,
    output sre,
    output ci,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);
localparam TLB_ENTRIES = (1 << `OR1200_DTLB_INDXW);
reg [31:13] mr_vpn [0:TLB_ENTRIES-1];
reg         mr_v   [0:TLB_ENTRIES-1];
reg [31:13] tr_ppn [0:TLB_ENTRIES-1];
reg         tr_uwe [0:TLB_ENTRIES-1];
reg         tr_ure [0:TLB_ENTRIES-1];
reg         tr_swe [0:TLB_ENTRIES-1];
reg         tr_sre [0:TLB_ENTRIES-1];
reg         tr_ci  [0:TLB_ENTRIES-1];
wire spr_mr = spr_cs && (spr_addr[`OR1200_SPR_GROUP_BITS] == `OR1200_SPR_GROUP_DMMU) && !spr_addr[10];
wire spr_tr = spr_cs && (spr_addr[`OR1200_SPR_GROUP_BITS] == `OR1200_SPR_GROUP_DMMU) &&  spr_addr[10];
wire [`OR1200_DTLB_INDXW-1:0] idx = spr_cs ? spr_addr[`OR1200_DTLB_INDXW-1:0] : vaddr[`OR1200_DTLB_INDXH:`OR1200_DMMU_PS];
assign hit = tlb_en && mr_v[idx] && (mr_vpn[idx] == vaddr[31:13]);
assign ppn = tr_ppn[idx];
assign uwe = tr_uwe[idx];
assign ure = tr_ure[idx];
assign swe = tr_swe[idx];
assign sre = tr_sre[idx];
assign ci  = tr_ci[idx];
assign spr_dat_o = (!spr_write && spr_mr) ? {mr_vpn[idx], 12'b0, mr_v[idx]} :
                   (!spr_write && spr_tr) ? {tr_ppn[idx], tr_swe[idx], tr_sre[idx], tr_uwe[idx], tr_ure[idx], 9'b0, tr_ci[idx]} : 32'b0;
integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i=0;i<TLB_ENTRIES;i=i+1) begin
            mr_vpn[i] <= 19'b0; mr_v[i] <= 1'b0; tr_ppn[i] <= 19'b0;
            tr_uwe[i] <= 1'b0; tr_ure[i] <= 1'b0; tr_swe[i] <= 1'b0; tr_sre[i] <= 1'b0; tr_ci[i] <= 1'b0;
        end
    end else if (spr_cs && spr_write) begin
        if (spr_mr) begin mr_vpn[idx] <= spr_dat_i[31:13]; mr_v[idx] <= spr_dat_i[0]; end
        if (spr_tr) begin tr_ppn[idx] <= spr_dat_i[31:13]; tr_swe[idx] <= spr_dat_i[12]; tr_sre[idx] <= spr_dat_i[11]; tr_uwe[idx] <= spr_dat_i[10]; tr_ure[idx] <= spr_dat_i[9]; tr_ci[idx] <= spr_dat_i[0]; end
    end
end
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

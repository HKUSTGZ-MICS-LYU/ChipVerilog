//-----------------------------------------------------------------------
// or1200_immu_top - Instruction-side MMU top level
// Copyright (C) 2009  Julius Baxter
// Copyright (C) 2005  Johnny Shiu
// Copyright (C) 2001  Damjan Lampret
//
// This file is part of OpenRISC 1000.
//
// OpenRISC 1000 is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// OpenRISC 1000 is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with OpenRISC 1000; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
//---------------------------------------------------------------------

// synopsys translate_off
`include "or1200_defines.v"
// synopsys translate_on

module or1200_immu_top(
    // Rst and clk
    clk,
    rst,

    // CPU i/f
    ic_en,
    immu_en,
    supv,
    icpu_adr_i,
    icpu_cycstb_i,
    icpu_adr_o,
    icpu_tag_o,
    icpu_rty_o,
    icpu_err_o,

    // SPR access
    spr_cs,
    spr_write,
    spr_addr,
    spr_dat_i,
    spr_dat_o,

`ifdef OR1200_BIST
    // RAM BIST
    mbist_si_i,
    mbist_so_o,
    mbist_ctrl_i,
`endif

    // QMEM i/f
    qmemimmu_rty_i,
    qmemimmu_err_i,
    qmemimmu_tag_i,
    qmemimmu_adr_o,
    qmemimmu_cycstb_o,
    qmemimmu_ci_o
);

//
// Parameters
//
parameter TLB_MISS_TAG = 4'b0001;
parameter PAGE_FAULT_TAG = 4'b0010;

//
// Rst and clk
//
input clk;
input rst;

//
// CPU i/f
//
input ic_en;
input immu_en;
input supv;
input [31:0] icpu_adr_i;
input icpu_cycstb_i;
output [31:0] icpu_adr_o;
output [3:0] icpu_tag_o;
output icpu_rty_o;
output icpu_err_o;

//
// SPR access
//
input spr_cs;
input spr_write;
input [31:0] spr_addr;
input [31:0] spr_dat_i;
output [31:0] spr_dat_o;

`ifdef OR1200_BIST
//
// RAM BIST
//
input mbist_si_i;
output mbist_so_o;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
`endif

//
// QMEM i/f
//
input qmemimmu_rty_i;
input qmemimmu_err_i;
input [3:0] qmemimmu_tag_i;
output [31:0] qmemimmu_adr_o;
output qmemimmu_cycstb_o;
output qmemimmu_ci_o;

//
// Internal signals
//
reg [31:0] icpu_adr_o;
reg [31:13] icpu_vpn_r;
reg itlb_en_r;
reg spr_access_active;

wire [31:13] vpn_i;
wire page_cross;
wire itlb_en;
wire itlb_done;
wire itlb_hit;
wire [31:13] itlb_ppn;
wire itlb_uxe;
wire itlb_sxe;
wire itlb_ci;
wire [31:0] itlb_dat_o;
wire miss;
wire fault;
wire local_retry;
wire local_err;
wire local_tag;

//
// Virtual page number latch and page crossing detection
//
assign vpn_i = icpu_adr_i[31:13];

always @(posedge clk or posedge rst) begin
    if (rst)
        icpu_vpn_r <= 19'd0;
    else
        icpu_vpn_r <= vpn_i;
end

assign page_cross = (vpn_i != icpu_vpn_r);

//
// Registered CPU address output
//
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge clk or posedge rst) begin
    if (rst)
        icpu_adr_o <= 32'h0000_0100;
    else
        icpu_adr_o <= icpu_adr_i;
end
`else
assign icpu_adr_o = icpu_adr_i;
`endif

//
// SPR access control
//
always @(posedge clk or posedge rst) begin
    if (rst)
        spr_access_active <= 1'b0;
    else begin
        if (spr_cs & ~spr_access_active)
            spr_access_active <= 1'b1;
        else
            spr_access_active <= 1'b0;
    end
end

assign local_retry = spr_access_active;
assign icpu_rty_o = qmemimmu_rty_i | local_retry;

//
// ITLB enable
//
assign itlb_en = (immu_en & icpu_cycstb_i) & ~spr_access_active;

always @(posedge clk or posedge rst) begin
    if (rst)
        itlb_en_r <= 1'b0;
    else
        itlb_en_r <= itlb_en;
end

//
// ITLB done
//
assign itlb_done = itlb_en_r & ~page_cross;

//
// TLB miss and page fault
//
assign miss = itlb_done & ~itlb_hit;
assign fault = itlb_done & itlb_hit & (supv ? ~itlb_sxe : ~itlb_uxe);

assign local_err = miss | fault;
assign local_tag = miss ? TLB_MISS_TAG : (fault ? PAGE_FAULT_TAG : 4'b0000);

//
// CPU tag and error output
//
assign icpu_tag_o = (local_err) ? local_tag : qmemimmu_tag_i;
assign icpu_err_o = local_err | qmemimmu_err_i;

//
// SPR read data
//
assign spr_dat_o = (spr_cs & ~spr_access_active) ? itlb_dat_o : 32'd0;

//
// Downstream request and address (with IMMU present)
//
`ifdef OR1200_IMPU_HAS_IMMU

wire qmemimmu_cycstb_imm;
assign qmemimmu_cycstb_imm = icpu_cycstb_i & itlb_done & ~miss & ~fault & ~page_cross;

wire qmemimmu_cycstb_noimm;
assign qmemimmu_cycstb_noimm = icpu_cycstb_i & ~page_cross;

assign qmemimmu_cycstb_o = immu_en ? qmemimmu_cycstb_imm : qmemimmu_cycstb_noimm;

wire [31:0] qmemimmu_adr_itlb;
wire [31:0] qmemimmu_adr_vpn;
assign qmemimmu_adr_itlb = {itlb_ppn, icpu_adr_i[12:0]};
assign qmemimmu_adr_vpn = {icpu_vpn_r, icpu_adr_i[12:0]};

assign qmemimmu_adr_o = itlb_done ? qmemimmu_adr_itlb : qmemimmu_adr_vpn;

assign qmemimmu_ci_o = 1'b0;

//
// ITLB instantiation
//
or1200_immu_itlb #(
    .ITLB_ENTRIES(`OR1200_ITLB_ENTRIES)
) itlb (
    .clk(clk),
    .rst(rst),
    .en(itlb_en),
    .addr(icpu_adr_i),
    .spr_cs(spr_cs & ~spr_access_active),
    .spr_write(spr_write),
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_i),
    .spr_dat_o(itlb_dat_o),
    .hit(itlb_hit),
    .ppn(itlb_ppn),
    .uxe(itlb_uxe),
    .sxe(itlb_sxe),
    .ci(itlb_ci)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

`else // !OR1200_IMPU_HAS_IMMU
//
// No IMMU - pass-through
//
assign qmemimmu_cycstb_o = icpu_cycstb_i;
assign qmemimmu_adr_o = icpu_adr_i;
assign qmemimmu_ci_o = 1'b0;

assign itlb_hit = 1'b0;
assign itlb_ppn = 19'd0;
assign itlb_uxe = 1'b0;
assign itlb_sxe = 1'b0;
assign itlb_ci = 1'b0;
assign itlb_dat_o = 32'd0;

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`endif // OR1200_IMPU_HAS_IMMU

endmodule

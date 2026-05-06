module or1200_immu_tlb(
    input clk,
    input rst,
    input tlb_en,
    input [31:0] vaddr,
    output hit,
    output [31:13] ppn,
    output uxe,
    output sxe,
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

    wire [31:19] vpn;
    wire v;
    wire [5:0] tlb_index;
    wire tlb_mr_en;
    wire tlb_mr_we;
    wire [13:0] tlb_mr_ram_in;
    wire [13:0] tlb_mr_ram_out;
    wire tlb_tr_en;
    wire tlb_tr_we;
    wire [21:0] tlb_tr_ram_in;
    wire [21:0] tlb_tr_ram_out;
    wire itlb_mr_ram_si;
    wire itlb_mr_ram_so;
    wire itlb_tr_ram_si;
    wire itlb_tr_ram_so;
    wire tlb_tr_en_wire;
    wire tlb_tr_we_wire;
    wire [5:0] tlb_index_wire;
    wire [21:0] tlb_tr_ram_in_wire;
    wire tlb_mr_en_wire;
    wire tlb_mr_we_wire;
    wire [13:0] tlb_mr_ram_in_wire;

    assign vpn = vaddr[31:19];
    assign tlb_index = tlb_en ? vaddr[18:13] : spr_addr[5:0];
    assign tlb_mr_en = tlb_en | spr_cs;
    assign tlb_mr_we = spr_cs & spr_write;
    assign tlb_tr_en = tlb_en | spr_cs;
    assign tlb_tr_we = spr_cs & spr_write;

    assign v = tlb_mr_ram_out[13];
    assign hit = tlb_en & (tlb_mr_ram_out[12:0] == vpn[12:0]) & v;
    assign ppn = tlb_tr_ram_out[21:3];
    assign uxe = tlb_tr_ram_out[2];
    assign sxe = tlb_tr_ram_out[1];
    assign ci = tlb_tr_ram_out[0];

    assign tlb_mr_ram_in = spr_dat_i[13:0];
    assign tlb_tr_ram_in = spr_dat_i[21:0];

    assign spr_dat_o = (spr_cs & ~spr_write) ? 
                       (spr_addr[5:0] < 64 ? {18'b0, tlb_mr_ram_out} : {10'b0, tlb_tr_ram_out}) : 32'b0;

`ifdef OR1200_BIST
    assign itlb_mr_ram_si = mbist_si_i;
    assign itlb_tr_ram_si = itlb_mr_ram_so;
    assign mbist_so_o = itlb_tr_ram_so;
`endif

    or1200_immu_tlb_mr_ram mr_ram_inst(
        .clk(clk),
        .rst(rst),
        .en(tlb_mr_en),
        .we(tlb_mr_we),
        .addr(tlb_index),
        .din(tlb_mr_ram_in),
        .dout(tlb_mr_ram_out)
`ifdef OR1200_BIST
        , .mbist_si_i(itlb_mr_ram_si),
        .mbist_so_o(itlb_mr_ram_so),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

    or1200_immu_tlb_tr_ram tr_ram_inst(
        .clk(clk),
        .rst(rst),
        .en(tlb_tr_en),
        .we(tlb_tr_we),
        .addr(tlb_index),
        .din(tlb_tr_ram_in),
        .dout(tlb_tr_ram_out)
`ifdef OR1200_BIST
        , .mbist_si_i(itlb_tr_ram_si),
        .mbist_so_o(itlb_tr_ram_so),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

endmodule

module or1200_immu_tlb_mr_ram(
    input clk,
    input rst,
    input en,
    input we,
    input [5:0] addr,
    input [13:0] din,
    output [13:0] dout
`ifdef OR1200_BIST
    , input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

reg [13:0] ram [0:63];

always @(posedge clk)
    if (en && we)
        ram[addr] <= din;

assign dout = ram[addr];

`ifdef OR1200_BIST
assign mbist_so_o = 1'b0;
`endif

endmodule

module or1200_immu_tlb_tr_ram(
    input clk,
    input rst,
    input en,
    input we,
    input [5:0] addr,
    input [21:0] din,
    output [21:0] dout
`ifdef OR1200_BIST
    , input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

reg [21:0] ram [0:63];

always @(posedge clk)
    if (en && we)
        ram[addr] <= din;

assign dout = ram[addr];

`ifdef OR1200_BIST
assign mbist_so_o = 1'b0;
`endif

endmodule

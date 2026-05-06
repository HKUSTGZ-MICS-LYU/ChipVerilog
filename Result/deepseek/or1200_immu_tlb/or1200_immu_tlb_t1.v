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

    // Internal signals
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

    // Index selection: SPR access has priority
    assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

    // MR RAM control
    assign tlb_mr_en = tlb_en | (spr_cs & !spr_addr[7]);
    assign tlb_mr_we = spr_cs & spr_write & !spr_addr[7];
    assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};

    // TR RAM control
    assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);
    assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];
    assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

    // Decode MR RAM output
    assign vpn = tlb_mr_ram_out[13:1];
    assign v   = tlb_mr_ram_out[0];

    // Decode TR RAM output
    assign ppn = tlb_tr_ram_out[21:3];
    assign uxe = tlb_tr_ram_out[2];
    assign sxe = tlb_tr_ram_out[1];
    assign ci  = tlb_tr_ram_out[0];

    // Hit generation
    assign hit = (vpn == vaddr[31:19]) & v;

    // SPR readback data (combinational, not gated by spr_cs)
    reg [31:0] spr_dat_o_reg;
    always @* begin
        if (spr_write) begin
            spr_dat_o_reg = 32'h00000000;
        end else if (!spr_addr[7]) begin
            // MR region readback
            spr_dat_o_reg = {tlb_mr_ram_out[13:1], 13'h0000, {5{v}} & tlb_index, 1'b0, tlb_mr_ram_out[0]};
        end else begin
            // TR region readback
            spr_dat_o_reg = {tlb_tr_ram_out[21:3], 13'h0000, tlb_tr_ram_out[2], tlb_tr_ram_out[1], 1'b0, tlb_tr_ram_out[0], 1'b0};
        end
    end
    assign spr_dat_o = spr_dat_o_reg;

    // RAM instantiation
`ifdef OR1200_RAM_MODELS_VIRTEX
    // Virtex RAM macros without rst
    wire tlb_tr_en_wire = tlb_tr_en;
    wire [0:0] tlb_tr_we_wire = tlb_tr_we;
    wire [5:0] tlb_index_wire = tlb_index;
    wire [21:0] tlb_tr_ram_in_wire = tlb_tr_ram_in;
    wire tlb_mr_en_wire = tlb_mr_en;
    wire [0:0] tlb_mr_we_wire = tlb_mr_we;
    wire [13:0] tlb_mr_ram_in_wire = tlb_mr_ram_in;

    itlb_tr_sub itlb_tr_sub_inst (
        .clk(clk),
        .en(tlb_tr_en_wire),
        .we(tlb_tr_we_wire),
        .addr(tlb_index_wire),
        .di(tlb_tr_ram_in_wire),
        .doq(tlb_tr_ram_out)
    );

    itlb_mr_sub itlb_mr_sub_inst (
        .clk(clk),
        .en(tlb_mr_en_wire),
        .we(tlb_mr_we_wire),
        .addr(tlb_index_wire),
        .di(tlb_mr_ram_in_wire),
        .doq(tlb_mr_ram_out)
    );

`else
    // Generic SPRAM with rst
`ifdef OR1200_BIST
    wire itlb_mr_ram_si;
    wire itlb_mr_ram_so;
    wire itlb_tr_ram_si;
    wire itlb_tr_ram_so;

    assign itlb_mr_ram_si = mbist_si_i;

    or1200_spram_64x14 itlb_mr_ram (
        .clk(clk),
        .rst(rst),
        .ce(tlb_mr_en),
        .we(tlb_mr_we),
        .oe(1'b1),
        .addr(tlb_index),
        .di(tlb_mr_ram_in),
        .doq(tlb_mr_ram_out),
        .mbist_si_i(itlb_mr_ram_si),
        .mbist_so_o(itlb_mr_ram_so),
        .mbist_ctrl_i(mbist_ctrl_i)
    );

    assign itlb_tr_ram_si = itlb_mr_ram_so;

    or1200_spram_64x22 itlb_tr_ram (
        .clk(clk),
        .rst(rst),
        .ce(tlb_tr_en),
        .we(tlb_tr_we),
        .oe(1'b1),
        .addr(tlb_index),
        .di(tlb_tr_ram_in),
        .doq(tlb_tr_ram_out),
        .mbist_si_i(itlb_tr_ram_si),
        .mbist_so_o(itlb_tr_ram_so),
        .mbist_ctrl_i(mbist_ctrl_i)
    );

    assign mbist_so_o = itlb_tr_ram_so;

`else
    or1200_spram_64x14 itlb_mr_ram (
        .clk(clk),
        .rst(rst),
        .ce(tlb_mr_en),
        .we(tlb_mr_we),
        .oe(1'b1),
        .addr(tlb_index),
        .di(tlb_mr_ram_in),
        .doq(tlb_mr_ram_out)
    );

    or1200_spram_64x22 itlb_tr_ram (
        .clk(clk),
        .rst(rst),
        .ce(tlb_tr_en),
        .we(tlb_tr_we),
        .oe(1'b1),
        .addr(tlb_index),
        .di(tlb_tr_ram_in),
        .doq(tlb_tr_ram_out)
    );
`endif
`endif

endmodule

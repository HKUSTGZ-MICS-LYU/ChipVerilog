`define OR1200_MBIST_CTRL_WIDTH 4
`endif

module or1200_immu_tlb (
    input clk,
    input rst,

    // I/F for translation
    input tlb_en,
    input [31:0] vaddr,
    output hit,
    output [31:13] ppn,
    output uxe,
    output sxe,
    output ci,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // SPR access
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

    // Internal wires and registers
    wire [5:0] tlb_index;
    wire tlb_mr_en, tlb_mr_we;
    wire [13:0] tlb_mr_ram_in, tlb_mr_ram_out;
    wire tlb_tr_en, tlb_tr_we;
    wire [21:0] tlb_tr_ram_in, tlb_tr_ram_out;

    // BIST chain wires
`ifdef OR1200_BIST
    wire itlb_mr_ram_si, itlb_mr_ram_so;
    wire itlb_tr_ram_si, itlb_tr_ram_so;
`endif

    // Intermediate wires for Virtex macro instantiation
`ifdef OR1200_RAM_MODELS_VIRTEX
    wire tlb_tr_en_wire;
    wire [0:0] tlb_tr_we_wire;
    wire [5:0] tlb_index_wire;
    wire [21:0] tlb_tr_ram_in_wire;
    wire tlb_mr_en_wire;
    wire [0:0] tlb_mr_we_wire;
    wire [13:0] tlb_mr_ram_in_wire;
`endif

    // TLB index selection
    assign tlb_index = (spr_cs) ? spr_addr[5:0] : vaddr[18:13];

    // Enable and write enable generation
    assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
    assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];
    assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);
    assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];

    // Data input packing for SPR writes
    assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};
    assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

    // Output unpacking
    wire [31:19] vpn;
    wire v;
    assign vpn = tlb_mr_ram_out[13:1];
    assign v = tlb_mr_ram_out[0];
    assign ppn = tlb_tr_ram_out[21:3];
    assign uxe = tlb_tr_ram_out[2];
    assign sxe = tlb_tr_ram_out[1];
    assign ci = tlb_tr_ram_out[0];

    // Hit generation (combinational)
    assign hit = (vpn == vaddr[31:19]) & v;

    // SPR read data generation (combinational)
    wire [5:0] index_readback;
    assign index_readback = {6{tlb_mr_ram_out[0]}} & tlb_index;

    reg [31:0] spr_dat_o_reg;
    always @* begin
        if (spr_write)
            spr_dat_o_reg = 32'd0;
        else if (~spr_addr[7]) begin
            // MR readback
            spr_dat_o_reg = {tlb_mr_ram_out[13:1], 6'd0, index_readback, 6'd0, tlb_mr_ram_out[0]};
        end else begin
            // TR readback
            spr_dat_o_reg = {tlb_tr_ram_out[21:3], 5'd0, tlb_tr_ram_out[2], tlb_tr_ram_out[1], 4'd0, tlb_tr_ram_out[0], 1'd0};
        end
    end
    assign spr_dat_o = spr_dat_o_reg;

    // RAM instantiations
`ifdef OR1200_RAM_MODELS_VIRTEX
    // Virtex-specific RAM macros
    assign tlb_index_wire = tlb_index;
    assign tlb_mr_en_wire = tlb_mr_en;
    assign tlb_mr_we_wire[0] = tlb_mr_we;
    assign tlb_mr_ram_in_wire = tlb_mr_ram_in;
    assign tlb_tr_en_wire = tlb_tr_en;
    assign tlb_tr_we_wire[0] = tlb_tr_we;
    assign tlb_tr_ram_in_wire = tlb_tr_ram_in;

    itlb_mr_sub mr_ram (
        .clk(clk),
        .en(tlb_mr_en_wire),
        .we(tlb_mr_we_wire[0]),
        .addr(tlb_index_wire),
        .di(tlb_mr_ram_in_wire),
        .do(tlb_mr_ram_out),
`ifdef OR1200_BIST
        .si(itlb_mr_ram_si),
        .so(itlb_mr_ram_so),
        .ctrl(mbist_ctrl_i)
`else
        .si(1'b0),
        .so(),
        .ctrl({(`OR1200_MBIST_CTRL_WIDTH){1'b0}})
`endif
    );

    itlb_tr_sub tr_ram (
        .clk(clk),
        .en(tlb_tr_en_wire),
        .we(tlb_tr_we_wire[0]),
        .addr(tlb_index_wire),
        .di(tlb_tr_ram_in_wire),
        .do(tlb_tr_ram_out),
`ifdef OR1200_BIST
        .si(itlb_tr_ram_si),
        .so(itlb_tr_ram_so),
        .ctrl(mbist_ctrl_i)
`else
        .si(1'b0),
        .so(),
        .ctrl({(`OR1200_MBIST_CTRL_WIDTH){1'b0}})
`endif
    );

`else
    // Generic SPRAM implementation
    or1200_spram_64x14 mr_ram (
        .clk(clk),
        .rst(rst),
        .ce(tlb_mr_en),
        .we(tlb_mr_we),
        .oe(1'b1),
        .addr(tlb_index),
        .di(tlb_mr_ram_in),
        .doq(tlb_mr_ram_out)
`ifdef OR1200_BIST
        ,
        .mbist_si(itlb_mr_ram_si),
        .mbist_so(itlb_mr_ram_so),
        .mbist_ctrl(mbist_ctrl_i)
`endif
    );

    or1200_spram_64x22 tr_ram (
        .clk(clk),
        .rst(rst),
        .ce(tlb_tr_en),
        .we(tlb_tr_we),
        .oe(1'b1),
        .addr(tlb_index),
        .di(tlb_tr_ram_in),
        .doq(tlb_tr_ram_out)
`ifdef OR1200_BIST
        ,
        .mbist_si(itlb_tr_ram_si),
        .mbist_so(itlb_tr_ram_so),
        .mbist_ctrl(mbist_ctrl_i)
`endif
    );

`endif

    // BIST scan chain
`ifdef OR1200_BIST
    assign itlb_mr_ram_si = mbist_si_i;
    assign itlb_tr_ram_si = itlb_mr_ram_so;
    assign mbist_so_o = itlb_tr_ram_so;
`endif

endmodule

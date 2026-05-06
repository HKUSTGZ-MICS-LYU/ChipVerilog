module or1200_immu_tlb(
    // Rst and clk
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

    // -----------------------------------------------------------------
    // Internal wires and registers
    // -----------------------------------------------------------------
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

`ifdef OR1200_BIST
    wire itlb_mr_ram_si;
    wire itlb_mr_ram_so;
    wire itlb_tr_ram_si;
    wire itlb_tr_ram_so;
`endif

    // Additional wires for Virtex branch
`ifdef OR1200_RAM_MODELS_VIRTEX
    wire tlb_tr_en_wire;
    wire [0 : 0] tlb_tr_we_wire;
    wire [5 : 0] tlb_index_wire;
    wire [21 : 0] tlb_tr_ram_in_wire;
    wire tlb_mr_en_wire;
    wire [0 : 0] tlb_mr_we_wire;
    wire [13 : 0] tlb_mr_ram_in_wire;
`endif

    // -----------------------------------------------------------------
    // TLB index selection
    // -----------------------------------------------------------------
    assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

    // -----------------------------------------------------------------
    // MR RAM enable and write enable
    // -----------------------------------------------------------------
    assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
    assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];

    // -----------------------------------------------------------------
    // TR RAM enable and write enable
    // -----------------------------------------------------------------
    assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);
    assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];

    // -----------------------------------------------------------------
    // RAM input data packing
    // -----------------------------------------------------------------
    // MR: {spr_dat_i[31:19], spr_dat_i[0]}
    assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};

    // TR: {spr_dat_i[31:13], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]}
    assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

    // -----------------------------------------------------------------
    // RAM outputs decomposition
    // -----------------------------------------------------------------
    assign vpn = tlb_mr_ram_out[13:1];
    assign v = tlb_mr_ram_out[0];
    assign {ppn, uxe, sxe, ci} = {tlb_tr_ram_out[21:3], tlb_tr_ram_out[2], tlb_tr_ram_out[1], tlb_tr_ram_out[0]};

    // -----------------------------------------------------------------
    // Hit generation
    // -----------------------------------------------------------------
    assign hit = (vpn == vaddr[31:19]) & v;

    // -----------------------------------------------------------------
    // SPR readback data
    // -----------------------------------------------------------------
    reg [31:0] spr_dat_o_reg;
    always @(*) begin
        if (spr_write) begin
            spr_dat_o_reg = 32'd0;
        end else begin
            if (~spr_addr[7]) begin // MR region
                spr_dat_o_reg[31:19] = tlb_mr_ram_out[13:1];
                spr_dat_o_reg[18:13] = tlb_index & {6{tlb_mr_ram_out[0]}};
                spr_dat_o_reg[12:1] = 12'd0;
                spr_dat_o_reg[0] = tlb_mr_ram_out[0];
            end else begin // TR region
                spr_dat_o_reg[31:13] = tlb_tr_ram_out[21:3];
                spr_dat_o_reg[12:8] = 5'd0;
                spr_dat_o_reg[7] = tlb_tr_ram_out[2];
                spr_dat_o_reg[6] = tlb_tr_ram_out[1];
                spr_dat_o_reg[5:2] = 4'd0;
                spr_dat_o_reg[1] = tlb_tr_ram_out[0];
                spr_dat_o_reg[0] = 1'd0;
            end
        end
    end
    assign spr_dat_o = spr_dat_o_reg;

    // -----------------------------------------------------------------
    // RAM instantiation
    // -----------------------------------------------------------------
`ifdef OR1200_RAM_MODELS_VIRTEX
    // Virtex-specific RAM macros

    // MR RAM: itlb_mr_sub
    // Assumed ports: clk, en, we, addr, di, doq, si, so, ctrl
    // The enable and write enable are passed through intermediate wires
    assign tlb_mr_en_wire = tlb_mr_en;
    assign tlb_mr_we_wire = tlb_mr_we;
    assign tlb_index_wire = tlb_index; // used as addr
    assign tlb_mr_ram_in_wire = tlb_mr_ram_in;

    itlb_mr_sub u_mr_ram (
        .clk(clk),
        .en(tlb_mr_en_wire),
        .we(tlb_mr_we_wire),
        .addr(tlb_index_wire),
        .di(tlb_mr_ram_in_wire),
        .doq(tlb_mr_ram_out),
`ifdef OR1200_BIST
        .si(itlb_mr_ram_si),
        .so(itlb_mr_ram_so),
        .ctrl(mbist_ctrl_i)
`endif
    );

    // TR RAM: itlb_tr_sub
    assign tlb_tr_en_wire = tlb_tr_en;
    assign tlb_tr_we_wire = tlb_tr_we;
    assign tlb_tr_ram_in_wire = tlb_tr_ram_in;

    itlb_tr_sub u_tr_ram (
        .clk(clk),
        .en(tlb_tr_en_wire),
        .we(tlb_tr_we_wire),
        .addr(tlb_index_wire),
        .di(tlb_tr_ram_in_wire),
        .doq(tlb_tr_ram_out),
`ifdef OR1200_BIST
        .si(itlb_tr_ram_si),
        .so(itlb_tr_ram_so),
        .ctrl(mbist_ctrl_i)
`endif
    );

`else
    // Generic SPRAMs

    // MR RAM: 64x14
    or1200_spram_64x14 u_mr_ram (
        .clk(clk),
        .rst(rst),
        .ce(tlb_mr_en),             // chip enable
        .we(tlb_mr_we),             // write enable
        .oe(1'b1),                  // output enable always on
        .addr(tlb_index),           // 6-bit address
        .di(tlb_mr_ram_in),
        .doq(tlb_mr_ram_out)
    );

    // TR RAM: 64x22
    or1200_spram_64x22 u_tr_ram (
        .clk(clk),
        .rst(rst),
        .ce(tlb_tr_en),
        .we(tlb_tr_we),
        .oe(1'b1),
        .addr(tlb_index),
        .di(tlb_tr_ram_in),
        .doq(tlb_tr_ram_out)
    );

`endif // OR1200_RAM_MODELS_VIRTEX

    // -----------------------------------------------------------------
    // MBIST chain
    // -----------------------------------------------------------------
`ifdef OR1200_BIST
    // Chain: mbist_si_i -> itlb_mr_ram_si -> itlb_mr_ram_so -> itlb_tr_ram_si -> itlb_tr_ram_so -> mbist_so_o
    assign itlb_mr_ram_si = mbist_si_i;
    assign itlb_tr_ram_si = itlb_mr_ram_so;
    assign mbist_so_o = itlb_tr_ram_so;
`endif

endmodule

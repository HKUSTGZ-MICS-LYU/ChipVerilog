module or1200_dmmu_tlb(
    input clk,
    input rst,
    // Translation interface
    input tlb_en,
    input [31:0] vaddr,
    output hit,
    output [31:13] ppn,
    output uwe, ure, swe, sre, ci,
`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif
    // SPR interface
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

    localparam OR1200_DTLB_INDXW = 6;

    // Internal wires
    wire [5:0] tlb_index;
    wire tlb_mr_en, tlb_tr_en;
    wire tlb_mr_we, tlb_tr_we;
    wire [13:0] tlb_mr_ram_out;
    wire [23:0] tlb_tr_ram_out;
    wire [12:0] vpn_ram;
    wire v;
    wire [18:0] ppn_ram;
    wire [5:0] index_masked;

    // Index selection: SPR has priority
    assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

    // RAM enables
    assign tlb_mr_en = tlb_en | (spr_cs & (spr_addr[7] == 1'b0));
    assign tlb_tr_en = tlb_en | (spr_cs & (spr_addr[7] == 1'b1));

    // RAM write enables (only during SPR writes)
    assign tlb_mr_we = spr_cs & spr_write & (spr_addr[7] == 1'b0);
    assign tlb_tr_we = spr_cs & spr_write & (spr_addr[7] == 1'b1);

    // Decode match RAM output
    assign vpn_ram = tlb_mr_ram_out[13:1];
    assign v = tlb_mr_ram_out[0];

    // Decode translate RAM output
    assign ppn_ram = tlb_tr_ram_out[23:5];
    assign swe = tlb_tr_ram_out[4];
    assign sre = tlb_tr_ram_out[3];
    assign uwe = tlb_tr_ram_out[2];
    assign ure = tlb_tr_ram_out[1];
    assign ci = tlb_tr_ram_out[0];

    // Hit generation (combinational, not gated by tlb_en)
    assign hit = (vpn_ram == vaddr[31:19]) & v;

    // Physical page number output
    assign ppn[31:13] = ppn_ram;
    assign ppn[12:0] = 13'd0;

    // SPR read data
    assign index_masked = tlb_index & {OR1200_DTLB_INDXW{v}};

    // SPR read data mux
    assign spr_dat_o = (spr_cs & ~spr_write & (spr_addr[7] == 1'b0)) ? 
                        {vpn_ram, index_masked, 12'b0, v} :
                      (spr_cs & ~spr_write & (spr_addr[7] == 1'b1)) ? 
                        {ppn_ram, 3'b000, swe, sre, uwe, ure, 4'b0000, ci, 1'b0} :
                      32'd0;

    // RAM instantiation – match RAM
`ifdef OR1200_RAM_MODELS_VIRTEX
    // Virtex-specific RAM instantiation (example: Xilinx RAMB16)
    // In practice, the exact module would be substituted.
    // For simulation, we use a generic RAM.
    or1200_spram_64x14 #(
        .INIT_FILE("none")
    ) or1200_dmmu_tlb_match_ram (
        .clk(clk),
        .rst(rst),
        .addr(tlb_index),
        .enable(tlb_mr_en),
        .we(tlb_mr_we),
        .din({spr_dat_i[31:19], spr_dat_i[0]}),
        .dout(tlb_mr_ram_out)
    `ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    `endif
    );
`else
    // Generic OR1200 single-port RAM
    or1200_spram_64x14 or1200_dmmu_tlb_match_ram (
        .clk(clk),
        .rst(rst),
        .addr(tlb_index),
        .enable(tlb_mr_en),
        .we(tlb_mr_we),
        .din({spr_dat_i[31:19], spr_dat_i[0]}),
        .dout(tlb_mr_ram_out)
    `ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    `endif
    );
`endif

    // RAM instantiation – translate RAM
`ifdef OR1200_RAM_MODELS_VIRTEX
    // Virtex-specific RAM instantiation (example: Xilinx RAMB16)
    or1200_spram_64x24 #(
        .INIT_FILE("none")
    ) or1200_dmmu_tlb_trans_ram (
        .clk(clk),
        .rst(rst),
        .addr(tlb_index),
        .enable(tlb_tr_en),
        .we(tlb_tr_we),
        .din({spr_dat_i[31:13], spr_dat_i[9:6], spr_dat_i[1]}),
        .dout(tlb_tr_ram_out)
    `ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    `endif
    );
`else
    or1200_spram_64x24 or1200_dmmu_tlb_trans_ram (
        .clk(clk),
        .rst(rst),
        .addr(tlb_index),
        .enable(tlb_tr_en),
        .we(tlb_tr_we),
        .din({spr_dat_i[31:13], spr_dat_i[9:6], spr_dat_i[1]}),
        .dout(tlb_tr_ram_out)
    `ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    `endif
    );
`endif

endmodule

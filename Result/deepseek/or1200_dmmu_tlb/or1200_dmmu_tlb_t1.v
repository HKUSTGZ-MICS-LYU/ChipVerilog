// or1200_dmmu_tlb - DTLB entry storage, SPR access, decode, and hit logic

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

    // Internal signals
    wire [5:0] tlb_index;
    wire tlb_mr_en;
    wire tlb_tr_en;
    wire tlb_mr_we;
    wire tlb_tr_we;
    wire [13:0] tlb_mr_ram_out;
    wire [23:0] tlb_tr_ram_out;

    // Index selection: SPR has priority
    assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

    // Match RAM control
    assign tlb_mr_en = (tlb_en && !spr_cs) || (spr_cs && (spr_addr[7] == 1'b0));
    assign tlb_mr_we = spr_cs && spr_write && (spr_addr[7] == 1'b0);

    // Translate RAM control
    assign tlb_tr_en = (tlb_en && !spr_cs) || (spr_cs && (spr_addr[7] == 1'b1));
    assign tlb_tr_we = spr_cs && spr_write && (spr_addr[7] == 1'b1);

    // Match RAM data input muxing
    wire [13:0] tlb_mr_di;
    assign tlb_mr_di = {spr_dat_i[31:19], spr_dat_i[0]};

    // Translate RAM data input muxing
    wire [23:0] tlb_tr_di;
    assign tlb_tr_di = {spr_dat_i[31:13], spr_dat_i[9], spr_dat_i[8], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

    // RAM instantiations
`ifdef OR1200_RAM_MODELS_VIRTEX
    // Virtex-specific RAM models (placeholder – implement according to library)
    // Match RAM: 64 x 14
    // Translate RAM: 64 x 24
    // For completeness, we instantiate generic simple dual-port or single-port models
    // Actual implementation details depend on the Virtex library; here we provide a behavioral model
    // that matches the required functionality.

    reg [13:0] mr_ram [0:63];
    reg [23:0] tr_ram [0:63];

    integer i;
    always @(posedge clk) begin
        if (tlb_mr_en) begin
            if (tlb_mr_we)
                mr_ram[tlb_index] <= tlb_mr_di;
        end
    end

    always @(posedge clk) begin
        if (tlb_tr_en) begin
            if (tlb_tr_we)
                tr_ram[tlb_index] <= tlb_tr_di;
        end
    end

    assign tlb_mr_ram_out = mr_ram[tlb_index];
    assign tlb_tr_ram_out = tr_ram[tlb_index];

`else
    // Generic OR1200 single-port RAM models
    or1200_spram_64x14 dmmu_mr_ram (
        .clk(clk),
        .rst(rst),
        .addr(tlb_index),
        .ce(tlb_mr_en),
        .we(tlb_mr_we),
        .di(tlb_mr_di),
        .doq(tlb_mr_ram_out)
    );

    or1200_spram_64x24 dmmu_tr_ram (
        .clk(clk),
        .rst(rst),
        .addr(tlb_index),
        .ce(tlb_tr_en),
        .we(tlb_tr_we),
        .di(tlb_tr_di),
        .doq(tlb_tr_ram_out)
    );
`endif

    // Decode match RAM output
    wire [31:19] vpn;
    wire v;
    assign vpn = tlb_mr_ram_out[13:1];
    assign v   = tlb_mr_ram_out[0];

    // Decode translate RAM output
    assign ppn = tlb_tr_ram_out[23:5];
    assign swe = tlb_tr_ram_out[4];
    assign sre = tlb_tr_ram_out[3];
    assign uwe = tlb_tr_ram_out[2];
    assign ure = tlb_tr_ram_out[1];
    assign ci  = tlb_tr_ram_out[0];

    // Hit generation
    assign hit = (vpn == vaddr[31:19]) & v;

    // SPR read data generation
    wire spr_read_match = spr_cs && !spr_write && (spr_addr[7] == 1'b0);
    wire spr_read_trans = spr_cs && !spr_write && (spr_addr[7] == 1'b1);

    assign spr_dat_o = spr_read_match ? {
        vpn,                               // [31:19]
        13'b0,                             // [18:6]
        (tlb_index & {6{v}}),              // [5:0]  index field masked by v
        v                                  // [0]
    } : spr_read_trans ? {
        ppn,                               // [31:13]
        3'b0,                              // [12:10]
        swe,                               // [9]
        sre,                               // [8]
        uwe,                               // [7]
        ure,                               // [6]
        4'b0,                              // [5:2]
        ci,                                // [1]
        1'b0                               // [0]
    } : 32'h00000000;

`ifdef OR1200_BIST
    // Placeholder BIST connectivity
    assign mbist_so_o = mbist_si_i; // simplified loopback
`endif

endmodule

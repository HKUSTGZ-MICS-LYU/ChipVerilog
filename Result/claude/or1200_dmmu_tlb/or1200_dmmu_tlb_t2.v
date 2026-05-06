// Data TLB
module or1200_dmmu_tlb(
    // Rst and clk
    input clk,
    input rst,

    // I/F for translation
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

// Internal signals
wire [12:0] vpn;
wire [12:0] tlb_vpn;
wire v;
wire [5:0] tlb_index;
wire tlb_mr_en;
wire tlb_mr_we;
wire [13:0] tlb_mr_ram_in;
wire [13:0] tlb_mr_ram_out;
wire tlb_tr_en;
wire tlb_tr_we;
wire [23:0] tlb_tr_ram_in;
wire [23:0] tlb_tr_ram_out;
wire mbist_mr_so;
wire mbist_tr_so;

`ifdef OR1200_BIST
wire mbist_mr_si;
wire mbist_tr_si;
assign mbist_mr_si = mbist_si_i;
assign mbist_tr_si = mbist_mr_so;
assign mbist_so_o = mbist_tr_so;
`endif

// TLB virtual page number from vaddr
assign vpn = vaddr[31:13];

// TLB index selection
assign tlb_index = tlb_en ? vaddr[18:13] : spr_addr[5:0];

// TLB match register enable and write enable
assign tlb_mr_en = tlb_en | spr_cs;
assign tlb_mr_we = spr_cs & spr_write & (spr_addr[10:9] == 2'b00);

// TLB translate register enable and write enable
assign tlb_tr_en = tlb_en | spr_cs;
assign tlb_tr_we = spr_cs & spr_write & (spr_addr[10:9] == 2'b01);

// TLB match register input packing
assign tlb_mr_ram_in = {vpn, 1'b1};

// TLB translate register input packing
assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[4], spr_dat_i[3], spr_dat_i[2], spr_dat_i[1], spr_dat_i[0]};

// Hit signal: valid and VPN match
assign tlb_vpn = tlb_mr_ram_out[13:1];
assign v = tlb_mr_ram_out[0];
assign hit = v & (tlb_vpn == vpn);

// Extract permission and cache inhibit bits from translate register
assign ppn = tlb_tr_ram_out[23:5];
assign swe = tlb_tr_ram_out[4];
assign sre = tlb_tr_ram_out[3];
assign uwe = tlb_tr_ram_out[2];
assign ure = tlb_tr_ram_out[1];
assign ci = tlb_tr_ram_out[0];

// SPR data output logic
assign spr_dat_o = (spr_cs & ~spr_write & (spr_addr[10:9] == 2'b00)) ? {18'b0, tlb_mr_ram_out[13:0]} :
                   (spr_cs & ~spr_write & (spr_addr[10:9] == 2'b01)) ? {8'b0, tlb_tr_ram_out[23:0]} :
                   32'b0;

// TLB Match Register RAM (64 entries x 14 bits)
// Stores: valid bit (1) + virtual page number (13)
or1200_tlb_ram_mr #(
    .ADDR_WIDTH(6),
    .DATA_WIDTH(14)
) tlb_mr_ram (
    .clk(clk),
    .rst(rst),
    .addr(tlb_index),
    .we(tlb_mr_we),
    .din(tlb_mr_ram_in),
    .dout(tlb_mr_ram_out)
`ifdef OR1200_BIST
    , .bist_si_i(mbist_mr_si),
    .bist_so_o(mbist_mr_so),
    .bist_ctrl_i(mbist_ctrl_i)
`endif
);

// TLB Translate Register RAM (64 entries x 24 bits)
// Stores: physical page number (19) + swe (1) + sre (1) + uwe (1) + ure (1) + ci (1)
or1200_tlb_ram_tr #(
    .ADDR_WIDTH(6),
    .DATA_WIDTH(24)
) tlb_tr_ram (
    .clk(clk),
    .rst(rst),
    .addr(tlb_index),
    .we(tlb_tr_we),
    .din(tlb_tr_ram_in),
    .dout(tlb_tr_ram_out)
`ifdef OR1200_BIST
    , .bist_si_i(mbist_tr_si),
    .bist_so_o(mbist_tr_so),
    .bist_ctrl_i(mbist_ctrl_i)
`endif
);

endmodule

// TLB Match Register RAM Module
module or1200_tlb_ram_mr #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 14
)(
    input clk,
    input rst,
    input [ADDR_WIDTH-1:0] addr,
    input we,
    input [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout
`ifdef OR1200_BIST
    , input bist_si_i,
    output bist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] bist_ctrl_i
`endif
);

reg [DATA_WIDTH-1:0] ram [0:(1 << ADDR_WIDTH) - 1];
wire [DATA_WIDTH-1:0] dout_wire;

always @(posedge clk)
    if (we)
        ram[addr] <= din;

assign dout_wire = ram[addr];
assign dout = dout_wire;

`ifdef OR1200_BIST
assign bist_so_o = 1'b0;
`endif

endmodule

// TLB Translate Register RAM Module
module or1200_tlb_ram_tr #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 24
)(
    input clk,
    input rst,
    input [ADDR_WIDTH-1:0] addr,
    input we,
    input [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout
`ifdef OR1200_BIST
    , input bist_si_i,
    output bist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] bist_ctrl_i
`endif
);

reg [DATA_WIDTH-1:0] ram [0:(1 << ADDR_WIDTH) - 1];
wire [DATA_WIDTH-1:0] dout_wire;

always @(posedge clk)
    if (we)
        ram[addr] <= din;

assign dout_wire = ram[addr];
assign dout = dout_wire;

`ifdef OR1200_BIST
assign bist_so_o = 1'b0;
`endif

endmodule

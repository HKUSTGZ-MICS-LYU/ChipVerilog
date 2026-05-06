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

localparam integer OR1200_DTLB_INDXW = 6;
localparam integer OR1200_DTLB_ENTRIES = 64;

wire [OR1200_DTLB_INDXW-1:0] tlb_index;
wire tlb_mr_en;
wire tlb_tr_en;
wire tlb_mr_we;
wire tlb_tr_we;

wire [13:0] tlb_mr_ram_in;
wire [23:0] tlb_tr_ram_in;
reg  [13:0] tlb_mr_ram_out;
reg  [23:0] tlb_tr_ram_out;

reg [13:0] tlb_mr_mem [0:OR1200_DTLB_ENTRIES-1];
reg [23:0] tlb_tr_mem [0:OR1200_DTLB_ENTRIES-1];

wire [12:0] vpn;
wire        v;

assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
assign tlb_tr_en = tlb_en | (spr_cs &  spr_addr[7]);

assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];
assign tlb_tr_we = spr_cs & spr_write &  spr_addr[7];

assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};
assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[9], spr_dat_i[8], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

assign vpn = tlb_mr_ram_out[13:1];
assign v   = tlb_mr_ram_out[0];

assign ppn = tlb_tr_ram_out[23:5];
assign swe = tlb_tr_ram_out[4];
assign sre = tlb_tr_ram_out[3];
assign uwe = tlb_tr_ram_out[2];
assign ure = tlb_tr_ram_out[1];
assign ci  = tlb_tr_ram_out[0];

assign hit = (vpn == vaddr[31:19]) & v;

assign spr_dat_o =
    (spr_cs & ~spr_write & ~spr_addr[7]) ? {vpn, (tlb_index & {OR1200_DTLB_INDXW{v}}), 12'h000, v} :
    (spr_cs & ~spr_write &  spr_addr[7]) ? {ppn, 3'b000, swe, sre, uwe, ure, 4'b0000, ci, 1'b0} :
                                            32'h0000_0000;

`ifdef OR1200_RAM_MODELS_VIRTEX
always @(posedge clk) begin
    if (tlb_mr_we)
        tlb_mr_mem[tlb_index] <= tlb_mr_ram_in;
    if (tlb_tr_we)
        tlb_tr_mem[tlb_index] <= tlb_tr_ram_in;

    if (tlb_mr_en)
        tlb_mr_ram_out <= tlb_mr_mem[tlb_index];
    if (tlb_tr_en)
        tlb_tr_ram_out <= tlb_tr_mem[tlb_index];
end
`else
integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < OR1200_DTLB_ENTRIES; i = i + 1) begin
            tlb_mr_mem[i] <= 14'h0000;
            tlb_tr_mem[i] <= 24'h000000;
        end
        tlb_mr_ram_out <= 14'h0000;
        tlb_tr_ram_out <= 24'h000000;
    end
    else begin
        if (tlb_mr_we)
            tlb_mr_mem[tlb_index] <= tlb_mr_ram_in;
        if (tlb_tr_we)
            tlb_tr_mem[tlb_index] <= tlb_tr_ram_in;

        if (tlb_mr_en)
            tlb_mr_ram_out <= tlb_mr_mem[tlb_index];
        if (tlb_tr_en)
            tlb_tr_ram_out <= tlb_tr_mem[tlb_index];
    end
end
`endif

`ifdef OR1200_BIST
wire [`OR1200_MBIST_CTRL_WIDTH - 1:0] unused_mbist_ctrl;
assign unused_mbist_ctrl = mbist_ctrl_i;
assign mbist_so_o = mbist_si_i;
`endif

endmodule

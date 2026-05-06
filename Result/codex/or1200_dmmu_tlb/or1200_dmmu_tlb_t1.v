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

localparam TLB_INDXW = 6;
localparam TLB_ENTRIES = 64;

reg [13:0] tlb_mr_ram [0:TLB_ENTRIES-1];
reg [23:0] tlb_tr_ram [0:TLB_ENTRIES-1];
reg [13:0] tlb_mr_ram_out;
reg [23:0] tlb_tr_ram_out;

wire tlb_mr_en;
wire tlb_tr_en;
wire tlb_mr_we;
wire tlb_tr_we;
wire [TLB_INDXW-1:0] tlb_index;
wire [13:0] tlb_mr_ram_in;
wire [23:0] tlb_tr_ram_in;
wire [12:0] vpn;
wire v;
wire [TLB_INDXW-1:0] masked_index;

integer i;

assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);
assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];
assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];
assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};
assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[9], spr_dat_i[8], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < TLB_ENTRIES; i = i + 1) begin
            tlb_mr_ram[i] <= 14'b0;
            tlb_tr_ram[i] <= 24'b0;
        end
    end else begin
        if (tlb_mr_we)
            tlb_mr_ram[tlb_index] <= tlb_mr_ram_in;
        if (tlb_tr_we)
            tlb_tr_ram[tlb_index] <= tlb_tr_ram_in;
    end
end

always @* begin
    if (tlb_mr_en)
        tlb_mr_ram_out = tlb_mr_ram[tlb_index];
    else
        tlb_mr_ram_out = tlb_mr_ram[tlb_index];
end

always @* begin
    if (tlb_tr_en)
        tlb_tr_ram_out = tlb_tr_ram[tlb_index];
    else
        tlb_tr_ram_out = tlb_tr_ram[tlb_index];
end

assign vpn = tlb_mr_ram_out[13:1];
assign v = tlb_mr_ram_out[0];
assign ppn = tlb_tr_ram_out[23:5];
assign swe = tlb_tr_ram_out[4];
assign sre = tlb_tr_ram_out[3];
assign uwe = tlb_tr_ram_out[2];
assign ure = tlb_tr_ram_out[1];
assign ci = tlb_tr_ram_out[0];
assign hit = (vpn == vaddr[31:19]) & v;
assign masked_index = tlb_index & {TLB_INDXW{v}};

assign spr_dat_o = (spr_cs & ~spr_write & ~spr_addr[7]) ? {vpn, masked_index, 12'b0, v} :
                   (spr_cs & ~spr_write &  spr_addr[7]) ? {ppn, 3'b000, swe, sre, uwe, ure, 4'b0000, ci, 1'b0} :
                                                          32'h00000000;

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

endmodule

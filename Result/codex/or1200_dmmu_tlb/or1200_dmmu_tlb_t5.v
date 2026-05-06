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
    output reg [31:0] spr_dat_o
);

reg [13:0] tlb_mr_ram [0:63];
reg [23:0] tlb_tr_ram [0:63];

wire tlb_mr_en;
wire tlb_tr_en;
wire tlb_mr_we;
wire tlb_tr_we;
wire [5:0] tlb_index;
wire [13:0] tlb_mr_ram_out;
wire [23:0] tlb_tr_ram_out;
wire [12:0] vpn;
wire v;
wire [5:0] mr_index_field;
integer i;

assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);
assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];
assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];
assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

assign tlb_mr_ram_out = tlb_mr_ram[tlb_index];
assign tlb_tr_ram_out = tlb_tr_ram[tlb_index];

assign vpn = tlb_mr_ram_out[13:1];
assign v = tlb_mr_ram_out[0];
assign ppn = tlb_tr_ram_out[23:5];
assign swe = tlb_tr_ram_out[4];
assign sre = tlb_tr_ram_out[3];
assign uwe = tlb_tr_ram_out[2];
assign ure = tlb_tr_ram_out[1];
assign ci = tlb_tr_ram_out[0];
assign hit = (vpn == vaddr[31:19]) & v;
assign mr_index_field = tlb_index & {6{v}};

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
wire [`OR1200_MBIST_CTRL_WIDTH - 1:0] unused_mbist_ctrl;
assign unused_mbist_ctrl = mbist_ctrl_i;
`endif

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < 64; i = i + 1) begin
            tlb_mr_ram[i] <= 14'b0;
            tlb_tr_ram[i] <= 24'b0;
        end
    end else begin
        if (tlb_mr_we)
            tlb_mr_ram[tlb_index] <= {spr_dat_i[31:19], spr_dat_i[0]};
        if (tlb_tr_we)
            tlb_tr_ram[tlb_index] <= {spr_dat_i[31:13], spr_dat_i[9], spr_dat_i[8], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};
    end
end

always @* begin
    spr_dat_o = 32'h00000000;
    if (spr_cs & ~spr_write) begin
        if (~spr_addr[7] & tlb_mr_en)
            spr_dat_o = {vpn, mr_index_field, 12'b0, v};
        else if (spr_addr[7] & tlb_tr_en)
            spr_dat_o = {ppn, 3'b000, swe, sre, uwe, ure, 4'b0000, ci, 1'b0};
    end
end

endmodule

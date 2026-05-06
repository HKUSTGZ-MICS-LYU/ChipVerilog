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
reg [13:0] tlb_mr_ram_out;
wire tlb_tr_en;
wire tlb_tr_we;
wire [21:0] tlb_tr_ram_in;
reg [21:0] tlb_tr_ram_out;
`ifdef OR1200_BIST
wire itlb_mr_ram_si;
wire itlb_mr_ram_so;
wire itlb_tr_ram_si;
wire itlb_tr_ram_so;
`endif

reg [13:0] tlb_mr_ram [0:63];
reg [21:0] tlb_tr_ram [0:63];

assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];
assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};

assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);
assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];
assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

assign vpn = tlb_mr_ram_out[13:1];
assign v = tlb_mr_ram_out[0];

assign hit = (vpn == vaddr[31:19]) & v;

assign ppn = tlb_tr_ram_out[21:3];
assign uxe = tlb_tr_ram_out[2];
assign sxe = tlb_tr_ram_out[1];
assign ci = tlb_tr_ram_out[0];

assign spr_dat_o = spr_write ? 32'h00000000 :
                   spr_addr[7] ? {ppn, 5'b00000, uxe, sxe, 4'b0000, ci, 1'b0} :
                                 {vpn, (tlb_index & {6{v}}), 12'b000000000000, v};

always @(posedge clk) begin
    if (tlb_mr_en) begin
        if (tlb_mr_we) begin
            tlb_mr_ram[tlb_index] <= tlb_mr_ram_in;
            tlb_mr_ram_out <= tlb_mr_ram_in;
        end
        else begin
            tlb_mr_ram_out <= tlb_mr_ram[tlb_index];
        end
    end

    if (tlb_tr_en) begin
        if (tlb_tr_we) begin
            tlb_tr_ram[tlb_index] <= tlb_tr_ram_in;
            tlb_tr_ram_out <= tlb_tr_ram_in;
        end
        else begin
            tlb_tr_ram_out <= tlb_tr_ram[tlb_index];
        end
    end
end

`ifdef OR1200_BIST
assign itlb_mr_ram_si = mbist_si_i;
assign itlb_mr_ram_so = itlb_mr_ram_si;
assign itlb_tr_ram_si = itlb_mr_ram_so;
assign itlb_tr_ram_so = itlb_tr_ram_si;
assign mbist_so_o = itlb_tr_ram_so;
`endif

endmodule

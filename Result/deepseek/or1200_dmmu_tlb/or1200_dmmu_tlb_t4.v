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

localparam DTLB_INDXW = 6; // 64 entries

// Internal signals
wire [5:0] tlb_index;
wire tlb_mr_en, tlb_tr_en;
wire tlb_mr_we, tlb_tr_we;
wire [13:0] tlb_mr_ram_out;
wire [23:0] tlb_tr_ram_out;

// Decoded match and translate fields
wire [12:0] vpn; // bits 31:19 of virtual page number
wire v;
wire [18:0] ppn_int; // physical page number bits 31:13 (19 bits)
wire swe_int, sre_int, uwe_int, ure_int, ci_int;

// TLB index selection
assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

// RAM enable signals
assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);

// RAM write enable signals
assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];
assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];

// Match RAM instantiation (64x14)
or1200_spram_64x14 match_ram (
    .clk(clk),
    .rst(rst),
    .ce(tlb_mr_en),
    .we(tlb_mr_we),
    .addr(tlb_index),
    .di({spr_dat_i[31:19], spr_dat_i[0]}),
    .do(tlb_mr_ram_out)
`ifdef OR1200_BIST
    ,.mbist_si_i(mbist_si_i),
    .mbist_so_o(),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

// Translate RAM instantiation (64x24)
or1200_spram_64x24 trans_ram (
    .clk(clk),
    .rst(rst),
    .ce(tlb_tr_en),
    .we(tlb_tr_we),
    .addr(tlb_index),
    .di({spr_dat_i[31:13], spr_dat_i[9], spr_dat_i[8], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]}),
    .do(tlb_tr_ram_out)
`ifdef OR1200_BIST
    ,.mbist_si_i(mbist_si_i),
    .mbist_so_o(),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

// Decode match RAM output
assign vpn = tlb_mr_ram_out[13:1];
assign v   = tlb_mr_ram_out[0];

// Decode translate RAM output
assign ppn_int = tlb_tr_ram_out[23:5];
assign swe_int = tlb_tr_ram_out[4];
assign sre_int = tlb_tr_ram_out[3];
assign uwe_int = tlb_tr_ram_out[2];
assign ure_int = tlb_tr_ram_out[1];
assign ci_int  = tlb_tr_ram_out[0];

// Hit generation
assign hit = (vpn == vaddr[31:19]) & v;

// Output assignments
assign ppn = ppn_int;
assign swe = swe_int;
assign sre = sre_int;
assign uwe = uwe_int;
assign ure = ure_int;
assign ci  = ci_int;

// SPR read data
reg [31:0] spr_dat_o;
always @(*) begin
    if (spr_cs && !spr_write) begin
        if (!spr_addr[7]) begin
            // Match register read
            spr_dat_o[31:19] = vpn;
            spr_dat_o[18:13] = tlb_index & {DTLB_INDXW{v}};
            spr_dat_o[12:1]  = 12'b0;
            spr_dat_o[0]     = v;
        end else begin
            // Translate register read
            spr_dat_o[31:13] = ppn_int;
            spr_dat_o[12:10] = 3'b0;
            spr_dat_o[9]     = swe_int;
            spr_dat_o[8]     = sre_int;
            spr_dat_o[7]     = uwe_int;
            spr_dat_o[6]     = ure_int;
            spr_dat_o[5:2]   = 4'b0;
            spr_dat_o[1]     = ci_int;
            spr_dat_o[0]     = 1'b0;
        end
    end else begin
        spr_dat_o = 32'h00000000;
    end
end

`ifdef OR1200_BIST
// MBIST scan output from last RAM instance (if needed)
assign mbist_so_o = 1'b0; // Placeholder, adjust based on actual RAM wiring
`endif

endmodule

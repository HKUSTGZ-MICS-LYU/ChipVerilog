// Generated from or1200_immu_tlb/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
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

reg hit_r;
reg [31:13] ppn_r;
reg uxe_r;
reg sxe_r;
reg ci_r;
`ifdef OR1200_BIST
reg mbist_so_o_r;
`endif
reg [31:0] spr_dat_o_r;
assign hit = hit_r;
assign ppn = ppn_r;
assign uxe = uxe_r;
assign sxe = sxe_r;
assign ci = ci_r;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_so_o_r;
`endif
assign spr_dat_o = spr_dat_o_r;

reg [13:0] mr_mem [0:63];
reg [20:0] tr_mem [0:63];
reg [5:0] tlb_index;
reg [13:0] mr_data;
reg [20:0] tr_data;

always @(posedge clk) begin
    tlb_index <= spr_cs ? spr_addr[13:8] : vaddr[18:13];
    if (spr_cs && spr_write) begin
        if (spr_addr[10])
            tr_mem[spr_addr[13:8]] <= spr_dat_i[20:0];
        else
            mr_mem[spr_addr[13:8]] <= spr_dat_i[13:0];
    end
    mr_data <= mr_mem[tlb_index];
    tr_data <= tr_mem[tlb_index];
end

always @* begin
    hit_r = tlb_en && mr_data[13] && (mr_data[12:0] == vaddr[31:19]);
    ppn_r = tr_data[20:2];
    uxe_r = tr_data[1];
    sxe_r = tr_data[0];
    ci_r = 1'b0;
    spr_dat_o_r = spr_addr[10] ? {11'd0, tr_mem[spr_addr[13:8]]} : {18'd0, mr_mem[spr_addr[13:8]]};
`ifdef OR1200_BIST
    mbist_so_o_r = mbist_si_i;
`endif
end

endmodule

module or1200_immu_top(
    input clk,
    input rst,
    input [31:0] vaddr,
    input [31:0] paddr_i,
    input we,
    input valid,
    input immu_en,
    output [31:0] paddr_o,
    output tlb_miss
);

    wire [31:0] tlb_paddr;
    wire tlb_hit;

    assign tlb_miss = !tlb_hit & immu_en;
    assign paddr_o = tlb_hit ? tlb_paddr : vaddr;

    or1200_immu_tlb tlb_inst(
        .clk(clk),
        .rst(rst),
        .vaddr(vaddr),
        .paddr(paddr_i),
        .we(we),
        .valid(valid),
        .paddr_out(tlb_paddr),
        .hit(tlb_hit)
    );

endmodule

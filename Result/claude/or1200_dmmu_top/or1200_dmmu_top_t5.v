module or1200_dmmu_top(
    input clk,
    input rst,
    input [31:0] vaddr,
    input [31:0] paddr_i,
    input we,
    input valid,
    input dmmu_en,
    output [31:0] paddr_o,
    output tlb_miss
);

    wire [31:0] tlb_paddr;
    wire tlb_hit;

    assign tlb_miss = !tlb_hit & dmmu_en;
    assign paddr_o = tlb_hit ? tlb_paddr : vaddr;

    or1200_dmmu_tlb tlb_inst(
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

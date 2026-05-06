module or1200_immu_tlb(
    input clk,
    input rst,
    input [31:0] vaddr,
    input [31:0] paddr,
    input we,
    output reg [31:0] paddr_out,
    output reg hit
);

    reg [31:0] tlb_vaddr [0:15];
    reg [31:0] tlb_paddr [0:15];
    reg [15:0] tlb_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tlb_valid <= 16'b0;
        end else if (we) begin
            tlb_vaddr[vaddr[3:0]] <= vaddr;
            tlb_paddr[vaddr[3:0]] <= paddr;
            tlb_valid[vaddr[3:0]] <= 1'b1;
        end
    end

    always @(*) begin
        if (tlb_valid[vaddr[3:0]] && tlb_vaddr[vaddr[3:0]] == vaddr) begin
            hit = 1'b1;
            paddr_out = tlb_paddr[vaddr[3:0]];
        end else begin
            hit = 1'b0;
            paddr_out = vaddr;
        end
    end

endmodule

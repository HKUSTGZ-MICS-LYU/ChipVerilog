module or1200_dmmu_tlb(
    input clk,
    input rst,
    input [31:0] vaddr,
    input [31:0] paddr,
    input we,
    input valid,
    output [31:0] paddr_out,
    output hit
);

    reg [31:0] tlb_vaddr [0:63];
    reg [31:0] tlb_paddr [0:63];
    reg [63:0] tlb_valid;
    reg [5:0] tlb_ptr;
    
    wire [5:0] vaddr_idx = vaddr[13:8];
    wire vaddr_match = (tlb_vaddr[vaddr_idx] == vaddr[31:12]);

    assign paddr_out = tlb_paddr[vaddr_idx];
    assign hit = tlb_valid[vaddr_idx] & vaddr_match;

    always @(posedge clk) begin
        if (rst) begin
            tlb_valid <= 64'b0;
            tlb_ptr <= 6'b0;
        end
        else if (we) begin
            tlb_vaddr[tlb_ptr] <= vaddr;
            tlb_paddr[tlb_ptr] <= paddr;
            tlb_valid[tlb_ptr] <= valid;
            tlb_ptr <= tlb_ptr + 1;
        end
    end

endmodule

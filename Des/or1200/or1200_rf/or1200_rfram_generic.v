`include "timescale.v"

module or1200_rfram_generic (
    input              clk,
    input              rst,
    input              ce_a,
    input      [4:0]   addr_a,
    output reg [31:0]  do_a,
    input              ce_b,
    input      [4:0]   addr_b,
    output reg [31:0]  do_b,
    input              ce_w,
    input              we_w,
    input      [4:0]   addr_w,
    input      [31:0]  di_w
);

reg [31:0] mem [0:31];
integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < 32; i = i + 1)
            mem[i] <= 32'h0;
        do_a <= 32'h0;
        do_b <= 32'h0;
    end else begin
        if (ce_w && we_w)
            mem[addr_w] <= di_w;

        if (ce_a)
            do_a <= (addr_a == 5'd0) ? 32'h0 : mem[addr_a];
        if (ce_b)
            do_b <= (addr_b == 5'd0) ? 32'h0 : mem[addr_b];
    end
end

endmodule

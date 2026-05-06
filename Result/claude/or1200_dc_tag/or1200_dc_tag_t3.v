module or1200_dc_tag(
    input clk,
    input rst,
    input [8:0] addr,
    input en,
    input we,
    input [19:0] datain,
    output tag_v,
    output [18:0] tag
);

    reg [19:0] mem [0:511];
    
    assign {tag_v, tag} = mem[addr];

    always @(posedge clk) begin
        if (en & we) begin
            mem[addr] <= datain;
        end
    end

endmodule

module or1200_reg2mem(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] regdata,
    output [31:0] memdata
);

localparam [3:0] LSUOP_SB = 4'b1000;
localparam [3:0] LSUOP_SH = 4'b1001;
localparam [3:0] LSUOP_SW = 4'b1010;

reg [7:0] memdata_hh;
reg [7:0] memdata_hl;
reg [7:0] memdata_lh;
reg [7:0] memdata_ll;

always @* begin
    casex ({lsu_op, addr})
        {LSUOP_SB, 2'b00}: memdata_hh = regdata[7:0];
        {LSUOP_SH, 2'b00}: memdata_hh = regdata[15:8];
        default: memdata_hh = regdata[31:24];
    endcase
end

always @* begin
    casex ({lsu_op, addr})
        {LSUOP_SW, 2'b00}: memdata_hl = regdata[23:16];
        default: memdata_hl = regdata[7:0];
    endcase
end

always @* begin
    casex ({lsu_op, addr})
        {LSUOP_SB, 2'b10}: memdata_lh = regdata[7:0];
        default: memdata_lh = regdata[15:8];
    endcase
end

always @* begin
    memdata_ll = regdata[7:0];
end

assign memdata = {memdata_hh, memdata_hl, memdata_lh, memdata_ll};

endmodule

module or1200_reg2mem(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] regdata,
    output [31:0] memdata
);

    localparam SB = 4'b0110;
    localparam SH = 4'b0111;
    localparam SW = 4'b0101;

    reg [7:0] memdata_hh;
    reg [7:0] memdata_hl;
    reg [7:0] memdata_lh;
    reg [7:0] memdata_ll;

    always @(*) begin
        memdata_hh = regdata[31:24];
        memdata_hl = regdata[7:0];
        memdata_lh = regdata[15:8];

        casex({lsu_op, addr[1:0]})
            6'b0110_00: memdata_hh = regdata[7:0];     // SB, addr=00
            6'b0111_00: memdata_hh = regdata[15:8];    // SH, addr=00
            6'b0101_00: memdata_hl = regdata[23:16];   // SW, addr=00
            6'b0110_10: memdata_lh = regdata[7:0];     // SB, addr=10
        endcase
    end

    assign memdata = {memdata_hh, memdata_hl, memdata_lh, regdata[7:0]};

endmodule

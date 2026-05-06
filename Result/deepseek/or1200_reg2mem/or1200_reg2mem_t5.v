module or1200_reg2mem (
    input  [1:0]  addr,
    input  [3:0]  lsu_op,
    input  [31:0] regdata,
    output [31:0] memdata
);

    reg [7:0] memdata_hh;
    reg [7:0] memdata_hl;
    reg [7:0] memdata_lh;
    reg [7:0] memdata_ll;

    localparam [3:0] SB = 4'b0000;
    localparam [3:0] SH = 4'b0010;
    localparam [3:0] SW = 4'b0100;

    always @(*) begin
        // default assignments
        memdata_hh = regdata[31:24];
        memdata_hl = regdata[7:0];
        memdata_lh = regdata[15:8];
        memdata_ll = regdata[7:0];

        // overrides based on operation and address
        casex ({lsu_op, addr[1:0]})
            {SB, 2'b00}: memdata_hh = regdata[7:0];
            {SH, 2'b00}: memdata_hh = regdata[15:8];
            {SW, 2'b00}: memdata_hl = regdata[23:16];
            {SB, 2'b10}: memdata_lh = regdata[7:0];
        endcase
    end

    assign memdata = {memdata_hh, memdata_hl, memdata_lh, memdata_ll};

endmodule

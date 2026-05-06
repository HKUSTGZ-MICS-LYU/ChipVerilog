module or1200_reg2mem (
    input  wire [1:0] addr,
    input  wire [3:0] lsu_op,
    input  wire [31:0] regdata,
    output wire [31:0] memdata
);

    localparam SB = 4'b0010;
    localparam SH = 4'b0011;
    localparam SW = 4'b0100;

    reg [7:0] memdata_hh;
    reg [7:0] memdata_hl;
    reg [7:0] memdata_lh;
    reg [7:0] memdata_ll;

    always @(*) begin
        casex ({lsu_op, addr})
            {SB, 2'b00} : begin
                memdata_hh = regdata[7:0];
                memdata_hl = regdata[7:0];
                memdata_lh = regdata[7:0];
                memdata_ll = regdata[7:0];
            end
            {SB, 2'b10} : begin
                memdata_hh = regdata[31:24];
                memdata_hl = regdata[7:0];
                memdata_lh = regdata[7:0];
                memdata_ll = regdata[7:0];
            end
            {SH, 2'b00} : begin
                memdata_hh = regdata[15:8];
                memdata_hl = regdata[7:0];
                memdata_lh = regdata[15:8];
                memdata_ll = regdata[7:0];
            end
            {SW, 2'b00} : begin
                memdata_hh = regdata[31:24];
                memdata_hl = regdata[23:16];
                memdata_lh = regdata[15:8];
                memdata_ll = regdata[7:0];
            end
            default : begin
                memdata_hh = regdata[31:24];
                memdata_hl = regdata[7:0];
                memdata_lh = regdata[15:8];
                memdata_ll = regdata[7:0];
            end
        endcase
    end

    assign memdata = {memdata_hh, memdata_hl, memdata_lh, memdata_ll};

endmodule

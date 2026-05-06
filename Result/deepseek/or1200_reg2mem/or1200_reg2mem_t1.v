// or1200_reg2mem: store write-data alignment module
// Converts regdata into memdata based on lsu_op and addr[1:0]
// No clock, reset, or state -- fully combinational

module or1200_reg2mem(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] regdata,
    output [31:0] memdata
);

    // Internal byte lanes (combinational regs)
    reg [7:0] memdata_hh;  // memdata[31:24]
    reg [7:0] memdata_hl;  // memdata[23:16]
    reg [7:0] memdata_lh;  // memdata[15:8]
    reg [7:0] memdata_ll;  // memdata[7:0]

    // SB, SH, SW opcode definitions (OR1200 LSU encodings)
    // These are typical values; actual encoding matches original OR1200
    localparam OR1200_LSU_SB = 4'b0100;  // store byte
    localparam OR1200_LSU_SH = 4'b0101;  // store halfword
    localparam OR1200_LSU_SW = 4'b0110;  // store word

    // Generate highest byte memdata[31:24]
    always @(*) begin
        casex ({lsu_op, addr})
            {OR1200_LSU_SB, 2'b00}:  memdata_hh = regdata[7:0];
            {OR1200_LSU_SH, 2'b00}:  memdata_hh = regdata[15:8];
            default:                 memdata_hh = regdata[31:24];
        endcase
    end

    // Generate memdata[23:16]
    always @(*) begin
        casex ({lsu_op, addr})
            {OR1200_LSU_SW, 2'b00}:  memdata_hl = regdata[23:16];
            default:                 memdata_hl = regdata[7:0];
        endcase
    end

    // Generate memdata[15:8]
    always @(*) begin
        casex ({lsu_op, addr})
            {OR1200_LSU_SB, 2'b10}:  memdata_lh = regdata[7:0];
            default:                 memdata_lh = regdata[15:8];
        endcase
    end

    // Lowest byte always from regdata[7:0]
    always @(*) begin
        memdata_ll = regdata[7:0];
    end

    // Concatenate byte lanes to form final memdata
    assign memdata = {memdata_hh, memdata_hl, memdata_lh, memdata_ll};

endmodule

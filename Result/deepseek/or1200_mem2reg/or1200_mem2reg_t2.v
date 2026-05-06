module or1200_mem2reg(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] memdata,
    output [31:0] regdata
);

    // Define LSU operation encodings
    // These match typical OR1200 LSU opcodes
    localparam LSU_LB  = 4'b0000; // Load byte unsigned
    localparam LSU_LH  = 4'b0001; // Load halfword unsigned
    localparam LSU_LW  = 4'b0010; // Load word
    localparam LSU_LBU = 4'b0011; // Load byte unsigned (alias)
    localparam LSU_LHU = 4'b0100; // Load halfword unsigned (alias)
    localparam LSU_LBS = 4'b0101; // Load byte signed
    localparam LSU_LHS = 4'b0110; // Load halfword signed

    wire [7:0] byte0, byte1, byte2, byte3;
    wire [15:0] half0, half1;
    reg [31:0] regdata;

    // Byte lanes from memdata (big-endian ordering as per spec:
    // addr[1:0]==00 -> MSB byte, 01 -> next, 10 -> next, 11 -> LSB)
    assign byte3 = memdata[31:24]; // addr 00
    assign byte2 = memdata[23:16]; // addr 01
    assign byte1 = memdata[15:8];  // addr 10
    assign byte0 = memdata[7:0];   // addr 11

    // Halfword lanes
    assign half1 = {byte3, byte2}; // addr 00
    assign half0 = {byte1, byte0}; // addr 10

    always @(*) begin
        case (lsu_op)
            LSU_LB, LSU_LBU: begin
                // Unsigned byte load
                case (addr)
                    2'b00: regdata = {24'b0, byte3};
                    2'b01: regdata = {24'b0, byte2};
                    2'b10: regdata = {24'b0, byte1};
                    2'b11: regdata = {24'b0, byte0};
                    default: regdata = 32'b0;
                endcase
            end
            LSU_LBS: begin
                // Signed byte load
                case (addr)
                    2'b00: regdata = {{24{byte3[7]}}, byte3};
                    2'b01: regdata = {{24{byte2[7]}}, byte2};
                    2'b10: regdata = {{24{byte1[7]}}, byte1};
                    2'b11: regdata = {{24{byte0[7]}}, byte0};
                    default: regdata = 32'b0;
                endcase
            end
            LSU_LH, LSU_LHU: begin
                // Unsigned halfword load
                case (addr[1])
                    1'b0: regdata = {16'b0, half1}; // addr 00
                    1'b1: regdata = {16'b0, half0}; // addr 10
                    default: regdata = 32'b0;
                endcase
            end
            LSU_LHS: begin
                // Signed halfword load
                case (addr[1])
                    1'b0: regdata = {{16{half1[15]}}, half1}; // addr 00
                    1'b1: regdata = {{16{half0[15]}}, half0}; // addr 10
                    default: regdata = 32'b0;
                endcase
            end
            LSU_LW: begin
                // Word load (assumed aligned addr=00)
                regdata = memdata;
            end
            default: begin
                regdata = 32'b0;
            end
        endcase
    end

endmodule

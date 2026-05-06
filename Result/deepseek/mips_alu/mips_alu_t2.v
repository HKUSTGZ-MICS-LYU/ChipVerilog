module alu
(
    input       [15:0]  a,
    input       [15:0]  b,
    input       [2:0]   cmd,
    output reg  [15:0]  r
);

    // ALU operation macros
    localparam ALU_ADD = 3'b000;
    localparam ALU_SUB = 3'b001;
    localparam ALU_AND = 3'b010;
    localparam ALU_OR  = 3'b011;
    localparam ALU_XOR = 3'b100;
    localparam ALU_SL  = 3'b101;
    localparam ALU_SR  = 3'b110;
    localparam ALU_SRU = 3'b111;
    localparam ALU_NC  = 3'bxxx; // Don't care, defined as needed

    always @(*) begin
        case (cmd)
            ALU_ADD: r = a + b;
            ALU_SUB: r = a - b;
            ALU_AND: r = a & b;
            ALU_OR:  r = a | b;
            ALU_XOR: r = a ^ b;
            ALU_SL:  r = a << b;
            ALU_SR:  r = {{16{a[15]}}, a} >> b;
            ALU_SRU: r = {16'b0, a} >> b;
            default: begin
                `ifndef CODE_FOR_SYNTHESIS
                    $display("Error: Unknown ALU command %b", cmd);
                `endif
                r = 16'h0;
            end
        endcase
    end

endmodule

`ifndef ALU_ADD
`define ALU_ADD 3'b000
`define ALU_SUB 3'b001
`define ALU_AND 3'b010
`define ALU_OR  3'b011
`define ALU_XOR 3'b100
`define ALU_SL  3'b101
`define ALU_SR  3'b110
`define ALU_SRU 3'b111
`define ALU_NC  3'bxxx
`endif

module alu
(
    input      [15:0] a,
    input      [15:0] b,
    input      [2:0]  cmd,
    output reg [15:0] r
);

always @(*) begin
    case (cmd)
        `ALU_ADD: r = a + b;
        `ALU_SUB: r = a - b;
        `ALU_AND: r = a & b;
        `ALU_OR:  r = a | b;
        `ALU_XOR: r = a ^ b;
        `ALU_SL:  r = a << b;
        `ALU_SR:  r = ({{16{a[15]}}, a} >> b)[15:0];
        `ALU_SRU: r = ({16'b0, a} >> b)[15:0];
        `ALU_NC:  r = 16'bx;
        default: begin
            r = 16'b0;
`ifndef CODE_FOR_SYNTHESIS
            $display("ERROR: alu: unknown cmd %b", cmd);
`endif
        end
    endcase
end

endmodule

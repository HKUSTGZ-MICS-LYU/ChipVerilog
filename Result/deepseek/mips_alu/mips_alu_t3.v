`include "mips_16_defs.v"

module alu
(
    input  [15:0] a,
    input  [15:0] b,
    input  [2:0]  cmd,
    output reg [15:0] r
);

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
        ALU_NC:  r = {16{1'bx}};
        default: begin
            r = 16'b0;
`ifndef CODE_FOR_SYNTHESIS
            $display("Error: unknown ALU command %b", cmd);
`endif
        end
    endcase
end

endmodule

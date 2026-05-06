module alu
(
    input      [15:0] a,
    input      [15:0] b,
    input      [2:0]  cmd,
    output reg [15:0] r
);

localparam [2:0] ALU_ADD = 3'b000;
localparam [2:0] ALU_SUB = 3'b001;
localparam [2:0] ALU_AND = 3'b010;
localparam [2:0] ALU_OR  = 3'b011;
localparam [2:0] ALU_XOR = 3'b100;
localparam [2:0] ALU_SL  = 3'b101;
localparam [2:0] ALU_SR  = 3'b110;
localparam [2:0] ALU_SRU = 3'b111;
localparam [2:0] ALU_NC  = 3'bxxx;

always @(*) begin
    case (cmd)
        ALU_ADD: r = a + b;
        ALU_SUB: r = a - b;
        ALU_AND: r = a & b;
        ALU_OR:  r = a | b;
        ALU_XOR: r = a ^ b;
        ALU_SL:  r = a << b;
        ALU_SR:  r = ({{16{a[15]}}, a} >> b);
        ALU_SRU: r = ({16'b0, a} >> b);
        ALU_NC:  r = 16'bx;
        default: begin
            r = 16'b0;
`ifndef CODE_FOR_SYNTHESIS
            $display("ERROR: unknown alu cmd %b", cmd);
`endif
        end
    endcase
end

endmodule

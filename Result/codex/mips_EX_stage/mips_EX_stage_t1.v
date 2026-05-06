module EX_stage
(
    input                   clk,
    input                   rst,
    input       [56:0]      pipeline_reg_in,
    output  reg [37:0]      pipeline_reg_out,
    output      [2:0]       ex_op_dest
);

wire [2:0]  alu_cmd;
wire [15:0] alu_src1;
wire [15:0] alu_src2;
wire [15:0] ex_alu_result;

assign alu_cmd    = pipeline_reg_in[56:54];
assign alu_src1   = pipeline_reg_in[53:38];
assign alu_src2   = pipeline_reg_in[37:22];
assign ex_op_dest = pipeline_reg_in[3:1];

alu alu_inst
(
    .alu_src1(alu_src1),
    .alu_src2(alu_src2),
    .alu_cmd(alu_cmd),
    .ex_alu_result(ex_alu_result)
);

always @(posedge clk) begin
    if (rst) begin
        pipeline_reg_out <= 38'b0;
    end
    else begin
        pipeline_reg_out[37:22] <= ex_alu_result;
        pipeline_reg_out[21:0]  <= pipeline_reg_in[21:0];
    end
end

endmodule

module alu
(
    input      [15:0] alu_src1,
    input      [15:0] alu_src2,
    input      [2:0]  alu_cmd,
    output reg [15:0] ex_alu_result
);

always @(*) begin
    case (alu_cmd)
        3'b000: ex_alu_result = alu_src1 + alu_src2;
        3'b001: ex_alu_result = alu_src1 - alu_src2;
        3'b010: ex_alu_result = alu_src1 & alu_src2;
        3'b011: ex_alu_result = alu_src1 | alu_src2;
        3'b100: ex_alu_result = alu_src1 ^ alu_src2;
        3'b101: ex_alu_result = ($signed(alu_src1) < $signed(alu_src2)) ? 16'h0001 : 16'h0000;
        3'b110: ex_alu_result = alu_src2 << alu_src1[3:0];
        3'b111: ex_alu_result = alu_src2 >> alu_src1[3:0];
        default: ex_alu_result = 16'h0000;
    endcase
end

endmodule

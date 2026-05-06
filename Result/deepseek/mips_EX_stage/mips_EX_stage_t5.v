module EX_stage (
    input clk,
    input rst,
    input [56:0] pipeline_reg_in,
    output reg [37:0] pipeline_reg_out,
    output [2:0] ex_op_dest
);

    // Extract fields from pipeline_reg_in
    wire [2:0] alu_cmd = pipeline_reg_in[56:54];
    wire [15:0] alu_src1 = pipeline_reg_in[53:38];
    wire [15:0] alu_src2 = pipeline_reg_in[37:22];
    // Memory control (bits [21:5]) and write-back control (bits [4:0]) are passed through directly.

    // Internal ALU result wire
    wire [15:0] ex_alu_result;

    // Instantiate ALU
    alu alu_inst (
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_cmd(alu_cmd),
        .ex_alu_result(ex_alu_result)
    );

    // Output to hazard detection unit (combinational)
    assign ex_op_dest = pipeline_reg_in[3:1];

    // Sequential logic for pipeline register output
    always @(posedge clk) begin
        if (rst) begin
            pipeline_reg_out <= 37'd0;
        end else begin
            pipeline_reg_out[37:22] <= ex_alu_result;
            pipeline_reg_out[21:0]  <= pipeline_reg_in[21:0];
        end
    end

endmodule

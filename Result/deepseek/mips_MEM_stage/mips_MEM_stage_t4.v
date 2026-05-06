module MEM_stage
(
    input wire clk,
    input wire rst,
    input wire [37:0] pipeline_reg_in,
    output reg [36:0] pipeline_reg_out,
    output wire [2:0] mem_op_dest
);

wire [15:0] ex_alu_result;
wire mem_write_en;
wire [15:0] mem_write_data;
wire [4:0] wb_control;
wire [15:0] mem_read_data;

assign ex_alu_result = pipeline_reg_in[37:22];
assign mem_write_en = pipeline_reg_in[21];
assign mem_write_data = pipeline_reg_in[20:5];
assign wb_control = pipeline_reg_in[4:0];
assign mem_op_dest = pipeline_reg_in[3:1];

data_mem dmem (
    .clk(clk),
    .wr_en(mem_write_en),
    .addr(ex_alu_result),
    .din(mem_write_data),
    .dout(mem_read_data)
);

always @(posedge clk) begin
    if (rst) begin
        pipeline_reg_out <= 37'd0;
    end else begin
        pipeline_reg_out[36:21] <= ex_alu_result;
        pipeline_reg_out[20:5] <= mem_read_data;
        pipeline_reg_out[4:0] <= wb_control;
    end
end

endmodule

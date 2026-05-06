module WB_stage
(
    input       [36:0] pipeline_reg_in,
    output             reg_write_en,
    output      [2:0]  reg_write_dest,
    output      [15:0] reg_write_data,
    output      [2:0]  wb_op_dest
);

wire [15:0] ex_alu_result;
wire [15:0] mem_read_data;
wire        write_back_result_mux;

assign ex_alu_result         = pipeline_reg_in[36:21];
assign mem_read_data         = pipeline_reg_in[20:5];
assign reg_write_en          = pipeline_reg_in[4];
assign reg_write_dest        = pipeline_reg_in[3:1];
assign write_back_result_mux = pipeline_reg_in[0];
assign reg_write_data        = write_back_result_mux ? mem_read_data : ex_alu_result;
assign wb_op_dest            = pipeline_reg_in[3:1];

endmodule

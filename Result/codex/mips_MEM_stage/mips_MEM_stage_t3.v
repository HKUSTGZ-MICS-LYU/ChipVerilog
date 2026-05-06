module data_mem
(
    input              clk,
    input      [15:0]  mem_access_addr,
    input      [15:0]  mem_write_data,
    input              mem_write_en,
    output     [15:0]  mem_read_data
);
    reg [15:0] mem_array [0:65535];

    assign mem_read_data = mem_array[mem_access_addr];

    always @(posedge clk) begin
        if (mem_write_en) begin
            mem_array[mem_access_addr] <= mem_write_data;
        end
    end
endmodule

module MEM_stage
(
    input               clk,
    input               rst,
    input      [37:0]   pipeline_reg_in,
    output reg [36:0]   pipeline_reg_out,
    output     [2:0]    mem_op_dest
);
    wire [15:0] ex_alu_result;
    wire        mem_write_en;
    wire [15:0] mem_write_data;
    wire [15:0] mem_read_data;

    assign ex_alu_result  = pipeline_reg_in[37:22];
    assign mem_write_en   = pipeline_reg_in[21];
    assign mem_write_data = pipeline_reg_in[20:5];
    assign mem_op_dest    = pipeline_reg_in[3:1];

    data_mem dmem (
        .clk(clk),
        .mem_access_addr(ex_alu_result),
        .mem_write_data(mem_write_data),
        .mem_write_en(mem_write_en),
        .mem_read_data(mem_read_data)
    );

    always @(posedge clk) begin
        if (rst) begin
            pipeline_reg_out <= 37'b0;
        end else begin
            pipeline_reg_out[36:21] <= ex_alu_result;
            pipeline_reg_out[20:5]  <= mem_read_data;
            pipeline_reg_out[4:0]   <= pipeline_reg_in[4:0];
        end
    end
endmodule

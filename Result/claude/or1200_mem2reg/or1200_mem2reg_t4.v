module or1200_mem2reg(
    input clk,
    input rst,
    input [31:0] mem_data,
    input [3:0] mem_sel,
    input [1:0] mem_type,
    output reg [31:0] reg_data
);

    always @(posedge clk) begin
        if (rst) begin
            reg_data <= 32'b0;
        end
        else begin
            case (mem_type)
                2'b00: reg_data <= mem_data;
                2'b01: begin
                    case (mem_sel[1:0])
                        2'b00: reg_data <= {{24{mem_data[7]}}, mem_data[7:0]};
                        2'b01: reg_data <= {{24{mem_data[15]}}, mem_data[15:8]};
                        2'b10: reg_data <= {{24{mem_data[23]}}, mem_data[23:16]};
                        2'b11: reg_data <= {{24{mem_data[31]}}, mem_data[31:24]};
                    endcase
                end
                2'b10: begin
                    case (mem_sel[2])
                        1'b0: reg_data <= {{16{mem_data[15]}}, mem_data[15:0]};
                        1'b1: reg_data <= {{16{mem_data[31]}}, mem_data[31:16]};
                    endcase
                end
                default: reg_data <= mem_data;
            endcase
        end
    end

endmodule

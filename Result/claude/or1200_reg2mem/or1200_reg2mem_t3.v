module or1200_reg2mem(
    input clk,
    input rst,
    input [31:0] reg_data,
    input [3:0] reg_sel,
    input [1:0] reg_type,
    output reg [31:0] mem_data
);

    always @(posedge clk) begin
        if (rst) begin
            mem_data <= 32'b0;
        end
        else begin
            case (reg_type)
                2'b00: mem_data <= reg_data;
                2'b01: begin
                    case (reg_sel[1:0])
                        2'b00: mem_data <= {24'b0, reg_data[7:0]};
                        2'b01: mem_data <= {24'b0, reg_data[15:8]};
                        2'b10: mem_data <= {24'b0, reg_data[23:16]};
                        2'b11: mem_data <= {24'b0, reg_data[31:24]};
                    endcase
                end
                2'b10: begin
                    case (reg_sel[2])
                        1'b0: mem_data <= {16'b0, reg_data[15:0]};
                        1'b1: mem_data <= {16'b0, reg_data[31:16]};
                    endcase
                end
                default: mem_data <= reg_data;
            endcase
        end
    end

endmodule

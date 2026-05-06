module or1200_except(
    input clk,
    input rst,
    input [31:0] id_pc,
    input [31:0] ex_pc,
    input [31:0] wb_pc,
    input icpu_err_i,
    input dcpu_err_i,
    input sig_int,
    input sig_tick,
    input ex_align,
    input ex_illegal,
    input lsu_align,
    input except_enable,
    output reg [31:0] except_pc,
    output reg except_start,
    output wire except_type,
    output reg [12:0] except_stop
);

    reg [3:0] except_type_reg;
    
    assign except_type = except_start ? 1'b1 : 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            except_start <= 1'b0;
            except_type_reg <= 4'b0;
            except_pc <= 32'b0;
            except_stop <= 13'b0;
        end
        else if (except_enable) begin
            if (icpu_err_i) begin
                except_start <= 1'b1;
                except_type_reg <= 4'b1;
                except_pc <= id_pc;
            end
            else if (dcpu_err_i) begin
                except_start <= 1'b1;
                except_type_reg <= 4'b0101;
                except_pc <= ex_pc;
            end
            else if (sig_int) begin
                except_start <= 1'b1;
                except_type_reg <= 4'b1000;
                except_pc <= wb_pc;
            end
            else if (sig_tick) begin
                except_start <= 1'b1;
                except_type_reg <= 4'b1001;
                except_pc <= wb_pc;
            end
            else if (ex_illegal) begin
                except_start <= 1'b1;
                except_type_reg <= 4'b0010;
                except_pc <= ex_pc;
            end
            else if (ex_align) begin
                except_start <= 1'b1;
                except_type_reg <= 4'b0011;
                except_pc <= ex_pc;
            end
            else if (lsu_align) begin
                except_start <= 1'b1;
                except_type_reg <= 4'b0011;
                except_pc <= ex_pc;
            end
            else begin
                except_start <= 1'b0;
            end
        end
        else begin
            except_start <= 1'b0;
        end
    end

endmodule

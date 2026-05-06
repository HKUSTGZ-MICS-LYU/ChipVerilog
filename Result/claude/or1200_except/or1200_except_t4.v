module or1200_except(
    input clk,
    input rst,
    input [31:0] pc,
    input illegal,
    input trap,
    input system_call,
    input data_bus_err,
    input inst_bus_err,
    output reg except_active,
    output reg [31:0] except_addr,
    output reg [3:0] except_type
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            except_active <= 1'b0;
            except_addr <= 32'hFFFFFFFF;
            except_type <= 4'b0;
        end else begin
            except_active <= illegal | trap | system_call | data_bus_err | inst_bus_err;
            
            if (inst_bus_err)
                except_type <= 4'b0000;
            else if (data_bus_err)
                except_type <= 4'b0001;
            else if (illegal)
                except_type <= 4'b0010;
            else if (system_call)
                except_type <= 4'b0011;
            else if (trap)
                except_type <= 4'b0100;
            
            except_addr <= 32'hFFFF0000 + {{28'b0, except_type}, 2'b00};
        end
    end

endmodule

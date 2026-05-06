module or1200_du(
    input clk,
    input rst,
    input [31:0] du_addr,
    input [31:0] du_dat_write,
    input du_read,
    input du_write,
    input du_stall,
    output [31:0] du_dat_read,
    output du_hwbkpt,
    output [12:0] du_except
);

    reg [31:0] bkpt_addr;
    reg [31:0] status_reg;
    
    assign du_hwbkpt = (du_addr == bkpt_addr) & du_read;
    assign du_except = 13'b0;
    
    assign du_dat_read = status_reg;

    always @(posedge clk) begin
        if (rst) begin
            bkpt_addr <= 32'b0;
            status_reg <= 32'b0;
        end
        else if (du_write) begin
            case (du_addr[7:0])
                8'h00: bkpt_addr <= du_dat_write;
                8'h10: status_reg <= du_dat_write;
                default: ;
            endcase
        end
    end

endmodule

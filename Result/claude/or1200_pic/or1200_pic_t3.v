module or1200_pic(
    input clk,
    input rst,
    input [31:0] pic_input,
    input [31:0] spr_addr,
    input we,
    input [31:0] spr_wdata,
    output reg [31:0] spr_rdata,
    output reg [31:0] interrupt
);

    reg [31:0] pic_mask;
    reg [31:0] pic_status;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pic_mask <= 32'b0;
            pic_status <= 32'b0;
            interrupt <= 32'b0;
        end else begin
            if (we) begin
                case (spr_addr[3:0])
                    4'b0000: pic_mask <= spr_wdata;
                    4'b0001: pic_status <= spr_wdata;
                endcase
            end
            pic_status <= pic_input;
            interrupt <= pic_status & pic_mask;
        end
    end

    always @(*) begin
        case (spr_addr[3:0])
            4'b0000: spr_rdata = pic_mask;
            4'b0001: spr_rdata = pic_status;
            default: spr_rdata = 32'b0;
        endcase
    end

endmodule

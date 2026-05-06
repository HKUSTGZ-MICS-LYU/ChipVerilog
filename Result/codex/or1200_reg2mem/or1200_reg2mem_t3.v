// Generated from or1200_reg2mem/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_reg2mem(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] regdata,
    output [31:0] memdata
);

reg [31:0] memdata_r;
assign memdata = memdata_r;

always @* begin
    memdata_r = regdata;
    case (lsu_op)
        4'b0001,
        4'b0010: begin
            case (addr)
                2'b00: memdata_r = {regdata[7:0], 24'd0};
                2'b01: memdata_r = {8'd0, regdata[7:0], 16'd0};
                2'b10: memdata_r = {16'd0, regdata[7:0], 8'd0};
                default: memdata_r = {24'd0, regdata[7:0]};
            endcase
        end
        4'b0011,
        4'b0100: begin
            if (addr[1] == 1'b0)
                memdata_r = {regdata[15:0], 16'd0};
            else
                memdata_r = {16'd0, regdata[15:0]};
        end
        default: memdata_r = regdata;
    endcase
end

endmodule

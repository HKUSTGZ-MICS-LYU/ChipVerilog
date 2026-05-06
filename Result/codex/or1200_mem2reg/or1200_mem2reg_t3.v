// Generated from or1200_mem2reg/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_mem2reg(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] memdata,
    output [31:0] regdata
);

reg [31:0] regdata_r;
assign regdata = regdata_r;

always @* begin
    reg [31:0] aligned;
    case (addr)
        2'b00: aligned = memdata;
        2'b01: aligned = {memdata[23:0], 8'b0};
        2'b10: aligned = {memdata[15:0], 16'b0};
        default: aligned = {memdata[7:0], 24'b0};
    endcase
    case (lsu_op)
        4'b0001: regdata_r = {24'd0, aligned[31:24]};
        4'b0010: regdata_r = {{24{aligned[31]}}, aligned[31:24]};
        4'b0011: regdata_r = {16'd0, aligned[31:16]};
        4'b0100: regdata_r = {{16{aligned[31]}}, aligned[31:16]};
        default: regdata_r = aligned;
    endcase
end

endmodule

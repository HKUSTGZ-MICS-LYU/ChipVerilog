module or1200_reg2mem(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] regdata,
    output [31:0] memdata
);

reg [7:0] memdata_hh;
reg [7:0] memdata_hl;
reg [7:0] memdata_lh;
reg [7:0] memdata_ll;

assign memdata = {memdata_hh, memdata_hl, memdata_lh, memdata_ll};

always @(*) begin
    memdata_ll = regdata[7:0];
    
    memdata_lh = regdata[15:8];
    if (lsu_op[1:0] == 2'b00 && addr[1] == 1'b1) begin
        memdata_lh = regdata[7:0];
    end
    
    memdata_hl = regdata[23:16];
    if (lsu_op[3:2] == 2'b01 && addr == 2'b00) begin
        memdata_hl = regdata[23:16];
    end else begin
        memdata_hl = regdata[7:0];
    end
    
    memdata_hh = regdata[31:24];
    if (lsu_op[1:0] == 2'b00 && addr[1:0] == 2'b00) begin
        memdata_hh = regdata[7:0];
    end else if (lsu_op[1:0] == 2'b01 && addr[1:0] == 2'b00) begin
        memdata_hh = regdata[15:8];
    end
end

endmodule

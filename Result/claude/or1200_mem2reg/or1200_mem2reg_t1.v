module or1200_mem2reg(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] memdata,
    output reg [31:0] regdata
);

localparam [3:0] LSUOP_LB_UNSIGNED = 4'b0000;
localparam [3:0] LSUOP_LB_SIGNED   = 4'b0001;
localparam [3:0] LSUOP_LH_UNSIGNED = 4'b0010;
localparam [3:0] LSUOP_LH_SIGNED   = 4'b0011;
localparam [3:0] LSUOP_LW          = 4'b0100;

wire [7:0] selected_byte =
    (addr == 2'b00) ? memdata[31:24] :
    (addr == 2'b01) ? memdata[23:16] :
    (addr == 2'b10) ? memdata[15:8]  :
                      memdata[7:0];

wire [15:0] selected_halfword = addr[1] ? memdata[15:0] : memdata[31:16];

always @* begin
    case (lsu_op)
        LSUOP_LB_UNSIGNED: regdata = {24'b0, selected_byte};
        LSUOP_LB_SIGNED:   regdata = {{24{selected_byte[7]}}, selected_byte};
        LSUOP_LH_UNSIGNED: regdata = {16'b0, selected_halfword};
        LSUOP_LH_SIGNED:   regdata = {{16{selected_halfword[15]}}, selected_halfword};
        LSUOP_LW:          regdata = memdata;
        default:           regdata = memdata;
    endcase
end

endmodule

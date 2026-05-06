module or1200_wbmux(
    input [31:0] alu_result,
    input [31:0] lsu_result,
    input [31:0] spr_result,
    input [31:0] link_addr,
    input [2:0] rfwb_op,
    output [31:0] wb_result
);

    assign wb_result = (rfwb_op == 3'b001) ? alu_result :
                       (rfwb_op == 3'b010) ? lsu_result :
                       (rfwb_op == 3'b011) ? spr_result :
                       (rfwb_op == 3'b100) ? link_addr :
                       32'b0;

endmodule

`include "or1200_defines.v"

module or1200_operandmuxes(
    input               clk,
    input               rst,
    input               id_freeze,
    input               ex_freeze,
    input  [31:0]       rf_dataa,
    input  [31:0]       rf_datab,
    input  [31:0]       ex_forw,
    input  [31:0]       wb_forw,
    input  [31:0]       simm,
    input  [1:0]        sel_a,
    input  [1:0]        sel_b,
    output reg [31:0]   operand_a,
    output reg [31:0]   operand_b,
    output [31:0]       muxed_b
);

reg [31:0] muxed_a_r;
reg [31:0] muxed_b_r;
reg saved_a;
reg saved_b;

always @* begin
    case (sel_a)
        2'b00: muxed_a_r = rf_dataa;
        2'b01: muxed_a_r = ex_forw;
        2'b10: muxed_a_r = wb_forw;
        default: muxed_a_r = rf_dataa;
    endcase
end

always @* begin
    case (sel_b)
        2'b00: muxed_b_r = rf_datab;
        2'b01: muxed_b_r = ex_forw;
        2'b10: muxed_b_r = wb_forw;
        2'b11: muxed_b_r = simm;
        default: muxed_b_r = rf_datab;
    endcase
end

assign muxed_b = muxed_b_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        operand_a <= 32'b0;
        operand_b <= 32'b0;
        saved_a   <= 1'b0;
        saved_b   <= 1'b0;
    end else if (!ex_freeze) begin
        if (id_freeze && !saved_a) begin
            operand_a <= muxed_a_r;
            saved_a   <= 1'b1;
        end else if (!saved_a) begin
            operand_a <= muxed_a_r;
        end

        if (id_freeze && !saved_b) begin
            operand_b <= muxed_b_r;
            saved_b   <= 1'b1;
        end else if (!saved_b) begin
            operand_b <= muxed_b_r;
        end

        if (!id_freeze) begin
            saved_a <= 1'b0;
            saved_b <= 1'b0;
        end
    end
end

endmodule

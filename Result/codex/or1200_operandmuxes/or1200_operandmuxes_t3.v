// Generated from or1200_operandmuxes/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_operandmuxes(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f
    input id_freeze,
    input ex_freeze,
    input [31:0] rf_dataa,
    input [31:0] rf_datab,
    input [31:0] ex_forw,
    input [31:0] wb_forw,
    input [31:0] simm,
    input [1:0] sel_a,
    input [1:0] sel_b,
    output [31:0] operand_a,
    output [31:0] operand_b,
    output [31:0] muxed_b
);

reg [31:0] operand_a_r;
reg [31:0] operand_b_r;
reg [31:0] muxed_b_r;
assign operand_a = operand_a_r;
assign operand_b = operand_b_r;
assign muxed_b = muxed_b_r;

reg [31:0] muxed_a_int;
reg saved_a;
reg saved_b;

always @* begin
    case (sel_a)
        2'b00: muxed_a_int = rf_dataa;
        2'b01: muxed_a_int = ex_forw;
        default: muxed_a_int = wb_forw;
    endcase
    case (sel_b)
        2'b00: muxed_b_r = rf_datab;
        2'b01: muxed_b_r = ex_forw;
        2'b10: muxed_b_r = wb_forw;
        default: muxed_b_r = simm;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        operand_a_r <= 32'd0;
        operand_b_r <= 32'd0;
        saved_a <= 1'b0;
        saved_b <= 1'b0;
    end else if (!ex_freeze) begin
        if (id_freeze && !saved_a) begin
            operand_a_r <= muxed_a_int;
            saved_a <= 1'b1;
        end else begin
            operand_a_r <= muxed_a_int;
            saved_a <= 1'b0;
        end
        if (id_freeze && !saved_b) begin
            operand_b_r <= muxed_b_r;
            saved_b <= 1'b1;
        end else begin
            operand_b_r <= muxed_b_r;
            saved_b <= 1'b0;
        end
    end
end

endmodule

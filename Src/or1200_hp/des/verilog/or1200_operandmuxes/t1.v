`include "timescale.v"
`include "or1200_defines.v"

module or1200_operandmuxes(
    clk, rst,
    id_freeze, ex_freeze,
    rf_dataa, rf_datab,
    ex_forw, wb_forw,
    simm, sel_a, sel_b,
    operand_a, operand_b, muxed_b
);

input         clk, rst;
input         id_freeze, ex_freeze;
input  [31:0] rf_dataa, rf_datab;
input  [31:0] ex_forw, wb_forw;
input  [31:0] simm;
input  [1:0]  sel_a, sel_b;
output [31:0] operand_a;
output [31:0] operand_b;
output [31:0] muxed_b;

reg [31:0] operand_a;
reg [31:0] operand_b;
reg [31:0] muxed_a;
reg [31:0] muxed_b;
reg        saved_a;
reg        saved_b;

// Combinational mux for operand A
always @(sel_a or rf_dataa or ex_forw or wb_forw) begin
    casex (sel_a)
        `OR1200_SEL_EX_FORW: muxed_a = ex_forw;
        `OR1200_SEL_WB_FORW: muxed_a = wb_forw;
        default:             muxed_a = rf_dataa;
    endcase
end

// Combinational mux for operand B
always @(sel_b or rf_datab or simm or ex_forw or wb_forw) begin
    casex (sel_b)
        `OR1200_SEL_IMM:     muxed_b = simm;
        `OR1200_SEL_EX_FORW: muxed_b = ex_forw;
        `OR1200_SEL_WB_FORW: muxed_b = wb_forw;
        default:             muxed_b = rf_datab;
    endcase
end

// Registered operand A with save/hold logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        operand_a <= 32'h0;
        saved_a   <= 1'b0;
    end
    else if (!ex_freeze) begin
        if (id_freeze && !saved_a) begin
            operand_a <= muxed_a;
            saved_a   <= 1'b1;
        end
        else if (!saved_a) begin
            operand_a <= muxed_a;
        end
        if (!id_freeze) begin
            saved_a <= 1'b0;
        end
    end
end

// Registered operand B with save/hold logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        operand_b <= 32'h0;
        saved_b   <= 1'b0;
    end
    else if (!ex_freeze) begin
        if (id_freeze && !saved_b) begin
            operand_b <= muxed_b;
            saved_b   <= 1'b1;
        end
        else if (!saved_b) begin
            operand_b <= muxed_b;
        end
        if (!id_freeze) begin
            saved_b <= 1'b0;
        end
    end
end

endmodule
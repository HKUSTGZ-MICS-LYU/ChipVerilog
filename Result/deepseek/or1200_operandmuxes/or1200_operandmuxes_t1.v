// OpenRISC OR1200 operand muxes and registration
// Handles operand selection, forwarding, and pipeline freeze logic

`define OR1200_SEL_RF    2'b00
`define OR1200_SEL_EX_FORW 2'b01
`define OR1200_SEL_WB_FORW 2'b10
`define OR1200_SEL_IMM    2'b11

module or1200_operandmuxes (
    input         clk,
    input         rst,
    input         id_freeze,
    input         ex_freeze,
    input  [31:0] rf_dataa,
    input  [31:0] rf_datab,
    input  [31:0] ex_forw,
    input  [31:0] wb_forw,
    input  [31:0] simm,
    input  [1:0]  sel_a,
    input  [1:0]  sel_b,
    output [31:0] operand_a,
    output [31:0] operand_b,
    output [31:0] muxed_b
);

    // Internal registers
    reg [31:0] operand_a;
    reg [31:0] operand_b;
    reg        saved_a;
    reg        saved_b;

    // Combinational muxed values
    wire [31:0] muxed_a;
    wire [31:0] muxed_b_int;

    // Operand A selection
    assign muxed_a = (sel_a == `OR1200_SEL_EX_FORW) ? ex_forw :
                     (sel_a == `OR1200_SEL_WB_FORW) ? wb_forw :
                     rf_dataa;

    // Operand B selection
    assign muxed_b_int = (sel_b == `OR1200_SEL_IMM)      ? simm :
                         (sel_b == `OR1200_SEL_EX_FORW) ? ex_forw :
                         (sel_b == `OR1200_SEL_WB_FORW) ? wb_forw :
                         rf_datab;

    assign muxed_b = muxed_b_int;

    // Sequential logic for operand_a and operand_b
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            operand_a <= 32'h0;
            operand_b <= 32'h0;
            saved_a   <= 1'b0;
            saved_b   <= 1'b0;
        end else begin
            if (!ex_freeze) begin
                // Operand A
                if (id_freeze && !saved_a) begin
                    operand_a <= muxed_a;
                    saved_a   <= 1'b1;
                end else if (!saved_a) begin
                    operand_a <= muxed_a;
                end
                if (!id_freeze) begin
                    saved_a <= 1'b0;
                end

                // Operand B
                if (id_freeze && !saved_b) begin
                    operand_b <= muxed_b_int;
                    saved_b   <= 1'b1;
                end else if (!saved_b) begin
                    operand_b <= muxed_b_int;
                end
                if (!id_freeze) begin
                    saved_b <= 1'b0;
                end
            end
        end
    end

endmodule

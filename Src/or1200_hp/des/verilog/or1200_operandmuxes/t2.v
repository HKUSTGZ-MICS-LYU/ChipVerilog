`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

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

    //--------------------------------------------------------------------------
    // Combinational operand selection
    //--------------------------------------------------------------------------
    reg [31:0] muxed_a;
    reg [31:0] muxed_b_r;

    assign muxed_b = muxed_b_r;

    // Operand A: rf_dataa | ex_forw | wb_forw
    always @(*) begin
        casex (sel_a)
            `OR1200_SEL_EX_FORW: muxed_a = ex_forw;
            `OR1200_SEL_WB_FORW: muxed_a = wb_forw;
            default:             muxed_a = rf_dataa;
        endcase
    end

    // Operand B: rf_datab | simm | ex_forw | wb_forw
    always @(*) begin
        casex (sel_b)
            `OR1200_SEL_IMM:     muxed_b_r = simm;
            `OR1200_SEL_EX_FORW: muxed_b_r = ex_forw;
            `OR1200_SEL_WB_FORW: muxed_b_r = wb_forw;
            default:             muxed_b_r = rf_datab;
        endcase
    end

    //--------------------------------------------------------------------------
    // Registered operand A with freeze / save logic
    //--------------------------------------------------------------------------
    reg [31:0] operand_a_r;
    reg        saved_a;

    assign operand_a = operand_a_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            operand_a_r <= 32'h0;
            saved_a     <= 1'b0;
        end else begin
            if (!ex_freeze) begin
                if (id_freeze && !saved_a) begin
                    // ID frozen, EX advancing: capture once and lock
                    operand_a_r <= muxed_a;
                    saved_a     <= 1'b1;
                end else if (!saved_a) begin
                    // Normal pipeline advance: update operand
                    operand_a_r <= muxed_a;
                end
                if (!id_freeze) begin
                    // Both stages unfrozen: release saved lock
                    saved_a <= 1'b0;
                end
            end
            // ex_freeze: hold operand_a_r and saved_a unchanged
        end
    end

    //--------------------------------------------------------------------------
    // Registered operand B with freeze / save logic
    //--------------------------------------------------------------------------
    reg [31:0] operand_b_r;
    reg        saved_b;

    assign operand_b = operand_b_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            operand_b_r <= 32'h0;
            saved_b     <= 1'b0;
        end else begin
            if (!ex_freeze) begin
                if (id_freeze && !saved_b) begin
                    // ID frozen, EX advancing: capture once and lock
                    operand_b_r <= muxed_b_r;
                    saved_b     <= 1'b1;
                end else if (!saved_b) begin
                    // Normal pipeline advance: update operand
                    operand_b_r <= muxed_b_r;
                end
                if (!id_freeze) begin
                    // Both stages unfrozen: release saved lock
                    saved_b <= 1'b0;
                end
            end
            // ex_freeze: hold operand_b_r and saved_b unchanged
        end
    end

endmodule
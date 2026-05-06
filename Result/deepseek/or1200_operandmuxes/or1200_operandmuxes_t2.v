// OpenRISC OR1200 operand multiplexers and pipeline freeze holding logic
// Parameter definitions for operand selection codes
`define OR1200_SEL_IMM      2'b00
`define OR1200_SEL_EX_FORW  2'b01
`define OR1200_SEL_WB_FORW  2'b10

module or1200_operandmuxes (
    input           clk,
    input           rst,
    input           id_freeze,
    input           ex_freeze,
    input  [31:0]   rf_dataa,
    input  [31:0]   rf_datab,
    input  [31:0]   ex_forw,
    input  [31:0]   wb_forw,
    input  [31:0]   simm,
    input  [1:0]    sel_a,
    input  [1:0]    sel_b,
    output [31:0]   operand_a,
    output [31:0]   operand_b,
    output [31:0]   muxed_b
);

    // Combinational mux signals
    reg [31:0] muxed_a;
    reg [31:0] muxed_b;

    // Registered operand outputs
    reg [31:0] operand_a;
    reg [31:0] operand_b;

    // Saved flags for freeze holding
    reg saved_a;
    reg saved_b;

    // --------------------------------------------------------
    // Combinational operand selection
    // --------------------------------------------------------
    // Operand A selection
    always @(*) begin
        casex (sel_a)
            `OR1200_SEL_EX_FORW: muxed_a = ex_forw;
            `OR1200_SEL_WB_FORW: muxed_a = wb_forw;
            default:             muxed_a = rf_dataa;
        endcase
    end

    // Operand B selection
    always @(*) begin
        casex (sel_b)
            `OR1200_SEL_IMM:     muxed_b = simm;
            `OR1200_SEL_EX_FORW: muxed_b = ex_forw;
            `OR1200_SEL_WB_FORW: muxed_b = wb_forw;
            default:             muxed_b = rf_datab;
        endcase
    end

    // --------------------------------------------------------
    // Sequential registration with freeze handling
    // --------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            operand_a <= 32'd0;
            operand_b <= 32'd0;
            saved_a   <= 1'b0;
            saved_b   <= 1'b0;
        end else begin
            // When EX stage is frozen, hold everything
            if (!ex_freeze) begin
                // --- Operand A logic ---
                if (id_freeze && !saved_a) begin
                    // Capture and hold operand A
                    operand_a <= muxed_a;
                    saved_a   <= 1'b1;
                end else if (!saved_a) begin
                    // Normal update
                    operand_a <= muxed_a;
                end
                // Release saved_a when both ID and EX are not frozen
                if (!id_freeze)
                    saved_a <= 1'b0;

                // --- Operand B logic ---
                if (id_freeze && !saved_b) begin
                    // Capture and hold operand B
                    operand_b <= muxed_b;
                    saved_b   <= 1'b1;
                end else if (!saved_b) begin
                    // Normal update
                    operand_b <= muxed_b;
                end
                // Release saved_b when both ID and EX are not frozen
                if (!id_freeze)
                    saved_b <= 1'b0;
            end
        end
    end

endmodule

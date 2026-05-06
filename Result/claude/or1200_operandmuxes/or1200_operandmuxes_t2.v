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

    reg [31:0] operand_a;
    reg [31:0] operand_b;
    wire [31:0] muxed_a;
    wire [31:0] muxed_b;
    reg saved_a;
    reg saved_b;

    // Combinational multiplexer for operand A
    // sel_a[1:0] selects between rf_dataa, ex_forw, and wb_forw
    assign muxed_a = (sel_a == 2'b00) ? rf_dataa :
                     (sel_a == 2'b01) ? ex_forw :
                     (sel_a == 2'b10) ? wb_forw :
                     rf_dataa;  // Default to rf_dataa

    // Combinational multiplexer for operand B
    // sel_b[1:0] selects between rf_datab, ex_forw, wb_forw, or simm
    assign muxed_b = (sel_b == 2'b00) ? rf_datab :
                     (sel_b == 2'b01) ? ex_forw :
                     (sel_b == 2'b10) ? wb_forw :
                     (sel_b == 2'b11) ? simm :
                     rf_datab;  // Default to rf_datab

    // Sequential logic for operand registers and save flags
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            // Reset: Clear operand registers and save flags
            operand_a <= 32'b0;
            operand_b <= 32'b0;
            saved_a <= 1'b0;
            saved_b <= 1'b0;
        end else begin
            // Normal operation:
            // Update operand_a if not frozen at execution level and not saved
            if (!ex_freeze && !saved_a) begin
                operand_a <= muxed_a;
            end

            // Update operand_b if not frozen at execution level and not saved
            if (!ex_freeze && !saved_b) begin
                operand_b <= muxed_b;
            end

            // Handle save flags based on freeze conditions
            // Save flag gets set when: !ex_freeze && id_freeze && !saved_x
            if (!ex_freeze && id_freeze) begin
                // Execution level advancing, ID level frozen - save operands
                if (!saved_a) begin
                    saved_a <= 1'b1;
                end
                if (!saved_b) begin
                    saved_b <= 1'b1;
                end
            end

            // Clear save flags when ID freeze is lifted
            if (!id_freeze) begin
                saved_a <= 1'b0;
                saved_b <= 1'b0;
            end
        end
    end

endmodule

module or1200_operandmuxes(
    input wire clk,
    input wire rst,
    input wire id_freeze,
    input wire ex_freeze,
    input wire [31:0] rf_dataa,
    input wire [31:0] rf_datab,
    input wire [31:0] ex_forw,
    input wire [31:0] wb_forw,
    input wire [31:0] simm,
    input wire [1:0] sel_a,
    input wire [1:0] sel_b,
    output reg [31:0] operand_a,
    output reg [31:0] operand_b,
    output reg [31:0] muxed_b
);

    reg [31:0] muxed_a;
    reg saved_a;
    reg saved_b;

    // Combinational mux for operand A
    always @* begin
        casex (sel_a)
            2'b01:   muxed_a = ex_forw;
            2'b10:   muxed_a = wb_forw;
            default: muxed_a = rf_dataa;
        endcase
    end

    // Combinational mux for operand B (also output muxed_b)
    always @* begin
        casex (sel_b)
            2'b01:   muxed_b = simm;
            2'b10:   muxed_b = ex_forw;
            2'b11:   muxed_b = wb_forw;
            default: muxed_b = rf_datab;
        endcase
    end

    // Sequential update for operand A and saved_a
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            operand_a <= 32'd0;
            saved_a   <= 1'b0;
        end else if (!ex_freeze) begin
            // Capture when id_freeze high and not yet saved
            if (id_freeze && !saved_a) begin
                operand_a <= muxed_a;
                saved_a   <= 1'b1;
            end
            // Normal update when operand not yet saved (regardless of id_freeze)
            else if (!saved_a) begin
                operand_a <= muxed_a;
            end
            // Clear saved flag when both stages are unfrozen
            if (!id_freeze)
                saved_a <= 1'b0;
        end
        // ex_freeze high -> hold state (no change)
    end

    // Sequential update for operand B and saved_b
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            operand_b <= 32'd0;
            saved_b   <= 1'b0;
        end else if (!ex_freeze) begin
            // Capture when id_freeze high and not yet saved
            if (id_freeze && !saved_b) begin
                operand_b <= muxed_b;
                saved_b   <= 1'b1;
            end
            // Normal update when operand not yet saved (regardless of id_freeze)
            else if (!saved_b) begin
                operand_b <= muxed_b;
            end
            // Clear saved flag when both stages are unfrozen
            if (!id_freeze)
                saved_b <= 1'b0;
        end
        // ex_freeze high -> hold state (no change)
    end

endmodule

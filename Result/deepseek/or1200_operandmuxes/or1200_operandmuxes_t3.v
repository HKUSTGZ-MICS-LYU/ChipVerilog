module or1200_operandmuxes(
    input clk,
    input rst,
    input id_freeze,
    input ex_freeze,
    input [31:0] rf_dataa,
    input [31:0] rf_datab,
    input [31:0] ex_forw,
    input [31:0] wb_forw,
    input [31:0] simm,
    input [1:0] sel_a,
    input [1:0] sel_b,
    output reg [31:0] operand_a,
    output reg [31:0] operand_b,
    output reg [31:0] muxed_b
);

    localparam [1:0] OR1200_SEL_EX_FORW = 2'b00;
    localparam [1:0] OR1200_SEL_WB_FORW = 2'b01;
    localparam [1:0] OR1200_SEL_IMM    = 2'b10;

    reg saved_a;
    reg saved_b;
    reg [31:0] muxed_a;

    always @(*) begin
        muxed_a = rf_dataa;
        muxed_b = rf_datab;
        casex(sel_a)
            OR1200_SEL_EX_FORW: muxed_a = ex_forw;
            OR1200_SEL_WB_FORW: muxed_a = wb_forw;
            default: ;
        endcase
        casex(sel_b)
            OR1200_SEL_EX_FORW: muxed_b = ex_forw;
            OR1200_SEL_WB_FORW: muxed_b = wb_forw;
            OR1200_SEL_IMM:     muxed_b = simm;
            default: ;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            operand_a <= 32'd0;
            operand_b <= 32'd0;
            saved_a   <= 1'b0;
            saved_b   <= 1'b0;
        end else begin
            if (!ex_freeze) begin
                // Operand A update logic
                if (id_freeze) begin
                    if (!saved_a) begin
                        operand_a <= muxed_a;
                        saved_a   <= 1'b1;
                    end
                end else begin
                    if (!saved_a) begin
                        operand_a <= muxed_a;
                    end
                    saved_a <= 1'b0;
                end

                // Operand B update logic
                if (id_freeze) begin
                    if (!saved_b) begin
                        operand_b <= muxed_b;
                        saved_b   <= 1'b1;
                    end
                end else begin
                    if (!saved_b) begin
                        operand_b <= muxed_b;
                    end
                    saved_b <= 1'b0;
                end
            end
        end
    end

endmodule

module or1200_operandmuxes(
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
    output reg [31:0] operand_a,
    output reg [31:0] operand_b,
    output reg [31:0] muxed_b
);

reg [31:0] muxed_a;
reg        saved_a;
reg        saved_b;

localparam [1:0] OR1200_SEL_RF      = 2'b00;
localparam [1:0] OR1200_SEL_IMM     = 2'b01;
localparam [1:0] OR1200_SEL_EX_FORW = 2'b10;
localparam [1:0] OR1200_SEL_WB_FORW = 2'b11;

always @(*) begin
    casex (sel_a)
        OR1200_SEL_EX_FORW: muxed_a = ex_forw;
        OR1200_SEL_WB_FORW: muxed_a = wb_forw;
        default:            muxed_a = rf_dataa;
    endcase
end

always @(*) begin
    casex (sel_b)
        OR1200_SEL_IMM:     muxed_b = simm;
        OR1200_SEL_EX_FORW: muxed_b = ex_forw;
        OR1200_SEL_WB_FORW: muxed_b = wb_forw;
        default:            muxed_b = rf_datab;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        operand_a <= 32'b0;
        saved_a   <= 1'b0;
    end
    else begin
        if (!ex_freeze && id_freeze && !saved_a) begin
            operand_a <= muxed_a;
            saved_a   <= 1'b1;
        end
        if (!ex_freeze && !saved_a)
            operand_a <= muxed_a;
        if (!ex_freeze && !id_freeze)
            saved_a <= 1'b0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        operand_b <= 32'b0;
        saved_b   <= 1'b0;
    end
    else begin
        if (!ex_freeze && id_freeze && !saved_b) begin
            operand_b <= muxed_b;
            saved_b   <= 1'b1;
        end
        if (!ex_freeze && !saved_b)
            operand_b <= muxed_b;
        if (!ex_freeze && !id_freeze)
            saved_b <= 1'b0;
    end
end

endmodule

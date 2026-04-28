module fpu (
    input clk,
    input rst,
    input enable,
    input [1:0]  rmode,
    input [2:0]  fpu_op,
    input [63:0] opa,
    input [63:0] opb,
    output reg [63:0] out,
    output reg ready,
    output reg underflow,
    output reg overflow,
    output reg inexact,
    output reg exception,
    output reg invalid
);

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    // Fixed latency per operation (cycles after enable edge to ready)
    // Add/Sub: 6 pipeline stages, Mul: 6, Div: ~56 (54 iter + 2 overhead)
    localparam LAT_ADD = 7;
    localparam LAT_MUL = 7;
    localparam LAT_DIV = 58;

    //--------------------------------------------------------------------------
    // Input capture on rising edge of enable
    //--------------------------------------------------------------------------
    reg  enable_r;
    wire enable_rise = enable & ~enable_r;

    always @(posedge clk) begin
        if (rst) enable_r <= 1'b0;
        else     enable_r <= enable;
    end

    reg [63:0] opa_r, opb_r;
    reg [2:0]  fpu_op_r;
    reg [1:0]  rmode_r;

    always @(posedge clk) begin
        if (rst) begin
            opa_r    <= 64'd0;
            opb_r    <= 64'd0;
            fpu_op_r <= 3'd0;
            rmode_r  <= 2'd0;
        end else if (enable_rise) begin
            opa_r    <= opa;
            opb_r    <= opb;
            fpu_op_r <= fpu_op;
            rmode_r  <= rmode;
        end
    end

    //--------------------------------------------------------------------------
    // Add/Sub routing: determine effective sign
    // Sub flips opb sign; then compare signs for same/diff magnitude path
    //--------------------------------------------------------------------------
    wire [63:0] opb_eff = fpu_op_r[0] ? {~opb_r[63], opb_r[62:0]} : opb_r;

    wire opa_sign = opa_r[63];
    wire opb_sign = opb_eff[63];

    // same_sign → use fpu_add datapath; diff_sign → use fpu_sub datapath
    wire addsub_same_sign = (opa_sign == opb_sign);

    //--------------------------------------------------------------------------
    // Arithmetic enable signals (gated by operation type)
    //--------------------------------------------------------------------------
    wire op_addsub = (fpu_op_r == 3'b000) | (fpu_op_r == 3'b001);
    wire op_mul    = (fpu_op_r == 3'b010);
    wire op_div    = (fpu_op_r == 3'b011);

    // Pipe the enable_rise through for arithmetic blocks
    reg arith_enable;
    always @(posedge clk) begin
        if (rst) arith_enable <= 1'b0;
        else     arith_enable <= enable_rise;
    end

    wire add_enable = arith_enable & op_addsub &  addsub_same_sign;
    wire sub_enable = arith_enable & op_addsub & ~addsub_same_sign;
    wire mul_enable = arith_enable & op_mul;
    wire div_enable = arith_enable & op_div;

    //--------------------------------------------------------------------------
    // fpu_add instantiation (same-sign addition)
    //--------------------------------------------------------------------------
    wire        add_sign;
    wire [55:0] add_sum;
    wire [10:0] add_exp;

    fpu_add u_add (
        .clk       (clk),
        .rst       (rst),
        .enable    (add_enable),
        .opa       (opa_r),
        .opb       (opb_eff),
        .sign      (add_sign),
        .sum_2     (add_sum),
        .exponent_2(add_exp)
    );

    //--------------------------------------------------------------------------
    // fpu_sub instantiation (different-sign → magnitude subtraction)
    //--------------------------------------------------------------------------
    wire        sub_sign;
    wire [55:0] sub_sum;
    wire [10:0] sub_exp;

    fpu_sub u_sub (
        .clk       (clk),
        .rst       (rst),
        .enable    (sub_enable),
        .opa       (opa_r),
        .opb       (opb_eff),
        .sign      (sub_sign),
        .sum_2     (sub_sum),
        .exponent_2(sub_exp)
    );

    //--------------------------------------------------------------------------
    // fpu_mul instantiation
    //--------------------------------------------------------------------------
    wire        mul_sign;
    wire [55:0] mul_mantissa;
    wire [10:0] mul_exp;

    fpu_mul u_mul (
        .clk        (clk),
        .rst        (rst),
        .enable     (mul_enable),
        .opa        (opa_r),
        .opb        (opb_r),
        .sign       (mul_sign),
        .mantissa_7 (mul_mantissa),
        .exponent_out(mul_exp)
    );

    //--------------------------------------------------------------------------
    // fpu_div instantiation
    //--------------------------------------------------------------------------
    wire        div_sign;
    wire [55:0] div_mantissa;
    wire [11:0] div_exp;

    fpu_div u_div (
        .clk         (clk),
        .rst         (rst),
        .enable      (div_enable),
        .opa         (opa_r),
        .opb         (opb_r),
        .sign        (div_sign),
        .mantissa_7  (div_mantissa),
        .exponent_out(div_exp)
    );

    //--------------------------------------------------------------------------
    // Latency counter and ready generation
    //--------------------------------------------------------------------------
    reg [7:0] lat_count;
    reg [7:0] lat_target;
    reg       counting;

    always @(posedge clk) begin
        if (rst) begin
            lat_count  <= 8'd0;
            lat_target <= 8'd0;
            counting   <= 1'b0;
        end else if (enable_rise) begin
            counting  <= 1'b1;
            lat_count <= 8'd0;
            case (fpu_op)
                3'b000, 3'b001: lat_target <= LAT_ADD;
                3'b010:         lat_target <= LAT_MUL;
                3'b011:         lat_target <= LAT_DIV;
                default:        lat_target <= LAT_ADD;
            endcase
        end else if (counting) begin
            if (lat_count == lat_target - 1) begin
                counting  <= 1'b0;
                lat_count <= 8'd0;
            end else begin
                lat_count <= lat_count + 1;
            end
        end
    end

    wire result_ready = counting & (lat_count == lat_target - 1);

    //--------------------------------------------------------------------------
    // Intermediate result selection
    //--------------------------------------------------------------------------
    reg        sel_sign;
    reg [55:0] sel_mantissa;
    reg [11:0] sel_exp;      // 12-bit to accommodate div

    always @(*) begin
        case (fpu_op_r)
            3'b000, 3'b001: begin
                if (addsub_same_sign) begin
                    sel_sign     = add_sign;
                    sel_mantissa = add_sum;
                    sel_exp      = {1'b0, add_exp};
                end else begin
                    sel_sign     = sub_sign;
                    sel_mantissa = sub_sum;
                    sel_exp      = {1'b0, sub_exp};
                end
            end
            3'b010: begin
                sel_sign     = mul_sign;
                sel_mantissa = mul_mantissa;
                sel_exp      = {1'b0, mul_exp};
            end
            3'b011: begin
                sel_sign     = div_sign;
                sel_mantissa = div_mantissa;
                sel_exp      = div_exp;
            end
            default: begin
                sel_sign     = 1'b0;
                sel_mantissa = 56'd0;
                sel_exp      = 12'd0;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // fpu_round instantiation
    //--------------------------------------------------------------------------
    wire [63:0] round_out;
    wire        round_inexact;

    fpu_round u_round (
        .clk        (clk),
        .rst        (rst),
        .enable     (result_ready),
        .sign       (sel_sign),
        .mantissa   (sel_mantissa),
        .exponent   (sel_exp),
        .rmode      (rmode_r),
        .out        (round_out),
        .inexact    (round_inexact)
    );

    //--------------------------------------------------------------------------
    // fpu_exceptions instantiation
    //--------------------------------------------------------------------------
    wire [63:0] exc_out;
    wire        exc_underflow;
    wire        exc_overflow;
    wire        exc_inexact;
    wire        exc_exception;
    wire        exc_invalid;

    fpu_exceptions u_exc (
        .clk       (clk),
        .rst       (rst),
        .enable    (result_ready),
        .opa       (opa_r),
        .opb       (opb_r),
        .fpu_op    (fpu_op_r),
        .rmode     (rmode_r),
        .sign      (sel_sign),
        .mantissa  (sel_mantissa),
        .exponent  (sel_exp),
        .round_out (round_out),
        .out       (exc_out),
        .underflow (exc_underflow),
        .overflow  (exc_overflow),
        .inexact   (exc_inexact),
        .exception (exc_exception),
        .invalid   (exc_invalid)
    );

    //--------------------------------------------------------------------------
    // Output registration — 1 cycle after result_ready (accounts for round/exc)
    //--------------------------------------------------------------------------
    reg result_ready_r;
    always @(posedge clk) begin
        if (rst) result_ready_r <= 1'b0;
        else     result_ready_r <= result_ready;
    end

    always @(posedge clk) begin
        if (rst) begin
            out       <= 64'd0;
            ready     <= 1'b0;
            underflow <= 1'b0;
            overflow  <= 1'b0;
            inexact   <= 1'b0;
            exception <= 1'b0;
            invalid   <= 1'b0;
        end else if (result_ready_r) begin
            out       <= exc_exception ? exc_out : round_out;
            ready     <= 1'b1;
            underflow <= exc_underflow;
            overflow  <= exc_overflow;
            inexact   <= exc_inexact | round_inexact;
            exception <= exc_exception;
            invalid   <= exc_invalid;
        end else begin
            ready <= 1'b0;
        end
    end

endmodule
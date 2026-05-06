module fpu_sub (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    input [2:0] fpu_op,
    output reg sign,
    output reg [55:0] diff_2,
    output reg [10:0] exponent_2
);

    // Pipeline registers
    reg [10:0] exponent_a, exponent_b;
    reg [51:0] mantissa_a, mantissa_b;
    reg sign_a, sign_b;
    reg [2:0] fpu_op_reg;

    reg [10:0] exp_a_p1, exp_b_p1;
    reg [51:0] man_a_p1, man_b_p1;
    reg sign_a_p1, sign_b_p1;
    reg [2:0] fpu_op_p1;
    reg a_gtet_b;

    reg [10:0] exponent_large, exponent_small;
    reg [51:0] mantissa_large, mantissa_small;
    reg small_is_denorm, large_is_denorm;
    reg small_is_nonzero;
    reg a_gtet_b_p2;
    reg sign_a_p2, sign_b_p2;
    reg [2:0] fpu_op_p2;

    reg large_norm_small_denorm;
    reg [10:0] exponent_diff;
    reg a_gtet_b_p3;
    reg sign_a_p3, sign_b_p3;
    reg [2:0] fpu_op_p3;

    reg [54:0] subtra_shift_3;
    reg a_gtet_b_p4;
    reg sign_a_p4, sign_b_p4;
    reg [2:0] fpu_op_p4;

    reg [54:0] diff;
    reg a_gtet_b_p5;
    reg sign_a_p5, sign_b_p5;
    reg [2:0] fpu_op_p5;

    reg [5:0] diff_shift_2;
    reg a_gtet_b_p6;
    reg sign_a_p6, sign_b_p6;
    reg [2:0] fpu_op_p6;

    reg [54:0] diff_1;
    reg [10:0] exponent_normalized;
    reg diffshift_et_55_reg;
    reg a_gtet_b_p7;
    reg sign_a_p7, sign_b_p7;
    reg [2:0] fpu_op_p7;

    // Combinational encoder result
    wire [5:0] diff_shift;

    // Stage1: input registers
    wire [10:0] n_exponent_a = opa[62:52];
    wire [10:0] n_exponent_b = opb[62:52];
    wire [51:0] n_mantissa_a = opa[51:0];
    wire [51:0] n_mantissa_b = opb[51:0];
    wire n_sign_a = opa[63];
    wire n_sign_b = opb[63];
    wire [2:0] n_fpu_op = fpu_op;

    // Stage2: comparison and data pass
    wire expa_gt_expb = (exponent_a > exponent_b);
    wire expa_et_expb = (exponent_a == exponent_b);
    wire mana_gtet_manb = (mantissa_a >= mantissa_b);
    wire n_a_gtet_b = expa_gt_expb || (expa_et_expb && mana_gtet_manb);
    wire [10:0] n_exp_a_p1 = exponent_a;
    wire [10:0] n_exp_b_p1 = exponent_b;
    wire [51:0] n_man_a_p1 = mantissa_a;
    wire [51:0] n_man_b_p1 = mantissa_b;
    wire n_sign_a_p1 = sign_a;
    wire n_sign_b_p1 = sign_b;
    wire [2:0] n_fpu_op_p1 = fpu_op_reg;

    // Stage3: operand selection and

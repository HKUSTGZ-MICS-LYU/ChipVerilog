module fpu_div (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output sign,
    output [55:0] mantissa_7,
    output reg [11:0] exponent_out
);

function [5:0] lzc52;
    input [51:0] v;
    integer i;
    reg found;
    begin
        lzc52 = 6'd52;
        found = 1'b0;
        for (i = 51; i >= 0; i = i - 1) begin
            if (!found && v[i]) begin
                lzc52 = 6'd51 - i[5:0];
                found = 1'b1;
            end
        end
    end
endfunction

wire [10:0] exp_a = opa[62:52];
wire [10:0] exp_b = opb[62:52];
wire [51:0] frac_a = opa[51:0];
wire [51:0] frac_b = opb[51:0];
wire a_is_zero = (opa[62:0] == 63'd0);
wire a_is_denorm = (exp_a == 11'd0) && (frac_a != 52'd0);
wire b_is_denorm = (exp_b == 11'd0) && (frac_b != 52'd0);
wire [5:0] lza = lzc52(frac_a);
wire [5:0] lzb = lzc52(frac_b);

wire [53:0] sig_a_pre = (exp_a != 11'd0) ? {1'b1, frac_a, 1'b0} :
                        (frac_a != 52'd0) ? ({1'b0, frac_a, 1'b0} << (lza + 6'd1)) :
                                            54'd0;
wire [53:0] sig_b_pre = (exp_b != 11'd0) ? {1'b1, frac_b, 1'b0} :
                        (frac_b != 52'd0) ? ({1'b0, frac_b, 1'b0} << (lzb + 6'd1)) :
                                            54'd0;

reg [1:0] enable_pipe;
reg busy;
reg [5:0] count;
reg [54:0] dividend_reg;
reg [54:0] divisor_reg;
reg [53:0] quotient_reg;
reg signed [13:0] exp_work_reg;
reg [55:0] mantissa_7_reg;

wire [53:0] q_norm = quotient_reg[53] ? quotient_reg : (quotient_reg << 1);
wire q_lead = quotient_reg[53];
wire [51:0] q_mant = q_norm[52:1];
wire q_guard = q_norm[0];
wire rem_sticky = |dividend_reg;
wire signed [13:0] exp_after_norm = q_lead ? exp_work_reg : (exp_work_reg - 14'sd1);

reg [54:0] denorm_shifted;
reg denorm_sticky;
reg [55:0] mantissa_next;
reg signed [13:0] exp_final;
reg [5:0] denorm_shamt;
reg [54:0] denorm_ext;
integer j;

assign sign = opa[63] ^ opb[63];
assign mantissa_7 = mantissa_7_reg;

always @(*) begin
    denorm_shifted = {q_norm, 1'b0};
    denorm_sticky = rem_sticky;
    mantissa_next = {1'b0, q_lead, q_mant, q_guard, rem_sticky};
    exp_final = exp_after_norm;

    if (exp_after_norm < 14'sd1) begin
        denorm_shamt = 6'd1 - exp_after_norm[5:0];
        denorm_ext = {q_norm, 1'b0};
        if (denorm_shamt >= 6'd55) begin
            denorm_shifted = 55'd0;
            denorm_sticky = denorm_sticky | (|denorm_ext);
        end else begin
            denorm_shifted = denorm_ext >> denorm_shamt;
            for (j = 0; j < 55; j = j + 1) begin
                if (j < denorm_shamt)
                    denorm_sticky = denorm_sticky | denorm_ext[j];
            end
        end
        mantissa_next = {1'b0, 1'b0, denorm_shifted[53:2], denorm_shifted[1], denorm_sticky};
        exp_final = 14'sd0;
    end

    if (a_is_zero) begin
        mantissa_next = 56'd0;
        exp_final = 14'sd0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        enable_pipe <= 2'b00;
        busy <= 1'b0;
        count <= 6'd0;
        dividend_reg <= 55'd0;
        divisor_reg <= 55'd0;
        quotient_reg <= 54'd0;
        exp_work_reg <= 14'sd0;
        mantissa_7_reg <= 56'd0;
        exponent_out <= 12'd0;
    end else begin
        enable_pipe <= {enable_pipe[0], enable};

        if (!busy && enable_pipe[1]) begin
            busy <= 1'b1;
            count <= 6'd53;
            quotient_reg <= 54'd0;
            dividend_reg <= {1'b0, sig_a_pre};
            divisor_reg <= {1'b0, sig_b_pre};
            exp_work_reg <= $signed({3'd0, (exp_a == 11'd0) ? 11'd1 : exp_a}) +
                            14'sd1023 -
                            $signed({3'd0, (exp_b == 11'd0) ? 11'd1 : exp_b}) -
                            $signed({8'd0, (a_is_denorm ? lza : 6'd0)}) +
                            $signed({8'd0, (b_is_denorm ? lzb : 6'd0)});
        end else if (busy) begin
            if (dividend_reg >= divisor_reg) begin
                quotient_reg[count] <= 1'b1;
                dividend_reg <= (dividend_reg - divisor_reg) << 1;
            end else begin
                quotient_reg[count] <= 1'b0;
                dividend_reg <= dividend_reg << 1;
            end

            if (count == 6'd0) begin
                busy <= 1'b0;
                mantissa_7_reg <= mantissa_next;
                exponent_out <= a_is_zero ? 12'd0 :
                                (exp_final < 14'sd0) ? 12'd0 :
                                exp_final[11:0];
            end else begin
                count <= count - 6'd1;
            end
        end
    end
end

endmodule

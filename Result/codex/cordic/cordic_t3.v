module cordic (
    input wire clk,
    input wire rst,
    input wire signed [16:0] x_i,
    input wire signed [16:0] y_i,
    input wire signed [16:0] theta_i,
    output wire signed [16:0] x_o,
    output wire signed [16:0] y_o,
    output wire signed [16:0] theta_o
);

localparam integer ITERATIONS = 16;

wire signed [16:0] x_pipe [0:ITERATIONS];
wire signed [16:0] y_pipe [0:ITERATIONS];
wire signed [16:0] z_pipe [0:ITERATIONS];

genvar i;

assign x_pipe[0] = x_i;
assign y_pipe[0] = y_i;
assign z_pipe[0] = theta_i;

generate
    for (i = 0; i < ITERATIONS; i = i + 1) begin : gen_stages
        cordic_stage #(
            .SHIFT(i)
        ) u_stage (
            .clk(clk),
            .rst(rst),
            .x_i(x_pipe[i]),
            .y_i(y_pipe[i]),
            .z_i(z_pipe[i]),
            .x_o(x_pipe[i + 1]),
            .y_o(y_pipe[i + 1]),
            .z_o(z_pipe[i + 1])
        );
    end
endgenerate

assign x_o = x_pipe[ITERATIONS];
assign y_o = y_pipe[ITERATIONS];
assign theta_o = z_pipe[ITERATIONS];

endmodule

module cordic_stage #(
    parameter integer SHIFT = 0
) (
    input wire clk,
    input wire rst,
    input wire signed [16:0] x_i,
    input wire signed [16:0] y_i,
    input wire signed [16:0] z_i,
    output reg signed [16:0] x_o,
    output reg signed [16:0] y_o,
    output reg signed [16:0] z_o
);

wire signed [16:0] x_shift;
wire signed [16:0] y_shift;

assign x_shift = x_i >>> SHIFT;
assign y_shift = y_i >>> SHIFT;

function signed [16:0] tanangle;
    input integer idx;
    begin
        case (idx)
            0: tanangle = 17'sd51471;
            1: tanangle = 17'sd30385;
            2: tanangle = 17'sd16054;
            3: tanangle = 17'sd8149;
            4: tanangle = 17'sd4090;
            5: tanangle = 17'sd2047;
            6: tanangle = 17'sd1023;
            7: tanangle = 17'sd511;
            8: tanangle = 17'sd255;
            9: tanangle = 17'sd127;
            10: tanangle = 17'sd63;
            11: tanangle = 17'sd31;
            12: tanangle = 17'sd15;
            13: tanangle = 17'sd7;
            14: tanangle = 17'sd3;
            15: tanangle = 17'sd1;
            default: tanangle = 17'sd0;
        endcase
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        x_o <= 17'sd0;
        y_o <= 17'sd0;
        z_o <= 17'sd0;
    end else if (z_i[16]) begin
        x_o <= x_i + y_shift;
        y_o <= y_i - x_shift;
        z_o <= z_i + tanangle(SHIFT);
    end else begin
        x_o <= x_i - y_shift;
        y_o <= y_i + x_shift;
        z_o <= z_i - tanangle(SHIFT);
    end
end

endmodule

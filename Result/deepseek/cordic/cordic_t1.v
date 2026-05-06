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

    localparam ITERATIONS = 16;
    localparam XY_BITS = 16;
    localparam THETA_BITS = 16;

    wire signed [16:0] x [0:ITERATIONS-1];
    wire signed [16:0] y [0:ITERATIONS-1];
    wire signed [16:0] z [0:ITERATIONS-1];

    function signed [16:0] tanangle;
        input [3:0] iter;
        begin
            case (iter)
                4'd0: tanangle = 17'd25735;
                4'd1: tanangle = 17'd15192;
                4'd2: tanangle = 17'd8027;
                4'd3: tanangle = 17'd4074;
                4'd4: tanangle = 17'd2045;
                4'd5: tanangle = 17'd1023;
                4'd6: tanangle = 17'd511;
                4'd7: tanangle = 17'd255;
                4'd8: tanangle = 17'd127;
                4'd9: tanangle = 17'd63;
                4'd10: tanangle = 17'd31;
                4'd11: tanangle = 17'd15;
                4'd12: tanangle = 17'd7;
                4'd13: tanangle = 17'd3;
                4'd14: tanangle = 17'd1;
                default: tanangle = 17'd0;
            endcase
        end
    endfunction

    assign x[0] = x_i;
    assign y[0] = y_i;
    assign z[0] = theta_i;

    genvar i;
    generate
        for (i = 0; i < ITERATIONS-1; i = i + 1) begin : stage
            wire signed [16:0] x_shifted;
            wire signed [16:0] y_shifted;
            wire signed [16:0] x_next;
            wire signed [16:0] y_next;
            wire signed [16:0] z_next;
            reg  signed [16:0] x_reg;
            reg  signed [16:0] y_reg;
            reg  signed [16:0] z_reg;

            assign x_shifted = x[i] >>> (i);
            assign y_shifted = y[i] >>> (i);

            assign x_next = (z[i][16]) ? (x[i] + y_shifted) : (x[i] - y_shifted);
            assign y_next = (z[i][16]) ? (y[i] - x_shifted) : (y[i] + x_shifted);
            assign z_next = (z[i][16]) ? (z[i] + tanangle(i)) : (z[i] - tanangle(i));

            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    x_reg <= 17'd0;
                    y_reg <= 17'd0;
                    z_reg <= 17'd0;
                end else begin
                    x_reg <= x_next;
                    y_reg <= y_next;
                    z_reg <= z_next;
                end
            end

            assign x[i+1] = x_reg;
            assign y[i+1] = y_reg;
            assign z[i+1] = z_reg;
        end
    endgenerate

    assign x_o = x[ITERATIONS-1];
    assign y_o = y[ITERATIONS-1];
    assign theta_o = z[ITERATIONS-1];

endmodule

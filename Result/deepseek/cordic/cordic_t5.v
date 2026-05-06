module cordic #(
    parameter XY_BITS = 16,
    parameter THETA_BITS = 16,
    parameter ITERATIONS = 16
) (
    input wire clk,
    input wire rst,
    input wire signed [XY_BITS:0] x_i,
    input wire signed [XY_BITS:0] y_i,
    input wire signed [THETA_BITS:0] theta_i,
    output wire signed [XY_BITS:0] x_o,
    output wire signed [XY_BITS:0] y_o,
    output wire signed [THETA_BITS:0] theta_o
);

function signed [THETA_BITS:0] tanangle(input integer idx);
begin
    case (idx)
        0: tanangle = 17'd51472;
        1: tanangle = 17'd30376;
        2: tanangle = 17'd16051;
        3: tanangle = 17'd8148;
        4: tanangle = 17'd4090;
        5: tanangle = 17'd2047;
        6: tanangle = 17'd1024;
        7: tanangle = 17'd512;
        8: tanangle = 17'd256;
        9: tanangle = 17'd128;
       10: tanangle = 17'd64;
       11: tanangle = 17'd32;
       12: tanangle = 17'd16;
       13: tanangle = 17'd8;
       14: tanangle = 17'd4;
       15: tanangle = 17'd2;
       default: tanangle = 17'd0;
    endcase
end
endfunction

reg signed [XY_BITS:0] x [0:ITERATIONS];
reg signed [XY_BITS:0] y [0:ITERATIONS];
reg signed [THETA_BITS:0] z [0:ITERATIONS];

always_ff @(posedge clk) begin
    if (rst) begin
        x[0] <= 0;
        y[0] <= 0;
        z[0] <= 0;
    end else begin
        x[0] <= x_i;
        y[0] <= y_i;
        z[0] <= theta_i;
    end
end

genvar i;
generate
    for (i = 0; i < ITERATIONS; i = i + 1) begin : stage
        always_ff @(posedge clk) begin
            if (rst) begin
                x[i+1] <= 0;
                y[i+1] <= 0;
                z[i+1] <= 0;
            end else begin
                if (z[i] < 0) begin
                    x[i+1] <= x[i] + (y[i] >>> i);
                    y[i+1] <= y[i] - (x[i] >>> i);
                    z[i+1] <= z[i] + tanangle(i);
                end else begin
                    x[i+1] <= x[i] - (y[i] >>> i);
                    y[i+1] <= y[i] + (x[i] >>> i);
                    z[i+1] <= z[i] - tanangle(i);
                end
            end
        end
    end
endgenerate

assign x_o = x[ITERATIONS];
assign y_o = y[ITERATIONS];
assign theta_o = z[ITERATIONS];

endmodule

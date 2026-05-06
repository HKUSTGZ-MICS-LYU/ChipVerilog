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

localparam integer XY_BITS = 16;
localparam integer THETA_BITS = 16;
localparam integer ITERATIONS = 16;

reg signed [XY_BITS:0] x_pipe [0:ITERATIONS-1];
reg signed [XY_BITS:0] y_pipe [0:ITERATIONS-1];
reg signed [THETA_BITS:0] z_pipe [0:ITERATIONS-1];

function signed [THETA_BITS:0] tanangle;
    input integer idx;
    begin
        case (idx)
            0: tanangle = 17'sd51472;
            1: tanangle = 17'sd30386;
            2: tanangle = 17'sd16055;
            3: tanangle = 17'sd8150;
            4: tanangle = 17'sd4091;
            5: tanangle = 17'sd2047;
            6: tanangle = 17'sd1024;
            7: tanangle = 17'sd512;
            8: tanangle = 17'sd256;
            9: tanangle = 17'sd128;
            10: tanangle = 17'sd64;
            11: tanangle = 17'sd32;
            12: tanangle = 17'sd16;
            13: tanangle = 17'sd8;
            14: tanangle = 17'sd4;
            15: tanangle = 17'sd2;
            default: tanangle = {THETA_BITS + 1{1'b0}};
        endcase
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        x_pipe[0] <= {XY_BITS + 1{1'b0}};
        y_pipe[0] <= {XY_BITS + 1{1'b0}};
        z_pipe[0] <= {THETA_BITS + 1{1'b0}};
    end else if (theta_i < 0) begin
        x_pipe[0] <= x_i + y_i;
        y_pipe[0] <= y_i - x_i;
        z_pipe[0] <= theta_i + tanangle(0);
    end else begin
        x_pipe[0] <= x_i - y_i;
        y_pipe[0] <= y_i + x_i;
        z_pipe[0] <= theta_i - tanangle(0);
    end
end

genvar i;
generate
    for (i = 1; i < ITERATIONS; i = i + 1) begin : stage_gen
        localparam integer STAGE = i;
        wire signed [XY_BITS:0] x_shift;
        wire signed [XY_BITS:0] y_shift;

        assign x_shift = x_pipe[STAGE-1] >>> STAGE;
        assign y_shift = y_pipe[STAGE-1] >>> STAGE;

        always @(posedge clk or posedge rst) begin
            if (rst) begin
                x_pipe[STAGE] <= {XY_BITS + 1{1'b0}};
                y_pipe[STAGE] <= {XY_BITS + 1{1'b0}};
                z_pipe[STAGE] <= {THETA_BITS + 1{1'b0}};
            end else if (z_pipe[STAGE-1] < 0) begin
                x_pipe[STAGE] <= x_pipe[STAGE-1] + y_shift;
                y_pipe[STAGE] <= y_pipe[STAGE-1] - x_shift;
                z_pipe[STAGE] <= z_pipe[STAGE-1] + tanangle(STAGE);
            end else begin
                x_pipe[STAGE] <= x_pipe[STAGE-1] - y_shift;
                y_pipe[STAGE] <= y_pipe[STAGE-1] + x_shift;
                z_pipe[STAGE] <= z_pipe[STAGE-1] - tanangle(STAGE);
            end
        end
    end
endgenerate

assign x_o = x_pipe[ITERATIONS-1];
assign y_o = y_pipe[ITERATIONS-1];
assign theta_o = z_pipe[ITERATIONS-1];

endmodule

module cordic (
    input wire clk,
    input wire rst,
`ifdef ITERATE
    input wire init,
`endif
    input wire signed [`XY_BITS:0]    x_i,
    input wire signed [`XY_BITS:0]    y_i,
    input wire signed [`THETA_BITS:0] theta_i,
    output wire signed [`XY_BITS:0]    x_o,
    output wire signed [`XY_BITS:0]    y_o,
    output wire signed [`THETA_BITS:0] theta_o
`ifdef VALID_FLAG
    , input wire valid_in,
    output wire valid_out
`endif
);

    localparam signed [`XY_BITS:0] CORDIC_1 = 17'd39796; // 0.607252 * 2^16
    // CORDIC_GAIN is not used internally; provided for reference.
    // localparam real CORDIC_GAIN = 1.646760;

    function signed [`THETA_BITS:0] tanangle (input [`ITERATION_BITS-1:0] iter);
        `ifdef RADIAN_16
            case (iter)
                0: return 17'd51471;
                1: return 17'd30386;
                2: return 17'd16055;
                3: return 17'd8150;
                4: return 17'd4091;
                5: return 17'd2047;
                6: return 17'd1023;
                7: return 17'd511;
                8: return 17'd255;
                9: return 17'd127;
                10: return 17'd63;
                11: return 17'd31;
                12: return 17'd15;
                13: return 17'd7;
                14: return 17'd3;
                default: return 0;
            endcase
        `elsif DEGREE_8_8
            // degree format table - scaled for 8 fractional bits
            case (iter)
                0: return 17'd11520; // 45° * 256
                1: return 17'd6804;
                2: return 17'd3632;
                3: return 17'd1856;
                4: return 17'd936;
                5: return 17'd470;
                6: return 17'd236;
                7: return 17'd118;
                8: return 17'd59;
                9: return 17'd29;
                10: return 17'd14;
                11: return 17'd7;
                12: return 17'd3;
                13: return 17'd1;
                14: return 17'd0;
                default: return 0;
            endcase
        `else
            return 0;
        `endif
    endfunction

`ifdef PIPELINE
    // Pipelined architecture
    reg signed [`XY_BITS:0]    x [0:`ITERATIONS-1];
    reg signed [`XY_BITS:0]    y [0:`ITERATIONS-1];
    reg signed [`THETA_BITS:0] z [0:`ITERATIONS-1];

    genvar i;
    generate
        // First stage loads inputs
        always @(posedge clk or posedge rst) begin
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

        for (i = 0; i < `ITERATIONS-1; i = i + 1) begin : stage
            wire signed [`XY_BITS:0]    x_shifted = x[i] >>> i;
            wire signed [`XY_BITS:0]    y_shifted = y[i] >>> i;
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    x[i+1] <= 0;
                    y[i+1] <= 0;
                    z[i+1] <= 0;
                end else begin
                    `ifdef ROTATE
                        if (z[i] < 0) begin
                            x[i+1] <= x[i] + y_shifted;
                            y[i+1] <= y[i] - x_shifted;
                            z[i+1] <= z[i] + tanangle(i);
                        end else begin
                            x[i+1] <= x[i] - y_shifted;
                            y[i+1] <= y[i] + x_shifted;
                            z[i+1] <= z[i] - tanangle(i);
                        end
                    `elsif VECTOR
                        if (y[i] < 0) begin
                            x[i+1] <= x[i] - y_shifted;
                            y[i+1] <= y[i] + x_shifted;
                            z[i+1] <= z[i] - tanangle(i);
                        end else begin
                            x[i+1] <= x[i] + y_shifted;
                            y[i+1] <= y[i] - x_shifted;
                            z[i+1] <= z[i] + tanangle(i);
                        end
                    `endif
                end
            end
        end
    endgenerate

    assign x_o = x[`ITERATIONS-1];
    assign y_o = y[`ITERATIONS-1];
    assign theta_o = z[`ITERATIONS-1];

`elsif ITERATE
    // Iterative architecture
    reg signed [`XY_BITS:0]    x_cur, y_cur;
    reg signed [`THETA_BITS:0] z_cur;
    reg [`ITERATION_BITS-1:0] cnt;
    reg done;

    wire signed [`XY_BITS:0]    x_shifted = x_cur >>> cnt;
    wire signed [`XY_BITS:0]    y_shifted = y_cur >>> cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_cur <= 0;
            y_cur <= 0;
            z_cur <= 0;
            cnt <= 0;
            done <= 0;
        end else if (init) begin
            x_cur <= x_i;
            y_cur <= y_i;
            z_cur <= theta_i;
            cnt <= 0;
            done <= 0;
        end else if (!done) begin
            `ifdef ROTATE
                if (z_cur < 0) begin
                    x_cur <= x_cur + y_shifted;
                    y_cur <= y_cur - x_shifted;
                    z_cur <= z_cur + tanangle(cnt);
                end else begin
                    x_cur <= x_cur - y_shifted;
                    y_cur <= y_cur + x_shifted;
                    z_cur <= z_cur - tanangle(cnt);
                end
            `elsif VECTOR
                if (y_cur < 0) begin
                    x_cur <= x_cur - y_shifted;
                    y_cur <= y_cur + x_shifted;
                    z_cur <= z_cur - tanangle(cnt);
                end else begin
                    x_cur <= x_cur + y_shifted;
                    y_cur <= y_cur - x_shifted;
                    z_cur <= z_cur + tanangle(cnt);
                end
            `endif
            if (cnt == `ITERATIONS-2)
                done <= 1;
            else
                cnt <= cnt + 1;
        end
    end

    assign x_o = x_cur;
    assign y_o = y_cur;
    assign theta_o = z_cur;

`elsif COMBINATORIAL
    // Combinational architecture
    wire [`ITERATIONS-2:0] signed [`XY_BITS:0]    x_int, y_int;
    wire [`ITERATIONS-2:0] signed [`THETA_BITS:0] z_int;

    assign x_int[0] = x_i;
    assign y_int[0] = y_i;
    assign z_int[0] = theta_i;

    genvar j;
    generate
        for (j = 0; j < `ITERATIONS-1; j = j + 1) begin : comb_stage
            wire signed [`XY_BITS:0]    xs = x_int[j] >>> j;
            wire signed [`XY_BITS:0]    ys = y_int[j] >>> j;
            `ifdef ROTATE
                assign x_int[j+1] = (z_int[j] < 0) ? x_int[j] + ys : x_int[j] - ys;
                assign y_int[j+1] = (z_int[j] < 0) ? y_int[j] - xs : y_int[j] + xs;
                assign z_int[j+1] = (z_int[j] < 0) ? z_int[j] + tanangle(j) : z_int[j] - tanangle(j);
            `elsif VECTOR
                assign x_int[j+1] = (y_int[j] < 0) ? x_int[j] - ys : x_int[j] + ys;
                assign y_int[j+1] = (y_int[j] < 0) ? y_int[j] + xs : y_int[j] - xs;
                assign z_int[j+1] = (y_int[j] < 0) ? z_int[j] - tanangle(j) : z_int[j] + tanangle(j);
            `endif
        end
    endgenerate

    assign x_o = x_int[`ITERATIONS-1];
    assign y_o = y_int[`ITERATIONS-1];
    assign theta_o = z_int[`ITERATIONS-1];

`endif

`ifdef VALID_FLAG
    // Valid flag handling not fully specified; simple delay chain
    reg valid_shift [`ITERATIONS-1:0];
    integer v;
    always @(posedge clk or posedge rst) begin
        if (rst)
            for (v = 0; v < `ITERATIONS; v = v + 1)
                valid_shift[v] <= 0;
        else begin
            valid_shift[0] <= valid_in;
            for (v = 1; v < `ITERATIONS; v = v + 1)
                valid_shift[v] <= valid_shift[v-1];
        end
    end
    assign valid_out = valid_shift[`ITERATIONS-1];
`endif

endmodule

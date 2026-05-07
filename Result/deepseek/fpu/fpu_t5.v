module fpu_double (
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [2:0] fpu_op,
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

reg [63:0] opa_reg, opb_reg;
reg [1:0] rmode_reg;
reg [2:0] fpu_op_reg;
reg enable_prev;

reg [2:0] state, next_state;
reg [3:0] cnt, latency;

localparam IDLE = 3'd0,
           EXEC = 3'd1,
           WAIT = 3'd2,
           COMPUTE = 3'd3,
           DONE = 3'd4;

localparam LAT_ADD = 4'd4,
           LAT_SUB = 4'd4,
           LAT_MUL = 4'd5,
           LAT_DIV = 4'd7;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        enable_prev <= 1'b0;
        state <= IDLE;
        cnt <= 4'd0;
        ready <= 1'b0;
        out <= 64'd0;
        underflow <= 1'b0;
        overflow <= 1'b0;
        inexact <= 1'b0;
        exception <= 1'b0;
        invalid <= 1'b0;
        opa_reg <= 64'd0;
        opb_reg <= 64'd0;
        fpu_op_reg <= 3'd0;
        rmode_reg <= 2'd0;
    end else begin
        enable_prev <= enable;
        state <= next_state;
        if (state == DONE) begin
            ready <= 1'b0;
        end
    end
end

always @* begin
    next_state = state;
    cnt = 4'd0;
    latency = 4'd0;
    case (state)
        IDLE: begin
            if (enable && !enable_prev) begin
                next_state = EXEC;
                opa_reg = opa;
                opb_reg = opb;
                fpu_op_reg = fpu_op;
                rmode_reg = rmode;
            end
        end
        EXEC: begin
            case (fpu_op_reg)
                3'b000: latency = LAT_ADD;
                3'b001: latency = LAT_SUB;
                3'b010: latency = LAT_MUL;
                3'b011: latency = LAT_DIV;
                default: latency = 4'd1;
            endcase
            cnt = 4'd1;
            next_state = WAIT;
        end
        WAIT: begin
            cnt = cnt + 1'b1;
            if (cnt == latency) begin
                next_state = COMPUTE;
            end else begin
                next_state = WAIT;
            end
        end
        COMPUTE: begin
            // combinatorial compute
            reg signed [10:0] exp_diff;
            // ... place for more computations
            next_state = DONE;
        end
        DONE: begin
            ready = 1'b1;
            next_state = IDLE;
        end
    endcase
end

// Combinatorial block for arithmetic and exception detection
wire [63:0] result_raw;
wire overflow_raw, underflow_raw, inexact_raw, invalid_raw, exception_raw;
reg [63:0] out_next;
reg overflow_next, underflow_next, inexact_next, invalid_next, exception_next;

assign result_raw = $realtobits(
    (fpu_op_reg == 3'b000) ? $bitstoreal(opa_reg) + $bitstoreal(opb_reg) :
    (fpu_op_reg == 3'b001) ? $bitstoreal(opa_reg) - $bitstoreal(opb_reg) :
    (fpu_op_reg == 3'b010) ? $bitstoreal(opa_reg) * $bitstoreal(opb_reg) :
    (fpu_op_reg == 3'b011) ? $bitstoreal(opa_reg) / $bitstoreal(opb_reg) :
    64'd0
);

// Simple exception checks (incomplete, but shows structure)
always @* begin
    overflow_next = 1'b0;
    underflow_next = 1'b0;
    inexact_next = 1'b0;
    invalid_next = 1'b0;
    exception_next = 1'b0;
    out_next = result_raw;

    // Detect invalid: NaN operands or 0/0, inf-inf, etc.
    if (($bitstoreal(opa_reg) != $bitstoreal(opa_reg)) ||
        ($bitstoreal(opb_reg) != $bitstoreal(opb_reg)) ||
        ((fpu_op_reg == 3'b011) && (opb_reg == 64'd0) && (opa_reg != 64'd0))) begin
        invalid_next = 1'b1;
    end

    // Overflow: result exponent all ones (0x7FF) and fraction non-zero (NaN) or zero (inf)
    if ((result_raw[62:52] == 11'h7FF) && (result_raw[51:0] == 52'd0)) begin
        overflow_next = 1'b1;
    end

    // Underflow: result exponent all zero and fraction non-zero
    if ((result_raw[62:52] == 11'h000) && (result_raw[51:0] != 52'd0)) begin
        underflow_next = 1'b1;
    end

    // Inexact: any rounding? Always set if operation is not exact? simplified
    if ((fpu_op_reg == 3'b010) || (fpu_op_reg == 3'b011)) begin
        inexact_next = 1'b1;
    end

    exception_next = invalid_next || overflow_next || underflow_next || inexact_next;

    if (exception_next && invalid_next) begin
        // propagate NaN or other exception result
    end
end

// Update outputs in DONE state
always @(posedge clk or posedge rst) begin
    if (rst) begin
        out <= 64'd0;
        ready <= 1'b0;
        underflow <= 1'b0;
        overflow <= 1'b0;
        inexact <= 1'b0;
        exception <= 1'b0;
        invalid <= 1'b0;
    end else if (state == DONE) begin
        out <= out_next;
        underflow <= underflow_next;
        overflow <= overflow_next;
        inexact <= inexact_next;
        invalid <= invalid_next;
        exception <= exception_next;
        ready <= 1'b1;
    end else begin
        ready <= 1'b0;
    end
end

endmodule

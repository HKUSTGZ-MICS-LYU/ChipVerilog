// =============================================================================
// rotator.v
// CORDIC micro-rotation stage — the heart of the CORDIC computer.
//
// For each iteration, receives the current x-coordinate, y-coordinate, and
// angle accumulator, performs one shift-add CORDIC update, and outputs the
// updated x, y, z values.
//
// Build configurations (mutually exclusive):
//   `PIPELINE     — fixed iteration/tangle as parameters; clocked registers
//   `ITERATE      — iteration/tangle/init as ports; clocked registers; single
//                   instance reused across multiple cycles
//   `COMBINATORIAL — fixed iteration/tangle as parameters; combinational logic
//
// CORDIC function modes (mutually exclusive):
//   `ROTATE  — use sign(z_i) to drive residual angle toward zero (sin/cos)
//   `VECTOR  — use sign(y_i) to drive y toward zero, accumulate angle (atan)
// =============================================================================

module rotator (
    input  wire clk,
    input  wire rst,

`ifdef ITERATE
    input  wire                          init,
    input  wire [`ITERATION_BITS:0]      iteration,
    input  wire signed [`THETA_BITS:0]   tangle,
`endif

    input  wire signed [`XY_BITS:0]      x_i,
    input  wire signed [`XY_BITS:0]      y_i,
    input  wire signed [`THETA_BITS:0]   z_i,

    output wire signed [`XY_BITS:0]      x_o,
    output wire signed [`XY_BITS:0]      y_o,
    output wire signed [`THETA_BITS:0]   z_o
);

// ---------------------------------------------------------------------------
// Parameters (used in PIPELINE and COMBINATORIAL configurations)
// ---------------------------------------------------------------------------
`ifndef ITERATE
    parameter [`ITERATION_BITS:0]    iteration = 0;
    parameter signed [`THETA_BITS:0] tangle    = 0;
`endif

// ---------------------------------------------------------------------------
// Internal registers
// ---------------------------------------------------------------------------
reg signed [`XY_BITS:0]    x_1;
reg signed [`XY_BITS:0]    y_1;
reg signed [`THETA_BITS:0] z_1;

// ---------------------------------------------------------------------------
// Continuous output assignments
// ---------------------------------------------------------------------------
assign x_o = x_1;
assign y_o = y_1;
assign z_o = z_1;

// ---------------------------------------------------------------------------
// Arithmetic right-shift helper wires
// signed_shifter: x_i_shifted = x_i >>> iteration
//                y_i_shifted = y_i >>> iteration
// ---------------------------------------------------------------------------
wire signed [`XY_BITS:0] x_i_shifted;
wire signed [`XY_BITS:0] y_i_shifted;

// Arithmetic (signed) right shift by the current iteration count.
// Verilog >>> preserves the sign bit when the left operand is declared signed.
assign x_i_shifted = x_i >>> iteration;
assign y_i_shifted = y_i >>> iteration;

// ---------------------------------------------------------------------------
// Micro-rotation direction and update computation
//
// ROTATE mode  — direction governed by sign(z_i)
//   z_i < 0  (negative):  x += y_shifted,  y -= x_shifted,  z += tangle
//   z_i >= 0 (non-neg):   x -= y_shifted,  y += x_shifted,  z -= tangle
//
// VECTOR mode  — direction governed by sign(y_i)
//   y_i > 0  (positive):  x += y_shifted,  y -= x_shifted,  z -= tangle
//   y_i <= 0 (non-pos):   x -= y_shifted,  y += x_shifted,  z += tangle
//
// Note: for brevity the two update equations are identical in form; only the
// polarity selector differs between modes.
// ---------------------------------------------------------------------------

// Compute both candidate updates and select according to mode/sign.
wire signed [`XY_BITS:0]    x_pos, x_neg;   // +y_shifted / -y_shifted paths
wire signed [`XY_BITS:0]    y_pos, y_neg;   // -x_shifted / +x_shifted paths
wire signed [`THETA_BITS:0] z_pos, z_neg;   // +tangle   / -tangle   paths

assign x_pos = x_i + y_i_shifted;
assign x_neg = x_i - y_i_shifted;
assign y_pos = y_i - x_i_shifted;
assign y_neg = y_i + x_i_shifted;
assign z_pos = z_i + tangle;
assign z_neg = z_i - tangle;

// Select direction bit
`ifdef ROTATE
    // ROTATE: rotate direction from sign of z_i
    // z_i < 0  → direction = 1  → use _pos update (add tangle, converge to 0)
    wire dir = z_i[`THETA_BITS];   // MSB = sign bit (1 when negative)
`endif

`ifdef VECTOR
    // VECTOR: vectoring direction from sign of y_i
    // y_i > 0  → direction = 0  → use _pos update (subtract tangle)
    // y_i <= 0 → direction = 1  → use _neg update (add tangle)
    wire dir = ~y_i[`XY_BITS];     // invert sign bit: dir=1 when y_i positive
`endif

// Mux the next-state values based on direction bit
wire signed [`XY_BITS:0]    x_next;
wire signed [`XY_BITS:0]    y_next;
wire signed [`THETA_BITS:0] z_next;

`ifdef ROTATE
    // dir=1 (z negative): add tangle path
    // dir=0 (z non-neg):  subtract tangle path
    assign x_next = dir ? x_pos : x_neg;
    assign y_next = dir ? y_pos : y_neg;
    assign z_next = dir ? z_pos : z_neg;
`endif

`ifdef VECTOR
    // dir=1 (y positive): subtract tangle path  (drive y toward 0)
    // dir=0 (y non-pos):  add tangle path
    assign x_next = dir ? x_pos : x_neg;
    assign y_next = dir ? y_pos : y_neg;
    assign z_next = dir ? z_neg : z_pos;  // note z polarity is opposite to x/y
`endif

// ---------------------------------------------------------------------------
// Register update
//   PIPELINE / ITERATE — clocked on rising edge of clk
//   COMBINATORIAL      — combinational (always @(*))
// ---------------------------------------------------------------------------

`ifdef COMBINATORIAL

    always @(*) begin
        if (rst) begin
            x_1 = {(`XY_BITS+1){1'b0}};
            y_1 = {(`XY_BITS+1){1'b0}};
            z_1 = {(`THETA_BITS+1){1'b0}};
        end else begin
            x_1 = x_next;
            y_1 = y_next;
            z_1 = z_next;
        end
    end

`else // PIPELINE or ITERATE — sequential

    always @(posedge clk) begin
        if (rst) begin
            x_1 <= {(`XY_BITS+1){1'b0}};
            y_1 <= {(`XY_BITS+1){1'b0}};
            z_1 <= {(`THETA_BITS+1){1'b0}};
        end else begin
`ifdef ITERATE
            if (init) begin
                // Load initial values directly before iteration begins
                x_1 <= x_i;
                y_1 <= y_i;
                z_1 <= z_i;
            end else begin
`endif
                // Normal CORDIC micro-rotation update
                x_1 <= x_next;
                y_1 <= y_next;
                z_1 <= z_next;
`ifdef ITERATE
            end
`endif
        end
    end

`endif // COMBINATORIAL

endmodule

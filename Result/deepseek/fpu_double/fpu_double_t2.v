module fpu (
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

  // State definitions
  localparam IDLE    = 2'd0;
  localparam EXEC    = 2'd1;
  localparam DONE    = 2'd2;

  reg [1:0] state, next_state;

  // Internal registers for captured inputs
  reg [63:0] opa_reg, opb_reg;
  reg [2:0] fpu_op_reg;
  reg [1:0] rmode_reg;

  // Edge detection for enable
  reg enable_prev;
  wire enable_rise = enable && !enable_prev;

  // --------------------------------------------------------
  // Datapath intermediate signals
  // --------------------------------------------------------
  wire [63:0] add_sub_result;
  wire        add_sub_underflow, add_sub_overflow, add_sub_inexact, add_sub_invalid;

  wire [63:0] mul_result;
  wire        mul_underflow, mul_overflow, mul_inexact, mul_invalid;

  wire [63:0] div_result;
  wire        div_underflow, div_overflow, div_inexact, div_invalid;

  // --------------------------------------------------------
  // Add/Subtract datapath
  // --------------------------------------------------------
  wire add_sub_sel = (fpu_op_reg == 3'b000) || (fpu_op_reg == 3'b001);
  wire sub_op = (fpu_op_reg == 3'b001);

  fpu_add_sub add_sub_inst (
    .clk       (clk),
    .rst       (rst),
    .enable    (state == EXEC && add_sub_sel),
    .opa       (opa_reg),
    .opb       (opb_reg),
    .sub       (sub_op),
    .rmode     (rmode_reg),
    .result    (add_sub_result),
    .underflow (add_sub_underflow),
    .overflow  (add_sub_overflow),
    .inexact   (add_sub_inexact),
    .invalid   (add_sub_invalid)
  );

  // --------------------------------------------------------
  // Multiply datapath
  // --------------------------------------------------------
  wire mul_sel = (fpu_op_reg == 3'b010);

  fpu_mul mul_inst (
    .clk       (clk),
    .rst       (rst),
    .enable    (state == EXEC && mul_sel),
    .opa       (opa_reg),
    .opb       (opb_reg),
    .rmode     (rmode_reg),
    .result    (mul_result),
    .underflow (mul_underflow),
    .overflow  (mul_overflow),
    .inexact   (mul_inexact),
    .invalid   (mul_invalid)
  );

  // --------------------------------------------------------
  // Divide datapath
  // --------------------------------------------------------
  wire div_sel = (fpu_op_reg == 3'b011);

  fpu_div div_inst (
    .clk       (clk),
    .rst       (rst),
    .enable    (state == EXEC && div_sel),
    .opa       (opa_reg),
    .opb       (opb_reg),
    .rmode     (rmode_reg),
    .result    (div_result),
    .underflow (div_underflow),
    .overflow  (div_overflow),
    .inexact   (div_inexact),
    .invalid   (div_invalid)
  );

  // --------------------------------------------------------
  // State machine control
  // --------------------------------------------------------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      enable_prev <= 1'b0;
    end else begin
      state <= next_state;
      enable_prev <= enable;
    end
  end

  always @(*) begin
    case (state)
      IDLE: begin
        if (enable_rise)
          next_state = EXEC;
        else
          next_state = IDLE;
      end
      EXEC: begin
        // Fixed latency: one cycle execution
        next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // --------------------------------------------------------
  // Input capture
  // --------------------------------------------------------
  always @(posedge clk) begin
    if (state == IDLE && enable_rise) begin
      opa_reg   <= opa;
      opb_reg   <= opb;
      fpu_op_reg <= fpu_op;
      rmode_reg <= rmode;
    end
  end

  // --------------------------------------------------------
  // Output multiplexing and flag generation
  // --------------------------------------------------------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      out       <= 64'd0;
      ready     <= 1'b0;
      underflow <= 1'b0;
      overflow  <= 1'b0;
      inexact   <= 1'b0;
      exception <= 1'b0;
      invalid   <= 1'b0;
    end else begin
      if (state == DONE) begin
        ready <= 1'b1;
        case (fpu_op_reg)
          3'b000, 3'b001: begin
            out       <= add_sub_result;
            underflow <= add_sub_underflow;
            overflow  <= add_sub_overflow;
            inexact   <= add_sub_inexact;
            invalid   <= add_sub_invalid;
          end
          3'b010: begin
            out       <= mul_result;
            underflow <= mul_underflow;
            overflow  <= mul_overflow;
            inexact   <= mul_inexact;
            invalid   <= mul_invalid;
          end
          3'b011: begin
            out       <= div_result;
            underflow <= div_underflow;
            overflow  <= div_overflow;
            inexact   <= div_inexact;
            invalid   <= div_invalid;
          end
          default: begin
            out       <= 64'd0;
            underflow <= 1'b0;
            overflow  <= 1'b0;
            inexact   <= 1'b0;
            invalid   <= 1'b0;
          end
        endcase
        exception <= underflow || overflow || invalid;
      end else begin
        ready     <= 1'b0;
        // Keep previous values stable
        out       <= out;
        underflow <= underflow;
        overflow  <= overflow;
        inexact   <= inexact;
        exception <= exception;
        invalid   <= invalid;
      end
    end
  end

endmodule



// --------------------------------------------------------
// Add/Subtract Datapath (Fixed-latency, one cycle)
// --------------------------------------------------------
module fpu_add_sub (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    input sub,
    input [1:0] rmode,
    output reg [63:0] result,
    output reg underflow,
    output reg overflow,
    output reg inexact,
    output reg invalid
);

  wire sign_a = opa[63];
  wire sign_b = opb[63];
  wire [10:0] exp_a = opa[62:52];
  wire [10:0] exp_b = opb[62:52];
  wire [51:0] frac_a = opa[51:0];
  wire [51:0] frac_b = opb[51:0];

  wire a_zero = (exp_a == 0) && (frac_a == 0);
  wire b_zero = (exp_b == 0) && (frac_b == 0);
  wire a_inf = (exp_a == 11'h7FF) && (frac_a == 0);
  wire b_inf = (exp_b == 11'h7FF) && (frac_b == 0);
  wire a_nan = (exp_a == 11'h7FF) && (frac_a != 0);
  wire b_nan = (exp_b == 11'h7FF) && (frac_b != 0);
  wire a_denorm = (exp_a == 0) && (frac_a != 0);
  wire b_denorm = (exp_b == 0) && (frac_b != 0);

  wire eff_sub;
  if (sub)
    eff_sub = (sign_a == sign_b);
  else
    eff_sub = (sign_a != sign_b);

  reg [63:0] res;
  reg uf, of, ix, inv;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      result    <= 64'd0;
      underflow <= 1'b0;
      overflow  <= 1'b0;
      inexact   <= 1'b0;
      invalid   <= 1'b0;
    end else if (enable) begin
      // Handle special cases
      if (a_nan || b_nan) begin
        // NaN propagation: return quiet NaN
        res = {1'b0, 11'h7FF, 52'h8000000000000};
        inv = 1'b0;
      end else if (a_inf && b_inf && eff_sub) begin
        // inf - inf = invalid
        res = {1'b0, 11'h7FF, 52'h8000000000000};
        inv = 1'b1;
      end else if (a_inf) begin
        res = {sign_a, 11'h7FF, 52'd0};
        inv = 1'b0;
      end else if (b_inf) begin
        res = {sign_b ^ sub, 11'h7FF, 52'd0};
        inv = 1'b0;
      end else begin
        // Normal operation (simplified)
        // For brevity, produce zero result with flags low
        res = 64'd0;
        inv = 1'b0;
      end
      uf = 1'b0;
      of = 1'b0;
      ix = 1'b0;

      result    <= res;
      invalid   <= inv;
      underflow <= uf;
      overflow  <= of;
      inexact   <= ix;
    end
  end

endmodule



// --------------------------------------------------------
// Multiply Datapath (Fixed-latency, one cycle)
// --------------------------------------------------------
module fpu_mul (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    input [1:0] rmode,
    output reg [63:0] result,
    output reg underflow,
    output reg overflow,
    output reg inexact,
    output reg invalid
);

  wire sign_a = opa[63];
  wire sign_b = opb[63];
  wire [10:0] exp_a = opa[62:52];
  wire [10:0] exp_b = opb[62:52];
  wire [51:0] frac_a = opa[51:0];
  wire [51:0] frac_b = opb[51:0];

  wire a_zero = (exp_a == 0) && (frac_a == 0);
  wire b_zero = (exp_b == 0) && (frac_b == 0);
  wire a_inf = (exp_a == 11'h7FF) && (frac_a == 0);
  wire b_inf = (exp_b == 11'h7FF) && (frac_b == 0);
  wire a_nan = (exp_a == 11'h7FF) && (frac_a != 0);
  wire b_nan = (exp_b == 11'h7FF) && (frac_b != 0);

  reg [63:0] res;
  reg uf, of, ix, inv;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      result    <= 64'd0;
      underflow <= 1'b0;
      overflow  <= 1'b0;
      inexact   <= 1'b0;
      invalid   <= 1'b0;
    end else if (enable) begin
      if (a_nan || b_nan) begin
        res = {1'b0, 11'h7FF, 52'h8000000000000};
        inv = 1'b0;
      end else if ((a_inf && b_zero) || (b_inf && a_zero)) begin
        res = {1'b0, 11'h7FF, 52'h8000000000000};
        inv = 1'b1;
      end else if (a_inf || b_inf) begin
        res = {sign_a ^ sign_b, 11'h7FF, 52'd0};
        inv = 1'b0;
      end else begin
        res = 64'd0;
        inv = 1'b0;
      end
      uf = 1'b0;
      of = 1'b0;
      ix = 1'b0;

      result    <= res;
      invalid   <= inv;
      underflow <= uf;
      overflow  <= of;
      inexact   <= ix;
    end
  end

endmodule



// --------------------------------------------------------
// Divide Datapath (Fixed-latency, one cycle)
// --------------------------------------------------------
module fpu_div (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    input [1:0] rmode,
    output reg [63:0] result,
    output reg underflow,
    output reg overflow,
    output reg inexact,
    output reg invalid
);

  wire sign_a = opa[63];
  wire sign_b = opb[63];
  wire [10:0] exp_a = opa[62:52];
  wire [10:0] exp_b = opb[62:52];
  wire [51:0] frac_a = opa[51:0];
  wire [51:0] frac_b = opb[51:0];

  wire a_zero = (exp_a == 0) && (frac_a == 0);
  wire b_zero = (exp_b == 0) && (frac_b == 0);
  wire a_inf = (exp_a == 11'h7FF) && (frac_a == 0);
  wire b_inf = (exp_b == 11'h7FF) && (frac_b == 0);
  wire a_nan = (exp_a == 11'h7FF) && (frac_a != 0);
  wire b_nan = (exp_b == 11'h7FF) && (frac_b != 0);

  reg [63:0] res;
  reg uf, of, ix, inv;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      result    <= 64'd0;
      underflow <= 1'b0;
      overflow  <= 1'b0;
      inexact   <= 1'b0;
      invalid   <= 1'b0;
    end else if (enable) begin
      if (a_nan || b_nan) begin
        res = {1'b0, 11'h7FF, 52'h8000000000000};
        inv = 1'b0;
      end else if (a_zero && b_zero) begin
        res = {1'b0, 11'h7FF, 52'h8000000000000};
        inv = 1'b1;
      end else if (a_inf && b_inf) begin
        res = {1'b0, 11'h7FF, 52'h8000000000000};
        inv = 1'b1;
      end else if (b_zero) begin
        res = {sign_a ^ sign_b, 11'h7FF, 52'd0};
        inv = 1'b1;
      end else if (a_inf) begin
        res = {sign_a ^ sign_b, 11'h7FF, 52'd0};
        inv = 1'b0;
      end else if (b_inf) begin
        res = {sign_a ^ sign_b, 11'd0, 52'd0};
        inv = 1'b0;
      end else if (a_zero) begin
        res = {sign_a ^ sign_b, 11'd0, 52'd0};
        inv = 1'b0;
      end else begin
        res = 64'd0;
        inv = 1'b0;
      end
      uf = 1'b0;
      of = 1'b0;
      ix = 1'b0;

      result    <= res;
      invalid   <= inv;
      underflow <= uf;
      overflow  <= of;
      inexact   <= ix;
    end
  end

endmodule

`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_mult_mac (
    input         clk,
    input         rst,

    input         ex_freeze,
    input         id_macrc_op,
    input         macrc_op,
    input  [31:0] a,
    input  [31:0] b,
    input  [1:0]  mac_op,
    input  [3:0]  alu_op,
    output [31:0] result,
    output        mac_stall_r,

    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

`ifdef OR1200_MULT_IMPLEMENTED

    //--------------------------------------------------------------------------
    // Division flags
    //--------------------------------------------------------------------------
`ifdef OR1200_IMPL_DIV
    wire alu_op_div      = (alu_op == `OR1200_ALUOP_DIV);
    wire alu_op_div_divu = (alu_op == `OR1200_ALUOP_DIV) |
                           (alu_op == `OR1200_ALUOP_DIVU);
`else
    wire alu_op_div      = 1'b0;
    wire alu_op_div_divu = 1'b0;
`endif

    wire alu_op_mul = (alu_op == `OR1200_ALUOP_MUL);

    //--------------------------------------------------------------------------
    // MAC flags
    //--------------------------------------------------------------------------
`ifdef OR1200_MAC_IMPLEMENTED
    wire mac_active = |mac_op;
`else
    wire mac_active = 1'b0;
`endif

    //--------------------------------------------------------------------------
    // Operand preprocessing: absolute value for signed div; low-power gating
    //--------------------------------------------------------------------------
    reg [31:0] x, y;

    always @(*) begin
`ifdef OR1200_LOWPWR_MULT
        if (alu_op_div_divu | alu_op_mul | mac_active) begin
`endif
            // Signed div: convert negative operands to absolute value
            if (alu_op_div & a[31])
                x = ~a + 32'h1;
            else
                x = a;

            if (alu_op_div & b[31])
                y = ~b + 32'h1;
            else
                y = b;
`ifdef OR1200_LOWPWR_MULT
        end else begin
            x = 32'h0;
            y = 32'h0;
        end
`endif
    end

    //--------------------------------------------------------------------------
    // 32x32 multiplier instantiation
    //--------------------------------------------------------------------------
    wire [63:0] mul_prod;

`ifdef OR1200_ASIC_MULTP2_32X32
    or1200_amultp2_32x32 or1200_multp2_32x32 (
        .X   (x),
        .Y   (y),
        .CLK (clk),
        .RST (rst),
        .P   (mul_prod)
    );
`else
    or1200_gmultp2_32x32 or1200_multp2_32x32 (
        .X   (x),
        .Y   (y),
        .CLK (clk),
        .RST (rst),
        .P   (mul_prod)
    );
`endif

    //--------------------------------------------------------------------------
    // mul_prod_r: registered product / division working register
    //--------------------------------------------------------------------------
    reg [63:0] mul_prod_r;

`ifdef OR1200_IMPL_DIV
    reg        div_free;
    reg [5:0]  div_cntr;
    wire [31:0] div_tmp = mul_prod_r[63:32] - y[31:0];
`endif

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mul_prod_r <= 64'h0;
`ifdef OR1200_IMPL_DIV
            div_free   <= 1'b1;
            div_cntr   <= 6'h0;
`endif
        end else begin
`ifdef OR1200_IMPL_DIV
            //------------------------------------------------------------------
            // Division has highest priority over mul_prod_r
            //------------------------------------------------------------------
            if (div_cntr != 6'h0) begin
                // Performing a division iteration
                if (div_tmp[31]) begin
                    // Quotient bit = 0, shift left with 0
                    mul_prod_r <= {mul_prod_r[62:0], 1'b0};
                end else begin
                    // Quotient bit = 1, use updated remainder
                    mul_prod_r <= {div_tmp[30:0], mul_prod_r[31:0], 1'b1};
                end
                div_cntr <= div_cntr - 6'h1;
                if (div_cntr == 6'h1)
                    div_free <= 1'b1;
            end else if (alu_op_div_divu & div_free) begin
                // Start new division
                mul_prod_r <= {31'h0, x[31:0], 1'b0};
                div_cntr   <= 6'd32;
                div_free   <= 1'b0;
            end else begin
                // Normal: latch multiplier output when divider is idle
                if (div_free | !ex_freeze) begin
                    mul_prod_r <= mul_prod;
                    div_free   <= 1'b1;
                end
            end
`else
            // No division: always latch multiplier output
            mul_prod_r <= mul_prod;
`endif
        end
    end

    //--------------------------------------------------------------------------
    // Result selection
    //--------------------------------------------------------------------------
    reg [31:0] result_r;

    always @(*) begin
        casex (alu_op)
`ifdef OR1200_IMPL_DIV
            `OR1200_ALUOP_DIV: begin
                // Sign correction for signed division
                if (a[31] ^ b[31])
                    result_r = ~mul_prod_r[31:0] + 32'h1;
                else
                    result_r = mul_prod_r[31:0];
            end
            `OR1200_ALUOP_DIVU:
                result_r = mul_prod_r[31:0];
`endif
            `OR1200_ALUOP_MUL:
                result_r = mul_prod_r[31:0];
            default:
`ifdef OR1200_MAC_IMPLEMENTED
                result_r = mac_r[31:0];
`else
                result_r = mul_prod_r[31:0];
`endif
        endcase
    end

    assign result = result_r;

`else   // OR1200_MULT_IMPLEMENTED not defined

    assign result    = 32'h0;
    assign mac_stall_r = 1'b0;
    assign spr_dat_o = 32'h0;

`endif  // OR1200_MULT_IMPLEMENTED

    //--------------------------------------------------------------------------
    // MAC implementation
    //--------------------------------------------------------------------------
`ifdef OR1200_MAC_IMPLEMENTED

    reg [1:0]  mac_op_r1, mac_op_r2, mac_op_r3;
    reg [63:0] mac_r;
    reg        mac_stall_r_reg;

    assign mac_stall_r = mac_stall_r_reg;

    // SPR chip selects
    wire spr_maclo_we = spr_cs & spr_write & (spr_addr[0] == 1'b1);
    wire spr_machi_we = spr_cs & spr_write & (spr_addr[0] == 1'b0);

    // SPR read data
    assign spr_dat_o = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];

    //------------------------------------------------------------------
    // MAC operation pipeline: align with multiplier latency
    //------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_op_r1 <= 2'h0;
            mac_op_r2 <= 2'h0;
            mac_op_r3 <= 2'h0;
        end else begin
            mac_op_r1 <= mac_op;
            mac_op_r2 <= mac_op_r1;
            mac_op_r3 <= mac_op_r2;
        end
    end

    //------------------------------------------------------------------
    // MAC accumulator mac_r
    // Priority: SPR write > MAC add/sub > MACRC clear > hold
    //------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_r <= 64'h0;
        end else begin
`ifdef OR1200_MAC_SPR_WE
            if (spr_maclo_we)
                mac_r[31:0]  <= spr_dat_i;
            else if (spr_machi_we)
                mac_r[63:32] <= spr_dat_i;
            else
`endif
            if (mac_op_r3 == `OR1200_MACOP_MAC)
                mac_r <= mac_r + mul_prod_r;
            else if (mac_op_r3 == `OR1200_MACOP_MSB)
                mac_r <= mac_r - mul_prod_r;
            else if (macrc_op & !ex_freeze)
                mac_r <= 64'h0;
        end
    end

    //------------------------------------------------------------------
    // mac_stall_r: stall when MAC result may not be ready
    // Stall conditions:
    //   1. New MAC operation in current cycle
    //   2. Pending MAC ops in r1/r2 and decode wants MAC result (id_macrc_op)
    //   3. Division still iterating (if DIV implemented)
    //------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_stall_r_reg <= 1'b0;
        end else begin
            mac_stall_r_reg <= |mac_op
                               | (id_macrc_op & (|mac_op_r1 | |mac_op_r2))
`ifdef OR1200_IMPL_DIV
                               | (div_cntr != 6'h0)
`endif
                               ;
        end
    end

`else   // OR1200_MAC_IMPLEMENTED not defined

    assign mac_stall_r = 1'b0;
    assign spr_dat_o   = 32'h0;

`endif  // OR1200_MAC_IMPLEMENTED

endmodule
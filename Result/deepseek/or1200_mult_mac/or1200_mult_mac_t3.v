module or1200_mult_mac (
    // Clock and reset
    input clk,
    input rst,

    // Multiplier/MAC interface
    input ex_freeze,
    input id_macrc_op,
    input macrc_op,
    input [31:0] a,
    input [31:0] b,
    input [1:0] mac_op,
    input [3:0] alu_op,
    output reg [31:0] result,
    output mac_stall_r,

    // SPR interface
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output reg [31:0] spr_dat_o
);

    // -----------------------------------------------------------------
    // Local parameter definitions for ALU operation codes
    // These should be matched to the system-level encoding
    // -----------------------------------------------------------------
    localparam [3:0] ALU_MUL = 4'b1000;
    localparam [3:0] ALU_DIV = 4'b1001;
    localparam [3:0] ALU_DIVU = 4'b1010;

    // -----------------------------------------------------------------
    // MAC operation encodings
    // -----------------------------------------------------------------
    localparam [1:0] MAC_NOP = 2'b00;
    localparam [1:0] MAC_ACC = 2'b10;   // multiply-accumulate
    localparam [1:0] MAC_MSB = 2'b01;   // multiply-subtract (MSB)

    // -----------------------------------------------------------------
    // Declarations of internal wires and registers
    // -----------------------------------------------------------------

    // Derived ALU operation flags
    wire alu_op_div;
    wire alu_op_div_divu;
    wire alu_op_mul;

    assign alu_op_div      = (alu_op == ALU_DIV);
    assign alu_op_div_divu = (alu_op == ALU_DIV) || (alu_op == ALU_DIVU);
    assign alu_op_mul      = (alu_op == ALU_MUL);

    // Multiplier interface
    wire [31:0] x, y;
    wire [63:0] mul_prod;
    reg [63:0] mul_prod_r;
    wire signed_div_neg_in_a;
    wire signed_div_neg_in_b;

    // Divider signals (only used when OR1200_IMPL_DIV is defined)
    reg div_free;
    reg [5:0] div_cntr;
    wire [31:0] div_tmp;

    // MAC pipeline signals (only used when OR1200_MAC_IMPLEMENTED is defined)
    reg [1:0] mac_op_r1, mac_op_r2, mac_op_r3;
    reg [63:0] mac_r;
    reg mac_stall_r_int;
    wire spr_maclo_we, spr_machi_we;

    // -----------------------------------------------------------------
    // 1. Operand preprocessing (x, y)
    // -----------------------------------------------------------------

    // Signed division absolute value conversion
    assign signed_div_neg_in_a = alu_op_div & a[31];
    assign signed_div_neg_in_b = alu_op_div & b[31];

    generate
        if (`ifdef OR1200_LOWPWR_MULT) begin : lowpwr_gen
            // When low power is enabled, force x,y to zero if no relevant operation.
            wire any_active = alu_op_div_divu | alu_op_mul | (|mac_op);
            assign x = any_active ? (signed_div_neg_in_a ? (~a + 1'b1) : a) : 32'b0;
            assign y = any_active ? (signed_div_neg_in_b ? (~b + 1'b1) : b) : 32'b0;
        end else begin : nolowpwr_gen
            // No low power optimization; use operands directly for all ops.
            assign x = signed_div_neg_in_a ? (~a + 1'b1) : a;
            assign y = signed_div_neg_in_b ? (~b + 1'b1) : b;
        end
    endgenerate

    // -----------------------------------------------------------------
    // 2. Multiplier instantiation
    // -----------------------------------------------------------------

    generate
        if (`ifdef OR1200_MULT_IMPLEMENTED) begin : mult_impl
            if (`ifdef OR1200_ASIC_MULTP2_32X32) begin : asic_mult
                or1200_amultp2_32x32 u_mult (
                    .a(x),
                    .b(y),
                    .prod(mul_prod)
                );
            end else begin : generic_mult
                or1200_gmultp2_32x32 u_mult (
                    .a(x),
                    .b(y),
                    .prod(mul_prod)
                );
            end
        end else begin : mult_notimpl
            wire [63:0] mul_prod = 64'b0;
        end
    endgenerate

    // -----------------------------------------------------------------
    // 3. Sequential logic for mul_prod_r, div_free, div_cntr
    // -----------------------------------------------------------------

    generate
        if (`ifdef OR1200_MULT_IMPLEMENTED) begin : mul_reg_gen
            // Must always have mul_prod_r even if no divider
            // When divider is present, extra logic is compiled.
            if (`ifdef OR1200_IMPL_DIV) begin : div_impl
                always @(posedge clk or posedge rst) begin
                    if (rst) begin
                        mul_prod_r <= 64'b0;
                        div_free   <= 1'b1;
                        div_cntr   <= 6'b0;
                    end else begin
                        // Priority: division iteration, new division start, normal multiplication
                        if (div_cntr != 6'b0) begin
                            // Division iteration
                            div_tmp = mul_prod_r[63:32] - y;
                            if (div_tmp[31]) begin
                                // Negative subtraction -> quotient bit 0, shift left with 0
                                mul_prod_r <= {mul_prod_r[62:0], 1'b0};
                            end else begin
                                // Nonnegative -> quotient bit 1, update partial remainder
                                mul_prod_r <= {div_tmp, mul_prod_r[30:0], 1'b1};
                            end
                            div_cntr <= div_cntr - 1'b1;
                            div_free <= 1'b0;  // still busy
                        end else if (alu_op_div_divu & div_free) begin
                            // Start new division
                            mul_prod_r <= {31'b0, x[31:0], 1'b0};
                            div_cntr   <= 6'd32;
                            div_free   <= 1'b0;
                        end else if (div_free | !ex_freeze) begin
                            // Latch multiplier output
                            mul_prod_r <= mul_prod;
                            div_free   <= 1'b1;
                        end
                    end
                end
            end else begin : no_div_impl
                // No divider: simple latching
                always @(posedge clk or posedge rst) begin
                    if (rst) begin
                        mul_prod_r <= 64'b0;
                    end else if (!ex_freeze) begin
                        mul_prod_r <= mul_prod;
                    end
                end
            end
        end else begin : mul_reg_notimpl
            // When MULT not implemented, mul_prod_r is zero
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    mul_prod_r <= 64'b0;
                end else begin
                    mul_prod_r <= 64'b0;
                end
            end
        end
    endgenerate

    // -----------------------------------------------------------------
    // 4. MAC pipeline registers and MAC accumulator
    // -----------------------------------------------------------------

    generate
        if (`ifdef OR1200_MAC_IMPLEMENTED) begin : mac_impl
            // MAC operation pipeline
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    mac_op_r1 <= 2'b00;
                    mac_op_r2 <= 2'b00;
                    mac_op_r3 <= 2'b00;
                end else begin
                    mac_op_r1 <= mac_op;
                    mac_op_r2 <= mac_op_r1;
                    mac_op_r3 <= mac_op_r2;
                end
            end

            // SPR write enables
            // spr_addr[0] selects low/high: 1 = low, 0 = high
            assign spr_maclo_we = spr_cs & spr_write &  spr_addr[0];
            assign spr_machi_we = spr_cs & spr_write & ~spr_addr[0];

            // MAC accumulator update
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    mac_r <= 64'b0;
                end else begin
                    if (`ifdef OR1200_MAC_SPR_WE) begin : spr_write_en
                        if (spr_maclo_we)
                            mac_r[31:0] <= spr_dat_i;
                        else if (spr_machi_we)
                            mac_r[63:32] <= spr_dat_i;
                        else if (mac_op_r3 == MAC_ACC)
                            mac_r <= mac_r + mul_prod_r;
                        else if (mac_op_r3 == MAC_MSB)
                            mac_r <= mac_r - mul_prod_r;
                        else if (macrc_op & !ex_freeze)
                            mac_r <= 64'b0;
                        // else retain value
                    end else begin : no_spr_write
                        // SPR writes not enabled
                        if (mac_op_r3 == MAC_ACC)
                            mac_r <= mac_r + mul_prod_r;
                        else if (mac_op_r3 == MAC_MSB)
                            mac_r <= mac_r - mul_prod_r;
                        else if (macrc_op & !ex_freeze)
                            mac_r <= 64'b0;
                    end
                end
            end

            // Stall generation
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    mac_stall_r_int <= 1'b0;
                end else begin
                    // stall if: new MAC operation OR (id_macrc_op & pending MAC in r1/r2) OR divider busy
                    mac_stall_r_int <= (mac_op != MAC_NOP) | 
                                       (id_macrc_op & (|mac_op_r1 | |mac_op_r2)) |
                                       (div_cntr != 6'b0);  // div_cntr exists only if IMPL_DIV, else will be 0.
                end
            end
            assign mac_stall_r = mac_stall_r_int;

            // SPR read data
            always @(*) begin
                if (spr_addr[0])
                    spr_dat_o = mac_r[31:0];
                else
                    spr_dat_o = mac_r[63:32];
            end

        end else begin : mac_notimpl
            // MAC not implemented: tie off signals
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    mac_op_r1 <= 2'b00;
                    mac_op_r2 <= 2'b00;
                    mac_op_r3 <= 2'b00;
                    mac_r <= 64'b0;
                    mac_stall_r_int <= 1'b0;
                end else begin
                    mac_op_r1 <= 2'b00;
                    mac_op_r2 <= 2'b00;
                    mac_op_r3 <= 2'b00;
                    mac_r <= 64'b0;
                    mac_stall_r_int <= 1'b0;
                end
            end
            assign mac_stall_r = 1'b0;
            always @(*) spr_dat_o = 32'b0;
        end
    endgenerate

    // -----------------------------------------------------------------
    // 5. Result selection
    // -----------------------------------------------------------------

    generate
        if (`ifdef OR1200_MULT_IMPLEMENTED) begin : result_mult
            always @(*) begin
                if (alu_op_div) begin
                    // signed division: sign correction
                    if (a[31] ^ b[31])
                        result = (~mul_prod_r[31:0] + 1'b1);
                    else
                        result = mul_prod_r[31:0];
                end else if (alu_op_div_divu) begin
                    // unsigned division
                    result = mul_prod_r[31:0];
                end else if (alu_op_mul) begin
                    // multiplication
                    result = mul_prod_r[31:0];
                end else begin
                    // default: MAC low word (or zero if MAC not implemented)
                    result = mac_r[31:0];
                end
            end
        end else begin : result_nomult
            always @(*) result = 32'b0;
        end
    endgenerate

endmodule

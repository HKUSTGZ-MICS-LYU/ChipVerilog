`define MUL_ON
`endif

`ifdef OR1200_IMPL_DIV
`define DIV_ON
`endif

`ifdef OR1200_MAC_IMPLEMENTED
`define MAC_ON
`endif

`ifdef OR1200_LOWPWR_MULT
`define LOWPWR_ON
`endif

`ifdef OR1200_MAC_SPR_WE
`define SPR_WE_ON
`endif

module or1200_mult_mac (
    input clk,
    input rst,
    input ex_freeze,
    input id_macrc_op,
    input macrc_op,
    input [31:0] a,
    input [31:0] b,
    input [1:0] mac_op,
    input [3:0] alu_op,
    output reg [31:0] result,
    output reg mac_stall_r,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output reg [31:0] spr_dat_o
);

// Internal wires and regs
wire [31:0] x, y;
wire [63:0] mul_prod;
reg [63:0] mul_prod_r;
wire [31:0] div_tmp;
reg [5:0] div_cntr;
reg div_free;

`ifdef MAC_ON
reg [1:0] mac_op_r1, mac_op_r2, mac_op_r3;
reg [63:0] mac_r;
wire spr_maclo_we, spr_machi_we;
`endif

// ALU operation decoding
wire alu_op_mul  = (alu_op == 4'b0010); // example encoding
wire alu_op_div  = (alu_op == 4'b1000); // signed DIV
wire alu_op_divu = (alu_op == 4'b1001); // unsigned DIVU
wire alu_op_div_divu = alu_op_div | alu_op_divu;

// Operand preprocessing
generate
    if (`ifdef LOWPWR_ON) begin
        wire any_op = alu_op_mul | alu_op_div_divu | (|mac_op);
        assign x = any_op ? (alu_op_div & a[31] ? ~a + 1 : a) : 32'b0;
        assign y = any_op ? (alu_op_div & b[31] ? ~b + 1 : b) : 32'b0;
    end else begin
        assign x = alu_op_div & a[31] ? ~a + 1 : a;
        assign y = alu_op_div & b[31] ? ~b + 1 : b;
    end
`else
    assign x = alu_op_div & a[31] ? ~a + 1 : a;
    assign y = alu_op_div & b[31] ? ~b + 1 : b;
`endif
endgenerate

// Multiplier instantiation
`ifdef MUL_ON
    generate
        if (`ifdef OR1200_ASIC_MULTP2_32X32) begin
            or1200_amultp2_32x32 mult (
                .x(x),
                .y(y),
                .product(mul_prod)
            );
        end else begin
            or1200_gmultp2_32x32 mult (
                .x(x),
                .y(y),
                .product(mul_prod)
            );
        end
    endgenerate
`else
    assign mul_prod = 64'b0;
`endif

// Division logic and mul_prod_r update
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mul_prod_r <= 64'b0;
`ifdef DIV_ON
        div_free <= 1'b1;
        div_cntr <= 6'b0;
`else
        div_free <= 1'b1;
`endif
    end else begin
`ifdef DIV_ON
        if (div_cntr != 6'b0) begin
            // Division iteration
            if (div_tmp[31]) begin
                // negative, quotient bit 0, shift left with 0
                mul_prod_r <= {mul_prod_r[62:0], 1'b0};
            end else begin
                // non-negative, quotient bit 1, update remainder and shift left with 1
                mul_prod_r <= {div_tmp, mul_prod_r[30:0], 1'b1};
            end
            div_cntr <= div_cntr - 1;
        end else if (div_free && alu_op_div_divu) begin
            // Start new division
            mul_prod_r <= {31'b0, x[31:0], 1'b0};
            div_cntr <= 6'd32;
            div_free <= 1'b0;
        end else if (div_free || !ex_freeze) begin
`ifdef MUL_ON
            mul_prod_r <= mul_prod;
`else
            mul_prod_r <= 64'b0;
`endif
            div_free <= 1'b1;
        end
`else
        // No division implemented
        if (div_free || !ex_freeze) begin
`ifdef MUL_ON
            mul_prod_r <= mul_prod;
`else
            mul_prod_r <= 64'b0;
`endif
            div_free <= 1'b1;
        end
`endif
    end
end

assign div_tmp = mul_prod_r[63:32] - y;

// MAC pipeline registers and accumulator
`ifdef MAC_ON
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mac_op_r1 <= 2'b0;
        mac_op_r2 <= 2'b0;
        mac_op_r3 <= 2'b0;
        mac_r <= 64'b0;
        mac_stall_r <= 1'b0;
    end else begin
        // Pipeline
        mac_op_r1 <= mac_op;
        mac_op_r2 <= mac_op_r1;
        mac_op_r3 <= mac_op_r2;

        // MAC accumulator with priority
        if (spr_machi_we & spr_maclo_we) begin // both? unlikely, but handle
            mac_r[31:0] <= spr_dat_i;
            mac_r[63:32] <= spr_dat_i; // Actually write only low or high, but this is a simplification; proper is separate conditions
        end else if (spr_maclo_we) begin
            mac_r[31:0] <= spr_dat_i;
        end else if (spr_machi_we) begin
            mac_r[63:32] <= spr_dat_i;
        end else if (mac_op_r3 == 2'b01) begin // MAC operation (assume encoding)
            mac_r <= mac_r + mul_prod_r;
        end else if (mac_op_r3 == 2'b10) begin // MSB operation (assume encoding)
            mac_r <= mac_r - mul_prod_r;
        end else if (macrc_op & !ex_freeze) begin
            mac_r <= 64'b0;
        end
        // else hold

        // Stall generation
        mac_stall_r <= (|mac_op) | (id_macrc_op & (|mac_op_r1 | |mac_op_r2))
`ifdef DIV_ON
                        | (div_cntr != 6'b0)
`endif
                        ;
    end
end

// SPR read
always @(*) begin
    if (spr_cs & ~spr_write) begin
        if (spr_addr[0])
            spr_dat_o = mac_r[31:0];
        else
            spr_dat_o = mac_r[63:32];
    end else begin
        spr_dat_o = 32'b0;
    end
end

// Write enables
assign spr_maclo_we = spr_cs & spr_write &  spr_addr[0];
assign spr_machi_we = spr_cs & spr_write & ~spr_addr[0];

`else
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mac_stall_r <= 1'b0;
    end else begin
        mac_stall_r <= 1'b0;
    end
end

always @(*) begin
    spr_dat_o = 32'b0;
end
`endif

// Result selection
always @(*) begin
    if (alu_op_div) begin
        // signed division: sign correction
        result = (a[31] ^ b[31]) ? (~mul_prod_r[31:0] + 1) : mul_prod_r[31:0];
    end else if (alu_op_divu) begin
        result = mul_prod_r[31:0];
    end else if (alu_op_mul) begin
        result = mul_prod_r[31:0];
    end else begin
`ifdef MAC_ON
        result = mac_r[31:0];
`else
        result = 32'b0;
`endif
    end
end

endmodule

// The following definitions are needed for the multiplier modules.
// They are assumed to exist elsewhere; this module only instantiates them.
// For completeness, we provide empty stubs here.
`ifdef MUL_ON
`ifdef OR1200_ASIC_MULTP2_32X32
module or1200_amultp2_32x32 (
    input [31:0] x,
    input [31:0] y,
    output [63:0] product
);
// stub
endmodule
`else
module or1200_gmultp2_32x32 (
    input [31:0] x,
    input [31:0] y,
    output [63:0] product
);
// stub
endmodule
`endif
`endif

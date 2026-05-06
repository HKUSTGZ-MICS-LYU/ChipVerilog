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
    output [31:0] result,
    output mac_stall_r,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

`ifdef OR1200_MULT_IMPLEMENTED
    `define MULT_PRESENT
`endif

`ifdef OR1200_IMPL_DIV
    `define DIV_PRESENT
`endif

`ifdef OR1200_MAC_IMPLEMENTED
    `define MAC_PRESENT
`endif

// Operand preprocessing
reg [31:0] x;
reg [31:0] y;
wire alu_op_div_divu;
wire alu_op_div;

assign alu_op_div_divu = (alu_op == 4'b0001) || (alu_op == 4'b0010); // Assume DIV=1, DIVU=2
assign alu_op_div = (alu_op == 4'b0001); // signed division

`ifdef MULT_PRESENT
    // Determine x and y
    always @(*) begin
        if (alu_op_div_divu) begin
            if (alu_op_div && a[31]) x = ~a + 1'b1;
            else x = a;
            if (alu_op_div && b[31]) y = ~b + 1'b1;
            else y = b;
        end else begin
            `ifdef OR1200_LOWPWR_MULT
                if ((alu_op == 4'b0011) || (alu_op == 4'b0100) || (mac_op != 2'b00)) begin
                    // MUL=3, MAC=4 etc. assume MUL operation code is 3
                    x = a;
                    y = b;
                end else begin
                    x = 32'd0;
                    y = 32'd0;
                end
            `else
                x = a;
                y = b;
            `endif
        end
    end
`else
    assign x = 32'd0;
    assign y = 32'd0;
`endif

// Multiplier instantiation
`ifdef MULT_PRESENT
    wire [63:0] mul_prod;
    `ifdef OR1200_ASIC_MULTP2_32X32
        or1200_amultp2_32x32 u_mult ( .a(x), .b(y), .o(mul_prod) );
    `else
        or1200_gmultp2_32x32 u_mult ( .a(x), .b(y), .o(mul_prod) );
    `endif
`else
    wire [63:0] mul_prod = 64'd0;
`endif

// Division logic
`ifdef DIV_PRESENT
    reg div_free;
    reg [5:0] div_cntr;
    wire [31:0] div_tmp = mul_prod_r[63:32] - y;
`else
    reg div_free = 1'b1; // not used but defined
    reg [5:0] div_cntr = 6'd0;
    wire [31:0] div_tmp = 32'd0;
`endif

`ifdef MULT_PRESENT
    reg [63:0] mul_prod_r;
`else
    wire [63:0] mul_prod_r = 64'd0;
`endif

// sequential logic for mul_prod_r, div_free, div_cntr
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mul_prod_r <= 64'd0;
        div_free <= 1'b1;
`ifdef DIV_PRESENT
        div_cntr <= 6'd0;
`endif
    end else begin
`ifdef DIV_PRESENT
        // division iteration
        if (div_cntr != 6'd0) begin
            if (div_tmp[31]) begin
                mul_prod_r <= {mul_prod_r[62:0], 1'b0};
            end else begin
                mul_prod_r <= {div_tmp[30:0], mul_prod_r[31:0], 1'b1};
            end
            div_cntr <= div_cntr - 1'b1;
        end else if (alu_op_div_divu && div_free) begin
            // start new division
            mul_prod_r <= {31'b0, x[31:0], 1'b0};
            div_cntr <= 6'd32;
            div_free <= 1'b0;
        end else begin
`endif
            // normal multiplier result latching
            if (div_free || !ex_freeze) begin
                mul_prod_r <= mul_prod;
                div_free <= 1'b1;
            end
`ifdef DIV_PRESENT
        end
`endif
    end
end

// MAC pipeline and accumulator
`ifdef MAC_PRESENT
    reg [1:0] mac_op_r1, mac_op_r2, mac_op_r3;
    reg [63:0] mac_r;
    reg mac_stall_r_reg;

    // SPR write enables
    wire spr_maclo_we = spr_cs && spr_write && (spr_addr[0] == 1'b1);
    wire spr_machi_we = spr_cs && spr_write && (spr_addr[0] == 1'b0);

    // always block for mac_op pipeline, mac_r, mac_stall_r
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_op_r1 <= 2'b00;
            mac_op_r2 <= 2'b00;
            mac_op_r3 <= 2'b00;
            mac_r <= 64'd0;
            mac_stall_r_reg <= 1'b0;
        end else begin
            // mac_op pipeline (assume mac_op is registered in execute stage; we latch it)
            mac_op_r1 <= mac_op;
            mac_op_r2 <= mac_op_r1;
            mac_op_r3 <= mac_op_r2;

            // mac_r update with priority
            // SPR write
            if (`ifdef OR1200_MAC_SPR_WE) begin
                if (spr_machi_we) mac_r[63:32] <= spr_dat_i;
                if (spr_maclo_we) mac_r[31:0] <= spr_dat_i;
            end else begin
                // no SPR write
            end
            // MAC/ MSB operation (if no SPR write)
            if (!( ( `ifdef OR1200_MAC_SPR_WE) && (spr_maclo_we || spr_machi_we) )) begin
                if (mac_op_r3 == 2'b01) // assume MAC=01
                    mac_r <= mac_r + mul_prod_r;
                else if (mac_op_r3 == 2'b10) // assume MSB=10
                    mac_r <= mac_r - mul_prod_r;
                else if (macrc_op && !ex_freeze)
                    mac_r <= 64'd0;
                // otherwise retain
            end

            // mac_stall_r
            mac_stall_r_reg <= (|mac_op) || ( (mac_op_r1 != 2'b00 || mac_op_r2 != 2'b00) && id_macrc_op) 
`ifdef DIV_PRESENT
                || (div_cntr != 6'd0)
`endif
                ;
        end
    end

    assign mac_stall_r = mac_stall_r_reg;
    assign spr_dat_o = (spr_addr[0] == 1'b1) ? mac_r[31:0] : mac_r[63:32];

`else
    // MAC not implemented
    reg [63:0] mac_r = 64'd0;
    reg mac_stall_r_reg = 1'b0;
    assign mac_stall_r = 1'b0;
    assign spr_dat_o = 32'd0;
    // dummy pipeline registers
    reg [1:0] mac_op_r1 = 2'b00;
    reg [1:0] mac_op_r2 = 2'b00;
    reg [1:0] mac_op_r3 = 2'b00;
`endif

// Result selection
`ifdef MULT_PRESENT
    always @(*) begin
        if (alu_op == 4'b0001) begin // DIV
            // sign correction
            if (a[31] ^ b[31])
                result = ~mul_prod_r[31:0] + 1'b1;
            else
                result = mul_prod_r[31:0];
        end else if (alu_op == 4'b0010) begin // DIVU
            result = mul_prod_r[31:0];
        end else if (alu_op == 4'b0011) begin // MUL
            result = mul_prod_r[31:0];
        end else begin
            result = mac_r[31:0];
        end
    end
`else
    assign result = mac_r[31:0];
`endif

endmodule

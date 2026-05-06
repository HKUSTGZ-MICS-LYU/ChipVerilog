module or1200_alu(
    input [31:0] a,
    input [31:0] b,
    input [31:0] mult_mac_result,
    input macrc_op,
    input [3:0] alu_op,
    input [1:0] shrot_op,
    input [3:0] comp_op,
    input [4:0] cust5_op,
    input [5:0] cust5_limm,
    output [31:0] result,
    output flagforw,
    output flag_we,
    output cyforw,
    output cy_we,
    input carry,
    input flag
);

    reg [31:0] result;
    reg [31:0] shifted_rotated;
    reg [31:0] result_cust5;
    reg flagforw;
    reg flagcomp;
    reg flag_we;
    reg cy_we;
    reg cyforw;

    wire [31:0] comp_a;
    wire [31:0] comp_b;
    wire a_eq_b;
    wire a_lt_b;
    wire [31:0] result_sum;
    wire [31:0] result_csum;
    wire cy_csum;
    wire [31:0] result_and;
    wire cy_sum;
    wire [32:0] cy_sum_result_sum;
    wire [32:0] cy_csum_result_csum;

    // 33-bit adders for addition operations
    assign cy_sum_result_sum = {1'b0, a} + {1'b0, b};
    assign result_sum = cy_sum_result_sum[31:0];
    assign cy_sum = cy_sum_result_sum[32];

    assign cy_csum_result_csum = {1'b0, a} + {1'b0, b} + {32'b0, carry};
    assign result_csum = cy_csum_result_csum[31:0];
    assign cy_csum = cy_csum_result_csum[32];

    // AND operation
    assign result_and = a & b;

    // Comparison logic
    assign comp_a = comp_op[3] ? {~a[31], a[30:0]} : a;
    assign comp_b = comp_op[3] ? {~b[31], b[30:0]} : b;
    assign a_eq_b = (comp_a == comp_b);
    assign a_lt_b = (comp_a < comp_b);

    // FF1 (Find First 1 bit)
    wire [31:0] ff1_result;
    assign ff1_result = (a[0] ? 32'd1 :
                         a[1] ? 32'd2 :
                         a[2] ? 32'd3 :
                         a[3] ? 32'd4 :
                         a[4] ? 32'd5 :
                         a[5] ? 32'd6 :
                         a[6] ? 32'd7 :
                         a[7] ? 32'd8 :
                         a[8] ? 32'd9 :
                         a[9] ? 32'd10 :
                         a[10] ? 32'd11 :
                         a[11] ? 32'd12 :
                         a[12] ? 32'd13 :
                         a[13] ? 32'd14 :
                         a[14] ? 32'd15 :
                         a[15] ? 32'd16 :
                         a[16] ? 32'd17 :
                         a[17] ? 32'd18 :
                         a[18] ? 32'd19 :
                         a[19] ? 32'd20 :
                         a[20] ? 32'd21 :
                         a[21] ? 32'd22 :
                         a[22] ? 32'd23 :
                         a[23] ? 32'd24 :
                         a[24] ? 32'd25 :
                         a[25] ? 32'd26 :
                         a[26] ? 32'd27 :
                         a[27] ? 32'd28 :
                         a[28] ? 32'd29 :
                         a[29] ? 32'd30 :
                         a[30] ? 32'd31 :
                         a[31] ? 32'd32 :
                         32'd0);

    // Shift and rotate logic
    always @(*) begin
        case (shrot_op)
            2'b00: shifted_rotated = a << b[4:0];  // Logical left shift
            2'b01: shifted_rotated = a >> b[4:0];  // Logical right shift
            2'b10: shifted_rotated = ({a, a} >> b[4:0]);  // Circular right shift
            2'b11: shifted_rotated = $signed(a) >>> b[4:0];  // Arithmetic right shift
        endcase
    end

    // l.cust5 custom operations
    always @(*) begin
        case (cust5_op)
            5'b00000: result_cust5 = a;  // Default: retain a
            5'b00001: result_cust5 = {a[31:8], cust5_limm[5:0], a[1:0]};  // Byte insertion
            5'b00010: result_cust5 = a | (32'b1 << cust5_limm[4:0]);  // Bit setting
            5'b00011: result_cust5 = a & ~(32'b1 << cust5_limm[4:0]);  // Bit clearing
            default: result_cust5 = a;  // Default: retain a
        endcase
    end

    // Comparison result
    always @(*) begin
        case (comp_op[2:0])
            3'b000: flagcomp = a_eq_b;  // Equal
            3'b001: flagcomp = ~a_eq_b;  // Not equal
            3'b010: flagcomp = a_lt_b;  // Less than
            3'b011: flagcomp = a_lt_b | a_eq_b;  // Less than or equal
            3'b100: flagcomp = ~a_lt_b & ~a_eq_b;  // Greater than
            3'b101: flagcomp = ~a_lt_b;  // Greater than or equal
            default: flagcomp = 1'b0;
        endcase
    end

    // Main result multiplexing and flag generation
    always @(*) begin
        flagforw = 1'b0;
        flag_we = 1'b0;
        cyforw = 1'b0;
        cy_we = 1'b0;

        case (alu_op)
            4'b0000: begin  // ADD
                result = result_sum;
                cyforw = cy_sum;
                cy_we = 1'b1;
                flagforw = (result_sum == 32'b0) ? 1'b1 : 1'b0;
                flag_we = 1'b1;
            end
            4'b0001: begin  // ADDC (ADD with carry)
                result = result_csum;
                cyforw = cy_csum;
                cy_we = 1'b1;
                flagforw = (result_csum == 32'b0) ? 1'b1 : 1'b0;
                flag_we = 1'b1;
            end
            4'b0010: begin  // SUB
                result = result_sum;
            end
            4'b0011: begin  // AND
                result = result_and;
                flagforw = (result_and == 32'b0) ? 1'b1 : 1'b0;
                flag_we = 1'b1;
            end
            4'b0100: begin  // OR
                result = a | b;
            end
            4'b0101: begin  // XOR
                result = a ^ b;
            end
            4'b0110: begin  // Shift/Rotate
                result = shifted_rotated;
            end
            4'b0111: begin  // Comparison
                result = 32'b0;
                flagforw = flagcomp;
                flag_we = 1'b1;
            end
            4'b1000: begin  // MOVHI
                if (macrc_op) begin
                    result = mult_mac_result;
                end else begin
                    result = {b[15:0], 16'b0};
                end
            end
            4'b1001: begin  // Conditional move (CMOV)
                result = flag ? a : b;
            end
            4'b1010: begin  // Immediate passthrough
                result = b;
            end
            4'b1011: begin  // Multiplication/MAC result transparent transmission
                result = mult_mac_result;
            end
            4'b1100: begin  // FF1 (Find First 1 bit)
                result = ff1_result;
            end
            4'b1101: begin  // l.cust5 custom operations
                result = result_cust5;
            end
            4'b1110: begin  // High-bit load
                result = {a[30:0], b[0]};
            end
            default: begin
                result = 32'b0;
            end
        endcase
    end

endmodule

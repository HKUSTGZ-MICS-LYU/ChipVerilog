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
    output reg [31:0] result,
    output reg flagforw,
    output reg flag_we,
    output reg cyforw,
    output reg cy_we,
    input carry,
    input flag
);

    reg [31:0] shifted_rotated;
    reg [31:0] result_cust5;
    reg flagcomp;
    wire [31:0] comp_a;
    wire [31:0] comp_b;
    wire a_eq_b;
    wire a_lt_b;
    wire [31:0] result_sum;
    wire [32:0] cy_sum_result_sum;
    wire [31:0] result_csum;
    wire [32:0] cy_csum_result_csum;
    wire cy_sum;
    wire cy_csum;
    wire [31:0] result_and;

    assign comp_a = (comp_op[3]) ? ~a : a;
    assign comp_b = (comp_op[3]) ? ~b : b;
    assign a_eq_b = (comp_a == comp_b);
    assign a_lt_b = (comp_a < comp_b);
    
    assign cy_sum_result_sum = {1'b0, a} + {1'b0, b};
    assign result_sum = cy_sum_result_sum[31:0];
    assign cy_sum = cy_sum_result_sum[32];
    
    assign cy_csum_result_csum = {1'b0, a} + {1'b0, b} + {32'b0, carry};
    assign result_csum = cy_csum_result_csum[31:0];
    assign cy_csum = cy_csum_result_csum[32];
    
    assign result_and = a & b;

    always @(*) begin
        case (alu_op)
            4'b0000: result = result_sum;
            4'b0001: result = result_csum;
            4'b0010: result = a - b;
            4'b0011: result = a & b;
            4'b0100: result = a | b;
            4'b0101: result = a ^ b;
            4'b0110: result = b;
            4'b0111: result = {b[15:0], 16'b0};
            4'b1000: result = macrc_op ? mult_mac_result : {b[15:0], 16'b0};
            4'b1001: result = {a[31], a[31:1]};
            4'b1010: begin
                case (shrot_op)
                    2'b00: shifted_rotated = a << b[4:0];
                    2'b01: shifted_rotated = a >> b[4:0];
                    2'b10: shifted_rotated = a >>> b[4:0];
                    2'b11: shifted_rotated = {a, a} >> b[4:0];
                    default: shifted_rotated = a;
                endcase
                result = shifted_rotated;
            end
            4'b1011: result = mult_mac_result;
            4'b1100: result = (flag) ? a : b;
            4'b1101: begin
                case (cust5_op)
                    5'b00000: result = {a[31:24], b[7:0], a[15:8], a[7:0]};
                    5'b00001: result = a | (1 << cust5_limm);
                    5'b00010: result = a & ~(1 << cust5_limm);
                    default: result = a;
                endcase
            end
            4'b1110: result = (a != 0) ? 32'b1 : 32'b0;
            default: result = a;
        endcase
    end

    always @(*) begin
        case (comp_op[2:0])
            3'b000: flagcomp = a_eq_b;
            3'b001: flagcomp = !a_eq_b;
            3'b010: flagcomp = a_lt_b;
            3'b011: flagcomp = a_lt_b | a_eq_b;
            3'b100: flagcomp = !a_lt_b & !a_eq_b;
            3'b101: flagcomp = !a_lt_b;
            default: flagcomp = 1'b0;
        endcase
        
        if ((alu_op == 4'b1011) | (alu_op == 4'b1100)) begin
            flagforw = flagcomp;
            flag_we = 1'b1;
        end else begin
            flagforw = (result == 32'b0) ? 1'b0 : 1'b1;
            flag_we = 1'b0;
        end
    end

    always @(*) begin
        case (alu_op)
            4'b0000: begin
                cyforw = cy_sum;
                cy_we = 1'b1;
            end
            4'b0001: begin
                cyforw = cy_csum;
                cy_we = 1'b1;
            end
            default: begin
                cyforw = 1'b0;
                cy_we = 1'b0;
            end
        endcase
    end

endmodule

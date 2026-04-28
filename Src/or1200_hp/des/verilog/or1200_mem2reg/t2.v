`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_mem2reg (
    input  [1:0]  addr,
    input  [3:0]  lsu_op,
    input  [31:0] memdata,
    output [31:0] regdata
);

    reg [7:0]  regdata_hh;   // [31:24]
    reg [7:0]  regdata_hl;   // [23:16]
    reg [7:0]  regdata_lh;   // [15:8]
    reg [7:0]  regdata_ll;   // [7:0]
    reg [31:0] regdata_r;

    assign regdata = regdata_r;

    // Select target byte from memdata according to addr[1:0]
    // addr=00 → memdata[31:24] (MSB), addr=01 → [23:16], 10 → [15:8], 11 → [7:0]
    reg [7:0] target_byte;
    always @(*) begin
        case (addr)
            2'b00: target_byte = memdata[31:24];
            2'b01: target_byte = memdata[23:16];
            2'b10: target_byte = memdata[15:8];
            2'b11: target_byte = memdata[7:0];
        endcase
    end

    // Select target halfword from memdata according to addr[1]
    // addr[1]=0 → memdata[31:16], addr[1]=1 → memdata[15:0]
    reg [15:0] target_hword;
    always @(*) begin
        case (addr[1])
            1'b0: target_hword = memdata[31:16];
            1'b1: target_hword = memdata[15:0];
        endcase
    end

    //--------------------------------------------------------------------------
    // Main decode
    //--------------------------------------------------------------------------
    always @(*) begin
        case (lsu_op)

            // Unsigned byte load: zero-extend byte
            `OR1200_LSUOP_LBZ: begin
                regdata_hh = 8'h00;
                regdata_hl = 8'h00;
                regdata_lh = 8'h00;
                regdata_ll = target_byte;
            end

            // Signed byte load: sign-extend byte
            `OR1200_LSUOP_LBS: begin
                regdata_hh = {8{target_byte[7]}};
                regdata_hl = {8{target_byte[7]}};
                regdata_lh = {8{target_byte[7]}};
                regdata_ll = target_byte;
            end

            // Unsigned halfword load: zero-extend halfword
            `OR1200_LSUOP_LHZ: begin
                regdata_hh = 8'h00;
                regdata_hl = 8'h00;
                regdata_lh = target_hword[15:8];
                regdata_ll = target_hword[7:0];
            end

            // Signed halfword load: sign-extend halfword
            `OR1200_LSUOP_LHS: begin
                regdata_hh = {8{target_hword[15]}};
                regdata_hl = {8{target_hword[15]}};
                regdata_lh = target_hword[15:8];
                regdata_ll = target_hword[7:0];
            end

            // Word load: output full 32-bit data
            `OR1200_LSUOP_LWZ,
            `OR1200_LSUOP_LWS: begin
                regdata_hh = memdata[31:24];
                regdata_hl = memdata[23:16];
                regdata_lh = memdata[15:8];
                regdata_ll = memdata[7:0];
            end

            // Default / store ops: pass through
            default: begin
                regdata_hh = memdata[31:24];
                regdata_hl = memdata[23:16];
                regdata_lh = memdata[15:8];
                regdata_ll = memdata[7:0];
            end

        endcase

        regdata_r = {regdata_hh, regdata_hl, regdata_lh, regdata_ll};
    end

endmodule
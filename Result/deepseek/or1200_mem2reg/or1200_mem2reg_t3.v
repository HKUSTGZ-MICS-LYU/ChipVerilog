module or1200_mem2reg(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] memdata,
    output reg [31:0] regdata
);

    wire [7:0] byte0 = memdata[7:0];
    wire [7:0] byte1 = memdata[15:8];
    wire [7:0] byte2 = memdata[23:16];
    wire [7:0] byte3 = memdata[31:24];
    wire [15:0] hword_low = memdata[15:0];
    wire [15:0] hword_high = memdata[31:16];

    wire [7:0] sel_byte;
    wire [15:0] sel_hword;

    // Select byte based on addr for byte loads
    always @(*) begin
        case (addr)
            2'b00: sel_byte = byte3; // most significant byte
            2'b01: sel_byte = byte2;
            2'b10: sel_byte = byte1;
            2'b11: sel_byte = byte0;
            default: sel_byte = 8'h0;
        endcase
    end

    // Select halfword based on addr for halfword loads
    always @(*) begin
        case (addr)
            2'b00: sel_hword = hword_high; // upper halfword
            2'b10: sel_hword = hword_low;  // lower halfword
            default: sel_hword = 16'h0;
        endcase
    end

    // Format regdata based on lsu_op
    always @(*) begin
        casez (lsu_op)
            // Signed byte load (lb)
            4'b0000: regdata = {{24{sel_byte[7]}}, sel_byte};
            // Signed halfword load (lh)
            4'b0001: regdata = {{16{sel_hword[15]}}, sel_hword};
            // Word load (lw) - both signed and unsigned versions
            4'b0010, 4'b0110: regdata = memdata;
            // Unsigned byte load (lbu)
            4'b0100: regdata = {24'h0, sel_byte};
            // Unsigned halfword load (lhu)
            4'b0101: regdata = {16'h0, sel_hword};
            default: regdata = 32'h0;
        endcase
    end

endmodule

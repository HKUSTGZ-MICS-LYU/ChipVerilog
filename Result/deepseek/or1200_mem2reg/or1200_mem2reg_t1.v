// or1200_mem2reg: load data alignment and extension module
// Part of the OR1200 load data path

module or1200_mem2reg(
    input  [1:0]  addr,
    input  [3:0]  lsu_op,
    input  [31:0] memdata,
    output [31:0] regdata
);

    // LSU operation encodings (derived from typical OR1200 definitions)
    // lsu_op[3]:    Reserved / unused in this module
    // lsu_op[2]:    Sign extension select (1 = signed, 0 = unsigned)
    // lsu_op[1:0]:  Transfer size (00 = byte, 01 = halfword, 10 = word, 11 = reserved)
    wire        sign_ext = lsu_op[2];
    wire [1:0]  size     = lsu_op[1:0];

    // Internal aligned data word (byte-rotated to put target byte at lane 0)
    reg [31:0] aligned;

    // Byte-select signals for each output lane
    reg  [3:0] sel_byte0;
    reg  [3:0] sel_byte1;
    reg  [3:0] sel_byte2;
    reg  [3:0] sel_byte3;

    // Byte lanes of the final register data
    wire [7:0] regdata_ll;
    wire [7:0] regdata_lh;
    wire [7:0] regdata_hl;
    wire [7:0] regdata_hh;

    // Extract target byte from memdata based on addr[1:0]
    // addr: 00 -> most significant byte [31:24]
    //       01 -> next most significant byte [23:16]
    //       10 -> next least significant byte [15:8]
    //       11 -> least significant byte [7:0]
    function [7:0] get_byte;
        input [31:0] data;
        input [1:0]  offset;
        begin
            case (offset)
                2'b00:   get_byte = data[31:24];
                2'b01:   get_byte = data[23:16];
                2'b10:   get_byte = data[15:8];
                2'b11:   get_byte = data[7:0];
                default: get_byte = data[7:0];
            endcase
        end
    endfunction

    // Extract target halfword from memdata based on addr[1:0]
    // Halfword aligned at offset 0 -> upper halfword [31:16]
    // Halfword aligned at offset 2 -> lower halfword [15:0]
    function [15:0] get_halfword;
        input [31:0] data;
        input [1:0]  offset;
        begin
            // Only valid offsets for halfword are 00 and 10
            case (offset[1])
                1'b0:   get_halfword = data[31:16];
                1'b1:   get_halfword = data[15:0];
                default: get_halfword = data[15:0];
            endcase
        end
    endfunction

    // Computation of aligned data: rotate memdata to place target byte at byte lane 0
    // For byte access: rotate so that the targeted byte ends up in bits [7:0]
    // For halfword access: rotate so that the targeted halfword ends up in bits [15:0]
    // For word access: no rotation, aligned = memdata
    always @(*) begin
        case (size)
            2'b00: begin // Byte
                case (addr)
                    2'b00: aligned = memdata;                  // byte at [31:24] -> stays at [31:24]
                    2'b01: aligned = {memdata[23:0], memdata[31:24]}; // byte at [23:16] -> moved to [31:24]
                    2'b10: aligned = {memdata[15:0], memdata[31:16]}; // byte at [15:8] -> moved to [31:24]
                    2'b11: aligned = {memdata[7:0],  memdata[31:8]};  // byte at [7:0] -> moved to [31:24]
                    default: aligned = memdata;
                endcase
            end
            2'b01: begin // Halfword
                case (addr[1])
                    1'b0: aligned = memdata;                  // halfword at [31:16] -> stays at [31:16]
                    1'b1: aligned = {memdata[15:0], memdata[31:16]}; // halfword at [15:0] -> moved to [31:16]
                    default: aligned = memdata;
                endcase
            end
            2'b10: begin // Word (aligned, addr must be 00)
                aligned = memdata;
            end
            default: begin
                aligned = memdata;
            end
        endcase
    end

    // Generate byte select signals for each output byte lane
    // These control muxing and sign/zero extension
    // Output byte lanes: regdata[31:24] = lane3, [23:16] = lane2, [15:8] = lane1, [7:0] = lane0
    // Byte select encoding for each lane:
    //   4'b0000 -> zero extension byte (0x00)
    //   4'b0001 -> sign extension byte from aligned[7]  (for signed loads, fill with {8{aligned[7]}})
    //   4'b0010 -> aligned[7:0]  (lane0 data)
    //   4'b0011 -> aligned[15:8] (lane1 data)
    //   4'b0100 -> aligned[23:16](lane2 data)
    //   4'b0101 -> aligned[31:24](lane3 data)
    // The select encoding is used by downstream mux logic to pick the correct byte.
    // We'll implement the mux directly in the byte lane assignment.

    always @(*) begin
        // Default: zero extension for all upper lanes, lane0 gets aligned[7:0]
        sel_byte0 = 4'b0010; // aligned[7:0]
        sel_byte1 = 4'b0000; // zero
        sel_byte2 = 4'b0000; // zero
        sel_byte3 = 4'b0000; // zero

        case (size)
            2'b00: begin // Byte load
                // Lane0 gets the targeted byte from aligned[7:0]
                sel_byte0 = 4'b0010; // aligned[7:0]
                if (sign_ext) begin
                    // Sign extension byte for upper lanes
                    sel_byte1 = 4'b0001; // sign extension from aligned[7]
                    sel_byte2 = 4'b0001;
                    sel_byte3 = 4'b0001;
                end else begin
                    // Zero extension for upper lanes
                    sel_byte1 = 4'b0000;
                    sel_byte2 = 4'b0000;
                    sel_byte3 = 4'b0000;
                end
            end
            2'b01: begin // Halfword load
                // Lane0 gets aligned[7:0], Lane1 gets aligned[15:8]
                sel_byte0 = 4'b0010; // aligned[7:0]
                sel_byte1 = 4'b0011; // aligned[15:8]
                if (sign_ext) begin
                    // Sign extension from halfword bit 15 (aligned[15])
                    sel_byte2 = 4'b0001; // sign extension from aligned[15]
                    sel_byte3 = 4'b0001;
                end else begin
                    sel_byte2 = 4'b0000;
                    sel_byte3 = 4'b0000;
                end
            end
            2'b10: begin // Word load
                // All lanes pass through aligned bytes
                sel_byte0 = 4'b0010; // aligned[7:0]
                sel_byte1 = 4'b0011; // aligned[15:8]
                sel_byte2 = 4'b0100; // aligned[23:16]
                sel_byte3 = 4'b0101; // aligned[31:24]
            end
            default: begin
                sel_byte0 = 4'b0010;
                sel_byte1 = 4'b0000;
                sel_byte2 = 4'b0000;
                sel_byte3 = 4'b0000;
            end
        endcase
    end

    // Byte lane mux implementation based on select signals
    assign regdata_ll = (sel_byte0 == 4'b0010) ? aligned[7:0]   :
                        (sel_byte0 == 4'b0011) ? aligned[15:8]  :
                        (sel_byte0 == 4'b0100) ? aligned[23:16] :
                        (sel_byte0 == 4'b0101) ? aligned[31:24] :
                        8'h00;

    assign regdata_lh = (sel_byte1 == 4'b0010) ? aligned[7:0]   :
                        (sel_byte1 == 4'b0011) ? aligned[15:8]  :
                        (sel_byte1 == 4'b0100) ? aligned[23:16] :
                        (sel_byte1 == 4'b0101) ? aligned[31:24] :
                        (sel_byte1 == 4'b0001) ? {8{aligned[15]}} :
                        8'h00;

    assign regdata_hl = (sel_byte2 == 4'b0010) ? aligned[7:0]   :
                        (sel_byte2 == 4'b0011) ? aligned[15:8]  :
                        (sel_byte2 == 4'b0100) ? aligned[23:16] :
                        (sel_byte2 == 4'b0101) ? aligned[31:24] :
                        (sel_byte2 == 4'b0001) ? {8{aligned[15]}} :
                        8'h00;

    assign regdata_hh = (sel_byte3 == 4'b0010) ? aligned[7:0]   :
                        (sel_byte3 == 4'b0011) ? aligned[15:8]  :
                        (sel_byte3 == 4'b0100) ? aligned[23:16] :
                        (sel_byte3 == 4'b0101) ? aligned[31:24] :
                        (sel_byte3 == 4'b0001) ? {8{aligned[15]}} :
                        8'h00;

    // Final assembly
    assign regdata = {regdata_hh, regdata_hl, regdata_lh, regdata_ll};

endmodule

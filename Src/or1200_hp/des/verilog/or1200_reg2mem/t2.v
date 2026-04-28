`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_reg2mem (
    input  [1:0]  addr,
    input  [3:0]  lsu_op,
    input  [31:0] regdata,
    output [31:0] memdata
);

    reg [7:0] memdata_hh;   // memdata[31:24]
    reg [7:0] memdata_hl;   // memdata[23:16]
    reg [7:0] memdata_lh;   // memdata[15:8]
    reg [7:0] memdata_ll;   // memdata[7:0]

    assign memdata = {memdata_hh, memdata_hl, memdata_lh, memdata_ll};

    //--------------------------------------------------------------------------
    // memdata[31:24]: byte lane 3 (most significant)
    // SB@00 → regdata[7:0]   (byte store to addr offset 00)
    // SH@00 → regdata[15:8]  (upper byte of halfword at offset 00)
    // default → regdata[31:24]
    //--------------------------------------------------------------------------
    always @(*) begin
        casex ({lsu_op, addr})
            {`OR1200_LSUOP_SB, 2'b00}: memdata_hh = regdata[7:0];
            {`OR1200_LSUOP_SH, 2'b00}: memdata_hh = regdata[15:8];
            default:                    memdata_hh = regdata[31:24];
        endcase
    end

    //--------------------------------------------------------------------------
    // memdata[23:16]: byte lane 2
    // SW@00 → regdata[23:16] (aligned word store: preserve original byte)
    // default → regdata[7:0] (catches SB@01, SH@00 upper, etc.)
    //--------------------------------------------------------------------------
    always @(*) begin
        casex ({lsu_op, addr})
            {`OR1200_LSUOP_SW, 2'b00}: memdata_hl = regdata[23:16];
            default:                    memdata_hl = regdata[7:0];
        endcase
    end

    //--------------------------------------------------------------------------
    // memdata[15:8]: byte lane 1
    // SB@10 → regdata[7:0]  (byte store to addr offset 10)
    // default → regdata[15:8]
    //--------------------------------------------------------------------------
    always @(*) begin
        casex ({lsu_op, addr})
            {`OR1200_LSUOP_SB, 2'b10}: memdata_lh = regdata[7:0];
            default:                    memdata_lh = regdata[15:8];
        endcase
    end

    //--------------------------------------------------------------------------
    // memdata[7:0]: byte lane 0 (least significant)
    // Always regdata[7:0] — no conditional needed
    //--------------------------------------------------------------------------
    always @(*) begin
        memdata_ll = regdata[7:0];
    end

endmodule
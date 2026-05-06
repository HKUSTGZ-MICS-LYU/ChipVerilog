module or1200_mem2reg(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] memdata,
    output [31:0] regdata
);

reg [7:0] regdata_hh;
reg [7:0] regdata_hl;
reg [7:0] regdata_lh;
reg [7:0] regdata_ll;
reg [31:0] aligned;
reg [3:0] sel_byte0;
reg [3:0] sel_byte1;
reg [3:0] sel_byte2;
reg [3:0] sel_byte3;
reg [31:0] regdata;

localparam [3:0] LSUOP_LBZ = 4'b0001;
localparam [3:0] LSUOP_LBS = 4'b0010;
localparam [3:0] LSUOP_LHZ = 4'b0011;
localparam [3:0] LSUOP_LHS = 4'b0100;
localparam [3:0] LSUOP_LWZ = 4'b0101;

localparam [3:0] SEL_ALIGNED_B3 = 4'd0;
localparam [3:0] SEL_ALIGNED_B2 = 4'd1;
localparam [3:0] SEL_ALIGNED_B1 = 4'd2;
localparam [3:0] SEL_ALIGNED_B0 = 4'd3;
localparam [3:0] SEL_ZERO       = 4'd4;
localparam [3:0] SEL_SIGN       = 4'd5;

always @* begin
    aligned = memdata << {addr, 3'b000};

    sel_byte0 = SEL_ALIGNED_B0;
    sel_byte1 = SEL_ALIGNED_B1;
    sel_byte2 = SEL_ALIGNED_B2;
    sel_byte3 = SEL_ALIGNED_B3;

    case (lsu_op)
        LSUOP_LBZ: begin
            sel_byte0 = SEL_ALIGNED_B3;
            sel_byte1 = SEL_ZERO;
            sel_byte2 = SEL_ZERO;
            sel_byte3 = SEL_ZERO;
        end
        LSUOP_LBS: begin
            sel_byte0 = SEL_ALIGNED_B3;
            sel_byte1 = SEL_SIGN;
            sel_byte2 = SEL_SIGN;
            sel_byte3 = SEL_SIGN;
        end
        LSUOP_LHZ: begin
            sel_byte0 = SEL_ALIGNED_B2;
            sel_byte1 = SEL_ALIGNED_B3;
            sel_byte2 = SEL_ZERO;
            sel_byte3 = SEL_ZERO;
        end
        LSUOP_LHS: begin
            sel_byte0 = SEL_ALIGNED_B2;
            sel_byte1 = SEL_ALIGNED_B3;
            sel_byte2 = SEL_SIGN;
            sel_byte3 = SEL_SIGN;
        end
        LSUOP_LWZ: begin
            sel_byte0 = SEL_ALIGNED_B0;
            sel_byte1 = SEL_ALIGNED_B1;
            sel_byte2 = SEL_ALIGNED_B2;
            sel_byte3 = SEL_ALIGNED_B3;
        end
        default: begin
            sel_byte0 = SEL_ALIGNED_B0;
            sel_byte1 = SEL_ALIGNED_B1;
            sel_byte2 = SEL_ALIGNED_B2;
            sel_byte3 = SEL_ALIGNED_B3;
        end
    endcase

    case (sel_byte0)
        SEL_ALIGNED_B3: regdata_ll = aligned[31:24];
        SEL_ALIGNED_B2: regdata_ll = aligned[23:16];
        SEL_ALIGNED_B1: regdata_ll = aligned[15:8];
        SEL_ALIGNED_B0: regdata_ll = aligned[7:0];
        SEL_ZERO:       regdata_ll = 8'b0;
        default:        regdata_ll = {8{aligned[31]}};
    endcase

    case (sel_byte1)
        SEL_ALIGNED_B3: regdata_lh = aligned[31:24];
        SEL_ALIGNED_B2: regdata_lh = aligned[23:16];
        SEL_ALIGNED_B1: regdata_lh = aligned[15:8];
        SEL_ALIGNED_B0: regdata_lh = aligned[7:0];
        SEL_ZERO:       regdata_lh = 8'b0;
        default:        regdata_lh = {8{aligned[31]}};
    endcase

    case (sel_byte2)
        SEL_ALIGNED_B3: regdata_hl = aligned[31:24];
        SEL_ALIGNED_B2: regdata_hl = aligned[23:16];
        SEL_ALIGNED_B1: regdata_hl = aligned[15:8];
        SEL_ALIGNED_B0: regdata_hl = aligned[7:0];
        SEL_ZERO:       regdata_hl = 8'b0;
        default:        regdata_hl = {8{aligned[31]}};
    endcase

    case (sel_byte3)
        SEL_ALIGNED_B3: regdata_hh = aligned[31:24];
        SEL_ALIGNED_B2: regdata_hh = aligned[23:16];
        SEL_ALIGNED_B1: regdata_hh = aligned[15:8];
        SEL_ALIGNED_B0: regdata_hh = aligned[7:0];
        SEL_ZERO:       regdata_hh = 8'b0;
        default:        regdata_hh = {8{aligned[31]}};
    endcase

    regdata = {regdata_hh, regdata_hl, regdata_lh, regdata_ll};
end

endmodule

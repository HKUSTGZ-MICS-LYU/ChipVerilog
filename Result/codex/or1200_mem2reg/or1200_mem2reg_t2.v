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

localparam [3:0] LSUOP_LBZ = 4'b0000;
localparam [3:0] LSUOP_LBS = 4'b0001;
localparam [3:0] LSUOP_LHZ = 4'b0010;
localparam [3:0] LSUOP_LHS = 4'b0011;
localparam [3:0] LSUOP_LWZ = 4'b0100;
localparam [3:0] LSUOP_LWS = 4'b0101;

always @* begin
    case (addr)
        2'b00: aligned = memdata;
        2'b01: aligned = {memdata[23:0], memdata[31:24]};
        2'b10: aligned = {memdata[15:0], memdata[31:16]};
        default: aligned = {memdata[7:0], memdata[31:8]};
    endcase

    sel_byte0 = 4'b0000;
    sel_byte1 = 4'b0000;
    sel_byte2 = 4'b0000;
    sel_byte3 = 4'b0000;

    case (lsu_op)
        LSUOP_LBZ: begin
            sel_byte0 = 4'b0001;
        end
        LSUOP_LBS: begin
            sel_byte0 = 4'b0001;
            sel_byte1 = 4'b1111;
            sel_byte2 = 4'b1111;
            sel_byte3 = 4'b1111;
        end
        LSUOP_LHZ: begin
            sel_byte0 = 4'b0010;
            sel_byte1 = 4'b0001;
        end
        LSUOP_LHS: begin
            sel_byte0 = 4'b0010;
            sel_byte1 = 4'b0001;
            sel_byte2 = 4'b1111;
            sel_byte3 = 4'b1111;
        end
        default: begin
            sel_byte0 = 4'b1000;
            sel_byte1 = 4'b0100;
            sel_byte2 = 4'b0010;
            sel_byte3 = 4'b0001;
        end
    endcase

    case (sel_byte0)
        4'b0001: regdata_ll = aligned[31:24];
        4'b0010: regdata_ll = aligned[23:16];
        4'b0100: regdata_ll = aligned[15:8];
        4'b1000: regdata_ll = aligned[7:0];
        4'b1111: regdata_ll = {8{aligned[31]}};
        default: regdata_ll = 8'h00;
    endcase

    case (sel_byte1)
        4'b0001: regdata_lh = aligned[31:24];
        4'b0010: regdata_lh = aligned[23:16];
        4'b0100: regdata_lh = aligned[15:8];
        4'b1000: regdata_lh = aligned[7:0];
        4'b1111: regdata_lh = {8{aligned[31]}};
        default: regdata_lh = 8'h00;
    endcase

    case (sel_byte2)
        4'b0001: regdata_hl = aligned[31:24];
        4'b0010: regdata_hl = aligned[23:16];
        4'b0100: regdata_hl = aligned[15:8];
        4'b1000: regdata_hl = aligned[7:0];
        4'b1111: regdata_hl = {8{aligned[31]}};
        default: regdata_hl = 8'h00;
    endcase

    case (sel_byte3)
        4'b0001: regdata_hh = aligned[31:24];
        4'b0010: regdata_hh = aligned[23:16];
        4'b0100: regdata_hh = aligned[15:8];
        4'b1000: regdata_hh = aligned[7:0];
        4'b1111: regdata_hh = {8{aligned[31]}};
        default: regdata_hh = 8'h00;
    endcase

    regdata = {regdata_hh, regdata_hl, regdata_lh, regdata_ll};

    if ((lsu_op == LSUOP_LWZ) || (lsu_op == LSUOP_LWS)) begin
        regdata = memdata;
    end
end

endmodule

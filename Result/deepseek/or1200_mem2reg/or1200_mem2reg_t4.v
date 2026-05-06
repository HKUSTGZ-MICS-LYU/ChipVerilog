module or1200_mem2reg(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] memdata,
    output reg [31:0] regdata
);

    localparam OP_LW  = 4'b0001;
    localparam OP_LBU = 4'b0010;
    localparam OP_LB  = 4'b0011;
    localparam OP_LHU = 4'b0100;
    localparam OP_LH  = 4'b0101;

    reg [7:0] regdata_hh;
    reg [7:0] regdata_hl;
    reg [7:0] regdata_lh;
    reg [7:0] regdata_ll;
    reg [31:0] aligned;
    reg [3:0] sel_byte0;
    reg [3:0] sel_byte1;
    reg [3:0] sel_byte2;
    reg [3:0] sel_byte3;

    always @* begin
        aligned = memdata;
        regdata_hh = 8'b0;
        regdata_hl = 8'b0;
        regdata_lh = 8'b0;
        regdata_ll = 8'b0;
        sel_byte0 = 4'b0000;
        sel_byte1 = 4'b0000;
        sel_byte2 = 4'b0000;
        sel_byte3 = 4'b0000;

        case (lsu_op)
            OP_LW: begin
                regdata_hh = memdata[31:24];
                regdata_hl = memdata[23:16];
                regdata_lh = memdata[15:8];
                regdata_ll = memdata[7:0];
                sel_byte0 = 4'b0011; // byte3 of memdata -> regdata_ll? not critical
                sel_byte1 = 4'b0010;
                sel_byte2 = 4'b0001;
                sel_byte3 = 4'b0000;
            end
            OP_LBU: begin
                case (addr)
                    2'b00: regdata_ll = memdata[31:24];
                    2'b01: regdata_ll = memdata[23:16];
                    2'b10: regdata_ll = memdata[15:8];
                    2'b11: regdata_ll = memdata[7:0];
                endcase
                regdata_hh = 8'b0;
                regdata_hl = 8'b0;
                regdata_lh = 8'b0;
                sel_byte0 = {2'b00, addr};
                sel_byte1 = 4'b0000;
                sel_byte2 = 4'b0000;
                sel_byte3 = 4'b0000;
            end
            OP_LB: begin
                case (addr)
                    2'b00: regdata_ll = memdata[31:24];
                    2'b01: regdata_ll = memdata[23:16];
                    2'b10: regdata_ll = memdata[15:8];
                    2'b11: regdata_ll = memdata[7:0];
                endcase
                regdata_hh = {8{regdata_ll[7]}};
                regdata_hl = {8{regdata_ll[7]}};
                regdata_lh = {8{regdata_ll[7]}};
                sel_byte0 = {2'b00, addr};
                sel_byte1 = 4'b0000;
                sel_byte2 = 4'b0000;
                sel_byte3 = 4'b0000;
            end
            OP_LHU: begin
                case (addr)
                    2'b00: begin
                        regdata_lh = memdata[31:24];
                        regdata_ll = memdata[23:16];
                        sel_byte0 = 4'b0010; // mem byte2 -> regdata_ll
                        sel_byte1 = 4'b0011; // mem byte3 -> regdata_lh
                    end
                    2'b10: begin
                        regdata_lh = memdata[15:8];
                        regdata_ll = memdata[7:0];
                        sel_byte0 = 4'b0000; // mem byte0 -> regdata_ll
                        sel_byte1 = 4'b0001; // mem byte1 -> regdata_lh
                    end
                    default: begin
                        regdata_lh = 8'b0;
                        regdata_ll = 8'b0;
                        sel_byte0 = 4'b0000;
                        sel_byte1 = 4'b0000;
                    end
                endcase
                regdata_hh = 8'b0;
                regdata_hl = 8'b0;
                sel_byte2 = 4'b0000;
                sel_byte3 = 4'b0000;
            end
            OP_LH: begin
                case (addr)
                    2'b00: begin
                        regdata_lh = memdata[31:24];
                        regdata_ll = memdata[23:16];
                        sel_byte0 = 4'b0010;
                        sel_byte1 = 4'b0011;
                    end
                    2'b10: begin
                        regdata_lh = memdata[15:8];
                        regdata_ll = memdata[7:0];
                        sel_byte0 = 4'b0000;
                        sel_byte1 = 4'b0001;
                    end
                    default: begin
                        regdata_lh = 8'b0;
                        regdata_ll = 8'b0;
                        sel_byte0 = 4'b0000;
                        sel_byte1 = 4'b0000;
                    end
                endcase
                regdata_hh = {8{regdata_lh[7]}};
                regdata_hl = {8{regdata_lh[7]}};
                sel_byte2 = 4'b0000;
                sel_byte3 = 4'b0000;
            end
            default: begin
                regdata_hh = 8'b0;
                regdata_hl = 8'b0;
                regdata_lh = 8'b0;
                regdata_ll = 8'b0;
                sel_byte0 = 4'b0000;
                sel_byte1 = 4'b0000;
                sel_byte2 = 4'b0000;
                sel_byte3 = 4'b0000;
            end
        endcase

        regdata = {regdata_hh, regdata_hl, regdata_lh, regdata_ll};
    end

endmodule

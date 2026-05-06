module or1200_mem2reg(
    input  [1:0] addr,
    input  [3:0] lsu_op,
    input  [31:0] memdata,
    output reg [31:0] regdata
);

    localparam OP_LW  = 4'b0000;
    localparam OP_LHU = 4'b0001;
    localparam OP_LHS = 4'b0010;
    localparam OP_LBU = 4'b0011;
    localparam OP_LBS = 4'b0100;

    reg [7:0] regdata_hh;
    reg [7:0] regdata_hl;
    reg [7:0] regdata_lh;
    reg [7:0] regdata_ll;
    reg [31:0] aligned;
    reg [3:0] sel_byte0;
    reg [3:0] sel_byte1;
    reg [3:0] sel_byte2;
    reg [3:0] sel_byte3;

    always @(*) begin
        // Defaults
        regdata_hh = 8'h00;
        regdata_hl = 8'h00;
        regdata_lh = 8'h00;
        regdata_ll = 8'h00;
        aligned    = memdata;
        sel_byte0  = 4'b0000;
        sel_byte1  = 4'b0000;
        sel_byte2  = 4'b0000;
        sel_byte3  = 4'b0000;

        case (lsu_op)
            OP_LW: begin
                regdata_hh = memdata[31:24];
                regdata_hl = memdata[23:16];
                regdata_lh = memdata[15: 8];
                regdata_ll = memdata[ 7: 0];
            end

            OP_LHU: begin
                if (addr[1] == 1'b0) begin  // upper halfword
                    regdata_hh = 8'h00;
                    regdata_hl = 8'h00;
                    regdata_lh = memdata[31:24];
                    regdata_ll = memdata[23:16];
                end else begin              // lower halfword
                    regdata_hh = 8'h00;
                    regdata_hl = 8'h00;
                    regdata_lh = memdata[15: 8];
                    regdata_ll = memdata[ 7: 0];
                end
            end

            OP_LHS: begin
                if (addr[1] == 1'b0) begin  // upper halfword
                    regdata_hh = (memdata[31]) ? 8'hFF : 8'h00;
                    regdata_hl = (memdata[31]) ? 8'hFF : 8'h00;
                    regdata_lh = memdata[31:24];
                    regdata_ll = memdata[23:16];
                end else begin              // lower halfword
                    regdata_hh = (memdata[15]) ? 8'hFF : 8'h00;
                    regdata_hl = (memdata[15]) ? 8'hFF : 8'h00;
                    regdata_lh = memdata[15: 8];
                    regdata_ll = memdata[ 7: 0];
                end
            end

            OP_LBU: begin
                case (addr)
                    2'b00: begin
                        regdata_hh = 8'h00;
                        regdata_hl = 8'h00;
                        regdata_lh = 8'h00;
                        regdata_ll = memdata[31:24];
                    end
                    2'b01: begin
                        regdata_hh = 8'h00;
                        regdata_hl = 8'h00;
                        regdata_lh = 8'h00;
                        regdata_ll = memdata[23:16];
                    end
                    2'b10: begin
                        regdata_hh = 8'h00;
                        regdata_hl = 8'h00;
                        regdata_lh = 8'h00;
                        regdata_ll = memdata[15: 8];
                    end
                    2'b11: begin
                        regdata_hh = 8'h00;
                        regdata_hl = 8'h00;
                        regdata_lh = 8'h00;
                        regdata_ll = memdata[ 7: 0];
                    end
                endcase
            end

            OP_LBS: begin
                case (addr)
                    2'b00: begin
                        regdata_hh = (memdata[31]) ? 8'hFF : 8'h00;
                        regdata_hl = (memdata[31]) ? 8'hFF : 8'h00;
                        regdata_lh = (memdata[31]) ? 8'hFF : 8'h00;
                        regdata_ll = memdata[31:24];
                    end
                    2'b01: begin
                        regdata_hh = (memdata[23]) ? 8'hFF : 8'h00;
                        regdata_hl = (memdata[23]) ? 8'hFF : 8'h00;
                        regdata_lh = (memdata[23]) ? 8'hFF : 8'h00;
                        regdata_ll = memdata[23:16];
                    end
                    2'b10: begin
                        regdata_hh = (memdata[15]) ? 8'hFF : 8'h00;
                        regdata_hl = (memdata[15]) ? 8'hFF : 8'h00;
                        regdata_lh = (memdata[15]) ? 8'hFF : 8'h00;
                        regdata_ll = memdata[15: 8];
                    end
                    2'b11: begin
                        regdata_hh = (memdata[ 7]) ? 8'hFF : 8'h00;
                        regdata_hl = (memdata[ 7]) ? 8'hFF : 8'h00;
                        regdata_lh = (memdata[ 7]) ? 8'hFF : 8'h00;
                        regdata_ll = memdata[ 7: 0];
                    end
                endcase
            end

            default: begin
                // Undefined operation – all bytes remain zero
            end
        endcase

        regdata = {regdata_hh, regdata_hl, regdata_lh, regdata_ll};
    end

endmodule

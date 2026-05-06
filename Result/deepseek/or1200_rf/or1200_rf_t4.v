module or1200_rf(
    input clk,
    input rst,
    input supv,
    input wb_freeze,
    input [4:0] addrw,
    input [31:0] dataw,
    input we,
    input flushpipe,
    input id_freeze,
    input [4:0] addra,
    input [4:0] addrb,
    output [31:0] dataa,
    output [31:0] datab,
    input rda,
    input rdb,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

localparam [5:0] OR1200_SPR_RF = 6'h00;

wire [31:0] from_rfa;
wire [31:0] from_rfb;
reg [32:0] dataa_saved;
reg [32:0] datab_saved;
wire [4:0] rf_addra;
wire [4:0] rf_addrw;
wire [31:0] rf_dataw;
wire rf_we_raw;
wire rf_we;
wire spr_valid;
wire rf_ena;
wire rf_enb;
reg rf_we_allow;
wire [31:0] from_rfa_int;
wire [31:0] from_rfb_int;
reg [4:0] rf_addra_reg;
reg [4:0] rf_addrb_reg;

assign spr_valid = spr_cs && (spr_addr[10:5] == OR1200_SPR_RF);

assign rf_addra = (spr_valid && !spr_write) ? spr_addr[4:0] : addra;
assign rf_addrb = addrb;
assign rf_addrw = (spr_valid && spr_write) ? spr_addr[4:0] : addrw;
assign rf_dataw = (spr_valid && spr_write) ? spr_dat_i : dataw;

assign rf_ena = (rda && !id_freeze) || spr_valid;
assign rf_enb = (rdb && !id_freeze) || spr_valid;

assign rf_we_raw = (spr_valid && spr_write) || (we && !wb_freeze);
assign rf_we = rf_we_raw && rf_we_allow && (supv || (|rf_addrw));

always @(posedge clk or posedge rst) begin
    if (rst)
        rf_we_allow <= 1'b1;
    else if (!wb_freeze)
        rf_we_allow <= !flushpipe;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dataa_saved <= 33'h0;
        datab_saved <= 33'h0;
    end else begin
        if (id_freeze) begin
            if (!dataa_saved[32])
                dataa_saved <= {1'b1, from_rfa};
            if (!datab_saved[32])
                datab_saved <= {1'b1, from_rfb};
        end else begin
            dataa_saved <= 33'h0;
            datab_saved <= 33'h0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rf_addra_reg <= 5'h00;
        rf_addrb_reg <= 5'h00;
    end else begin
        rf_addra_reg <= rf_addra;
        rf_addrb_reg <= rf_addrb;
    end
end

assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;
assign spr_dat_o = from_rfa;

// Instantiate the register file based on compile-time macros
generate
    if (`ifdef OR1200_RFRAM_TWOPORT) begin : gen_twoport
        or1200_tpram_32x32 u0_rf_tpram_a(
            .clk(clk),
            .we(rf_we),
            .addr(rf_addrw),
            .di(rf_dataw),
            .do(from_rfa_int),
            .re(rf_ena),
            .addr_r(rf_addra)
        );
        or1200_tpram_32x32 u1_rf_tpram_b(
            .clk(clk),
            .we(rf_we),
            .addr(rf_addrw),
            .di(rf_dataw),
            .do(from_rfb_int),
            .re(rf_enb),
            .addr_r(rf_addrb)
        );
        assign from_rfa = from_rfa_int;
        assign from_rfb = from_rfb_int;
    end else if (`ifdef OR1200_RFRAM_DUALPORT) begin : gen_dualport
        or1200_dpram_32x32 u0_rf_dpram_a(
            .clk(clk),
            .we(rf_we),
            .addr_w(rf_addrw),
            .di(rf_dataw),
            .do(from_rfa_int),
            .re(rf_ena),
            .addr_r(rf_addra)
        );
        or1200_dpram_32x32 u1_rf_dpram_b(
            .clk(clk),
            .we(rf_we),
            .addr_w(rf_addrw),
            .di(rf_dataw),
            .do(from_rfb_int),
            .re(rf_enb),
            .addr_r(rf_addrb)
        );
        assign from_rfa = from_rfa_int;
        assign from_rfb = from_rfb_int;
    end else if (`ifdef OR1200_RFRAM_GENERIC) begin : gen_generic
        or1200_rfram_generic u_rf_generic(
            .clk(clk),
            .we(rf_we),
            .addr(rf_addrw),
            .di(rf_dataw),
            .doa(from_rfa_int),
            .dob(from_rfb_int),
            .rea(rf_ena),
            .reb(rf_enb),
            .addra(rf_addra),
            .addrb(rf_addrb)
        );
        assign from_rfa = from_rfa_int;
        assign from_rfb = from_rfb_int;
    end else if (`ifdef OR1200_RAM_MODELS_VIRTEX) begin : gen_virtex
        rf_sub u_rf_sub_a(
            .clk(clk),
            .we(rf_we),
            .addr(rf_addrw),
            .din(rf_dataw),
            .dout(from_rfa_int),
            .re(rf_ena),
            .addr_r(rf_addra)
        );
        rf_sub u_rf_sub_b(
            .clk(clk),
            .we(rf_we),
            .addr(rf_addrw),
            .din(rf_dataw),
            .dout(from_rfb_int),
            .re(rf_enb),
            .addr_r(rf_addrb)
        );
        assign from_rfa = (rf_addra_reg == 5'h00) ? 32'h0 : from_rfa_int;
        assign from_rfb = (rf_addrb_reg == 5'h00) ? 32'h0 : from_rfb_int;
    end else begin : gen_error
        initial begin
            $display("Define RFRAM type.");
            $finish;
        end
    end
endgenerate

endmodule

module or1200_rf #(
    parameter SPR_RF = 6'h01
) (
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

    wire [31:0] from_rfa;
    wire [31:0] from_rfb;
    wire [31:0] from_rfa_int;
    wire [31:0] from_rfb_int;
    wire [4:0] rf_addra;
    wire [4:0] rf_addrw;
    wire [31:0] rf_dataw;
    wire rf_we;
    wire spr_valid;
    wire rf_ena;
    wire rf_enb;
    reg  rf_we_allow;
    reg  [32:0] dataa_saved;
    reg  [32:0] datab_saved;

    // spr_valid
    assign spr_valid = spr_cs && (spr_addr[10:5] == SPR_RF);

    // Read address selection
    assign rf_addra = (spr_valid && !spr_write) ? spr_addr[4:0] : addra;

    // Write address and data selection
    assign rf_addrw = (spr_valid && spr_write) ? spr_addr[4:0] : addrw;
    assign rf_dataw = (spr_valid && spr_write) ? spr_dat_i : dataw;

    // Read enables
    assign rf_ena = (rda && !id_freeze) || spr_valid;
    assign rf_enb = (rdb && !id_freeze) || spr_valid;

    // rf_we_allow register
    always @(posedge clk or posedge rst) begin
        if (rst)
            rf_we_allow <= 1'b1;
        else if (!wb_freeze)
            rf_we_allow <= ~flushpipe;
    end

    // rf_we
    assign rf_we = ((spr_valid & spr_write) | (we & ~wb_freeze)) & rf_we_allow & (supv | (|rf_addrw));

    // Operand retention logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dataa_saved <= 33'b0;
            datab_saved <= 33'b0;
        end else begin
            // dataa
            if (id_freeze && !dataa_saved[32]) begin
                dataa_saved <= {1'b1, from_rfa};
            end else if (!id_freeze) begin
                dataa_saved <= 33'b0;
            end
            // datab
            if (id_freeze && !datab_saved[32]) begin
                datab_saved <= {1'b1, from_rfb};
            end else if (!id_freeze) begin
                datab_saved <= 33'b0;
            end
        end
    end

    // Outputs
    assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
    assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;
    assign spr_dat_o = from_rfa;

    // ----------------------------------------------------------------------
    // Register file implementation selection
    // ----------------------------------------------------------------------
`ifdef OR1200_RFRAM_TWOPORT
    or1200_tpram_32x32 ram_a (
        .clk(clk),
        .rst(rst),
        .addra(rf_addra),
        .ena(rf_ena),
        .we(rf_we),
        .addrw(rf_addrw),
        .di(rf_dataw),
        .do(from_rfa_int)
    );
    or1200_tpram_32x32 ram_b (
        .clk(clk),
        .rst(rst),
        .addra(rf_addrb),
        .ena(rf_enb),
        .we(rf_we),
        .addrw(rf_addrw),
        .di(rf_dataw),
        .do(from_rfb_int)
    );
    assign from_rfa = from_rfa_int;
    assign from_rfb = from_rfb_int;
`elsif OR1200_RFRAM_DUALPORT
    or1200_dpram_32x32 ram_a (
        .clk(clk),
        .rst(rst),
        .addra(rf_addra),
        .ena(rf_ena),
        .we(rf_we),
        .addrw(rf_addrw),
        .di(rf_dataw),
        .do(from_rfa_int)
    );
    or1200_dpram_32x32 ram_b (
        .clk(clk),
        .rst(rst),
        .addra(rf_addrb),
        .ena(rf_enb),
        .we(rf_we),
        .addrw(rf_addrw),
        .di(rf_dataw),
        .do(from_rfb_int)
    );
    assign from_rfa = from_rfa_int;
    assign from_rfb = from_rfb_int;
`elsif OR1200_RFRAM_GENERIC
    or1200_rfram_generic u_rf (
        .clk(clk),
        .rst(rst),
        .addra(rf_addra),
        .addrb(rf_addrb),
        .ena(rf_ena),
        .enb(rf_enb),
        .we(rf_we),
        .addrw(rf_addrw),
        .di(rf_dataw),
        .do_a(from_rfa_int),
        .do_b(from_rfb_int)
    );
    assign from_rfa = from_rfa_int;
    assign from_rfb = from_rfb_int;
`elsif OR1200_RAM_MODELS_VIRTEX
    reg [4:0] rf_addra_reg;
    reg [4:0] rf_addrb_reg;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf_addra_reg <= 5'b0;
            rf_addrb_reg <= 5'b0;
        end else begin
            rf_addra_reg <= rf_addra;
            rf_addrb_reg <= rf_addrb;
        end
    end
    rf_sub ram_a (
        .clk(clk),
        .rst(rst),
        .en(rf_ena),
        .addr(rf_addra_reg),
        .we(rf_we),
        .addrw(rf_addrw),
        .di(rf_dataw),
        .do(from_rfa_int)
    );
    rf_sub ram_b (
        .clk(clk),
        .rst(rst),
        .en(rf_enb),
        .addr(rf_addrb_reg),
        .we(rf_we),
        .addrw(rf_addrw),
        .di(rf_dataw),
        .do(from_rfb_int)
    );
    assign from_rfa = (rf_addra_reg == 5'b0) ? 32'b0 : from_rfa_int;
    assign from_rfb = (rf_addrb_reg == 5'b0) ? 32'b0 : from_rfb_int;
`else
    initial begin
        $display("Define RFRAM type.");
        $finish;
    end
`endif

endmodule

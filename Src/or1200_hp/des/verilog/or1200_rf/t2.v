`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_rf (
    input         clk,
    input         rst,

    // Write i/f
    input         supv,
    input         wb_freeze,
    input  [4:0]  addrw,
    input  [31:0] dataw,
    input         we,
    input         flushpipe,

    // Read i/f
    input         id_freeze,
    input  [4:0]  addra,
    input  [4:0]  addrb,
    output [31:0] dataa,
    output [31:0] datab,
    input         rda,
    input         rdb,

    // Debug/SPR
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

    //--------------------------------------------------------------------------
    // SPR range decode: GPR bank when spr_addr[10:5] == OR1200_SPR_RF
    //--------------------------------------------------------------------------
    wire spr_valid = spr_cs & (spr_addr[10:5] == `OR1200_SPR_RF);

    //--------------------------------------------------------------------------
    // Write address/data arbitration: SPR write overrides pipeline write-back
    //--------------------------------------------------------------------------
    wire [4:0]  rf_addrw = (spr_valid & spr_write) ? spr_addr[4:0] : addrw;
    wire [31:0] rf_dataw = (spr_valid & spr_write) ? spr_dat_i     : dataw;

    //--------------------------------------------------------------------------
    // rf_we_allow: suppresses writes after a flushpipe while WB is not frozen
    //--------------------------------------------------------------------------
    reg rf_we_allow;

    always @(posedge clk or posedge rst) begin
        if (rst)
            rf_we_allow <= 1'b1;
        else if (!wb_freeze)
            rf_we_allow <= ~flushpipe;
    end

    //--------------------------------------------------------------------------
    // Write enable:
    //   ((SPR write) OR (pipeline write-back & ~wb_freeze))
    //   & rf_we_allow
    //   & (supv mode OR non-zero address) -- guard r0
    //--------------------------------------------------------------------------
    wire rf_we = ((spr_valid & spr_write) | (we & ~wb_freeze))
                 & rf_we_allow
                 & (supv | (|rf_addrw));

    //--------------------------------------------------------------------------
    // Read address arbitration: SPR read redirects port A to spr_addr[4:0]
    //--------------------------------------------------------------------------
    wire [4:0] rf_addra = (spr_valid & ~spr_write) ? spr_addr[4:0] : addra;
    wire [4:0] rf_addrb = addrb;  // port B always from pipeline

    //--------------------------------------------------------------------------
    // Read enables
    // Port A: (pipeline read request & ID not frozen) OR SPR access
    // Port B: (pipeline read request & ID not frozen) OR SPR access
    //--------------------------------------------------------------------------
    wire rf_ena = (rda & ~id_freeze) | spr_valid;
    wire rf_enb = (rdb & ~id_freeze) | spr_valid;

    //--------------------------------------------------------------------------
    // Raw read data from register-file implementation
    //--------------------------------------------------------------------------
    wire [31:0] from_rfa_int;
    wire [31:0] from_rfb_int;

    //--------------------------------------------------------------------------
    // Register-file storage implementation selection
    //--------------------------------------------------------------------------

`ifdef OR1200_RFRAM_TWOPORT

    // Two separate true-two-port RAMs sharing write port
    or1200_tpram_32x32 or1200_rf_a (
        .clk_a  (clk), .rst_a  (rst),
        .ce_a   (rf_ena), .we_a  (1'b0),
        .oe_a   (1'b1),   .addr_a(rf_addra), .di_a(32'h0), .do_a(from_rfa_int),
        .clk_b  (clk), .rst_b  (rst),
        .ce_b   (rf_we),  .we_b  (rf_we),
        .oe_b   (1'b0),   .addr_b(rf_addrw), .di_b(rf_dataw), .do_b()
    );

    or1200_tpram_32x32 or1200_rf_b (
        .clk_a  (clk), .rst_a  (rst),
        .ce_a   (rf_enb), .we_a  (1'b0),
        .oe_a   (1'b1),   .addr_a(rf_addrb), .di_a(32'h0), .do_a(from_rfb_int),
        .clk_b  (clk), .rst_b  (rst),
        .ce_b   (rf_we),  .we_b  (rf_we),
        .oe_b   (1'b0),   .addr_b(rf_addrw), .di_b(rf_dataw), .do_b()
    );

`else
`ifdef OR1200_RFRAM_DUALPORT

    or1200_dpram_32x32 or1200_rf_a (
        .clk_a  (clk), .rst_a  (rst),
        .ce_a   (rf_ena), .we_a  (1'b0),
        .oe_a   (1'b1),   .addr_a(rf_addra), .di_a(32'h0), .do_a(from_rfa_int),
        .clk_b  (clk), .rst_b  (rst),
        .ce_b   (rf_we),  .we_b  (rf_we),
        .oe_b   (1'b0),   .addr_b(rf_addrw), .di_b(rf_dataw), .do_b()
    );

    or1200_dpram_32x32 or1200_rf_b (
        .clk_a  (clk), .rst_a  (rst),
        .ce_a   (rf_enb), .we_a  (1'b0),
        .oe_a   (1'b1),   .addr_a(rf_addrb), .di_a(32'h0), .do_a(from_rfb_int),
        .clk_b  (clk), .rst_b  (rst),
        .ce_b   (rf_we),  .we_b  (rf_we),
        .oe_b   (1'b0),   .addr_b(rf_addrw), .di_b(rf_dataw), .do_b()
    );

`else
`ifdef OR1200_RFRAM_GENERIC

    or1200_rfram_generic or1200_rf_generic (
        .clk    (clk), .rst    (rst),
        .addra  (rf_addra), .ena   (rf_ena), .douta (from_rfa_int),
        .addrb  (rf_addrb), .enb   (rf_enb), .doutb (from_rfb_int),
        .addrw  (rf_addrw), .we    (rf_we),  .din   (rf_dataw)
    );

`else
`ifdef OR1200_RAM_MODELS_VIRTEX

    // Virtex FPGA-specific: register read addresses for pipelined RAM read
    reg [4:0] rf_addra_reg;
    reg [4:0] rf_addrb_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf_addra_reg <= 5'h0;
            rf_addrb_reg <= 5'h0;
        end else begin
            if (rf_ena) rf_addra_reg <= rf_addra;
            if (rf_enb) rf_addrb_reg <= rf_addrb;
        end
    end

    wire [31:0] rfa_raw;
    wire [31:0] rfb_raw;

    // Force r0 reads to zero
    assign from_rfa_int = (rf_addra_reg == 5'h00) ? 32'h0 : rfa_raw;
    assign from_rfb_int = (rf_addrb_reg == 5'h00) ? 32'h0 : rfb_raw;

    rf_sub or1200_rf_a (
        .clk   (clk),
        .ce    (rf_ena),
        .we    (rf_we),
        .addra (rf_addra),
        .addrb (rf_addrw),
        .di    (rf_dataw),
        .do    (rfa_raw)
    );

    rf_sub or1200_rf_b (
        .clk   (clk),
        .ce    (rf_enb),
        .we    (rf_we),
        .addra (rf_addrb),
        .addrb (rf_addrw),
        .di    (rf_dataw),
        .do    (rfb_raw)
    );

`else

    // No valid RF RAM type defined
    initial begin
        $display("Define RFRAM type.");
        $finish;
    end

    assign from_rfa_int = 32'h0;
    assign from_rfb_int = 32'h0;

`endif  // OR1200_RAM_MODELS_VIRTEX
`endif  // OR1200_RFRAM_GENERIC
`endif  // OR1200_RFRAM_DUALPORT
`endif  // OR1200_RFRAM_TWOPORT

    //--------------------------------------------------------------------------
    // from_rfa / from_rfb: raw outputs (Virtex already handles r0 above)
    //--------------------------------------------------------------------------
    wire [31:0] from_rfa = from_rfa_int;
    wire [31:0] from_rfb = from_rfb_int;

    //--------------------------------------------------------------------------
    // SPR read data: always from port A
    //--------------------------------------------------------------------------
    assign spr_dat_o = from_rfa;

    //--------------------------------------------------------------------------
    // Operand freeze / save logic
    // dataa_saved[32]: valid flag; dataa_saved[31:0]: saved operand A
    // datab_saved[32]: valid flag; datab_saved[31:0]: saved operand B
    //
    // When id_freeze asserted and valid not yet set:
    //   capture current read value, set valid flag
    // When id_freeze deasserted:
    //   clear saved register (valid flag = 0)
    // While frozen and valid flag set:
    //   hold saved value (no update)
    //--------------------------------------------------------------------------
    reg [32:0] dataa_saved;
    reg [32:0] datab_saved;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dataa_saved <= 33'h0;
        end else begin
            if (id_freeze & ~dataa_saved[32]) begin
                // First cycle of freeze: capture operand A
                dataa_saved <= {1'b1, from_rfa};
            end else if (~id_freeze) begin
                // Freeze released: clear saved value
                dataa_saved <= 33'h0;
            end
            // id_freeze & dataa_saved[32]: hold (do nothing)
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            datab_saved <= 33'h0;
        end else begin
            if (id_freeze & ~datab_saved[32]) begin
                datab_saved <= {1'b1, from_rfb};
            end else if (~id_freeze) begin
                datab_saved <= 33'h0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Output selection: prefer saved value when valid, else live read data
    //--------------------------------------------------------------------------
    assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
    assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;

endmodule
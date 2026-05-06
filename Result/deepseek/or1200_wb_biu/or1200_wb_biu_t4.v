module or1200_wb_biu #(
    parameter DW = 32,
    parameter AW = 32,
    parameter RETRY_CNT_WIDTH = 8
) (
    // RISC clock, reset and clock control
    input clk,
    input rst,
    input [1:0] clmode,

    // WISHBONE interface
    input wb_clk_i,
    input wb_rst_i,
    input wb_ack_i,
    input wb_err_i,
    input wb_rty_i,
    input [31:0] wb_dat_i,
    output wb_cyc_o,
    output [31:0] wb_adr_o,
    output wb_stb_o,
    output wb_we_o,
    output [3:0] wb_sel_o,
    output [31:0] wb_dat_o,
`ifdef OR1200_WB_CAB
    output wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0] wb_cti_o,
    output [1:0] wb_bte_o,
`endif

    // Internal RISC bus
    input [31:0] biu_dat_i,
    input [31:0] biu_adr_i,
    input biu_cyc_i,
    input biu_stb_i,
    input biu_we_i,
    input [3:0] biu_sel_i,
    input biu_cab_i,
    output [31:0] biu_dat_o,
    output biu_ack_o,
    output biu_err_o
);

    // ------------------------------------------------------------------------
    // valid_div counter in RISC clock domain
    // ------------------------------------------------------------------------
    reg [1:0] valid_div;
    always @(posedge clk or posedge rst) begin
        if (rst)
            valid_div <= 2'b00;
        else
            valid_div <= valid_div + 1'b1;
    end

    // ------------------------------------------------------------------------
    // WISHBONE domain signals
    // ------------------------------------------------------------------------
    // aborted combinational: strobe high, internal request invalid, no ack/err
    wire aborted;
    // aborted_r registered
    reg aborted_r;

`ifdef OR1200_WB_RETRY
    reg [RETRY_CNT_WIDTH-1:0] retry_cntr;
    wire retry;
    assign retry = wb_rty_i | (|retry_cntr);
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            retry_cntr <= 0;
        else if (wb_rty_i)
            retry_cntr <= {RETRY_CNT_WIDTH{1'b1}};
        else if (|retry_cntr)
            retry_cntr <= retry_cntr - 1;
    end
`else
    wire retry;
    assign retry = 1'b0;
`endif

`ifdef OR1200_WB_B3
    reg [1:0] burst_len;
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            burst_len <= 2'b00;
        else if (~biu_cab_i)
            burst_len <= 2'b11;
        else if (biu_cab_i & wb_ack_i & (burst_len != 2'b00))
            burst_len <= burst_len - 1'b1;
    end
`endif

    // ------------------------------------------------------------------------
    // aborted_r flip-flop
    // ------------------------------------------------------------------------
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            aborted_r <= 1'b0;
        else if (wb_ack_i | wb_err_i)
            aborted_r <= 1'b0;
        else if (aborted)
            aborted_r <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // Registered outputs (if OR1200_REGISTERED_OUTPUTS defined)
    // ------------------------------------------------------------------------
`ifdef OR1200_REGISTERED_OUTPUTS
    reg wb_cyc_o_reg;
    reg wb_stb_o_reg;
    reg wb_we_o_reg;
    reg [3:0] wb_sel_o_reg;
    reg [31:0] wb_adr_o_reg;
    reg [31:0] wb_dat_o_reg;
`ifdef OR1200_WB_CAB
    reg wb_cab_o_reg;
`endif
`ifdef OR1200_WB_B3
    reg [2:0] wb_cti_o_reg;
`endif

    // Combinational aborted (uses registered wb_stb_o_reg)
    assign aborted = wb_stb_o_reg & ~(biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~wb_err_i;

    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_cyc_o_reg <= 1'b0;
            wb_stb_o_reg <= 1'b0;
            wb_we_o_reg <= 1'b0;
            wb_sel_o_reg <= 4'b0000;
            wb_adr_o_reg <= 32'b0;
            wb_dat_o_reg <= 32'b0;
`ifdef OR1200_WB_CAB
            wb_cab_o_reg <= 1'b0;
`endif
`ifdef OR1200_WB_B3
            wb_cti_o_reg <= 3'b000;
`endif
        end else begin
            // wb_cyc_o_reg
            wb_cyc_o_reg <= ((biu_cyc_i | biu_cab_i) & ~wb_ack_i & ~retry) |
                             (aborted & ~wb_ack_i);
            // wb_stb_o_reg
            wb_stb_o_reg <= (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~retry) |
                             (aborted & ~wb_ack_i);
            // wb_we_o_reg: update on new request, hold during abort
            if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted)
                wb_we_o_reg <= biu_we_i;
            // else hold (including abort hold)
            // wb_sel_o_reg: load every cycle
            wb_sel_o_reg <= biu_sel_i;
            // wb_adr_o_reg: update when new request, no ack, no abort, strobe not active
            if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted & ~wb_stb_o_reg)
                wb_adr_o_reg <= biu_adr_i;
            // wb_dat_o_reg: update on new request, no ack, no abort
            if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted)
                wb_dat_o_reg <= biu_dat_i;
`ifdef OR1200_WB_CAB
            wb_cab_o_reg <= biu_cab_i;
`endif
`ifdef OR1200_WB_B3
            // wb_cti_o_reg
`ifdef OR1200_NO_BURSTS
            wb_cti_o_reg <= 3'b111;
`else
            if (biu_cab_i & burst_len[1])
                wb_cti_o_reg <= 3'b010;
            else
                wb_cti_o_reg <= 3'b111;
`endif
`endif
        end
    end

    // Output assignments from registered versions
    assign wb_cyc_o = wb_cyc_o_reg;
    assign wb_stb_o = wb_stb_o_reg;
    assign wb_we_o = wb_we_o_reg;
    assign wb_sel_o = wb_sel_o_reg;
    assign wb_adr_o = wb_adr_o_reg;
    assign wb_dat_o = wb_dat_o_reg;
`ifdef OR1200_WB_CAB
    assign wb_cab_o = wb_cab_o_reg;
`endif
`ifdef OR1200_WB_B3
    assign wb_cti_o = wb_cti_o_reg;
    assign wb_bte_o = 2'b01;
`endif

`else // not OR1200_REGISTERED_OUTPUTS
    // Non-registered outputs - combinational
    assign aborted = 1'b0; // not used in combinational mode

    // wb_cyc_o: per spec: biu_cyc_i & ~retry (burst disabled) or biu_cyc_i | biu_cab_i & ~retry
    // Here we use biu_cab_i as burst indicator
`ifdef OR1200_WB_CAB
    assign wb_cyc_o = (biu_cyc_i | (biu_cab_i & ~retry));
`else
    assign wb_cyc_o = biu_cyc_i & ~retry;
`endif
    assign wb_stb_o = biu_cyc_i & biu_stb_i;
    assign wb_we_o = biu_cyc_i & biu_stb_i & biu_we_i;
    assign wb_sel_o = biu_sel_i;
    assign wb_adr_o = biu_adr_i;
    assign wb_dat_o = biu_dat_i;
`ifdef OR1200_WB_CAB
    assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
    assign wb_bte_o = 2'b01;
    // wb_cti_o for non-registered: use same logic as registered case but combined?
    // Spec says unsupported, but we'll use burst_len and biu_cab_i
`ifdef OR1200_NO_BURSTS
    assign wb_cti_o = 3'b111;
`else
    assign wb_cti_o = (biu_cab_i & burst_len[1]) ? 3'b010 : 3'b111;
`endif
`endif
`endif

    // ------------------------------------------------------------------------
    // Input side (BIU return path)
    // ------------------------------------------------------------------------
`ifdef OR1200_REGISTERED_INPUTS
    reg [31:0] biu_dat_o_reg;
    reg long_ack_o_reg, long_err_o_reg;

    // long_ack_o and long_err_o registered
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            long_ack_o_reg <= 1'b0;
            long_err_o_reg <= 1'b0;
            biu_dat_o_reg <= 32'b0;
        end else begin
            long_ack_o_reg <= wb_ack_i & ~aborted;
            long_err_o_reg <= wb_err_i & ~aborted;
            if (wb_ack_i)
                biu_dat_o_reg <= wb_dat_i;
        end
    end

    wire long_ack_o = long_ack_o_reg;
    wire long_err_o = long_err_o_reg;
    assign biu_dat_o = biu_dat_o_reg;
`else
    // non-registered inputs
    wire long_ack_o = wb_ack_i & ~aborted_r;
    wire long_err_o = wb_err_i & ~aborted_r;
    assign biu_dat_o = wb_dat_i;
`endif

    // ------------------------------------------------------------------------
    // Clock division gating for biu_ack_o and biu_err_o
    // ------------------------------------------------------------------------
    // valid_div is in clk domain, long_ack_o/long_err_o in wb domain
    // Gating logic: when clock division is supported, only assert on appropriate phase
`ifdef OR1200_CLKDIV_2_SUPPORTED
    wire clkdiv2_gate = (clmode == 2'b01) ? (valid_div[0] == 1'b0) : 1'b1;
`else
    wire clkdiv2_gate = 1'b1;
`endif
`ifdef OR1200_CLKDIV_4_SUPPORTED
    wire clkdiv4_gate = (clmode == 2'b11) ? (valid_div == 2'b00) : 1'b1;
`else
    wire clkdiv4_gate = 1'b1;
`endif
    wire clkdiv_gate = clkdiv2_gate & clkdiv4_gate;

    assign biu_ack_o = long_ack_o & clkdiv_gate;
    assign biu_err_o = long_err_o & clkdiv_gate;

endmodule

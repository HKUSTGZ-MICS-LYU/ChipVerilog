`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_wb_biu (
    // RISC clock, reset and clock control
    input         clk,
    input         rst,
    input  [1:0]  clmode,

    // WISHBONE interface
    input         wb_clk_i,
    input         wb_rst_i,
    input         wb_ack_i,
    input         wb_err_i,
    input         wb_rty_i,
    input  [31:0] wb_dat_i,
    output        wb_cyc_o,
    output [31:0] wb_adr_o,
    output        wb_stb_o,
    output        wb_we_o,
    output [3:0]  wb_sel_o,
    output [31:0] wb_dat_o,
`ifdef OR1200_WB_CAB
    output        wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0]  wb_cti_o,
    output [1:0]  wb_bte_o,
`endif

    // Internal RISC bus
    input  [31:0] biu_dat_i,
    input  [31:0] biu_adr_i,
    input         biu_cyc_i,
    input         biu_stb_i,
    input         biu_we_i,
    input  [3:0]  biu_sel_i,
    input         biu_cab_i,
    output [31:0] biu_dat_o,
    output        biu_ack_o,
    output        biu_err_o
);

    //--------------------------------------------------------------------------
    // RISC-domain: valid_div counter for clock-ratio phase selection
    //--------------------------------------------------------------------------
    reg [1:0] valid_div;

    always @(posedge clk or posedge rst) begin
        if (rst) valid_div <= 2'b00;
        else     valid_div <= valid_div + 2'b01;
    end

    //--------------------------------------------------------------------------
    // Wishbone-domain state
    //--------------------------------------------------------------------------
    reg aborted_r;

`ifdef OR1200_WB_RETRY
    reg [`OR1200_WB_RETRY-1:0] retry_cntr;
    wire retry = wb_rty_i | (|retry_cntr);
`else
    wire retry = 1'b0;
`endif

`ifdef OR1200_WB_B3
    reg [1:0] burst_len;
`endif

    //--------------------------------------------------------------------------
    // Abort detection (combinational)
    // aborted: stb issued, BIU withdrew request, no ack/err this cycle
    //--------------------------------------------------------------------------
`ifdef OR1200_REGISTERED_OUTPUTS
    wire aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~wb_err_i;
`else
    wire aborted = 1'b0;
`endif

    //--------------------------------------------------------------------------
    // aborted_r: hold abort state until external termination (WB domain)
    //--------------------------------------------------------------------------
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            aborted_r <= 1'b0;
        else if (wb_ack_i | wb_err_i)
            aborted_r <= 1'b0;
        else if (aborted)
            aborted_r <= 1'b1;
    end

`ifdef OR1200_WB_RETRY
    //--------------------------------------------------------------------------
    // Retry counter (WB domain)
    //--------------------------------------------------------------------------
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            retry_cntr <= {`OR1200_WB_RETRY{1'b0}};
        else if (wb_rty_i)
            retry_cntr <= {`OR1200_WB_RETRY{1'b1}};
        else if (|retry_cntr)
            retry_cntr <= retry_cntr - 1;
    end
`endif

    //==========================================================================
    // OUTPUT PATH
    //==========================================================================

`ifdef OR1200_REGISTERED_OUTPUTS

    //--------------------------------------------------------------------------
    // Registered Wishbone outputs (WB domain)
    //--------------------------------------------------------------------------
    reg        wb_cyc_r, wb_stb_r, wb_we_r;
    reg [31:0] wb_adr_r, wb_dat_r;
    reg [3:0]  wb_sel_r;
`ifdef OR1200_WB_CAB
    reg        wb_cab_r;
`endif
`ifdef OR1200_WB_B3
    reg [2:0]  wb_cti_r;
`endif

    assign wb_cyc_o = wb_cyc_r;
    assign wb_stb_o = wb_stb_r;
    assign wb_we_o  = wb_we_r;
    assign wb_adr_o = wb_adr_r;
    assign wb_dat_o = wb_dat_r;
    assign wb_sel_o = wb_sel_r;
`ifdef OR1200_WB_CAB
    assign wb_cab_o = wb_cab_r;
`endif
`ifdef OR1200_WB_B3
    assign wb_cti_o = wb_cti_r;
    assign wb_bte_o = 2'b01;   // 4-beat wrap burst
`endif

    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_cyc_r <= 1'b0;
            wb_stb_r <= 1'b0;
            wb_we_r  <= 1'b0;
            wb_adr_r <= 32'h0;
            wb_dat_r <= 32'h0;
            wb_sel_r <= 4'h0;
`ifdef OR1200_WB_CAB
            wb_cab_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
            wb_cti_r <= 3'b000;
`endif
        end else begin

            // wb_sel_o: load every cycle (no ack/retry gating)
            wb_sel_r <= biu_sel_i;

`ifdef OR1200_WB_CAB
            wb_cab_r <= biu_cab_i;
`endif

            // Normal new request: not retrying, not aborted, BIU has valid req
            if (biu_cyc_i & biu_stb_i & ~retry & ~aborted_r & ~wb_ack_i) begin
                wb_cyc_r <= 1'b1;
                wb_stb_r <= 1'b1;
                wb_we_r  <= biu_we_i;
                wb_dat_r <= biu_dat_i;
                // Address: only when no previous stb waiting for ack
                if (~wb_stb_r | wb_ack_i)
                    wb_adr_r <= biu_adr_i;
`ifdef OR1200_WB_B3
`ifdef OR1200_NO_BURSTS
                wb_cti_r <= 3'b111;   // end-of-burst (no burst mode)
`else
                if (biu_cab_i & burst_len[1])
                    wb_cti_r <= 3'b010;  // incrementing burst
                else
                    wb_cti_r <= 3'b111;  // end-of-burst
`endif
`endif
            end
            // Abort hold: BIU withdrew but external not yet terminated
            else if (aborted & ~wb_ack_i) begin
                wb_cyc_r <= 1'b1;
                wb_stb_r <= 1'b1;
                wb_we_r  <= wb_we_r;   // preserve write direction
            end
            // Request complete or no active request
            else if (wb_ack_i | wb_err_i | (~biu_cyc_i & ~aborted_r)) begin
                wb_cyc_r <= biu_cyc_i & ~retry;
                wb_stb_r <= 1'b0;
`ifdef OR1200_WB_B3
                wb_cti_r <= 3'b000;
`endif
            end
        end
    end

`ifdef OR1200_WB_B3
    // burst_len counter (WB domain)
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            burst_len <= 2'b11;
        else if (~biu_cab_i)
            burst_len <= 2'b11;
        else if (biu_cab_i & |burst_len & wb_ack_i)
            burst_len <= burst_len - 2'b01;
    end
`endif

`else   // Non-registered outputs: combinational

    assign wb_adr_o = biu_adr_i;
    assign wb_dat_o = biu_dat_i;
    assign wb_sel_o = biu_sel_i;
    assign wb_we_o  = biu_cyc_i & biu_stb_i & biu_we_i;
    assign wb_stb_o = biu_cyc_i & biu_stb_i;

`ifdef OR1200_NO_BURSTS
    assign wb_cyc_o = biu_cyc_i & ~retry;
`else
    // biu_cyc_i | (biu_cab_i & ~retry)  — retry gates CAB only
    assign wb_cyc_o = biu_cyc_i | (biu_cab_i & ~retry);
`endif

`ifdef OR1200_WB_CAB
    assign wb_cab_o = biu_cab_i;
`endif

`ifdef OR1200_WB_B3
    // B3 without registered outputs: unsupported per spec
    assign wb_cti_o = 3'b000;
    assign wb_bte_o = 2'b01;
`endif

`endif  // OR1200_REGISTERED_OUTPUTS

    //==========================================================================
    // INPUT / RESPONSE PATH
    //==========================================================================

`ifdef OR1200_REGISTERED_INPUTS

    reg [31:0] biu_dat_r;
    reg        long_ack_r, long_err_r;

    assign biu_dat_o  = biu_dat_r;
    wire   long_ack_o = long_ack_r;
    wire   long_err_o = long_err_r;

    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            biu_dat_r  <= 32'h0;
            long_ack_r <= 1'b0;
            long_err_r <= 1'b0;
        end else begin
            if (wb_ack_i)
                biu_dat_r  <= wb_dat_i;
            long_ack_r <= wb_ack_i & ~aborted;
            long_err_r <= wb_err_i & ~aborted;
        end
    end

`else   // Non-registered inputs: combinational

    assign biu_dat_o = wb_dat_i;
    wire long_ack_o  = wb_ack_i;
    wire long_err_o  = wb_err_i & ~aborted_r;

`endif  // OR1200_REGISTERED_INPUTS

    //--------------------------------------------------------------------------
    // biu_ack_o / biu_err_o: phase-select via valid_div when clkdiv supported
    //--------------------------------------------------------------------------
    wire valid_phase =
`ifdef OR1200_CLKDIV_4_SUPPORTED
        (clmode == 2'b11) ? (valid_div == 2'b11) :
`endif
`ifdef OR1200_CLKDIV_2_SUPPORTED
        (clmode == 2'b01) ? valid_div[0] :
`endif
        1'b1;

    assign biu_ack_o = long_ack_o & valid_phase;
    assign biu_err_o = long_err_o & valid_phase;

endmodule
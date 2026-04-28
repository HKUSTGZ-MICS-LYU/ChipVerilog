`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_iwb_biu (
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
    // RISC-clock-domain registers
    //--------------------------------------------------------------------------
    reg [1:0] valid_div;
    reg       repeated_access_ack;

    //--------------------------------------------------------------------------
    // Wishbone-clock-domain registers
    //--------------------------------------------------------------------------
`ifdef OR1200_REGISTERED_OUTPUTS
    reg [31:0] wb_adr_o_r;
    reg        wb_cyc_o_r;
    reg        wb_stb_o_r;
    reg        wb_we_o_r;
    reg [3:0]  wb_sel_o_r;
    reg [31:0] wb_dat_o_r;
`ifdef OR1200_WB_CAB
    reg        wb_cab_o_r;
`endif
`ifdef OR1200_WB_B3
    reg [2:0]  wb_cti_o_r;
`endif
`endif  // OR1200_REGISTERED_OUTPUTS

`ifdef OR1200_REGISTERED_INPUTS
    reg [31:0] biu_dat_o_r;
    reg        long_ack_o_r;
    reg        long_err_o_r;
`endif

    reg [31:0] wb_dat_r;          // saved previous read data
    reg        previous_complete;
    reg        aborted_r;

`ifdef OR1200_WB_RETRY
    reg [`OR1200_WB_RETRY-1:0] retry_cntr;
    wire retry = |retry_cntr;
`else
    wire retry = 1'b0;
`endif

`ifdef OR1200_WB_B3
    reg [1:0] burst_len;
`endif

    //--------------------------------------------------------------------------
    // Repeated-access detection
    //--------------------------------------------------------------------------
    wire same_addr     = (wb_adr_o == biu_adr_i);
    wire repeated_access = same_addr & previous_complete;

    //--------------------------------------------------------------------------
    // Abort logic
    //--------------------------------------------------------------------------
`ifdef OR1200_REGISTERED_OUTPUTS
    wire aborted = wb_stb_o_r & ~(biu_cyc_i & biu_stb_i) &
                   ~wb_ack_i & ~wb_err_i;
`else
    wire aborted = 1'b0;
`endif

    //--------------------------------------------------------------------------
    // long_ack / long_err (registered or combinational)
    //--------------------------------------------------------------------------
`ifdef OR1200_REGISTERED_INPUTS
    wire long_ack_o = long_ack_o_r;
    wire long_err_o = long_err_o_r;
`else
    wire long_ack_o = wb_ack_i;
    wire long_err_o = wb_err_i & ~aborted_r;
`endif

    //--------------------------------------------------------------------------
    // valid_div: RISC-clock phase qualifier for fixed clock-ratio modes
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            valid_div <= 2'b00;
        else
            valid_div <= valid_div + 2'b01;
    end

    wire valid_phase =
`ifdef OR1200_CLKDIV_4_SUPPORTED
        (clmode == 2'b11) ? (valid_div == 2'b11) :
`endif
`ifdef OR1200_CLKDIV_2_SUPPORTED
        (clmode == 2'b01) ? valid_div[0] :
`endif
        1'b1;

    //--------------------------------------------------------------------------
    // repeated_access_ack: RISC-clock domain
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            repeated_access_ack <= 1'b0;
        else
            repeated_access_ack <= repeated_access & biu_cyc_i & biu_stb_i
                                   & ~repeated_access_ack;
    end

    //--------------------------------------------------------------------------
    // biu_ack_o / biu_err_o
    //--------------------------------------------------------------------------
    assign biu_ack_o = (repeated_access_ack | long_ack_o) & ~aborted_r & valid_phase;
    assign biu_err_o = long_err_o & valid_phase;

    //--------------------------------------------------------------------------
    // biu_dat_o
    //--------------------------------------------------------------------------
`ifdef OR1200_REGISTERED_INPUTS
    assign biu_dat_o = biu_dat_o_r;
`else
    assign biu_dat_o = repeated_access_ack ? wb_dat_r : wb_dat_i;
`endif

    //--------------------------------------------------------------------------
    // Wishbone outputs: registered or combinational
    //--------------------------------------------------------------------------
`ifdef OR1200_REGISTERED_OUTPUTS

    assign wb_adr_o = wb_adr_o_r;
    assign wb_cyc_o = wb_cyc_o_r;
    assign wb_stb_o = wb_stb_o_r;
    assign wb_we_o  = wb_we_o_r;
    assign wb_sel_o = wb_sel_o_r;
    assign wb_dat_o = wb_dat_o_r;
`ifdef OR1200_WB_CAB
    assign wb_cab_o = wb_cab_o_r;
`endif
`ifdef OR1200_WB_B3
    assign wb_cti_o = wb_cti_o_r;
    assign wb_bte_o = 2'b01;     // 4-beat wrap burst
`endif

    // Registered Wishbone output update
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_adr_o_r <= 32'h0;
            wb_cyc_o_r <= 1'b0;
            wb_stb_o_r <= 1'b0;
            wb_we_o_r  <= 1'b0;
            wb_sel_o_r <= 4'h0;
            wb_dat_o_r <= 32'h0;
`ifdef OR1200_WB_CAB
            wb_cab_o_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
            wb_cti_o_r <= 3'b000;
`endif
        end else begin
            // Normal request launch: not retrying, not repeated_access, not aborted
            if (biu_cyc_i & biu_stb_i & ~retry & ~repeated_access & ~aborted_r) begin
                wb_adr_o_r <= biu_adr_i;
                wb_dat_o_r <= biu_dat_i;
                wb_sel_o_r <= biu_sel_i;
                wb_we_o_r  <= biu_we_i;
                wb_cyc_o_r <= 1'b1;
                wb_stb_o_r <= 1'b1;
`ifdef OR1200_WB_CAB
                wb_cab_o_r <= biu_cab_i;
`endif
`ifdef OR1200_WB_B3
                wb_cti_o_r <= biu_cab_i ? 3'b010 : 3'b111;
`endif
            end else if (aborted) begin
                // Graceful abort: keep cycle/strobe until external terminates
                wb_stb_o_r <= 1'b1;
                wb_cyc_o_r <= 1'b1;
            end else if (~(biu_cyc_i & biu_stb_i) & ~aborted_r) begin
                wb_cyc_o_r <= 1'b0;
                wb_stb_o_r <= 1'b0;
`ifdef OR1200_WB_CAB
                wb_cab_o_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
                wb_cti_o_r <= 3'b000;
`endif
            end else if (wb_ack_i | wb_err_i) begin
                // External terminates: deassert strobe
                wb_stb_o_r <= 1'b0;
                if (~(biu_cyc_i & biu_stb_i))
                    wb_cyc_o_r <= 1'b0;
`ifdef OR1200_WB_B3
                wb_cti_o_r <= 3'b111;  // end-of-burst
`endif
            end
        end
    end

`else   // OR1200_REGISTERED_OUTPUTS not defined: combinational

    assign wb_adr_o = biu_adr_i;
    assign wb_dat_o = biu_dat_i;
    assign wb_sel_o = biu_sel_i;
    assign wb_we_o  = biu_cyc_i & biu_stb_i & biu_we_i;
    assign wb_stb_o = biu_cyc_i & biu_stb_i;
`ifdef OR1200_NO_BURSTS
    assign wb_cyc_o = biu_cyc_i;
`else
    assign wb_cyc_o = biu_cyc_i & ~retry;
`endif
`ifdef OR1200_WB_CAB
    assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
    // B3 with non-registered outputs: unsupported
    assign wb_cti_o = 3'b000;
    assign wb_bte_o = 2'b00;
`endif

`endif  // OR1200_REGISTERED_OUTPUTS

    //--------------------------------------------------------------------------
    // Wishbone-clock-domain input registers
    //--------------------------------------------------------------------------
`ifdef OR1200_REGISTERED_INPUTS
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            biu_dat_o_r <= 32'h0;
            long_ack_o_r <= 1'b0;
            long_err_o_r <= 1'b0;
        end else begin
            if (wb_ack_i)
                biu_dat_o_r <= wb_dat_i;
            long_ack_o_r <= wb_ack_i & ~aborted_r;
            long_err_o_r <= wb_err_i & ~aborted_r;
        end
    end
`endif

    //--------------------------------------------------------------------------
    // wb_dat_r: save previous read data for repeated_access
    //--------------------------------------------------------------------------
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            wb_dat_r <= 32'h0;
        else if (wb_ack_i)
            wb_dat_r <= wb_dat_i;
    end

    //--------------------------------------------------------------------------
    // previous_complete
    //--------------------------------------------------------------------------
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            previous_complete <= 1'b1;
        else if (wb_ack_i & biu_cyc_i & biu_stb_i)
            previous_complete <= 1'b1;
        else if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted_r
`ifdef OR1200_REGISTERED_OUTPUTS
                 & ~wb_stb_o_r
`endif
                )
            previous_complete <= 1'b0;
    end

    //--------------------------------------------------------------------------
    // aborted_r
    //--------------------------------------------------------------------------
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            aborted_r <= 1'b0;
        else if (wb_ack_i | wb_err_i)
            aborted_r <= 1'b0;
        else if (aborted)
            aborted_r <= 1'b1;
    end

    //--------------------------------------------------------------------------
    // Retry counter
    //--------------------------------------------------------------------------
`ifdef OR1200_WB_RETRY
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            retry_cntr <= {`OR1200_WB_RETRY{1'b0}};
        else if (wb_rty_i)
            retry_cntr <= {`OR1200_WB_RETRY{1'b1}};
        else if (|retry_cntr)
            retry_cntr <= retry_cntr - 1;
    end
`endif

    //--------------------------------------------------------------------------
    // B3 burst_len counter
    //--------------------------------------------------------------------------
`ifdef OR1200_WB_B3
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            burst_len <= 2'h0;
        else if (wb_ack_i & biu_cab_i & |burst_len)
            burst_len <= burst_len - 2'h1;
        else if (biu_cab_i & ~|burst_len & biu_cyc_i & biu_stb_i)
            burst_len <= 2'h3;
    end
`endif

endmodule
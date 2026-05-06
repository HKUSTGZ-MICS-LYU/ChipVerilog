// or1200_iwb_biu - OR1200 instruction-side Wishbone bus interface unit
// Generated implementation matching the specification

module or1200_iwb_biu(
    input clk,
    input rst,
    input [1:0] clmode,
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

    // Internal signals
    wire same_addr;
    wire repeated_access;
    reg  repeated_access_ack;
    reg  [1:0] valid_div;
    wire aborted;
    reg  aborted_r;
    reg  previous_complete;
    reg  [31:0] wb_dat_r;
    wire long_ack;
    wire long_err;
    reg  long_ack_o;
    reg  long_err_o;

`ifdef OR1200_WB_RETRY
    reg  [3:0] retry_cntr;
    wire retry;
`endif

`ifdef OR1200_WB_B3
    reg  [1:0] burst_len;
    wire [2:0] next_cti;
`endif

    // Registered Wishbone outputs
`ifdef OR1200_REGISTERED_OUTPUTS
    reg  wb_cyc_o_r;
    reg  [31:0] wb_adr_o_r;
    reg  wb_stb_o_r;
    reg  wb_we_o_r;
    reg  [3:0] wb_sel_o_r;
    reg  [31:0] wb_dat_o_r;
    `ifdef OR1200_WB_CAB
    reg  wb_cab_o_r;
    `endif
    `ifdef OR1200_WB_B3
    reg  [2:0] wb_cti_o_r;
    reg  [1:0] wb_bte_o_r;
    `endif
`endif

    // RISC clock domain: valid_div counter
    always @(posedge clk or posedge rst) begin
        if (rst)
            valid_div <= 2'b00;
        else
            valid_div <= valid_div + 2'b01;
    end

    // Same address comparison
    assign same_addr = (wb_adr_o == biu_adr_i);

    // repeated_access detection (combinational in RISC domain, but uses wb_clk_i state)
    assign repeated_access = same_addr & previous_complete;

    // repeated_access_ack generation in RISC clock domain
    always @(posedge clk or posedge rst) begin
        if (rst)
            repeated_access_ack <= 1'b0;
        else
            repeated_access_ack <= repeated_access & biu_cyc_i & biu_stb_i;
    end

    // =========================================================================
    // Wishbone clock domain logic
    // =========================================================================

    // wb_dat_r: capture read data on ack
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            wb_dat_r <= 32'h00000000;
        else if (wb_ack_i)
            wb_dat_r <= wb_dat_i;
    end

    // previous_complete
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            previous_complete <= 1'b1;
        else if (wb_ack_i & biu_cyc_i & biu_stb_i)
            previous_complete <= 1'b1;
        else if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted & ~wb_stb_o)
            previous_complete <= 1'b0;
    end

    // aborted detection
    assign aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~wb_err_i;

    // aborted_r
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            aborted_r <= 1'b0;
        else if (aborted)
            aborted_r <= 1'b1;
        else if (wb_ack_i | wb_err_i)
            aborted_r <= 1'b0;
    end

    // long_ack / long_err combinational (Wishbone domain)
    assign long_ack = wb_ack_i & ~aborted;
    assign long_err = wb_err_i & ~aborted;

    // Registered or combinational inputs
`ifdef OR1200_REGISTERED_INPUTS
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            long_ack_o <= 1'b0;
            long_err_o <= 1'b0;
        end else begin
            long_ack_o <= wb_ack_i & ~aborted;
            long_err_o <= wb_err_i & ~aborted;
        end
    end
`else
    assign long_ack_o = wb_ack_i;
    assign long_err_o = wb_err_i & ~aborted_r;
`endif

    // Retry logic
`ifdef OR1200_WB_RETRY
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            retry_cntr <= 4'h0;
        else if (wb_rty_i)
            retry_cntr <= 4'hf;
        else if (retry_cntr != 4'h0)
            retry_cntr <= retry_cntr - 4'h1;
    end
    assign retry = (retry_cntr != 4'h0);
`endif

    // B3 burst logic
`ifdef OR1200_WB_B3
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            burst_len <= 2'b11;
        else if (wb_ack_i & wb_stb_o) begin
            if (burst_len == 2'b00)
                burst_len <= 2'b11;
            else
                burst_len <= burst_len - 2'b01;
        end
    end

    assign next_cti = (burst_len == 2'b11) ? 3'b010 :
                      (burst_len == 2'b00) ? 3'b111 :
                      3'b010;
`endif

    // =========================================================================
    // Registered Wishbone outputs
    // =========================================================================
`ifdef OR1200_REGISTERED_OUTPUTS
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_cyc_o_r <= 1'b0;
            wb_adr_o_r <= 32'h00000000;
            wb_stb_o_r <= 1'b0;
            wb_we_o_r  <= 1'b0;
            wb_sel_o_r <= 4'h0;
            wb_dat_o_r <= 32'h00000000;
            `ifdef OR1200_WB_CAB
            wb_cab_o_r <= 1'b0;
            `endif
            `ifdef OR1200_WB_B3
            wb_cti_o_r <= 3'b000;
            wb_bte_o_r <= 2'b01;
            `endif
        end else begin
            // Normal request launch
            if (biu_cyc_i & biu_stb_i & ~repeated_access
                `ifdef OR1200_WB_RETRY
                & ~retry
                `endif
                ) begin
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
                wb_cti_o_r <= next_cti;
                wb_bte_o_r <= 2'b01;
                `endif
            end else if (aborted) begin
                // Keep transaction alive on abort
                wb_cyc_o_r <= 1'b1;
                wb_stb_o_r <= 1'b1;
            end else if (wb_ack_i | wb_err_i) begin
                wb_cyc_o_r <= 1'b0;
                wb_stb_o_r <= 1'b0;
            end
        end
    end

    assign wb_cyc_o = wb_cyc_o_r;
    assign wb_adr_o = wb_adr_o_r;
    assign wb_stb_o = wb_stb_o_r;
    assign wb_we_o  = wb_we_o_r;
    assign wb_sel_o = wb_sel_o_r;
    assign wb_dat_o = wb_dat_o_r;
    `ifdef OR1200_WB_CAB
    assign wb_cab_o = wb_cab_o_r;
    `endif
    `ifdef OR1200_WB_B3
    assign wb_cti_o = wb_cti_o_r;
    assign wb_bte_o = wb_bte_o_r;
    `endif

`else // !OR1200_REGISTERED_OUTPUTS
    // Combinational Wishbone outputs
    assign wb_adr_o = biu_adr_i;
    assign wb_dat_o = biu_dat_i;
    assign wb_sel_o = biu_sel_i;
    assign wb_we_o  = biu_cyc_i & biu_stb_i & biu_we_i;
    assign wb_stb_o = biu_cyc_i & biu_stb_i;
    `ifdef OR1200_WB_CAB
    assign wb_cab_o = biu_cab_i;
    `endif
    `ifdef OR1200_NO_BURSTS
    assign wb_cyc_o = biu_cyc_i & biu_stb_i;
    `else
    assign wb_cyc_o = biu_cyc_i & biu_stb_i
        `ifdef OR1200_WB_RETRY
        & ~retry
        `endif
        ;
    `endif
    `ifdef OR1200_WB_B3
    // B3 not supported in non-registered mode
    assign wb_cti_o = 3'b000;
    assign wb_bte_o = 2'b00;
    `endif
`endif

    // =========================================================================
    // biu_dat_o generation
    // =========================================================================
`ifdef OR1200_REGISTERED_INPUTS
    reg [31:0] biu_dat_o_r;
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            biu_dat_o_r <= 32'h00000000;
        else if (wb_ack_i)
            biu_dat_o_r <= wb_dat_i;
    end
    assign biu_dat_o = biu_dat_o_r;
`else
    assign biu_dat_o = repeated_access_ack ? wb_dat_r : wb_dat_i;
`endif

    // =========================================================================
    // biu_ack_o / biu_err_o generation with clmode phase control
    // =========================================================================
    wire ack_int;
    wire err_int;

    assign ack_int = (repeated_access_ack | long_ack_o) & ~aborted_r;
    assign err_int = long_err_o;

    // Phase qualification for fixed clock-ratio modes
`ifdef OR1200_CLKDIV_2_SUPPORTED
    `ifdef OR1200_CLKDIV_4_SUPPORTED
    assign biu_ack_o = ack_int & 
        ( (clmode == 2'b00) ? 1'b1 :
          (clmode == 2'b01) ? (valid_div[0] == 1'b1) :
          (clmode == 2'b11) ? (valid_div == 2'b11) : 1'b0 );
    assign biu_err_o = err_int &
        ( (clmode == 2'b00) ? 1'b1 :
          (clmode == 2'b01) ? (valid_div[0] == 1'b1) :
          (clmode == 2'b11) ? (valid_div == 2'b11) : 1'b0 );
    `else
    assign biu_ack_o = ack_int &
        ( (clmode == 2'b00) ? 1'b1 :
          (clmode == 2'b01) ? (valid_div[0] == 1'b1) : 1'b0 );
    assign biu_err_o = err_int &
        ( (clmode == 2'b00) ? 1'b1 :
          (clmode == 2'b01) ? (valid_div[0] == 1'b1) : 1'b0 );
    `endif
`else
    assign biu_ack_o = ack_int;
    assign biu_err_o = err_int;
`endif

endmodule

// Module: or1200_iwb_biu
// OR1200 Instruction Wishbone Bus Interface Unit

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

    // ==============================================
    // Internal wires and regs
    // ==============================================
    wire        biu_req;          // Internal BIU request
    wire        repeated_access;
    reg         repeated_access_ack;
    wire        same_addr;
    wire        aborted;
    reg         aborted_r;
    reg         previous_complete;
    reg  [31:0] wb_dat_r;

    // Long ack/err signals
    wire        long_ack;
    wire        long_err;
    reg         long_ack_o;
    reg         long_err_o;

    // Registered Wishbone outputs
`ifdef OR1200_REGISTERED_OUTPUTS
    reg         wb_cyc_o;
    reg  [31:0] wb_adr_o;
    reg         wb_stb_o;
    reg         wb_we_o;
    reg  [3:0]  wb_sel_o;
    reg  [31:0] wb_dat_o;
`else
    // Non-registered outputs are wires
    // Declared as wires by default in output port list.
    // Assignment will be continuous.
`endif

`ifdef OR1200_WB_CAB
`ifdef OR1200_REGISTERED_OUTPUTS
    reg         wb_cab_o;
`else
    // wb_cab_o is wire
`endif
`endif

`ifdef OR1200_WB_B3
`ifdef OR1200_REGISTERED_OUTPUTS
    reg  [2:0]  wb_cti_o;
    reg  [1:0]  wb_bte_o;
    reg  [1:0]  burst_len;
`endif
    // B3 is unsupported without registered outputs
`endif

    // Retry counter
`ifdef OR1200_WB_RETRY
    reg  [3:0]  retry_cntr;
    wire        retry;
`endif

    // valid_div counter for clock modes
    reg  [1:0]  valid_div;

    // ==============================================
    // RISC clock domain: valid_div
    // ==============================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            valid_div <= 2'b00;
        else
            valid_div <= valid_div + 2'b01;
    end

    // ==============================================
    // RISC clock domain: repeated_access_ack
    // ==============================================
    // biu_req is a combinational request indicator
    assign biu_req = biu_cyc_i & biu_stb_i;

    // same_addr compares current BIU address with latched WB address
    assign same_addr = (biu_adr_i == wb_adr_o);

    // repeated_access is a combinational signal from WB domain
    // but used in RISC domain; met by synthesis constraint
    assign repeated_access = same_addr & previous_complete;

    always @(posedge clk or posedge rst) begin
        if (rst)
            repeated_access_ack <= 1'b0;
        else
            // Assert for one RISC cycle on a repeated access request
            repeated_access_ack <= repeated_access & biu_req;
    end

    // ==============================================
    // Wishbone clock domain: aborted, aborted_r
    // ==============================================
    assign aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~(wb_ack_i | wb_err_i);

    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            aborted_r <= 1'b0;
        else if (wb_ack_i | wb_err_i)
            aborted_r <= 1'b0;
        else if (aborted)
            aborted_r <= 1'b1;
    end

    // ==============================================
    // Wishbone clock domain: previous_complete, wb_dat_r
    // ==============================================
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            previous_complete <= 1'b1;
            wb_dat_r          <= 32'b0;
        end else begin
            // Capture read data on ack
            if (wb_ack_i)
                wb_dat_r <= wb_dat_i;

            // previous_complete logic:
            // Set on qualifying ack, cleared on new request start with no ack/abort and no pending stb
            if (wb_ack_i & biu_cyc_i & biu_stb_i)
                previous_complete <= 1'b1;
            else if (biu_req & ~wb_ack_i & ~aborted & ~wb_stb_o)
                previous_complete <= 1'b0;
        end
    end

    // ==============================================
    // Wishbone clock domain: long_ack_o, long_err_o (registered inputs)
    // ==============================================
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
    assign long_ack = long_ack_o;
    assign long_err = long_err_o;
`else
    assign long_ack = wb_ack_i;
    assign long_err = wb_err_i & ~aborted_r;
`endif

    // ==============================================
    // Registered Outputs Logic
    // ==============================================
`ifdef OR1200_REGISTERED_OUTPUTS

    // Retry logic
`ifdef OR1200_WB_RETRY
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            retry_cntr <= 4'b0;
        else if (wb_rty_i)
            retry_cntr <= 4'hf;  // max retry count
        else if (|retry_cntr)
            retry_cntr <= retry_cntr - 4'b1;
    end
    assign retry = |retry_cntr;
`else
    assign retry = 1'b0;
`endif

    // Main registered output block
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_adr_o <= 32'b0;
            wb_we_o  <= 1'b0;
            wb_sel_o <= 4'b0;
            wb_dat_o <= 32'b0;
`ifdef OR1200_WB_CAB
            wb_cab_o <= 1'b0;
`endif
`ifdef OR1200_WB_B3
            wb_cti_o   <= 3'b000;
            wb_bte_o   <= 2'b01;
            burst_len  <= 2'b11;
`endif
        end else begin
            // If aborted, keep cycle/strobe active until termination
            if (aborted) begin
                // Keep existing values; do not launch new
            end
            // Normal request launch: no retry, no repeated_access, not aborted
            else if (biu_req & ~retry & ~repeated_access) begin
                wb_adr_o <= biu_adr_i;
                wb_we_o  <= biu_we_i;
                wb_sel_o <= biu_sel_i;
                wb_dat_o <= biu_dat_i;
`ifdef OR1200_WB_CAB
                wb_cab_o <= biu_cab_i;
`endif
`ifdef OR1200_WB_B3
                // Burst length counter management
                if (biu_cab_i) begin
                    if (burst_len == 2'b00)
                        burst_len <= 2'b11;
                    else if (wb_ack_i)
                        burst_len <= burst_len - 2'b01;
                end else begin
                    burst_len <= 2'b11;
                end

                // CTI generation
                if (biu_cab_i) begin
                    if (burst_len == 2'b00)
                        wb_cti_o <= 3'b111; // End of burst
                    else if (burst_len == 2'b01)
                        wb_cti_o <= 3'b111; // End of burst (last beat)
                    else
                        wb_cti_o <= 3'b010; // Incrementing burst
                end else begin
                    wb_cti_o <= 3'b000; // Classic cycle
                end
                wb_bte_o <= 2'b01; // 4-beat wrap burst
`endif
                // Start Wishbone cycle
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
            end
            // Terminate cycle on ack or err
            else if (wb_ack_i | wb_err_i) begin
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
            end
            // If repeated_access and no active cycle, we don't start a new one
            else if (repeated_access) begin
                // Suppress new cycle
            end
            // Retry condition: suppress strobe but keep cycle if active
`ifdef OR1200_WB_RETRY
            if (retry & wb_cyc_o) begin
                wb_stb_o <= 1'b0;
            end
`endif
        end
    end

    // Registered biu_dat_o
`ifdef OR1200_REGISTERED_INPUTS
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            biu_dat_o <= 32'b0;
        else if (wb_ack_i)
            biu_dat_o <= wb_dat_i;
    end
`else
    // Non-registered biu_dat_o uses wb_dat_r for repeated_access
    assign biu_dat_o = repeated_access_ack ? wb_dat_r : wb_dat_i;
`endif

`else
    // ==============================================
    // Non-Registered Outputs Logic
    // ==============================================

    // wb_adr_o, wb_dat_o, wb_sel_o are direct
    assign wb_adr_o = biu_adr_i;
    assign wb_dat_o = biu_dat_i;
    assign wb_sel_o = biu_sel_i;

    // wb_we_o and wb_stb_o are combinational from BIU
    assign wb_we_o  = biu_req & biu_we_i;
    assign wb_stb_o = biu_req;

`ifdef OR1200_WB_CAB
    assign wb_cab_o = biu_cab_i;
`endif

    // wb_cyc_o generation depends on burst/retry macros
`ifdef OR1200_NO_BURSTS
    assign wb_cyc_o = biu_req;
`else
    // With bursts, consider CAB and retry
`ifdef OR1200_WB_RETRY
    assign wb_cyc_o = biu_req & ~retry;
`else
    assign wb_cyc_o = biu_req;
`endif
`endif

    // Non-registered biu_dat_o
    assign biu_dat_o = repeated_access_ack ? wb_dat_r : wb_dat_i;

`endif // !OR1200_REGISTERED_OUTPUTS

    // ==============================================
    // BIU Response Generation (RISC clock domain)
    // ==============================================
    wire biu_ack_pre;
    wire biu_err_pre;

    assign biu_ack_pre = (repeated_access_ack | long_ack) & ~aborted_r;
    assign biu_err_pre = long_err;

    // Clock mode phase qualification for biu_ack_o and biu_err_o
`ifdef OR1200_CLKDIV_2_SUPPORTED
    wire valid_phase_2;
    assign valid_phase_2 = (clmode == 2'b01) ? valid_div[0] : 1'b1;
`else
    wire valid_phase_2 = 1'b1;
`endif

`ifdef OR1200_CLKDIV_4_SUPPORTED
    wire valid_phase_4;
    assign valid_phase_4 = (clmode == 2'b11) ? (&valid_div) : 1'b1;
`else
    wire valid_phase_4 = 1'b1;
`endif

    // Final qualified outputs
    assign biu_ack_o = biu_ack_pre & valid_phase_2 & valid_phase_4;
    assign biu_err_o = biu_err_pre & valid_phase_2 & valid_phase_4;

endmodule

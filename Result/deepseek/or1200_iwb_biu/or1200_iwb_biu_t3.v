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
    output reg wb_cyc_o,
    output reg [31:0] wb_adr_o,
    output reg wb_stb_o,
    output reg wb_we_o,
    output reg [3:0] wb_sel_o,
    output reg [31:0] wb_dat_o,
`ifdef OR1200_WB_CAB
    output reg wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output reg [2:0] wb_cti_o,
    output reg [1:0] wb_bte_o,
`endif
    input [31:0] biu_dat_i,
    input [31:0] biu_adr_i,
    input biu_cyc_i,
    input biu_stb_i,
    input biu_we_i,
    input [3:0] biu_sel_i,
    input biu_cab_i,
    output reg [31:0] biu_dat_o,
    output reg biu_ack_o,
    output reg biu_err_o
);

    // Internal signals
    reg [1:0] valid_div;
    reg repeated_access_ack;
    wire same_addr;
    wire repeated_access;
    wire previous_complete;
    reg aborted_r;
    wire aborted;
    reg [31:0] wb_dat_r;
    reg long_ack_o;
    reg long_err_o;
    wire wb_ack_i_unmasked;
    wire wb_err_i_unmasked;
    reg [7:0] retry_cntr;
    wire retry;
    reg [1:0] burst_len; // for B3
    wire burst_last;

    // Wishbone clock domain registers (wb_clk_i, wb_rst_i)
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_adr_o <= 32'b0;
            wb_dat_o <= 32'b0;
            wb_sel_o <= 4'b0;
            wb_we_o <= 1'b0;
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
`ifdef OR1200_WB_CAB
            wb_cab_o <= 1'b0;
`endif
`ifdef OR1200_WB_B3
            wb_cti_o <= 3'b0;
            wb_bte_o <= 2'b0;
`endif
            previous_complete <= 1'b1;
            wb_dat_r <= 32'b0;
            aborted_r <= 1'b0;
            retry_cntr <= 8'b0;
            burst_len <= 2'b0;
        end else begin
            // Registered outputs logic
`ifdef OR1200_REGISTERED_OUTPUTS
            if (~retry & ~repeated_access & ~(biu_cyc_i & biu_stb_i) & aborted) begin
                // Keep outputs if abort and no new request
            end else if (biu_cyc_i & biu_stb_i & ~retry & ~repeated_access) begin
                wb_adr_o <= biu_adr_i;
                wb_dat_o <= biu_dat_i;
                wb_sel_o <= biu_sel_i;
                wb_we_o <= biu_we_i;
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
`ifdef OR1200_WB_CAB
                wb_cab_o <= biu_cab_i;
`endif
`ifdef OR1200_WB_B3
                if (biu_cab_i) begin
                    wb_cti_o <= 3'b010; // incrementing burst
                    wb_bte_o <= 2'b01; // 4-beat wrap
                end else begin
                    wb_cti_o <= 3'b000; // classic cycle
                    wb_bte_o <= 2'b00;
                end
`endif
            end else if (wb_ack_i & biu_cab_i & ~burst_last) begin
                // Continue burst: update address, keep cyc/stb, decrement burst_len
                wb_adr_o <= wb_adr_o + 4; // increment by 4 for 32-bit bus
                // burst_len decrement handled separately
                // Keep wb_cyc_o and wb_stb_o asserted
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
`ifdef OR1200_WB_CAB
                wb_cab_o <= 1'b1;
`endif
`ifdef OR1200_WB_B3
                wb_cti_o <= 3'b010; // continue burst
                wb_bte_o <= 2'b01;
`endif
            end else if (wb_ack_i | wb_err_i) begin
                // End cycle on ack or err (including abort termination)
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
`ifdef OR1200_WB_CAB
                wb_cab_o <= 1'b0;
`endif
`ifdef OR1200_WB_B3
                wb_cti_o <= 3'b111; // end of burst
                wb_bte_o <= 2'b00;
`endif
            end else if (aborted & ~wb_ack_i & ~wb_err_i) begin
                // Keep cyc/stb active while aborted and no response
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
            end
`else // non-registered outputs
            // Combinational outputs: update as biu_* inputs change
            // But wb_cyc_o, wb_stb_o might be affected by retry/abort/repeated? Spec says not for stb in non-registered mode.
            wb_adr_o <= biu_adr_i;
            wb_dat_o <= biu_dat_i;
            wb_sel_o <= biu_sel_i;
            wb_we_o <= biu_cyc_i & biu_stb_i & biu_we_i;
            wb_stb_o <= biu_cyc_i & biu_stb_i; // never masked by retry/abort/repeated
`ifdef OR1200_NO_BURSTS
            wb_cyc_o <= biu_cyc_i & biu_stb_i & ~retry;
`else
            wb_cyc_o <= biu_cyc_i & biu_stb_i & ~retry & ~repeated_access;
`endif
`ifdef OR1200_WB_CAB
            wb_cab_o <= biu_cab_i;
`endif
`endif
            // Previous complete state
            if (wb_ack_i & biu_cyc_i & biu_stb_i) begin
                previous_complete <= 1'b1;
            end else if ((biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~aborted & ~wb_stb_o) begin
                previous_complete <= 1'b0;
            end
            // Data save on ack
            if (wb_ack_i) begin
                wb_dat_r <= wb_dat_i;
            end
            // Abort register
            if (aborted) begin
                aborted_r <= 1'b1;
            end else if (wb_ack_i | wb_err_i) begin
                aborted_r <= 1'b0;
            end
            // Retry counter
`ifdef OR1200_WB_RETRY
            if (wb_rty_i) begin
                retry_cntr <= 8'd255; // some initial value; could be parameter
            end else if (retry) begin
                retry_cntr <= retry_cntr - 1;
            end
`else
            retry_cntr <= 8'b0;
`endif
            // Burst length counter
`ifdef OR1200_WB_B3
            if (biu_cyc_i & biu_stb_i & biu_cab_i) begin
                burst_len <= 2'd3; // 4 beats total (0..3)
            end else if (wb_ack_i & biu_cab_i & ~burst_last) begin
                burst_len <= burst_len - 1;
            end else if (wb_ack_i | wb_err_i) begin
                burst_len <= 2'b0;
            end
`endif
        end
    end

    // RISC clock domain (clk, rst)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_div <= 2'b0;
            repeated_access_ack <= 1'b0;
        end else begin
            // valid_div counter increments on clk
            if (clmode == 2'b01) begin // half speed
                valid_div <= valid_div + 1;
            end else if (clmode == 2'b11) begin // quarter speed
                valid_div <= valid_div + 1;
            end else begin
                valid_div <= 2'b0; // same speed, no division
            end
            // repeated_access_ack pulse
            if (repeated_access & biu_cyc_i & biu_stb_i) begin
                repeated_access_ack <= 1'b1;
            end else begin
                repeated_access_ack <= 1'b0;
            end
        end
    end

    // Combinational signals
    assign same_addr = (wb_adr_o == biu_adr_i);
    assign repeated_access = previous_complete & same_addr;

    // Aborted condition
`ifdef OR1200_REGISTERED_OUTPUTS
    assign aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~wb_err_i;
`else
    assign aborted = 1'b0; // not defined for non-registered? Spec says logic keeps already-issued transaction active; but since stb is combinational, aborted may not be meaningful. We'll set to 0.
`endif

    // Retry active
`ifdef OR1200_WB_RETRY
    assign retry = (retry_cntr != 8'b0);
`else
    assign retry = 1'b0;
`endif

    // Burst last
`ifdef OR1200_WB_B3
    assign burst_last = (burst_len == 2'b0);
`else
    assign burst_last = 1'b1;
`endif

    // Input return path
`ifdef OR1200_REGISTERED_INPUTS
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            biu_dat_o <= 32'b0;
            long_ack_o <= 1'b0;
            long_err_o <= 1'b0;
        end else begin
            if (wb_ack_i & ~aborted_r) begin
                biu_dat_o <= wb_dat_i;
                long_ack_o <= 1'b1;
            end else begin
                long_ack_o <= 1'b0;
            end
            if (wb_err_i & ~aborted_r) begin
                long_err_o <= 1'b1;
            end else begin
                long_err_o <= 1'b0;
            end
        end
    end
`else
    always @* begin
        if (repeated_access_ack) begin
            biu_dat_o = wb_dat_r;
        end else begin
            biu_dat_o = wb_dat_i;
        end
        // long_ack_o, long_err_o are combinational
        long_ack_o = wb_ack_i & ~aborted_r;
        long_err_o = wb_err_i & ~aborted_r;
    end
`endif

    // biu_ack_o generation
    reg biu_ack_int;
    always @* begin
        biu_ack_int = (repeated_access_ack | long_ack_o) & ~aborted_r;
        // Phase qualification with valid_div and clmode
`ifdef OR1200_CLKDIV_2_SUPPORTED
        if (clmode == 2'b01) begin
            biu_ack_int = biu_ack_int & (valid_div == 2'b0);
        end
`endif
`ifdef OR1200_CLKDIV_4_SUPPORTED
        if (clmode == 2'b11) begin
            biu_ack_int = biu_ack_int & (valid_div == 2'b0);
        end
`endif
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            biu_ack_o <= 1'b0;
        end else begin
            biu_ack_o <= biu_ack_int;
        end
    end

    // biu_err_o generation
    reg biu_err_int;
    always @* begin
        biu_err_int = long_err_o & ~aborted_r;
`ifdef OR1200_CLKDIV_2_SUPPORTED
        if (clmode == 2'b01) begin
            biu_err_int = biu_err_int & (valid_div == 2'b0);
        end
`endif
`ifdef OR1200_CLKDIV_4_SUPPORTED
        if (clmode == 2'b11) begin
            biu_err_int = biu_err_int & (valid_div == 2'b0);
        end
`endif
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            biu_err_o <= 1'b0;
        end else begin
            biu_err_o <= biu_err_int;
        end
    end

endmodule

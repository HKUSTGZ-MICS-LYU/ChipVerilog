`include "timescale.v"
`include "or1200_defines.v"

module or1200_iwb_biu(
    clk, rst, clmode,
    wb_clk_i, wb_rst_i,
    wb_ack_i, wb_err_i, wb_rty_i, wb_dat_i,
    wb_cyc_o, wb_adr_o, wb_stb_o, wb_we_o, wb_sel_o, wb_dat_o,
`ifdef OR1200_WB_CAB
    wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    wb_cti_o, wb_bte_o,
`endif
    biu_dat_i, biu_adr_i, biu_cyc_i, biu_stb_i,
    biu_we_i, biu_sel_i, biu_cab_i,
    biu_dat_o, biu_ack_o, biu_err_o
);

input         clk, rst;
input  [1:0]  clmode;
input         wb_clk_i, wb_rst_i;
input         wb_ack_i, wb_err_i, wb_rty_i;
input  [31:0] wb_dat_i;
output        wb_cyc_o;
output [31:0] wb_adr_o;
output        wb_stb_o;
output        wb_we_o;
output [3:0]  wb_sel_o;
output [31:0] wb_dat_o;
`ifdef OR1200_WB_CAB
output        wb_cab_o;
`endif
`ifdef OR1200_WB_B3
output [2:0]  wb_cti_o;
output [1:0]  wb_bte_o;
`endif
input  [31:0] biu_dat_i;
input  [31:0] biu_adr_i;
input         biu_cyc_i, biu_stb_i, biu_we_i;
input  [3:0]  biu_sel_i;
input         biu_cab_i;
output [31:0] biu_dat_o;
output        biu_ack_o;
output        biu_err_o;

// RISC-domain registers
reg [1:0]  valid_div;
reg        repeated_access_ack;

// WB-domain registers
reg [31:0] wb_adr_r;
reg        wb_cyc_r;
reg        wb_stb_r;
reg        wb_we_r;
reg [3:0]  wb_sel_r;
reg [31:0] wb_dat_r_out;
`ifdef OR1200_WB_CAB
reg        wb_cab_r;
`endif
reg [31:0] wb_dat_r;
reg        previous_complete;
reg        aborted_r;
`ifdef OR1200_WB_RETRY
reg [7:0]  retry_cntr;
wire       retry = |retry_cntr;
`else
wire       retry = 1'b0;
`endif
`ifdef OR1200_WB_B3
reg [1:0]  burst_len;
reg [2:0]  wb_cti_r;
`endif

// Repeated access detection
wire same_addr = (wb_adr_o == biu_adr_i);
wire repeated_access = same_addr & previous_complete;

// Graceful abort
wire aborted = wb_stb_o & !(biu_cyc_i & biu_stb_i) & !wb_ack_i & !wb_err_i;

`ifdef OR1200_REGISTERED_INPUTS
// Registered input path (WB domain)
reg [31:0] biu_dat_reg;
reg        long_ack_r;
reg        long_err_r;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        biu_dat_reg <= 32'h0;
        long_ack_r  <= 1'b0;
        long_err_r  <= 1'b0;
    end else begin
        if (wb_ack_i) biu_dat_reg <= wb_dat_i;
        long_ack_r <= wb_ack_i & ~aborted_r;
        long_err_r <= wb_err_i & ~aborted_r;
    end
end

wire long_ack_o = long_ack_r;
wire long_err_o = long_err_r;
assign biu_dat_o = repeated_access_ack ? wb_dat_r : biu_dat_reg;

`else
// Non-registered input path
wire long_ack_o = wb_ack_i;
wire long_err_o = wb_err_i & ~aborted_r;
assign biu_dat_o = repeated_access_ack ? wb_dat_r : wb_dat_i;
`endif

// valid_div: RISC-domain phase counter for clock-ratio modes
always @(posedge clk or posedge rst) begin
    if (rst)
        valid_div <= 2'b00;
    else
        valid_div <= valid_div + 2'b01;
end

// repeated_access_ack: RISC-domain fast completion
always @(posedge clk or posedge rst) begin
    if (rst)
        repeated_access_ack <= 1'b0;
    else
        repeated_access_ack <= repeated_access & biu_cyc_i & biu_stb_i & ~repeated_access_ack;
end

// biu_ack_o generation with optional clmode phase qualification
wire raw_ack = (repeated_access_ack | long_ack_o) & ~aborted_r;
`ifdef OR1200_CLKDIV_2_SUPPORTED
`ifdef OR1200_CLKDIV_4_SUPPORTED
assign biu_ack_o = raw_ack & (
    (clmode == 2'b00) ? 1'b1 :
    (clmode == 2'b01) ? valid_div[0] :
    (clmode == 2'b11) ? (valid_div == 2'b11) :
    1'b1);
`else
assign biu_ack_o = raw_ack & (
    (clmode == 2'b00) ? 1'b1 :
    (clmode == 2'b01) ? valid_div[0] :
    1'b1);
`endif
`else
assign biu_ack_o = raw_ack;
`endif

// biu_err_o generation with optional clmode phase qualification
wire raw_err = long_err_o;
`ifdef OR1200_CLKDIV_2_SUPPORTED
`ifdef OR1200_CLKDIV_4_SUPPORTED
assign biu_err_o = raw_err & (
    (clmode == 2'b00) ? 1'b1 :
    (clmode == 2'b01) ? valid_div[0] :
    (clmode == 2'b11) ? (valid_div == 2'b11) :
    1'b1);
`else
assign biu_err_o = raw_err & (
    (clmode == 2'b00) ? 1'b1 :
    (clmode == 2'b01) ? valid_div[0] :
    1'b1);
`endif
`else
assign biu_err_o = raw_err;
`endif

// WB-domain sequential state
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        previous_complete <= 1'b1;
        aborted_r         <= 1'b0;
        wb_dat_r          <= 32'h0;
`ifdef OR1200_WB_RETRY
        retry_cntr        <= 8'h0;
`endif
`ifdef OR1200_WB_B3
        burst_len         <= 2'b0;
        wb_cti_r          <= 3'b000;
`endif
    end else begin
        // Save previous read data
        if (wb_ack_i) wb_dat_r <= wb_dat_i;

        // previous_complete
        if (wb_ack_i & biu_cyc_i & biu_stb_i)
            previous_complete <= 1'b1;
        else if (biu_cyc_i & biu_stb_i & !wb_ack_i & !aborted_r & !wb_stb_o)
            previous_complete <= 1'b0;

        // aborted_r
        if (aborted)
            aborted_r <= 1'b1;
        else if (wb_ack_i | wb_err_i)
            aborted_r <= 1'b0;

`ifdef OR1200_WB_RETRY
        // Retry counter
        if (wb_rty_i & !retry)
            retry_cntr <= `OR1200_WB_RETRY;
        else if (|retry_cntr)
            retry_cntr <= retry_cntr - 8'd1;
`endif

`ifdef OR1200_WB_B3
        // Burst counter
        if (wb_ack_i & biu_cab_i & |burst_len)
            burst_len <= burst_len - 2'd1;
        else if (biu_cyc_i & biu_stb_i & biu_cab_i & !wb_stb_r)
            burst_len <= 2'b11;
`endif
    end
end

`ifdef OR1200_REGISTERED_OUTPUTS

// Registered Wishbone outputs
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_adr_r    <= 32'h0;
        wb_cyc_r    <= 1'b0;
        wb_stb_r    <= 1'b0;
        wb_we_r     <= 1'b0;
        wb_sel_r    <= 4'h0;
        wb_dat_r_out<= 32'h0;
`ifdef OR1200_WB_CAB
        wb_cab_r    <= 1'b0;
`endif
`ifdef OR1200_WB_B3
        wb_cti_r    <= 3'b000;
`endif
    end else begin
        // Normal request: not repeated_access, not retry, not aborted
        if (biu_cyc_i & biu_stb_i & !repeated_access & !retry & !aborted_r) begin
            wb_adr_r    <= biu_adr_i;
            wb_cyc_r    <= 1'b1;
            wb_stb_r    <= 1'b1;
            wb_we_r     <= biu_we_i;
            wb_sel_r    <= biu_sel_i;
            wb_dat_r_out<= biu_dat_i;
`ifdef OR1200_WB_CAB
            wb_cab_r    <= biu_cab_i;
`endif
        end else if (!biu_cyc_i & !aborted_r) begin
            wb_cyc_r    <= 1'b0;
            wb_stb_r    <= 1'b0;
`ifdef OR1200_WB_CAB
            wb_cab_r    <= 1'b0;
`endif
        end else if (wb_ack_i | wb_err_i) begin
            // Terminate if no new request after completion
            if (!biu_cyc_i | !biu_stb_i | repeated_access) begin
                wb_cyc_r <= 1'b0;
                wb_stb_r <= 1'b0;
            end
        end

`ifdef OR1200_WB_B3
        // CTI generation
        if (biu_cab_i) begin
            if (burst_len == 2'b01 && wb_ack_i)
                wb_cti_r <= 3'b111; // end of burst
            else if (wb_stb_r)
                wb_cti_r <= 3'b010; // incrementing burst
            else
                wb_cti_r <= 3'b010;
        end else
            wb_cti_r <= 3'b000; // classic cycle
`endif
    end
end

assign wb_adr_o = wb_adr_r;
assign wb_cyc_o = wb_cyc_r;
assign wb_stb_o = wb_stb_r;
assign wb_we_o  = wb_we_r;
assign wb_sel_o = wb_sel_r;
assign wb_dat_o = wb_dat_r_out;
`ifdef OR1200_WB_CAB
assign wb_cab_o = wb_cab_r;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = wb_cti_r;
assign wb_bte_o = 2'b01;
`endif

`else // Non-registered outputs

assign wb_adr_o = biu_adr_i;
assign wb_dat_o = biu_dat_i;
assign wb_sel_o = biu_sel_i;
assign wb_we_o  = biu_cyc_i & biu_stb_i & biu_we_i;
assign wb_stb_o = biu_cyc_i & biu_stb_i;
`ifdef OR1200_NO_BURSTS
assign wb_cyc_o = biu_cyc_i;
`else
assign wb_cyc_o = biu_cyc_i | (wb_stb_o & !wb_ack_i);
`endif
`ifdef OR1200_WB_CAB
assign wb_cab_o = biu_cab_i;
`endif

`endif // OR1200_REGISTERED_OUTPUTS

endmodule
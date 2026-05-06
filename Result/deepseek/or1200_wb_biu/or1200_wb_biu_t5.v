`timescale 1ns / 1ps

module or1200_wb_biu (
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
    output biu_ack_o,
    output biu_err_o
);

// ---------- Internal Wires and Registers ----------
reg [1:0] valid_div; // in clk domain

// In wb_clk_i domain:
reg aborted_r;
`ifdef OR1200_WB_RETRY
    reg [2:0] retry_cntr;
    wire retry;
`endif
`ifdef OR1200_WB_B3
    reg [1:0] burst_len;
`endif

// Signals for internal generation:
reg long_ack_o, long_err_o;
wire aborted;

// ---------- valid_div in clk domain ----------
always @(posedge clk or posedge rst) begin
    if (rst)
        valid_div <= 2'b00;
    else
        valid_div <= valid_div + 1'b1;
end

// ---------- Wishbone side logic (wb_clk_i domain) ----------
// aborted combinational
assign aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~wb_err_i;

// aborted_r register
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        aborted_r <= 1'b0;
    else if (wb_ack_i || wb_err_i)
        aborted_r <= 1'b0;
    else if (aborted)
        aborted_r <= 1'b1;
end

`ifdef OR1200_WB_RETRY
// retry combinational
assign retry = wb_rty_i || (|retry_cntr);

// retry counter
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        retry_cntr <= 3'b000;
    else if (wb_rty_i)
        retry_cntr <= 3'b111;
    else if (|retry_cntr)
        retry_cntr <= retry_cntr - 1'b1;
end
`endif

`ifdef OR1200_WB_B3
// burst_len counter
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        burst_len <= 2'b11;
    else if (~biu_cab_i)
        burst_len <= 2'b11;
    else if (biu_cab_i & |burst_len & wb_ack_i)
        burst_len <= burst_len - 1'b1;
end

// wb_bte_o fixed to 2'b01
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_bte_o <= 2'b00;
    else
        wb_bte_o <= 2'b01;
end

// wb_cti_o depends on registered_outputs and burst configuration
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_cti_o <= 3'b000;
    else begin
`ifdef OR1200_NO_BURSTS
        wb_cti_o <= 3'b111;
`else
        if (biu_cab_i & burst_len[1])
            wb_cti_o <= 3'b010; // incrementing burst
        else if (biu_cab_i & wb_ack_i)
            wb_cti_o <= 3'b111; // end of burst
        else
            wb_cti_o <= 3'b000; // classic
`endif
    end
end
`else
// Not supported, but keep as constant for completeness
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_cti_o <= 3'b000;
    else
        wb_cti_o <= 3'b000; // Unsupported, classic
end
`endif
`endif // OR1200_WB_B3

`ifdef OR1200_WB_CAB
// wb_cab_o
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_cab_o <= 1'b0;
    else
        wb_cab_o <= biu_cab_i;
end
`else
assign wb_cab_o = biu_cab_i;
`endif
`endif

// ---------- Registered Outputs ----------
`ifdef OR1200_REGISTERED_OUTPUTS

// wb_adr_o
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_adr_o <= 32'h0;
    else if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted & ~(wb_stb_o & ~wb_ack_i & ~aborted))
        wb_adr_o <= biu_adr_i;
end

// wb_dat_o
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_dat_o <= 32'h0;
    else if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted)
        wb_dat_o <= biu_dat_i;
end

// wb_sel_o
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_sel_o <= 4'h0;
    else
        wb_sel_o <= biu_sel_i;
end

// wb_cyc_o
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_cyc_o <= 1'b0;
    else if (aborted & ~wb_ack_i)
        wb_cyc_o <= 1'b1;
`ifdef OR1200_NO_BURSTS
    else if (biu_cyc_i & ~wb_ack_i & ~retry)
        wb_cyc_o <= 1'b1;
`else
    else if (biu_cyc_i & ~wb_ack_i & ~retry)
        wb_cyc_o <= 1'b1;
    else if (biu_cab_i & ~wb_ack_i & ~retry)
        wb_cyc_o <= 1'b1;
`endif
    else
        wb_cyc_o <= 1'b0;
end

// wb_stb_o
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_stb_o <= 1'b0;
    else if (aborted & ~wb_ack_i)
        wb_stb_o <= 1'b1;
    else if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~retry)
        wb_stb_o <= 1'b1;
    else
        wb_stb_o <= 1'b0;
end

// wb_we_o
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_we_o <= 1'b0;
    else if (aborted)
        wb_we_o <= wb_we_o;
    else if (biu_cyc_i & biu_stb_i & biu_we_i & ~wb_ack_i & ~retry)
        wb_we_o <= 1'b1;
    else if (biu_cyc_i & biu_stb_i & ~biu_we_i & ~wb_ack_i & ~retry)
        wb_we_o <= 1'b0;
end

`else // Non-registered outputs (combinational)

assign wb_adr_o = biu_adr_i;
assign wb_dat_o = biu_dat_i;
assign wb_sel_o = biu_sel_i;
assign wb_we_o = biu_cyc_i & biu_stb_i & biu_we_i;
assign wb_stb_o = biu_cyc_i & biu_stb_i;

`ifdef OR1200_NO_BURSTS
assign wb_cyc_o = biu_cyc_i & ~retry;
`else
assign wb_cyc_o = biu_cyc_i | (biu_cab_i & ~retry);
`endif

`endif // OR1200_REGISTERED_OUTPUTS

// ---------- Input Path ----------
`ifdef OR1200_REGISTERED_INPUTS
// Registered input path
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        biu_dat_o <= 32'h0;
    else if (wb_ack_i)
        biu_dat_o <= wb_dat_i;
end

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
// Combinational input path
assign biu_dat_o = wb_dat_i;
assign long_ack_o = wb_ack_i & ~aborted_r;
assign long_err_o = wb_err_i & ~aborted_r;
`endif

// ---------- Generate biu_ack_o and biu_err_o with valid_div gating ----------
reg biu_ack_o, biu_err_o;

always @* begin
    biu_ack_o = long_ack_o;
    biu_err_o = long_err_o;

`ifdef OR1200_CLKDIV_2_SUPPORTED
    if (clmode == 2'b01) begin // WB = RISC/2
        biu_ack_o = long_ack_o & (valid_div[0] == 1'b0); // use LSB for division by 2
        biu_err_o = long_err_o & (valid_div[0] == 1'b0);
    end
`endif

`ifdef OR1200_CLKDIV_4_SUPPORTED
    if (clmode == 2'b11) begin // WB = RISC/4
        biu_ack_o = long_ack_o & (valid_div == 2'b00); // use both bits
        biu_err_o = long_err_o & (valid_div == 2'b00);
    end
`endif
end

endmodule

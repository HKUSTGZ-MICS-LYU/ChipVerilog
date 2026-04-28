`include "timescale.v"
`include "or1200_defines.v"

module or1200_wb_biu(
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

parameter dw = `OR1200_OPERAND_WIDTH;
parameter aw = `OR1200_OPERAND_WIDTH;

input         clk, rst;
input  [1:0]  clmode;
input         wb_clk_i, wb_rst_i;
input         wb_ack_i, wb_err_i, wb_rty_i;
input  [31:0] wb_dat_i;
output        wb_cyc_o;
output [31:0] wb_adr_o;
output        wb_stb_o, wb_we_o;
output [3:0]  wb_sel_o;
output [31:0] wb_dat_o;
`ifdef OR1200_WB_CAB
output        wb_cab_o;
`endif
`ifdef OR1200_WB_B3
output [2:0]  wb_cti_o;
output [1:0]  wb_bte_o;
`endif
input  [31:0] biu_dat_i, biu_adr_i;
input         biu_cyc_i, biu_stb_i, biu_we_i, biu_cab_i;
input  [3:0]  biu_sel_i;
output [31:0] biu_dat_o;
output        biu_ack_o, biu_err_o;

// RISC-domain: valid_div counter
reg [1:0] valid_div;
always @(posedge clk or posedge rst) begin
    if (rst) valid_div <= 2'b00;
    else     valid_div <= valid_div + 2'b01;
end

// WB-domain state
reg         aborted_r;
`ifdef OR1200_WB_RETRY
reg [`OR1200_WB_RETRY-1:0] retry_cntr;
wire retry = wb_rty_i | (|retry_cntr);
`else
wire retry = 1'b0;
`endif

`ifdef OR1200_WB_B3
reg [1:0] burst_len;
`endif

// Abort detection
wire aborted = wb_stb_o & !(biu_cyc_i & biu_stb_i) & !wb_ack_i & !wb_err_i;

// WB-domain sequential state
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        aborted_r <= 1'b0;
`ifdef OR1200_WB_RETRY
        retry_cntr <= {`OR1200_WB_RETRY{1'b0}};
`endif
`ifdef OR1200_WB_B3
        burst_len <= 2'b11;
`endif
    end else begin
        // aborted_r
        if (wb_ack_i | wb_err_i)
            aborted_r <= 1'b0;
        else if (aborted)
            aborted_r <= 1'b1;

`ifdef OR1200_WB_RETRY
        // retry counter
        if (wb_rty_i)
            retry_cntr <= {`OR1200_WB_RETRY{1'b1}};
        else if (|retry_cntr)
            retry_cntr <= retry_cntr - 1'b1;
`endif

`ifdef OR1200_WB_B3
        // burst_len
        if (!biu_cab_i)
            burst_len <= 2'b11;
        else if (biu_cab_i & (|burst_len) & wb_ack_i)
            burst_len <= burst_len - 2'b01;
`endif
    end
end

`ifdef OR1200_REGISTERED_OUTPUTS

reg [31:0] wb_adr_r, wb_dat_r;
reg        wb_cyc_r, wb_stb_r, wb_we_r;
reg [3:0]  wb_sel_r;
`ifdef OR1200_WB_CAB
reg        wb_cab_r;
`endif
`ifdef OR1200_WB_B3
reg [2:0]  wb_cti_r;
`endif

assign wb_adr_o = wb_adr_r;
assign wb_dat_o = wb_dat_r;
assign wb_cyc_o = wb_cyc_r;
assign wb_stb_o = wb_stb_r;
assign wb_we_o  = wb_we_r;
assign wb_sel_o = wb_sel_r;
`ifdef OR1200_WB_CAB
assign wb_cab_o = wb_cab_r;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = wb_cti_r;
assign wb_bte_o = 2'b01;
`endif

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_adr_r <= 32'h0; wb_dat_r <= 32'h0;
        wb_cyc_r <= 1'b0;  wb_stb_r <= 1'b0;
        wb_we_r  <= 1'b0;  wb_sel_r <= 4'h0;
`ifdef OR1200_WB_CAB
        wb_cab_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
        wb_cti_r <= 3'b000;
`endif
    end else begin
        // wb_sel always loads
        wb_sel_r <= biu_sel_i;

        // Normal request: new BIU request, no ack, no abort, no retry
        if (biu_cyc_i & biu_stb_i & !wb_ack_i & !aborted_r & !retry) begin
            wb_adr_r <= biu_adr_i;
            wb_we_r  <= biu_we_i;
`ifdef OR1200_WB_CAB
            wb_cab_r <= biu_cab_i;
`endif
        end else if (aborted_r & !wb_ack_i) begin
            // hold during abort
            wb_we_r  <= wb_we_r;
`ifdef OR1200_WB_CAB
            wb_cab_r <= wb_cab_r;
`endif
        end

        // wb_dat: update on new request, no ack, no abort
        if (biu_cyc_i & biu_stb_i & !wb_ack_i & !aborted_r)
            wb_dat_r <= biu_dat_i;

        // wb_cyc
`ifdef OR1200_NO_BURSTS
        if (biu_cyc_i & !wb_ack_i & !retry)
            wb_cyc_r <= 1'b1;
        else if (aborted_r & !wb_ack_i)
            wb_cyc_r <= 1'b1;
        else
            wb_cyc_r <= 1'b0;
`else
        if ((biu_cyc_i | biu_cab_i) & !wb_ack_i & !retry)
            wb_cyc_r <= 1'b1;
        else if (aborted_r & !wb_ack_i)
            wb_cyc_r <= 1'b1;
        else
            wb_cyc_r <= 1'b0;
`endif

        // wb_stb
        if (biu_cyc_i & biu_stb_i & !wb_ack_i & !retry)
            wb_stb_r <= 1'b1;
        else if (aborted_r & !wb_ack_i)
            wb_stb_r <= 1'b1;
        else
            wb_stb_r <= 1'b0;

`ifdef OR1200_WB_B3
        // wb_cti
        if (wb_rst_i)
            wb_cti_r <= 3'b000;
        else begin
`ifdef OR1200_NO_BURSTS
            wb_cti_r <= 3'b111;
`else
            if (biu_cab_i & burst_len[1])
                wb_cti_r <= 3'b010;
            else if (biu_cab_i)
                wb_cti_r <= 3'b111;
            else
                wb_cti_r <= 3'b000;
`endif
        end
`endif
    end
end

`else // Non-registered outputs

assign wb_adr_o = biu_adr_i;
assign wb_dat_o = biu_dat_i;
assign wb_sel_o = biu_sel_i;
assign wb_we_o  = biu_cyc_i & biu_stb_i & biu_we_i;
assign wb_stb_o = biu_cyc_i & biu_stb_i;
`ifdef OR1200_NO_BURSTS
assign wb_cyc_o = biu_cyc_i & ~retry;
`else
assign wb_cyc_o = biu_cyc_i | (biu_cab_i & ~retry);
`endif
`ifdef OR1200_WB_CAB
assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
// Unsupported !!!
assign wb_cti_o = 3'b000;
assign wb_bte_o = 2'b01;
`endif

`endif // OR1200_REGISTERED_OUTPUTS

// Input data path
`ifdef OR1200_REGISTERED_INPUTS
reg [31:0] biu_dat_r;
reg        long_ack_r, long_err_r;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        biu_dat_r  <= 32'h0;
        long_ack_r <= 1'b0;
        long_err_r <= 1'b0;
    end else begin
        if (wb_ack_i) biu_dat_r <= wb_dat_i;
        long_ack_r <= wb_ack_i & ~aborted;
        long_err_r <= wb_err_i & ~aborted;
    end
end

assign biu_dat_o  = biu_dat_r;
wire   long_ack_o = long_ack_r;
wire   long_err_o = long_err_r;

`else // Non-registered inputs

assign biu_dat_o  = wb_dat_i;
wire   long_ack_o = wb_ack_i & ~aborted_r;
wire   long_err_o = wb_err_i & ~aborted_r;

`endif

// biu_ack_o / biu_err_o with optional clock-division phase gating
`ifdef OR1200_CLKDIV_2_SUPPORTED
`ifdef OR1200_CLKDIV_4_SUPPORTED
assign biu_ack_o = long_ack_o &
    ((clmode == 2'b00) ? 1'b1 :
     (clmode == 2'b01) ? valid_div[0] :
     (clmode == 2'b11) ? (valid_div == 2'b11) : 1'b1);
assign biu_err_o = long_err_o &
    ((clmode == 2'b00) ? 1'b1 :
     (clmode == 2'b01) ? valid_div[0] :
     (clmode == 2'b11) ? (valid_div == 2'b11) : 1'b1);
`else
assign biu_ack_o = long_ack_o &
    ((clmode == 2'b01) ? valid_div[0] : 1'b1);
assign biu_err_o = long_err_o &
    ((clmode == 2'b01) ? valid_div[0] : 1'b1);
`endif
`else
assign biu_ack_o = long_ack_o;
assign biu_err_o = long_err_o;
`endif

endmodule
module or1200_wb_biu(
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

wire biu_req;
wire retry;
wire wb_cyc_c;
wire [31:0] wb_adr_c;
wire wb_stb_c;
wire wb_we_c;
wire [3:0] wb_sel_c;
wire [31:0] wb_dat_c;
wire aborted;
wire long_ack_o;
wire long_err_o;
wire phase_eq;
wire phase_div2;
wire phase_div4;
wire phase_sel;

reg [1:0] valid_div;
reg aborted_r;

`ifdef OR1200_REGISTERED_OUTPUTS
reg wb_cyc_r;
reg [31:0] wb_adr_r;
reg wb_stb_r;
reg wb_we_r;
reg [3:0] wb_sel_r;
reg [31:0] wb_dat_r;
`ifdef OR1200_WB_CAB
reg wb_cab_r;
`endif
`ifdef OR1200_WB_B3
reg [2:0] wb_cti_r;
reg [1:0] burst_len;
`endif
`endif

`ifdef OR1200_REGISTERED_INPUTS
reg [31:0] biu_dat_r;
reg long_ack_r;
reg long_err_r;
`endif

`ifdef OR1200_WB_RETRY
reg [2:0] retry_cntr;
assign retry = wb_rty_i | (|retry_cntr);
`else
assign retry = 1'b0;
`endif

assign biu_req  = biu_cyc_i & biu_stb_i;
assign wb_adr_c = biu_adr_i;
assign wb_dat_c = biu_dat_i;
assign wb_sel_c = biu_sel_i;
assign wb_we_c  = biu_cyc_i & biu_stb_i & biu_we_i;
assign wb_stb_c = biu_cyc_i & biu_stb_i;
`ifdef OR1200_NO_BURSTS
assign wb_cyc_c = biu_cyc_i & ~retry;
`else
assign wb_cyc_c = biu_cyc_i | (biu_cab_i & ~retry);
`endif

`ifdef OR1200_REGISTERED_OUTPUTS
assign wb_cyc_o = wb_cyc_r;
assign wb_adr_o = wb_adr_r;
assign wb_stb_o = wb_stb_r;
assign wb_we_o  = wb_we_r;
assign wb_sel_o = wb_sel_r;
assign wb_dat_o = wb_dat_r;
`ifdef OR1200_WB_CAB
assign wb_cab_o = wb_cab_r;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = wb_cti_r;
assign wb_bte_o = 2'b01;
`endif
`else
assign wb_cyc_o = wb_cyc_c;
assign wb_adr_o = wb_adr_c;
assign wb_stb_o = wb_stb_c;
assign wb_we_o  = wb_we_c;
assign wb_sel_o = wb_sel_c;
assign wb_dat_o = wb_dat_c;
`ifdef OR1200_WB_CAB
assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = 3'b000;
assign wb_bte_o = 2'b01;
`endif
`endif

assign aborted = wb_stb_o & ~biu_req & ~wb_ack_i & ~wb_err_i;

always @(posedge clk or posedge rst)
begin
    if (rst)
        valid_div <= 2'b00;
    else
        valid_div <= valid_div + 2'b01;
end

always @(posedge wb_clk_i or posedge wb_rst_i)
begin
    if (wb_rst_i)
        aborted_r <= 1'b0;
    else if (wb_ack_i | wb_err_i)
        aborted_r <= 1'b0;
    else if (aborted)
        aborted_r <= 1'b1;
end

`ifdef OR1200_WB_RETRY
always @(posedge wb_clk_i or posedge wb_rst_i)
begin
    if (wb_rst_i)
        retry_cntr <= 3'b000;
    else if (wb_rty_i)
        retry_cntr <= 3'b111;
    else if (|retry_cntr)
        retry_cntr <= retry_cntr - 3'b001;
end
`endif

`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
begin
    if (wb_rst_i) begin
        wb_cyc_r <= 1'b0;
        wb_adr_r <= 32'b0;
        wb_stb_r <= 1'b0;
        wb_we_r  <= 1'b0;
        wb_sel_r <= 4'b0;
        wb_dat_r <= 32'b0;
`ifdef OR1200_WB_CAB
        wb_cab_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
        wb_cti_r  <= 3'b000;
        burst_len <= 2'b00;
`endif
    end else begin
        wb_sel_r <= biu_sel_i;

`ifdef OR1200_NO_BURSTS
        if (aborted & ~wb_ack_i)
            wb_cyc_r <= 1'b1;
        else
            wb_cyc_r <= biu_cyc_i & ~wb_ack_i & ~retry;
`else
        if (aborted & ~wb_ack_i)
            wb_cyc_r <= 1'b1;
        else
            wb_cyc_r <= (biu_cyc_i | biu_cab_i) & ~wb_ack_i & ~retry;
`endif

        if (aborted & ~wb_ack_i)
            wb_stb_r <= 1'b1;
        else
            wb_stb_r <= biu_cyc_i & biu_stb_i & ~wb_ack_i & ~retry;

        if (aborted & ~wb_ack_i)
            wb_we_r <= wb_we_r;
        else
            wb_we_r <= biu_cyc_i & biu_stb_i & biu_we_i;

        if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted & ~(wb_stb_r & ~wb_ack_i))
            wb_adr_r <= biu_adr_i;

        if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted)
            wb_dat_r <= biu_dat_i;

`ifdef OR1200_WB_CAB
        wb_cab_r <= biu_cab_i;
`endif

`ifdef OR1200_WB_B3
        if (!biu_cab_i)
            burst_len <= 2'b11;
        else if ((burst_len != 2'b00) & wb_ack_i)
            burst_len <= burst_len - 2'b01;

`ifdef OR1200_NO_BURSTS
        wb_cti_r <= 3'b111;
`else
        if (biu_cab_i & burst_len[1])
            wb_cti_r <= 3'b010;
        else if (biu_cab_i & wb_ack_i)
            wb_cti_r <= 3'b111;
        else
            wb_cti_r <= 3'b000;
`endif
`endif
    end
end
`endif

`ifdef OR1200_REGISTERED_INPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
begin
    if (wb_rst_i) begin
        biu_dat_r  <= 32'b0;
        long_ack_r <= 1'b0;
        long_err_r <= 1'b0;
    end else begin
        if (wb_ack_i)
            biu_dat_r <= wb_dat_i;
        long_ack_r <= wb_ack_i & ~aborted;
        long_err_r <= wb_err_i & ~aborted;
    end
end

assign biu_dat_o  = biu_dat_r;
assign long_ack_o = long_ack_r;
assign long_err_o = long_err_r;
`else
assign biu_dat_o  = wb_dat_i;
assign long_ack_o = wb_ack_i & ~aborted_r;
assign long_err_o = wb_err_i & ~aborted_r;
`endif

assign phase_eq = (clmode == 2'b00);
`ifdef OR1200_CLKDIV_2_SUPPORTED
assign phase_div2 = (clmode == 2'b01) & (valid_div[0] == 1'b0);
`else
assign phase_div2 = 1'b0;
`endif
`ifdef OR1200_CLKDIV_4_SUPPORTED
assign phase_div4 = (clmode == 2'b11) & (valid_div == 2'b00);
`else
assign phase_div4 = 1'b0;
`endif
assign phase_sel = phase_eq | phase_div2 | phase_div4;

assign biu_ack_o = long_ack_o & phase_sel;
assign biu_err_o = long_err_o & phase_sel;

endmodule

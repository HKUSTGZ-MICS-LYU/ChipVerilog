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

localparam [31:0] ZERO32 = 32'h00000000;
`ifdef OR1200_WB_RETRY
localparam integer RETRY_WIDTH = 8;
`endif

wire biu_req;
wire retry;
wire aborted;
wire long_ack_o;
wire long_err_o;
wire ack_div2;
wire err_div2;
wire ack_div4;
wire err_div4;

reg [1:0] valid_div;
reg aborted_r;

assign biu_req = biu_cyc_i & biu_stb_i;

always @(posedge clk or posedge rst) begin
    if (rst)
        valid_div <= 2'b00;
    else
        valid_div <= valid_div + 2'b01;
end

`ifdef OR1200_WB_RETRY
reg [RETRY_WIDTH-1:0] retry_cntr;

assign retry = wb_rty_i | (retry_cntr != {RETRY_WIDTH{1'b0}});

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        retry_cntr <= {RETRY_WIDTH{1'b0}};
    else if (wb_rty_i)
        retry_cntr <= {RETRY_WIDTH{1'b1}};
    else if (retry_cntr != {RETRY_WIDTH{1'b0}})
        retry_cntr <= retry_cntr - {{(RETRY_WIDTH-1){1'b0}}, 1'b1};
end
`else
assign retry = 1'b0;
`endif

`ifdef OR1200_REGISTERED_OUTPUTS
reg wb_cyc_o_r;
reg [31:0] wb_adr_o_r;
reg wb_stb_o_r;
reg wb_we_o_r;
reg [3:0] wb_sel_o_r;
reg [31:0] wb_dat_o_r;
`ifdef OR1200_WB_CAB
reg wb_cab_o_r;
`endif

assign wb_cyc_o = wb_cyc_o_r;
assign wb_adr_o = wb_adr_o_r;
assign wb_stb_o = wb_stb_o_r;
assign wb_we_o = wb_we_o_r;
assign wb_sel_o = wb_sel_o_r;
assign wb_dat_o = wb_dat_o_r;
`ifdef OR1200_WB_CAB
assign wb_cab_o = wb_cab_o_r;
`endif

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_cyc_o_r <= 1'b0;
        wb_adr_o_r <= ZERO32;
        wb_stb_o_r <= 1'b0;
        wb_we_o_r <= 1'b0;
        wb_sel_o_r <= 4'b0000;
        wb_dat_o_r <= ZERO32;
`ifdef OR1200_WB_CAB
        wb_cab_o_r <= 1'b0;
`endif
    end else begin
`ifdef OR1200_NO_BURSTS
        wb_cyc_o_r <= (biu_cyc_i & ~wb_ack_i & ~retry) | (aborted & ~wb_ack_i);
`else
        wb_cyc_o_r <= ((biu_cyc_i | biu_cab_i) & ~wb_ack_i & ~retry) | (aborted & ~wb_ack_i);
`endif
        wb_stb_o_r <= (biu_req & ~wb_ack_i & ~retry) | (aborted & ~wb_ack_i);
        if (!aborted)
            wb_we_o_r <= biu_req & biu_we_i;
        else
            wb_we_o_r <= wb_we_o_r;
        wb_sel_o_r <= biu_sel_i;
        if (biu_req & ~wb_ack_i & ~aborted & ~wb_stb_o_r)
            wb_adr_o_r <= biu_adr_i;
        if (biu_req & ~wb_ack_i & ~aborted)
            wb_dat_o_r <= biu_dat_i;
`ifdef OR1200_WB_CAB
        wb_cab_o_r <= biu_cab_i;
`endif
    end
end
`else
assign wb_adr_o = biu_adr_i;
assign wb_dat_o = biu_dat_i;
assign wb_sel_o = biu_sel_i;
assign wb_we_o = biu_req & biu_we_i;
assign wb_stb_o = biu_req;
`ifdef OR1200_NO_BURSTS
assign wb_cyc_o = biu_cyc_i & ~retry;
`else
assign wb_cyc_o = biu_cyc_i | (biu_cab_i & ~retry);
`endif
`ifdef OR1200_WB_CAB
assign wb_cab_o = biu_cab_i;
`endif
`endif

assign aborted = wb_stb_o & ~biu_req & ~wb_ack_i & ~wb_err_i;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        aborted_r <= 1'b0;
    else if (wb_ack_i | wb_err_i)
        aborted_r <= 1'b0;
    else if (aborted)
        aborted_r <= 1'b1;
end

`ifdef OR1200_REGISTERED_INPUTS
reg [31:0] biu_dat_o_r;
reg long_ack_r;
reg long_err_r;

assign biu_dat_o = biu_dat_o_r;
assign long_ack_o = long_ack_r;
assign long_err_o = long_err_r;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        biu_dat_o_r <= ZERO32;
        long_ack_r <= 1'b0;
        long_err_r <= 1'b0;
    end else begin
        if (wb_ack_i)
            biu_dat_o_r <= wb_dat_i;
        long_ack_r <= wb_ack_i & ~aborted;
        long_err_r <= wb_err_i & ~aborted;
    end
end
`else
assign biu_dat_o = wb_dat_i;
assign long_ack_o = wb_ack_i & ~aborted_r;
assign long_err_o = wb_err_i & ~aborted_r;
`endif

`ifdef OR1200_CLKDIV_2_SUPPORTED
assign ack_div2 = long_ack_o & ~valid_div[0];
assign err_div2 = long_err_o & ~valid_div[0];
`else
assign ack_div2 = long_ack_o;
assign err_div2 = long_err_o;
`endif

`ifdef OR1200_CLKDIV_4_SUPPORTED
assign ack_div4 = long_ack_o & (valid_div == 2'b00);
assign err_div4 = long_err_o & (valid_div == 2'b00);
`else
assign ack_div4 = long_ack_o;
assign err_div4 = long_err_o;
`endif

assign biu_ack_o = (clmode == 2'b01) ? ack_div2 :
                   (clmode == 2'b11) ? ack_div4 :
                   long_ack_o;
assign biu_err_o = (clmode == 2'b01) ? err_div2 :
                   (clmode == 2'b11) ? err_div4 :
                   long_err_o;

`ifdef OR1200_WB_B3
assign wb_bte_o = 2'b01;
`ifdef OR1200_REGISTERED_OUTPUTS
reg [1:0] burst_len;
reg [2:0] wb_cti_o_r;

assign wb_cti_o = wb_cti_o_r;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        burst_len <= 2'b00;
    else if (!biu_cab_i)
        burst_len <= 2'b11;
    else if ((burst_len != 2'b00) && wb_ack_i)
        burst_len <= burst_len - 2'b01;
end

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_cti_o_r <= 3'b000;
    else begin
`ifdef OR1200_NO_BURSTS
        wb_cti_o_r <= 3'b111;
`else
        if (biu_cab_i && burst_len[1])
            wb_cti_o_r <= 3'b010;
        else if (biu_cab_i && wb_ack_i)
            wb_cti_o_r <= 3'b111;
        else
            wb_cti_o_r <= 3'b000;
`endif
    end
end
`else
assign wb_cti_o = 3'b000;
`endif
`endif

endmodule

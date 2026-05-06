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

reg [1:0] valid_div;
reg repeated_access_ack;
reg repeated_access_hit_d;
reg [31:0] wb_dat_r;
reg [31:0] last_addr_r;
reg previous_complete;
reg aborted_r;

`ifdef OR1200_WB_RETRY
reg [1:0] retry_cntr;
wire retry;
assign retry = |retry_cntr;
`else
wire retry;
assign retry = 1'b0;
`endif

`ifdef OR1200_WB_B3
reg [1:0] burst_len;
`endif

`ifdef OR1200_REGISTERED_OUTPUTS
reg wb_cyc_r;
reg [31:0] wb_adr_r;
reg wb_stb_r;
reg wb_we_r;
reg [3:0] wb_sel_r;
reg [31:0] wb_dat_out_r;
`ifdef OR1200_WB_CAB
reg wb_cab_r;
`endif
`ifdef OR1200_WB_B3
reg [2:0] wb_cti_r;
`endif
`endif

`ifdef OR1200_REGISTERED_INPUTS
reg [31:0] biu_dat_r_reg;
reg long_ack_r;
reg long_err_r;
wire long_ack_w;
wire long_err_w;
assign long_ack_w = long_ack_r;
assign long_err_w = long_err_r;
assign biu_dat_o = biu_dat_r_reg;
`else
wire long_ack_w;
wire long_err_w;
assign long_ack_w = wb_ack_i;
assign long_err_w = wb_err_i & ~aborted_r;
assign biu_dat_o = repeated_access_ack ? wb_dat_r : wb_dat_i;
`endif

wire same_addr;
wire repeated_access;
wire repeated_access_hit;
wire launch_req;
wire aborted;
reg phase_ok;

assign same_addr = (last_addr_r == biu_adr_i);
assign repeated_access = same_addr & previous_complete;
assign repeated_access_hit = repeated_access & biu_cyc_i & biu_stb_i;
assign launch_req = biu_cyc_i & biu_stb_i & ~repeated_access & ~retry;
assign aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~wb_err_i;

always @* begin
    phase_ok = 1'b1;
`ifdef OR1200_CLKDIV_2_SUPPORTED
    if (clmode == 2'b01)
        phase_ok = (valid_div[0] == 1'b0);
`endif
`ifdef OR1200_CLKDIV_4_SUPPORTED
    if (clmode == 2'b11)
        phase_ok = (valid_div == 2'b00);
`endif
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_div <= 2'b00;
        repeated_access_ack <= 1'b0;
        repeated_access_hit_d <= 1'b0;
    end else begin
        valid_div <= valid_div + 2'b01;
        repeated_access_ack <= repeated_access_hit & ~repeated_access_hit_d;
        repeated_access_hit_d <= repeated_access_hit;
    end
end

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_dat_r <= 32'b0;
        last_addr_r <= 32'b0;
        previous_complete <= 1'b1;
        aborted_r <= 1'b0;
`ifdef OR1200_WB_RETRY
        retry_cntr <= 2'b00;
`endif
`ifdef OR1200_WB_B3
        burst_len <= 2'b00;
`endif
    end else begin
        if (wb_ack_i) begin
            wb_dat_r <= wb_dat_i;
            last_addr_r <= wb_adr_o;
        end

        if (wb_ack_i && biu_cyc_i && biu_stb_i)
            previous_complete <= 1'b1;
        else if (biu_cyc_i && biu_stb_i && ~wb_ack_i && ~aborted && ~wb_stb_o)
            previous_complete <= 1'b0;

        if (wb_ack_i || wb_err_i)
            aborted_r <= 1'b0;
        else if (aborted)
            aborted_r <= 1'b1;

`ifdef OR1200_WB_RETRY
        if (wb_rty_i)
            retry_cntr <= 2'b01;
        else if (retry_cntr != 2'b00)
            retry_cntr <= retry_cntr - 2'b01;
`endif

`ifdef OR1200_WB_B3
        if (launch_req && biu_cab_i)
            burst_len <= 2'b11;
        else if (wb_ack_i && burst_len != 2'b00)
            burst_len <= burst_len - 2'b01;
        else if (!wb_cyc_o)
            burst_len <= 2'b00;
`endif
    end
end

`ifdef OR1200_REGISTERED_INPUTS
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        biu_dat_r_reg <= 32'b0;
        long_ack_r <= 1'b0;
        long_err_r <= 1'b0;
    end else begin
        long_ack_r <= wb_ack_i & ~aborted;
        long_err_r <= wb_err_i & ~aborted;
        if (wb_ack_i)
            biu_dat_r_reg <= wb_dat_i;
    end
end
`endif

`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_cyc_r <= 1'b0;
        wb_adr_r <= 32'b0;
        wb_stb_r <= 1'b0;
        wb_we_r <= 1'b0;
        wb_sel_r <= 4'b0;
        wb_dat_out_r <= 32'b0;
`ifdef OR1200_WB_CAB
        wb_cab_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
        wb_cti_r <= 3'b000;
`endif
    end else begin
        if (wb_rty_i) begin
            wb_cyc_r <= 1'b0;
            wb_stb_r <= 1'b0;
            wb_we_r <= 1'b0;
`ifdef OR1200_WB_CAB
            wb_cab_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
            wb_cti_r <= 3'b000;
`endif
        end else if (aborted_r || aborted) begin
            wb_cyc_r <= 1'b1;
            wb_stb_r <= 1'b1;
`ifdef OR1200_WB_B3
            if (wb_cab_r)
                wb_cti_r <= (burst_len == 2'b00) ? 3'b111 : 3'b010;
            else
                wb_cti_r <= 3'b000;
`endif
        end else if (wb_ack_i || wb_err_i) begin
            if (launch_req) begin
                wb_cyc_r <= 1'b1;
                wb_adr_r <= biu_adr_i;
                wb_stb_r <= 1'b1;
                wb_we_r <= biu_we_i;
                wb_sel_r <= biu_sel_i;
                wb_dat_out_r <= biu_dat_i;
`ifdef OR1200_WB_CAB
                wb_cab_r <= biu_cab_i;
`endif
`ifdef OR1200_WB_B3
                wb_cti_r <= biu_cab_i ? 3'b010 : 3'b000;
`endif
            end else begin
                wb_cyc_r <= 1'b0;
                wb_stb_r <= 1'b0;
                wb_we_r <= 1'b0;
`ifdef OR1200_WB_CAB
                wb_cab_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
                wb_cti_r <= 3'b000;
`endif
            end
        end else if (launch_req && !wb_cyc_r) begin
            wb_cyc_r <= 1'b1;
            wb_adr_r <= biu_adr_i;
            wb_stb_r <= 1'b1;
            wb_we_r <= biu_we_i;
            wb_sel_r <= biu_sel_i;
            wb_dat_out_r <= biu_dat_i;
`ifdef OR1200_WB_CAB
            wb_cab_r <= biu_cab_i;
`endif
`ifdef OR1200_WB_B3
            wb_cti_r <= biu_cab_i ? 3'b010 : 3'b000;
`endif
        end else if (!wb_cyc_r) begin
            wb_stb_r <= 1'b0;
`ifdef OR1200_WB_B3
            wb_cti_r <= 3'b000;
`endif
        end else begin
`ifdef OR1200_WB_B3
            if (wb_cab_r)
                wb_cti_r <= (burst_len == 2'b00) ? 3'b111 : 3'b010;
            else
                wb_cti_r <= 3'b000;
`endif
        end
    end
end

assign wb_cyc_o = wb_cyc_r;
assign wb_adr_o = wb_adr_r;
assign wb_stb_o = wb_stb_r;
assign wb_we_o = wb_we_r;
assign wb_sel_o = wb_sel_r;
assign wb_dat_o = wb_dat_out_r;
`ifdef OR1200_WB_CAB
assign wb_cab_o = wb_cab_r;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = wb_cti_r;
assign wb_bte_o = 2'b01;
`endif
`else
assign wb_cyc_o = biu_cyc_i;
assign wb_adr_o = biu_adr_i;
assign wb_stb_o = biu_cyc_i & biu_stb_i;
assign wb_we_o = biu_cyc_i & biu_stb_i & biu_we_i;
assign wb_sel_o = biu_sel_i;
assign wb_dat_o = biu_dat_i;
`ifdef OR1200_WB_CAB
assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = 3'b000;
assign wb_bte_o = 2'b01;
`endif
`endif

assign biu_ack_o = (repeated_access_ack | long_ack_w) & ~aborted_r & phase_ok;
assign biu_err_o = long_err_w & phase_ok;

endmodule

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
reg [31:0] wb_dat_r;
reg previous_complete;
reg aborted_r;
reg response_phase_ok;

wire biu_req;
wire same_addr;
wire repeated_access;
wire aborted;
wire long_ack_int;
wire long_err_int;
wire base_ack;
wire base_err;
wire retry;

`ifdef OR1200_WB_RETRY
reg [2:0] retry_cntr;
localparam [2:0] RETRY_HOLDOFF = 3'd2;
assign retry = |retry_cntr;
`else
assign retry = 1'b0;
`endif

`ifdef OR1200_REGISTERED_OUTPUTS
reg wb_cyc_r;
reg [31:0] wb_adr_r;
reg wb_stb_r;
reg wb_we_r;
reg [3:0] wb_sel_r;
reg [31:0] wb_dat_out_r;
reg wb_cab_r;
assign wb_cyc_o = wb_cyc_r;
assign wb_adr_o = wb_adr_r;
assign wb_stb_o = wb_stb_r;
assign wb_we_o  = wb_we_r;
assign wb_sel_o = wb_sel_r;
assign wb_dat_o = wb_dat_out_r;
`ifdef OR1200_WB_CAB
assign wb_cab_o = wb_cab_r;
`endif
`ifdef OR1200_WB_B3
reg [2:0] wb_cti_r;
reg [1:0] burst_len;
assign wb_cti_o = wb_cti_r;
assign wb_bte_o = 2'b01;
`endif
wire wb_active;
wire continue_cab_seq;
assign wb_active = wb_cyc_r | wb_stb_r;
assign continue_cab_seq = wb_cab_r & biu_cab_i & wb_ack_i & biu_req & ~retry & ~repeated_access;
`else
assign wb_adr_o = biu_adr_i;
assign wb_stb_o = biu_cyc_i & biu_stb_i;
assign wb_we_o  = biu_cyc_i & biu_stb_i & biu_we_i;
assign wb_sel_o = biu_sel_i;
assign wb_dat_o = biu_dat_i;
`ifdef OR1200_WB_RETRY
assign wb_cyc_o = biu_cyc_i & ~retry;
`else
assign wb_cyc_o = biu_cyc_i;
`endif
`ifdef OR1200_WB_CAB
assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
reg [1:0] burst_len;
assign wb_cti_o = 3'b000;
assign wb_bte_o = 2'b01;
`endif
`endif

`ifdef OR1200_REGISTERED_INPUTS
reg [31:0] biu_dat_r;
reg long_ack_r;
reg long_err_r;
assign biu_dat_o = biu_dat_r;
assign long_ack_int = long_ack_r;
assign long_err_int = long_err_r;
`else
assign biu_dat_o = repeated_access_ack ? wb_dat_r : wb_dat_i;
assign long_ack_int = wb_ack_i;
assign long_err_int = wb_err_i & ~aborted_r;
`endif

assign biu_req = biu_cyc_i & biu_stb_i;
assign same_addr = (wb_adr_o == biu_adr_i);
assign repeated_access = same_addr & previous_complete;
assign aborted = wb_stb_o & ~biu_req & ~wb_ack_i & ~wb_err_i;
assign base_ack = (repeated_access_ack | long_ack_int) & ~aborted_r;
assign base_err = long_err_int;
assign biu_ack_o = base_ack & response_phase_ok;
assign biu_err_o = base_err & response_phase_ok;

always @* begin
    response_phase_ok = 1'b1;
`ifdef OR1200_CLKDIV_2_SUPPORTED
    if (clmode == 2'b01)
        response_phase_ok = valid_div[0];
`endif
`ifdef OR1200_CLKDIV_4_SUPPORTED
    if (clmode == 2'b11)
        response_phase_ok = &valid_div;
`endif
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_div <= 2'b00;
        repeated_access_ack <= 1'b0;
    end
    else begin
        valid_div <= valid_div + 2'b01;
        repeated_access_ack <= repeated_access & biu_req;
    end
end

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_dat_r <= 32'b0;
        previous_complete <= 1'b1;
        aborted_r <= 1'b0;
`ifdef OR1200_WB_RETRY
        retry_cntr <= 3'b000;
`endif
`ifdef OR1200_REGISTERED_INPUTS
        biu_dat_r <= 32'b0;
        long_ack_r <= 1'b0;
        long_err_r <= 1'b0;
`endif
    end
    else begin
        if (wb_ack_i)
            wb_dat_r <= wb_dat_i;
`ifdef OR1200_REGISTERED_INPUTS
        if (wb_ack_i)
            biu_dat_r <= wb_dat_i;
        long_ack_r <= wb_ack_i & ~aborted;
        long_err_r <= wb_err_i & ~aborted;
`endif
        if (wb_ack_i & biu_req)
            previous_complete <= 1'b1;
        else if (biu_req & ~wb_ack_i & ~aborted & ~wb_stb_o)
            previous_complete <= 1'b0;

        if (wb_ack_i | wb_err_i)
            aborted_r <= 1'b0;
        else if (aborted)
            aborted_r <= 1'b1;

`ifdef OR1200_WB_RETRY
        if (wb_rty_i)
            retry_cntr <= RETRY_HOLDOFF;
        else if (retry_cntr != 3'b000)
            retry_cntr <= retry_cntr - 3'b001;
`endif
    end
end

`ifdef OR1200_WB_B3
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        burst_len <= 2'b00;
    else if (wb_ack_i | wb_err_i) begin
        if (biu_req & biu_cab_i & ~retry & ~repeated_access) begin
            if (wb_cab_r & wb_ack_i & (burst_len != 2'b00))
                burst_len <= burst_len - 2'b01;
            else
                burst_len <= 2'b11;
        end
        else if (wb_ack_i & wb_cab_r & (burst_len != 2'b00))
            burst_len <= burst_len - 2'b01;
        else
            burst_len <= 2'b00;
    end
    else if (~wb_cyc_r & biu_req & biu_cab_i & ~retry & ~repeated_access)
        burst_len <= 2'b11;
    else if (~wb_cyc_r)
        burst_len <= 2'b00;
end
`else
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        burst_len <= 2'b00;
    else if (biu_req & biu_cab_i) begin
        if (wb_ack_i) begin
            if (burst_len != 2'b00)
                burst_len <= burst_len - 2'b01;
            else
                burst_len <= 2'b11;
        end
        else if (burst_len == 2'b00)
            burst_len <= 2'b11;
    end
    else
        burst_len <= 2'b00;
end
`endif
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
        wb_cab_r <= 1'b0;
`ifdef OR1200_WB_B3
        wb_cti_r <= 3'b000;
`endif
    end
    else begin
        if (wb_ack_i | wb_err_i) begin
            if (biu_req & ~retry & ~repeated_access) begin
                wb_cyc_r <= 1'b1;
                wb_stb_r <= 1'b1;
                if (continue_cab_seq)
                    wb_adr_r <= wb_adr_r + 32'd4;
                else
                    wb_adr_r <= biu_adr_i;
                wb_we_r <= biu_we_i;
                wb_sel_r <= biu_sel_i;
                wb_dat_out_r <= biu_dat_i;
                wb_cab_r <= biu_cab_i;
`ifdef OR1200_WB_B3
                if (biu_cab_i) begin
                    if (continue_cab_seq & (burst_len <= 2'b01))
                        wb_cti_r <= 3'b111;
                    else
                        wb_cti_r <= 3'b010;
                end
                else
                    wb_cti_r <= 3'b000;
`endif
            end
            else begin
                wb_cyc_r <= 1'b0;
                wb_stb_r <= 1'b0;
                wb_cab_r <= 1'b0;
`ifdef OR1200_WB_B3
                wb_cti_r <= 3'b000;
`endif
            end
        end
        else if (wb_active) begin
            wb_cyc_r <= 1'b1;
            wb_stb_r <= 1'b1;
`ifdef OR1200_WB_B3
            if (wb_cab_r) begin
                if (burst_len == 2'b00)
                    wb_cti_r <= 3'b111;
                else
                    wb_cti_r <= 3'b010;
            end
            else
                wb_cti_r <= 3'b000;
`endif
        end
        else if (biu_req & ~retry & ~repeated_access) begin
            wb_cyc_r <= 1'b1;
            wb_stb_r <= 1'b1;
            wb_adr_r <= biu_adr_i;
            wb_we_r <= biu_we_i;
            wb_sel_r <= biu_sel_i;
            wb_dat_out_r <= biu_dat_i;
            wb_cab_r <= biu_cab_i;
`ifdef OR1200_WB_B3
            if (biu_cab_i)
                wb_cti_r <= 3'b010;
            else
                wb_cti_r <= 3'b000;
`endif
        end
        else begin
            wb_cyc_r <= 1'b0;
            wb_stb_r <= 1'b0;
            wb_cab_r <= 1'b0;
`ifdef OR1200_WB_B3
            wb_cti_r <= 3'b000;
`endif
        end
    end
end
`endif

endmodule

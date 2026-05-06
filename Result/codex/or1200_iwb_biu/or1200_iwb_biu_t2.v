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

wire request_active;
wire same_addr;
wire repeated_access;
wire aborted;

wire long_ack_int;
wire long_err_int;
wire ack_unqual;
wire err_unqual;

reg phase_ok;

assign request_active = biu_cyc_i & biu_stb_i;
assign same_addr = (wb_adr_o == biu_adr_i);
assign repeated_access = previous_complete & same_addr;
assign aborted = wb_stb_o & ~request_active & ~wb_ack_i & ~wb_err_i;

always @(posedge clk or posedge rst) begin
    if (rst)
        valid_div <= 2'b00;
    else
        valid_div <= valid_div + 2'b01;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        repeated_access_ack <= 1'b0;
    else
        repeated_access_ack <= repeated_access & request_active;
end

always @* begin
    phase_ok = 1'b1;
    case (clmode)
        2'b00: phase_ok = 1'b1;
        2'b01: begin
`ifdef OR1200_CLKDIV_2_SUPPORTED
            phase_ok = (valid_div[0] == 1'b0);
`endif
        end
        2'b11: begin
`ifdef OR1200_CLKDIV_4_SUPPORTED
            phase_ok = (valid_div == 2'b00);
`endif
        end
        default: phase_ok = 1'b1;
    endcase
end

assign ack_unqual = (repeated_access_ack | long_ack_int) & ~aborted_r;
assign err_unqual = long_err_int;

assign biu_ack_o = ack_unqual & phase_ok;
assign biu_err_o = err_unqual & phase_ok;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        wb_dat_r <= 32'h0000_0000;
    else if (wb_ack_i)
        wb_dat_r <= wb_dat_i;
end

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        aborted_r <= 1'b0;
    else if (wb_ack_i | wb_err_i)
        aborted_r <= 1'b0;
    else if (aborted)
        aborted_r <= 1'b1;
end

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        previous_complete <= 1'b1;
    else if (wb_ack_i & request_active)
        previous_complete <= 1'b1;
    else if (request_active & ~wb_ack_i & ~aborted & ~wb_stb_o)
        previous_complete <= 1'b0;
end

`ifdef OR1200_WB_RETRY
reg [2:0] retry_cntr;
wire retry;
localparam [2:0] RETRY_LOAD = 3'd4;

assign retry = |retry_cntr;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i)
        retry_cntr <= 3'd0;
    else if (wb_rty_i)
        retry_cntr <= RETRY_LOAD;
    else if (retry_cntr != 3'd0)
        retry_cntr <= retry_cntr - 3'd1;
end
`else
wire retry;
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
`ifdef OR1200_WB_B3
reg [2:0] wb_cti_o_r;
reg [1:0] burst_len;
`endif

wire launch_req;
assign launch_req = request_active & ~repeated_access & ~retry;

assign wb_cyc_o = wb_cyc_o_r;
assign wb_adr_o = wb_adr_o_r;
assign wb_stb_o = wb_stb_o_r;
assign wb_we_o = wb_we_o_r;
assign wb_sel_o = wb_sel_o_r;
assign wb_dat_o = wb_dat_o_r;
`ifdef OR1200_WB_CAB
assign wb_cab_o = wb_cab_o_r;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = wb_cti_o_r;
assign wb_bte_o = 2'b01;
`endif

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_cyc_o_r <= 1'b0;
        wb_stb_o_r <= 1'b0;
        wb_adr_o_r <= 32'h0000_0000;
        wb_we_o_r <= 1'b0;
        wb_sel_o_r <= 4'h0;
        wb_dat_o_r <= 32'h0000_0000;
`ifdef OR1200_WB_CAB
        wb_cab_o_r <= 1'b0;
`endif
    end else begin
        if ((!wb_cyc_o_r || (wb_ack_i | wb_err_i)) && launch_req) begin
            wb_cyc_o_r <= 1'b1;
            wb_stb_o_r <= 1'b1;
            wb_adr_o_r <= biu_adr_i;
            wb_we_o_r <= biu_we_i;
            wb_sel_o_r <= biu_sel_i;
            wb_dat_o_r <= biu_dat_i;
`ifdef OR1200_WB_CAB
            wb_cab_o_r <= biu_cab_i;
`endif
        end else if (wb_ack_i | wb_err_i) begin
            wb_stb_o_r <= 1'b0;
            wb_cyc_o_r <= 1'b0;
            wb_we_o_r <= 1'b0;
`ifdef OR1200_WB_CAB
            wb_cab_o_r <= 1'b0;
`endif
        end else begin
            wb_cyc_o_r <= wb_cyc_o_r;
            wb_stb_o_r <= wb_stb_o_r;
            wb_we_o_r <= wb_we_o_r;
            wb_adr_o_r <= wb_adr_o_r;
            wb_sel_o_r <= wb_sel_o_r;
            wb_dat_o_r <= wb_dat_o_r;
`ifdef OR1200_WB_CAB
            wb_cab_o_r <= wb_cab_o_r;
`endif
        end
    end
end

`ifdef OR1200_WB_B3
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        burst_len <= 2'd0;
        wb_cti_o_r <= 3'b000;
    end else if ((!wb_cyc_o_r || (wb_ack_i | wb_err_i)) && launch_req) begin
        burst_len <= biu_cab_i ? 2'd3 : 2'd0;
        wb_cti_o_r <= biu_cab_i ? 3'b010 : 3'b000;
    end else if (wb_ack_i && wb_stb_o_r) begin
        if (burst_len != 2'd0)
            burst_len <= burst_len - 2'd1;
        else
            burst_len <= 2'd0;

        if (burst_len == 2'd1)
            wb_cti_o_r <= 3'b111;
        else if (burst_len != 2'd0)
            wb_cti_o_r <= 3'b010;
        else
            wb_cti_o_r <= 3'b000;
    end else if (!wb_cyc_o_r) begin
        burst_len <= 2'd0;
        wb_cti_o_r <= 3'b000;
    end
end
`endif
`else
assign wb_adr_o = biu_adr_i;
assign wb_dat_o = biu_dat_i;
assign wb_sel_o = biu_sel_i;
assign wb_we_o = biu_cyc_i & biu_stb_i & biu_we_i;
assign wb_stb_o = biu_cyc_i & biu_stb_i;
`ifdef OR1200_WB_RETRY
`ifdef OR1200_NO_BURSTS
assign wb_cyc_o = biu_cyc_i & ~retry;
`else
assign wb_cyc_o = biu_cyc_i;
`endif
`else
assign wb_cyc_o = biu_cyc_i;
`endif
`ifdef OR1200_WB_CAB
assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = 3'b000;
assign wb_bte_o = 2'b01;
`endif
`endif

`ifdef OR1200_REGISTERED_INPUTS
reg [31:0] biu_dat_o_r;
reg long_ack_o_r;
reg long_err_o_r;

assign biu_dat_o = biu_dat_o_r;
assign long_ack_int = long_ack_o_r;
assign long_err_int = long_err_o_r;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        biu_dat_o_r <= 32'h0000_0000;
        long_ack_o_r <= 1'b0;
        long_err_o_r <= 1'b0;
    end else begin
        if (wb_ack_i)
            biu_dat_o_r <= wb_dat_i;
        long_ack_o_r <= wb_ack_i & ~aborted;
        long_err_o_r <= wb_err_i & ~aborted;
    end
end
`else
assign biu_dat_o = repeated_access_ack ? wb_dat_r : wb_dat_i;
assign long_ack_int = wb_ack_i;
assign long_err_int = wb_err_i & ~aborted_r;
`endif

endmodule

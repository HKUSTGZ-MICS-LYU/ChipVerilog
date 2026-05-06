module or1200_iwb_biu(
    // RISC clock, reset and clock control
    input clk,
    input rst,
    input [1:0] clmode,

    // WISHBONE interface
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

    // Internal RISC bus
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

// Internal signals in RISC clock domain
reg [1:0] valid_div;
reg [31:0] wb_adr_r;
reg wb_cyc_r;
reg wb_stb_r;
reg wb_we_r;
reg [3:0] wb_sel_r;
reg [31:0] wb_dat_r;

`ifdef OR1200_WB_CAB
reg wb_cab_r;
`endif

`ifdef OR1200_WB_B3
reg [1:0] burst_len;
reg [2:0] wb_cti_r;
`endif

// Internal signals in WISHBONE clock domain
reg [31:0] wb_adr_ack_sync;
reg [31:0] wb_dat_int;
reg long_ack_o;
reg long_err_o;
reg [31:0] biu_dat_o;
reg aborted_r;
reg [6:0] retry_cntr;
reg previous_complete;
reg repeated_access_ack;
reg [31:0] wb_dat_r_wb;

// Wire declarations
wire [31:0] wb_adr_o = wb_adr_r;
wire wb_cyc_o;
wire wb_stb_o;
wire wb_we_o = wb_we_r;
wire [3:0] wb_sel_o = wb_sel_r;
wire [31:0] wb_dat_o = wb_dat_r;

`ifdef OR1200_WB_CAB
wire wb_cab_o = wb_cab_r;
`endif

`ifdef OR1200_WB_B3
wire [2:0] wb_cti_o = wb_cti_r;
wire [1:0] wb_bte_o = 2'b10;
`endif

wire aborted;
wire retry;
wire same_addr;
wire repeated_access;

assign same_addr = (biu_adr_i == wb_adr_r);
assign repeated_access = same_addr & previous_complete;
assign aborted = (wb_stb_r & ~biu_stb_i);
assign retry = (retry_cntr != 7'b0);

assign wb_cyc_o = (retry ? 1'b0 : biu_cyc_i) | aborted_r;
assign wb_stb_o = (retry ? 1'b0 : biu_stb_i) | aborted_r;

assign biu_ack_o = long_ack_o & valid_div[clmode[1:0]];
assign biu_err_o = long_err_o & valid_div[clmode[1:0]];

// RISC clock domain logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_div <= 2'b01;
        wb_adr_r <= 32'h0;
        wb_cyc_r <= 1'b0;
        wb_stb_r <= 1'b0;
        wb_we_r <= 1'b0;
        wb_sel_r <= 4'h0;
        wb_dat_r <= 32'h0;
        biu_dat_o <= 32'h0;
        repeated_access_ack <= 1'b0;

        `ifdef OR1200_WB_CAB
        wb_cab_r <= 1'b0;
        `endif

        `ifdef OR1200_WB_B3
        burst_len <= 2'h0;
        wb_cti_r <= 3'h7;
        `endif
    end else begin
        valid_div <= {valid_div[0], valid_div[1]};

        if (biu_cyc_i & biu_stb_i) begin
            wb_adr_r <= biu_adr_i;
            wb_we_r <= biu_we_i;
            wb_sel_r <= biu_sel_i;
            wb_dat_r <= biu_dat_i;

            `ifdef OR1200_WB_CAB
            wb_cab_r <= biu_cab_i;
            `endif
        end

        if (repeated_access) begin
            biu_dat_o <= wb_dat_r_wb;
            repeated_access_ack <= 1'b1;
        end else begin
            repeated_access_ack <= 1'b0;
        end

        if (long_ack_o | long_err_o) begin
            biu_dat_o <= wb_dat_int;
        end
    end
end

// WISHBONE clock domain logic
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        long_ack_o <= 1'b0;
        long_err_o <= 1'b0;
        aborted_r <= 1'b0;
        retry_cntr <= 7'h0;
        previous_complete <= 1'b0;
        wb_dat_r_wb <= 32'h0;

        `ifdef OR1200_WB_B3
        burst_len <= 2'h0;
        `endif
    end else begin
        if (wb_ack_i) begin
            long_ack_o <= 1'b1;
            wb_dat_r_wb <= wb_dat_i;
            previous_complete <= 1'b1;
            aborted_r <= 1'b0;
            retry_cntr <= 7'h0;

            `ifdef OR1200_WB_B3
            if (burst_len > 2'h0) begin
                burst_len <= burst_len - 1;
                wb_cti_r <= (burst_len == 2'h1) ? 3'h7 : 3'h2;
            end
            `endif
        end else if (wb_err_i) begin
            long_err_o <= 1'b1;
            previous_complete <= 1'b1;
            aborted_r <= 1'b0;
            retry_cntr <= 7'h0;

            `ifdef OR1200_WB_B3
            burst_len <= 2'h0;
            `endif
        end else if (wb_rty_i) begin
            `ifdef OR1200_WB_RETRY
            retry_cntr <= 7'h7f;
            `endif
        end else begin
            long_ack_o <= 1'b0;
            long_err_o <= 1'b0;

            if (retry_cntr != 7'h0) begin
                retry_cntr <= retry_cntr - 1;
            end

            if (aborted) begin
                aborted_r <= 1'b1;
                previous_complete <= 1'b0;
            end

            `ifdef OR1200_WB_B3
            if (biu_cyc_i & biu_stb_i & biu_cab_i) begin
                burst_len <= 2'h3;
                wb_cti_r <= 3'h2;
            end
            `endif
        end
    end
end

assign wb_dat_int = wb_dat_i;

endmodule

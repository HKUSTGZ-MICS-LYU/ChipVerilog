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

// --------------------------------------------------
// Local parameters
// --------------------------------------------------
localparam DW = 32;
localparam AW = 32;

// --------------------------------------------------
// RISC clock domain signals
// --------------------------------------------------
reg [1:0] valid_div;

// --------------------------------------------------
// Wishbone clock domain signals
// --------------------------------------------------
`ifdef OR1200_REGISTERED_OUTPUTS
reg [31:0] wb_adr_r;
reg [31:0] wb_dat_r;
reg wb_cyc_r;
reg wb_stb_r;
reg wb_we_r;
reg [3:0] wb_sel_r;
`ifdef OR1200_WB_CAB
reg wb_cab_r;
`endif
`ifdef OR1200_WB_B3
reg [2:0] wb_cti_r;
reg [1:0] wb_bte_r;
`endif
`endif

`ifdef OR1200_REGISTERED_INPUTS
reg [31:0] biu_dat_r;
reg long_ack_r;
reg long_err_r;
`endif

`ifdef OR1200_WB_RETRY
reg [3:0] retry_cntr;  // counter width from source code example
`endif

reg aborted_r;

`ifdef OR1200_WB_B3
reg [1:0] burst_len;
`endif

// --------------------------------------------------
// Combinational signals
// --------------------------------------------------
wire aborted;
wire retry;
wire long_ack;
wire long_err;

// --------------------------------------------------
// RISC clock domain: valid_div counter
// --------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_div <= 2'b00;
    end else begin
        valid_div <= valid_div + 1'b1;
    end
end

// --------------------------------------------------
// Wishbone clock domain: aborted detection and register
// --------------------------------------------------
assign aborted = (wb_stb_o) & ~(biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~wb_err_i;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        aborted_r <= 1'b0;
    end else if (wb_ack_i | wb_err_i) begin
        aborted_r <= 1'b0;
    end else if (aborted) begin
        aborted_r <= 1'b1;
    end
end

// --------------------------------------------------
// Wishbone clock domain: retry counter
// --------------------------------------------------
`ifdef OR1200_WB_RETRY
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        retry_cntr <= 4'b0;
    end else if (wb_rty_i) begin
        retry_cntr <= 4'b1111; // load with all ones
    end else if (retry_cntr != 4'b0) begin
        retry_cntr <= retry_cntr - 1'b1;
    end
end
assign retry = wb_rty_i | (retry_cntr != 4'b0);
`else
assign retry = 1'b0;
`endif

// --------------------------------------------------
// Wishbone combinational output signals (non-registered)
// --------------------------------------------------
`ifdef OR1200_REGISTERED_OUTPUTS
// In registered output mode, the output registers are used.
// However, combinational versions are still needed for internal use.
wire wb_cyc_comb;
wire wb_stb_comb;
wire wb_we_comb;
wire [31:0] wb_adr_comb;
wire [31:0] wb_dat_comb;
wire [3:0] wb_sel_comb;
`endif

`ifndef OR1200_REGISTERED_OUTPUTS
// Non-registered output: combinational
assign wb_adr_o = biu_adr_i;
assign wb_dat_o = biu_dat_i;
assign wb_sel_o = biu_sel_i;
assign wb_we_o = biu_cyc_i & biu_stb_i & biu_we_i;
assign wb_stb_o = biu_cyc_i & biu_stb_i;
`ifdef OR1200_WB_CAB
assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_NO_BURSTS
`ifdef OR1200_WB_B3
assign wb_cti_o = 3'b111;
assign wb_bte_o = 2'b01;
`endif
`endif
`endif

// --------------------------------------------------
// Wishbone clock domain: registered output
// --------------------------------------------------
`ifdef OR1200_REGISTERED_OUTPUTS
// Combinational expressions for the registered outputs
assign wb_adr_comb = biu_adr_i;
assign wb_dat_comb = biu_dat_i;
assign wb_sel_comb = biu_sel_i;
assign wb_we_comb = biu_cyc_i & biu_stb_i & biu_we_i;
assign wb_stb_comb = biu_cyc_i & biu_stb_i;
assign wb_cyc_comb = biu_cyc_i;

// Registered output logic for address, data, select, we, stb, cyc, cab, cti, bte
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_adr_r <= {AW{1'b0}};
        wb_dat_r <= {DW{1'b0}};
        wb_sel_r <= 4'b0000;
        wb_we_r <= 1'b0;
        wb_stb_r <= 1'b0;
        wb_cyc_r <= 1'b0;
`ifdef OR1200_WB_CAB
        wb_cab_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
        wb_cti_r <= 3'b000;
        wb_bte_r <= 2'b01;
`endif
    end else begin
        // address update: new internal request and no ACK and not entering abort and not holding strobe waiting for ack
        if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted & ~(wb_stb_r & ~wb_ack_i)) begin
            wb_adr_r <= wb_adr_comb;
        end
        // data update: new internal request and no ACK and no abort
        if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted) begin
            wb_dat_r <= wb_dat_comb;
        end
        // sel update: every wb_clk cycle load from biu_sel_i
        wb_sel_r <= wb_sel_comb;
        // we update: normal request or abort hold
        if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~retry) begin
            wb_we_r <= wb_we_comb;
        end else if (aborted & ~wb_ack_i) begin
            wb_we_r <= wb_we_r; // hold previous value
        end
        // stb update
        if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~retry) begin
            wb_stb_r <= 1'b1;
        end else if (wb_ack_i) begin
            wb_stb_r <= 1'b0;
        end else if (aborted & ~wb_ack_i) begin
            wb_stb_r <= 1'b1;
        end else if (~biu_cyc_i) begin
            wb_stb_r <= 1'b0;
        end
        // cyc update
        `ifndef OR1200_WB_CAB
        if (biu_cyc_i & ~wb_ack_i & ~retry) begin
            wb_cyc_r <= 1'b1;
        end else if (aborted & ~wb_ack_i) begin
            wb_cyc_r <= 1'b1;
        end else if (wb_ack_i) begin
            wb_cyc_r <= 1'b0;
        end else if (~biu_cyc_i) begin
            wb_cyc_r <= 1'b0;
        end
        `else
        if ((biu_cyc_i | (biu_cab_i & ~retry)) & ~wb_ack_i) begin
            wb_cyc_r <= 1'b1;
        end else if (aborted & ~wb_ack_i) begin
            wb_cyc_r <= 1'b1;
        end else if (wb_ack_i) begin
            wb_cyc_r <= 1'b0;
        end else if (~biu_cyc_i) begin
            wb_cyc_r <= 1'b0;
        end
        `endif
`ifdef OR1200_WB_CAB
        // cab update: load biu_cab_i on each wb_clk, reset clear
        wb_cab_r <= biu_cab_i;
`endif
`ifdef OR1200_WB_B3
        // cti and bte update
        `ifdef OR1200_NO_BURSTS
        wb_cti_r <= 3'b111;
        `else
        if (biu_cab_i & burst_len[1]) begin
            wb_cti_r <= 3'b010;
        end else if (biu_cab_i & wb_ack_i) begin
            wb_cti_r <= 3'b111;
        end else begin
            wb_cti_r <= 3'b000;
        end
        `endif
        wb_bte_r <= 2'b01;
`endif
    end
end

// Assign outputs from registered values
assign wb_adr_o = wb_adr_r;
assign wb_dat_o = wb_dat_r;
assign wb_sel_o = wb_sel_r;
assign wb_we_o = wb_we_r;
assign wb_stb_o = wb_stb_r;
assign wb_cyc_o = wb_cyc_r;
`ifdef OR1200_WB_CAB
assign wb_cab_o = wb_cab_r;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = wb_cti_r;
assign wb_bte_o = wb_bte_r;
`endif
`endif // OR1200_REGISTERED_OUTPUTS

// --------------------------------------------------
// Long ack/err generation (combinational or registered)
// --------------------------------------------------
`ifdef OR1200_REGISTERED_INPUTS
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        biu_dat_r <= {DW{1'b0}};
        long_ack_r <= 1'b0;
        long_err_r <= 1'b0;
    end else begin
        if (wb_ack_i) begin
            biu_dat_r <= wb_dat_i;
        end
        long_ack_r <= wb_ack_i & ~aborted;
        long_err_r <= wb_err_i & ~aborted;
    end
end
assign biu_dat_o = biu_dat_r;
assign long_ack = long_ack_r;
assign long_err = long_err_r;
`else
assign biu_dat_o = wb_dat_i;
assign long_ack = wb_ack_i & ~aborted_r;
assign long_err = wb_err_i & ~aborted_r;
`endif

// --------------------------------------------------
// BIU acknowledge and error generation (with clock division)
// --------------------------------------------------
wire gate_ack, gate_err;

`ifdef OR1200_CLKDIV_2_SUPPORTED
wire clkdiv2_ack, clkdiv2_err;
`endif
`ifdef OR1200_CLKDIV_4_SUPPORTED
wire clkdiv4_ack, clkdiv4_err;
`endif

// Determine gating based on clmode and valid_div
assign gate_ack = (clmode == 2'b00) ? 1'b1 :
`ifdef OR1200_CLKDIV_2_SUPPORTED
                  (clmode == 2'b01) ? (valid_div == 2'b00) :
`endif
`ifdef OR1200_CLKDIV_4_SUPPORTED
                  (clmode == 2'b11) ? (valid_div == 2'b00) :
`endif
                  1'b1; // default

assign gate_err = gate_ack; // same gating

assign biu_ack_o = long_ack & gate_ack;
assign biu_err_o = long_err & gate_err;

// --------------------------------------------------
// Burst counter for B3 (Wishbone clock domain)
// --------------------------------------------------
`ifdef OR1200_WB_B3
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        burst_len <= 2'b11;
    end else if (~biu_cab_i) begin
        burst_len <= 2'b11;
    end else if (biu_cab_i & wb_ack_i & (burst_len != 2'b00)) begin
        burst_len <= burst_len - 1'b1;
    end
end
`endif

endmodule

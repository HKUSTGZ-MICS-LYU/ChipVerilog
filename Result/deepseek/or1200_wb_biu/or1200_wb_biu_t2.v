module or1200_wb_biu #(
    parameter dw = 32,
    parameter aw = 32
) (
    input clk,
    input rst,
    input [1:0] clmode,

    input wb_clk_i,
    input wb_rst_i,
    input wb_ack_i,
    input wb_err_i,
    input wb_rty_i,
    input [dw-1:0] wb_dat_i,
    output wb_cyc_o,
    output [aw-1:0] wb_adr_o,
    output wb_stb_o,
    output wb_we_o,
    output [3:0] wb_sel_o,
    output [dw-1:0] wb_dat_o,
`ifdef OR1200_WB_CAB
    output wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0] wb_cti_o,
    output [1:0] wb_bte_o,
`endif

    input [dw-1:0] biu_dat_i,
    input [aw-1:0] biu_adr_i,
    input biu_cyc_i,
    input biu_stb_i,
    input biu_we_i,
    input [3:0] biu_sel_i,
    input biu_cab_i,
    output [31:0] biu_dat_o,
    output biu_ack_o,
    output biu_err_o
);

    // Internal signals
    wire aborted;
    reg aborted_r;
    
    reg [1:0] valid_div;
    
    wire long_ack_o;
    wire long_err_o;
    
    // Retry support
`ifdef OR1200_WB_RETRY
    reg [3:0] retry_cntr;
    wire retry;
    assign retry = wb_rty_i | (retry_cntr != 0);
`else
    wire retry;
    assign retry = 0;
`endif

    // Abort logic
    assign aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~wb_err_i;
    
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            aborted_r <= 0;
        else if (wb_ack_i | wb_err_i)
            aborted_r <= 0;
        else if (aborted)
            aborted_r <= 1;
    end

    // Output register logic
`ifdef OR1200_REGISTERED_OUTPUTS
    reg wb_cyc_o_reg;
    reg [aw-1:0] wb_adr_o_reg;
    reg wb_stb_o_reg;
    reg wb_we_o_reg;
    reg [3:0] wb_sel_o_reg;
    reg [dw-1:0] wb_dat_o_reg;
`ifdef OR1200_WB_CAB
    reg wb_cab_o_reg;
`endif
`ifdef OR1200_WB_B3
    reg [2:0] wb_cti_o_reg;
    reg [1:0] wb_bte_o_reg;
`endif

    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_adr_o_reg <= 0;
            wb_dat_o_reg <= 0;
            wb_sel_o_reg <= 0;
`ifdef OR1200_WB_CAB
            wb_cab_o_reg <= 0;
`endif
`ifdef OR1200_WB_B3
            wb_cti_o_reg <= 0;
            wb_bte_o_reg <= 2'b01;
`endif
        end else begin
            // wb_sel_o loads every cycle
            wb_sel_o_reg <= biu_sel_i;
            
            // wb_adr_o: new request, no ack, not aborting, and not holding strobe waiting for ack
            if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted & ~(wb_stb_o_reg & ~wb_ack_i))
                wb_adr_o_reg <= biu_adr_i;
            
            // wb_dat_o: new request, no ack, no abort
            if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted)
                wb_dat_o_reg <= biu_dat_i;
                
`ifdef OR1200_WB_CAB
            wb_cab_o_reg <= biu_cab_i;
`endif
        end
    end

    // wb_cyc_o
`ifdef OR1200_NO_BURSTS
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            wb_cyc_o_reg <= 0;
        else if (aborted & ~wb_ack_i)
            wb_cyc_o_reg <= 1;
        else
            wb_cyc_o_reg <= biu_cyc_i & ~wb_ack_i & ~retry;
    end
`else
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            wb_cyc_o_reg <= 0;
        else if (aborted & ~wb_ack_i)
            wb_cyc_o_reg <= 1;
        else
            wb_cyc_o_reg <= (biu_cyc_i | biu_cab_i) & ~wb_ack_i & ~retry;
    end
`endif

    // wb_stb_o
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            wb_stb_o_reg <= 0;
        else if (aborted & ~wb_ack_i)
            wb_stb_o_reg <= 1;
        else
            wb_stb_o_reg <= biu_cyc_i & biu_stb_i & ~wb_ack_i & ~retry;
    end

    // wb_we_o
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            wb_we_o_reg <= 0;
        else if (aborted & ~wb_ack_i)
            wb_we_o_reg <= wb_we_o_reg;
        else if (biu_cyc_i & biu_stb_i & ~wb_ack_i & ~retry)
            wb_we_o_reg <= biu_we_i;
    end

`ifdef OR1200_WB_B3
    // B3 burst logic
    reg [1:0] burst_len;
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            burst_len <= 2'b11;
        else if (~biu_cab_i)
            burst_len <= 2'b11;
        else if (biu_cab_i & (burst_len != 0) & wb_ack_i)
            burst_len <= burst_len - 1;
    end

    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            wb_cti_o_reg <= 3'b000;
`ifdef OR1200_NO_BURSTS
        else
            wb_cti_o_reg <= 3'b111;
`else
        else if (biu_cab_i & burst_len[1])
            wb_cti_o_reg <= 3'b010;
        else if (biu_cab_i & wb_ack_i)
            wb_cti_o_reg <= 3'b111;
        else
            wb_cti_o_reg <= 3'b000;
`endif
    end
    
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            wb_bte_o_reg <= 2'b01;
        else
            wb_bte_o_reg <= 2'b01;
    end
`endif

    assign wb_cyc_o = wb_cyc_o_reg;
    assign wb_adr_o = wb_adr_o_reg;
    assign wb_stb_o = wb_stb_o_reg;
    assign wb_we_o = wb_we_o_reg;
    assign wb_sel_o = wb_sel_o_reg;
    assign wb_dat_o = wb_dat_o_reg;
`ifdef OR1200_WB_CAB
    assign wb_cab_o = wb_cab_o_reg;
`endif
`ifdef OR1200_WB_B3
    assign wb_cti_o = wb_cti_o_reg;
    assign wb_bte_o = wb_bte_o_reg;
`endif

`else // !OR1200_REGISTERED_OUTPUTS

    // Combinational outputs
`ifdef OR1200_NO_BURSTS
    assign wb_cyc_o = biu_cyc_i & ~retry;
`else
    assign wb_cyc_o = biu_cyc_i | (biu_cab_i & ~retry);
`endif
    assign wb_adr_o = biu_adr_i;
    assign wb_stb_o = biu_cyc_i & biu_stb_i;
    assign wb_we_o = biu_cyc_i & biu_stb_i & biu_we_i;
    assign wb_sel_o = biu_sel_i;
    assign wb_dat_o = biu_dat_i;
`ifdef OR1200_WB_CAB
    assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
    // Unsupported
    assign wb_cti_o = 3'b000;
    assign wb_bte_o = 2'b01;
`endif

`endif // OR1200_REGISTERED_OUTPUTS

    // Input data and response path
`ifdef OR1200_REGISTERED_INPUTS
    reg [31:0] biu_dat_o_reg;
    reg long_ack_o_reg;
    reg long_err_o_reg;
    
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            biu_dat_o_reg <= 0;
            long_ack_o_reg <= 0;
            long_err_o_reg <= 0;
        end else begin
            if (wb_ack_i)
                biu_dat_o_reg <= wb_dat_i;
            long_ack_o_reg <= wb_ack_i & ~aborted;
            long_err_o_reg <= wb_err_i & ~aborted;
        end
    end
    
    assign biu_dat_o = biu_dat_o_reg;
    assign long_ack_o = long_ack_o_reg;
    assign long_err_o = long_err_o_reg;

`else // !OR1200_REGISTERED_INPUTS
    assign biu_dat_o = wb_dat_i;
    assign long_ack_o = wb_ack_i & ~aborted_r;
    assign long_err_o = wb_err_i & ~aborted_r;
`endif

    // valid_div counter (RISC domain)
    always @(posedge clk or posedge rst) begin
        if (rst)
            valid_div <= 0;
        else
            valid_div <= valid_div + 1;
    end

    // Clock division gating for ack/err
    wire div2_ok;
    wire div4_ok;
    
`ifdef OR1200_CLKDIV_2_SUPPORTED
    assign div2_ok = (clmode == 2'b01) ? valid_div[0] : 1'b1;
`else
    assign div2_ok = 1'b1;
`endif

`ifdef OR1200_CLKDIV_4_SUPPORTED
    assign div4_ok = (clmode == 2'b11) ? (valid_div == 2'b11) : 1'b1;
`else
    assign div4_ok = 1'b1;
`endif

    assign biu_ack_o = long_ack_o & div2_ok & div4_ok;
    assign biu_err_o = long_err_o & div2_ok & div4_ok;

    // Retry counter
`ifdef OR1200_WB_RETRY
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            retry_cntr <= 0;
        else if (wb_rty_i)
            retry_cntr <= 4'hF;
        else if (retry_cntr != 0)
            retry_cntr <= retry_cntr - 1;
    end
`endif

endmodule

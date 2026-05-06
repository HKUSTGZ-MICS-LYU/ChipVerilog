`include "or1200_defines.v"

module or1200_wb_biu(
    input         clk,
    input         rst,
    input  [1:0]  clmode,
    input         wb_clk_i,
    input         wb_rst_i,
    input         wb_ack_i,
    input         wb_err_i,
    input         wb_rty_i,
    input  [31:0] wb_dat_i,
    output        wb_cyc_o,
    output [31:0] wb_adr_o,
    output        wb_stb_o,
    output        wb_we_o,
    output [3:0]  wb_sel_o,
    output [31:0] wb_dat_o,
`ifdef OR1200_WB_CAB
    output        wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0]  wb_cti_o,
    output [1:0]  wb_bte_o,
`endif
    input  [31:0] biu_dat_i,
    input  [31:0] biu_adr_i,
    input         biu_cyc_i,
    input         biu_stb_i,
    input         biu_we_i,
    input  [3:0]  biu_sel_i,
    input         biu_cab_i,
    output [31:0] biu_dat_o,
    output        biu_ack_o,
    output        biu_err_o
);

reg [31:0] wb_dat_r;
reg [31:0] wb_adr_r;
reg previous_complete;
reg aborted_r;
reg wb_we_r;
wire repeated_access = previous_complete & ~biu_we_i & (biu_adr_i == wb_adr_r);
wire aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~(wb_ack_i | wb_err_i);

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_dat_r <= 32'b0;
        wb_adr_r <= 32'b0;
        previous_complete <= 1'b0;
        aborted_r <= 1'b0;
    end else begin
        if (biu_cyc_i & biu_stb_i) begin
            wb_adr_r <= biu_adr_i;
        end
        if (wb_ack_i)
            wb_dat_r <= wb_dat_i;
        previous_complete <= wb_ack_i | wb_err_i;
        if (biu_cyc_i & biu_stb_i)
            wb_we_r <= biu_we_i;
        if (aborted)
            aborted_r <= 1'b1;
        else if (wb_ack_i | wb_err_i)
            aborted_r <= 1'b0;
    end
end

assign wb_cyc_o = (biu_cyc_i & ~repeated_access) | (aborted_r & ~wb_ack_i & ~wb_err_i);
assign wb_stb_o = (biu_stb_i & ~repeated_access) | (aborted_r & ~wb_ack_i & ~wb_err_i);
assign wb_adr_o = biu_adr_i;
assign wb_we_o  = aborted_r ? wb_we_r : biu_we_i;
assign wb_sel_o = biu_sel_i;
assign wb_dat_o = biu_dat_i;
assign biu_dat_o = repeated_access ? wb_dat_r : wb_dat_i;
assign biu_ack_o = repeated_access ? 1'b1 : (wb_ack_i & ~aborted_r);
assign biu_err_o = wb_err_i & ~aborted_r;
`ifdef OR1200_WB_CAB
assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = biu_cab_i ? 3'b010 : 3'b111;
assign wb_bte_o = 2'b01;
`endif

endmodule

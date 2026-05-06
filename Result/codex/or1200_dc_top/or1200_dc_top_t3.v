`include "or1200_defines.v"
module or1200_dc_top(
    input clk,
    input rst,
    output [31:0] dcsb_dat_o,
    output [31:0] dcsb_adr_o,
    output dcsb_cyc_o,
    output dcsb_stb_o,
    output dcsb_we_o,
    output [3:0] dcsb_sel_o,
    output dcsb_cab_o,
    input [31:0] dcsb_dat_i,
    input dcsb_ack_i,
    input dcsb_err_i,
    input dc_en,
    input [31:0] dcqmem_adr_i,
    input dcqmem_cycstb_i,
    input dcqmem_ci_i,
    input dcqmem_we_i,
    input [3:0] dcqmem_sel_i,
    input [3:0] dcqmem_tag_i,
    input [31:0] dcqmem_dat_i,
    output [31:0] dcqmem_dat_o,
    output dcqmem_ack_o,
    output dcqmem_rty_o,
    output dcqmem_err_o,
    output [3:0] dcqmem_tag_o,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input spr_cs,
    input spr_write,
    input [31:0] spr_dat_i
);
localparam integer DATA_DEPTH=(1<<11);
localparam integer TAG_DEPTH=(1<<9);
reg [31:0] dcram [0:DATA_DEPTH-1]; reg [19:0] tagram [0:TAG_DEPTH-1];
reg [31:0] saved_addr; reg [1:0] state; reg [2:0] cnt; reg cache_inhibit; integer i;
localparam IDLE=2'd0, MISS=2'd1, REFILL=2'd2;
wire [31:0] active_addr = (state==IDLE) ? dcqmem_adr_i : saved_addr;
wire [8:0] tag_idx = active_addr[`OR1200_DCINDXH:`OR1200_DCTAGL];
wire [10:0] data_idx = active_addr[`OR1200_DCINDXH:2];
wire [19:0] tag_q = tagram[tag_idx];
wire tag_v = tag_q[0]; wire [18:0] tag = tag_q[19:1];
wire tagcomp_miss = (~tag_v) | (tag != saved_addr[31:`OR1200_DCTAGL]);
wire hit_now = dcqmem_cycstb_i & !dcqmem_ci_i & tag_v & (tag == dcqmem_adr_i[31:`OR1200_DCTAGL]);
assign dcsb_dat_o = dcqmem_dat_i;
assign dcsb_adr_o = (state==IDLE) ? dcqmem_adr_i : saved_addr;
assign dcsb_cyc_o = dc_en ? ((state!=IDLE) || (dcqmem_cycstb_i && (dcqmem_we_i || !hit_now))) : dcqmem_cycstb_i;
assign dcsb_stb_o = dcsb_cyc_o;
assign dcsb_we_o  = dc_en ? (state==IDLE && dcqmem_cycstb_i && dcqmem_we_i) : dcqmem_we_i;
assign dcsb_sel_o = dcqmem_sel_i;
assign dcsb_cab_o = (state==REFILL);
assign dcqmem_dat_o = (!dc_en || state!=IDLE || !hit_now) ? dcsb_dat_i : dcram[dcqmem_adr_i[`OR1200_DCINDXH:2]];
assign dcqmem_ack_o = !dc_en ? dcsb_ack_i : (hit_now & ~dcqmem_we_i) | (dcsb_ack_i & (state!=REFILL));
assign dcqmem_err_o = !dc_en ? dcsb_err_i : (dcsb_err_i & (state!=REFILL));
assign dcqmem_rty_o = ~dcqmem_ack_o & ~dcqmem_err_o;
assign dcqmem_tag_o = dcqmem_err_o ? `OR1200_DTAG_BE : dcqmem_tag_i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state<=IDLE; saved_addr<=32'h0; cnt<=3'h0; cache_inhibit<=1'b0;
        for (i=0;i<DATA_DEPTH;i=i+1) dcram[i] <= 32'h0;
        for (i=0;i<TAG_DEPTH;i=i+1) tagram[i] <= 20'h0;
    end else begin
        if (spr_cs && spr_write) tagram[spr_dat_i[`OR1200_DCINDXH:`OR1200_DCTAGL]] <= {tagram[spr_dat_i[`OR1200_DCINDXH:`OR1200_DCTAGL]][19:1],1'b0};
        case (state)
            IDLE: begin
                if (dc_en && dcqmem_cycstb_i) begin
                    saved_addr <= dcqmem_adr_i; cache_inhibit <= dcqmem_ci_i;
                    if (dcqmem_we_i) begin
                        if (hit_now) begin
                            if (dcqmem_sel_i[0]) dcram[dcqmem_adr_i[`OR1200_DCINDXH:2]][7:0] <= dcqmem_dat_i[7:0];
                            if (dcqmem_sel_i[1]) dcram[dcqmem_adr_i[`OR1200_DCINDXH:2]][15:8] <= dcqmem_dat_i[15:8];
                            if (dcqmem_sel_i[2]) dcram[dcqmem_adr_i[`OR1200_DCINDXH:2]][23:16] <= dcqmem_dat_i[23:16];
                            if (dcqmem_sel_i[3]) dcram[dcqmem_adr_i[`OR1200_DCINDXH:2]][31:24] <= dcqmem_dat_i[31:24];
                        end
                    end else if (!hit_now) begin
                        state <= MISS;
                    end
                end
            end
            MISS: begin
                if (dcsb_err_i) state <= IDLE;
                else if (dcsb_ack_i) begin
                    if (!cache_inhibit) begin
                        dcram[saved_addr[`OR1200_DCINDXH:2]] <= dcsb_dat_i;
                        tagram[saved_addr[`OR1200_DCINDXH:`OR1200_DCTAGL]] <= {saved_addr[31:`OR1200_DCTAGL],1'b1};
                        saved_addr[3:2] <= saved_addr[3:2] + 2'd1; cnt <= `OR1200_DCLS - 2; state <= REFILL;
                    end else state <= IDLE;
                end
            end
            REFILL: begin
                if (dcsb_err_i) state <= IDLE;
                else if (dcsb_ack_i) begin
                    dcram[saved_addr[`OR1200_DCINDXH:2]] <= dcsb_dat_i;
                    if (cnt != 0) begin cnt <= cnt - 3'd1; saved_addr[3:2] <= saved_addr[3:2] + 2'd1; end else state <= IDLE;
                end
            end
        endcase
    end
end
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

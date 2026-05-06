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

localparam [1:0] IDLE   = 2'd0,
                 CFETCH = 2'd1,
                 REFILL = 2'd2,
                 WRITE  = 2'd3;

localparam integer DATA_DEPTH = 2048;
localparam integer TAG_DEPTH  = 512;

reg [31:0] dcram[0:DATA_DEPTH-1];
reg [19:0] tagram[0:TAG_DEPTH-1];
reg [31:0] saved_addr;
reg [1:0]  state;
reg [2:0]  cnt;
reg        cache_inhibit;
reg        first_eval;
integer i;

wire dc_inv;
wire [31:0] dc_addr;
wire [8:0] dctag_addr;
wire [10:0] dcram_addr;
wire [19:0] tag_q;
wire tag_v;
wire [18:0] tag;
wire tagcomp_miss;
wire hit_now;
wire first_hit_ack;
wire first_miss_ack;
wire first_miss_err;
wire dcfsm_burst;
wire dcfsm_biu_read;
wire dcfsm_biu_write;
wire [31:0] to_dcram;
wire [31:0] from_dcram;
wire [3:0] dcram_we;
wire [3:0] store_hit_we;
wire [3:0] refill_we;
wire [19:0] dctag_datain;

assign dc_inv = spr_cs & spr_write;
assign dc_addr = (dcfsm_biu_read | dcfsm_burst) ? saved_addr : dcqmem_adr_i;
assign dctag_addr = dc_inv ? spr_dat_i[`OR1200_DCINDXH:`OR1200_DCTAGL] : dc_addr[`OR1200_DCINDXH:`OR1200_DCTAGL];
assign dcram_addr = dc_addr[`OR1200_DCINDXH:2];
assign tag_q = tagram[dctag_addr];
assign tag_v = tag_q[0];
assign tag   = tag_q[19:1];
assign tagcomp_miss = ~tag_v | (tag != saved_addr[31:`OR1200_DCTAGL]);
assign hit_now = dcqmem_cycstb_i & ~dcqmem_ci_i & tagram[dcqmem_adr_i[`OR1200_DCINDXH:`OR1200_DCTAGL]][0]
               & (tagram[dcqmem_adr_i[`OR1200_DCINDXH:`OR1200_DCTAGL]][19:1] == dcqmem_adr_i[31:`OR1200_DCTAGL]);

assign dcfsm_biu_read  = dc_en & ((state == CFETCH && ((first_eval && tagcomp_miss) || ~first_eval)) | (state == REFILL));
assign dcfsm_biu_write = dc_en & ((state == WRITE) | (state == IDLE && dcqmem_cycstb_i && dcqmem_we_i));
assign dcfsm_burst     = dc_en & (((state == CFETCH) && tagcomp_miss && ~cache_inhibit) | (state == REFILL));
assign first_hit_ack   = dc_en & (state == CFETCH) & first_eval & ~tagcomp_miss & ~cache_inhibit & ~saved_addr[31];
assign first_miss_ack  = dc_en & dcfsm_biu_read & dcsb_ack_i & first_eval & tagcomp_miss;
assign first_miss_err  = dc_en & dcfsm_biu_read & dcsb_err_i & first_eval & tagcomp_miss;
assign to_dcram = dcfsm_biu_read ? dcsb_dat_i : dcqmem_dat_i;
assign from_dcram = dcram[dcram_addr];
assign store_hit_we = (dc_en & (state == IDLE) & dcqmem_cycstb_i & dcqmem_we_i & hit_now) ? dcqmem_sel_i : 4'b0000;
assign refill_we = {4{dcfsm_biu_read & dcsb_ack_i & ~cache_inhibit}};
assign dcram_we = store_hit_we | refill_we;
assign dctag_datain = {saved_addr[31:`OR1200_DCTAGL], ~dc_inv};

assign dcsb_dat_o = dcqmem_dat_i;
assign dcsb_adr_o = dc_addr;
assign dcsb_cyc_o = dc_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
assign dcsb_stb_o = dcsb_cyc_o;
assign dcsb_we_o  = dc_en ? dcfsm_biu_write : dcqmem_we_i;
assign dcsb_sel_o = (dc_en && dcfsm_biu_read) ? 4'b1111 : dcqmem_sel_i;
assign dcsb_cab_o = dc_en ? dcfsm_burst : 1'b0;
assign dcqmem_dat_o = (first_miss_ack | ~dc_en) ? dcsb_dat_i : from_dcram;
assign dcqmem_ack_o = dc_en ? (first_hit_ack | first_miss_ack | ((state == WRITE) & dcsb_ack_i)) : dcsb_ack_i;
assign dcqmem_err_o = dc_en ? (first_miss_err | ((state == WRITE) & dcsb_err_i)) : dcsb_err_i;
assign dcqmem_rty_o = ~dcqmem_ack_o;
assign dcqmem_tag_o = dcqmem_err_o ? `OR1200_DTAG_BE : dcqmem_tag_i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        saved_addr <= 32'h0000_0000;
        cnt <= 3'd0;
        cache_inhibit <= 1'b0;
        first_eval <= 1'b0;
        for (i = 0; i < DATA_DEPTH; i = i + 1)
            dcram[i] <= 32'h0000_0000;
        for (i = 0; i < TAG_DEPTH; i = i + 1)
            tagram[i] <= 20'h00000;
    end else begin
        if (dc_inv)
            tagram[dctag_addr] <= {tagram[dctag_addr][19:1], 1'b0};

        if (dcram_we[0]) dcram[dcram_addr][7:0]   <= to_dcram[7:0];
        if (dcram_we[1]) dcram[dcram_addr][15:8]  <= to_dcram[15:8];
        if (dcram_we[2]) dcram[dcram_addr][23:16] <= to_dcram[23:16];
        if (dcram_we[3]) dcram[dcram_addr][31:24] <= to_dcram[31:24];
        if (dcfsm_biu_read & dcsb_ack_i & ~cache_inhibit)
            tagram[saved_addr[`OR1200_DCINDXH:`OR1200_DCTAGL]] <= {saved_addr[31:`OR1200_DCTAGL], 1'b1};

        case (state)
            IDLE: begin
                cnt <= 3'd0;
                first_eval <= 1'b0;
                cache_inhibit <= 1'b0;
                if (dc_en && dcqmem_cycstb_i) begin
                    saved_addr <= dcqmem_adr_i;
                    cache_inhibit <= dcqmem_ci_i;
                    first_eval <= 1'b1;
                    if (dcqmem_we_i)
                        state <= WRITE;
                    else
                        state <= CFETCH;
                end
            end

            WRITE: begin
                if (dcsb_ack_i | dcsb_err_i)
                    state <= IDLE;
            end

            CFETCH: begin
                if (~dc_en || ~dcqmem_cycstb_i) begin
                    state <= IDLE;
                    first_eval <= 1'b0;
                end else if (~tagcomp_miss && ~cache_inhibit) begin
                    state <= IDLE;
                    first_eval <= 1'b0;
                end else if (dcsb_err_i) begin
                    state <= IDLE;
                    first_eval <= 1'b0;
                end else if (dcsb_ack_i && tagcomp_miss) begin
                    if (cache_inhibit) begin
                        state <= IDLE;
                        first_eval <= 1'b0;
                    end else begin
                        state <= REFILL;
                        first_eval <= 1'b0;
                        cnt <= `OR1200_DCLS - 2;
                        saved_addr[3:2] <= saved_addr[3:2] + 2'd1;
                    end
                end
            end

            REFILL: begin
                if (dcsb_err_i) begin
                    state <= IDLE;
                end else if (dcsb_ack_i) begin
                    if (cnt != 0) begin
                        cnt <= cnt - 3'd1;
                        saved_addr[3:2] <= saved_addr[3:2] + 2'd1;
                    end else begin
                        state <= IDLE;
                    end
                end
            end
            default: state <= IDLE;
        endcase
    end
end

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

endmodule

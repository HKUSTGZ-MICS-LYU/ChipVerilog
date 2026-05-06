`ifndef OR1200_DTAG_BE
`define OR1200_DTAG_BE 4'b0001
`endif

`ifdef OR1200_BIST
`ifndef OR1200_MBIST_CTRL_WIDTH
`define OR1200_MBIST_CTRL_WIDTH 3
`endif
`endif

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

wire tag_v;
wire [18:0] tag;
wire [31:0] to_dcram;
wire [31:0] from_dcram;
wire [31:0] saved_addr;
wire [3:0] dcram_we;
wire dctag_we;
wire [31:0] dc_addr;
wire dcfsm_biu_read;
wire dcfsm_biu_write;
reg tagcomp_miss;
wire [12:4] dctag_addr;
wire dctag_en;
wire dctag_v;
wire dc_inv;
wire dcfsm_first_hit_ack;
wire dcfsm_first_miss_ack;
wire dcfsm_first_miss_err;
wire dcfsm_burst;
wire dcfsm_tag_we;
wire [31:12] dc_tag_datain;
`ifdef OR1200_BIST
wire mbist_ram_so;
wire mbist_tag_so;
wire mbist_ram_si;
wire mbist_tag_si;
assign mbist_ram_si = mbist_si_i;
assign mbist_tag_si = mbist_ram_so;
assign mbist_so_o = mbist_tag_so;
`endif

assign dc_inv = spr_cs & spr_write;
assign dctag_we = dcfsm_tag_we | dc_inv;
assign dctag_addr = dc_inv ? spr_dat_i[12:4] : dc_addr[12:4];
assign dctag_en = (dc_en & dcqmem_cycstb_i) | dctag_we;
assign dctag_v = ~dc_inv;
assign dc_tag_datain = {dctag_v, saved_addr[31:13]};

assign dcsb_dat_o = dcqmem_dat_i;
assign dcsb_adr_o = dc_addr;
assign dcsb_cyc_o = dc_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
assign dcsb_stb_o = dc_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
assign dcsb_we_o = dc_en ? dcfsm_biu_write : dcqmem_we_i;
assign dcsb_sel_o = (dc_en && dcfsm_biu_read && !dcqmem_ci_i) ? 4'b1111 : dcqmem_sel_i;
assign dcsb_cab_o = dc_en ? dcfsm_burst : 1'b0;

assign to_dcram = dcfsm_biu_read ? dcsb_dat_i : dcqmem_dat_i;
assign dcqmem_dat_o = (!dc_en || dcfsm_first_miss_ack) ? dcsb_dat_i : from_dcram;
assign dcqmem_ack_o = dc_en ? (dcfsm_first_hit_ack | dcfsm_first_miss_ack) : dcsb_ack_i;
assign dcqmem_err_o = dc_en ? dcfsm_first_miss_err : dcsb_err_i;
assign dcqmem_rty_o = ~dcqmem_ack_o;
assign dcqmem_tag_o = dcqmem_err_o ? `OR1200_DTAG_BE : dcqmem_tag_i;

always @* begin
    tagcomp_miss = 1'b1;
    if (tag_v && (tag == saved_addr[31:13]))
        tagcomp_miss = 1'b0;
end

or1200_dc_fsm u_dc_fsm (
    .clk(clk),
    .rst(rst),
    .dc_en(dc_en),
    .dcqmem_adr_i(dcqmem_adr_i),
    .dcqmem_cycstb_i(dcqmem_cycstb_i),
    .dcqmem_ci_i(dcqmem_ci_i),
    .dcqmem_we_i(dcqmem_we_i),
    .dcqmem_sel_i(dcqmem_sel_i),
    .tagcomp_miss(tagcomp_miss),
    .dcsb_ack_i(dcsb_ack_i),
    .dcsb_err_i(dcsb_err_i),
    .saved_addr(saved_addr),
    .dc_addr(dc_addr),
    .dcram_we(dcram_we),
    .dcfsm_biu_read(dcfsm_biu_read),
    .dcfsm_biu_write(dcfsm_biu_write),
    .dcfsm_first_hit_ack(dcfsm_first_hit_ack),
    .dcfsm_first_miss_ack(dcfsm_first_miss_ack),
    .dcfsm_first_miss_err(dcfsm_first_miss_err),
    .dcfsm_burst(dcfsm_burst),
    .dcfsm_tag_we(dcfsm_tag_we)
);

or1200_dc_ram u_dc_ram (
    .clk(clk),
    .addr(dc_addr),
    .we(dcram_we),
    .datain(to_dcram),
    .dataout(from_dcram)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(mbist_ram_si),
    .mbist_so_o(mbist_ram_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_dc_tag u_dc_tag (
    .clk(clk),
    .rst(rst),
    .en(dctag_en),
    .we(dctag_we),
    .addr(dctag_addr),
    .datain(dc_tag_datain),
    .tag_v(tag_v),
    .tag(tag)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(mbist_tag_si),
    .mbist_so_o(mbist_tag_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

endmodule

module or1200_dc_fsm(
    input clk,
    input rst,
    input dc_en,
    input [31:0] dcqmem_adr_i,
    input dcqmem_cycstb_i,
    input dcqmem_ci_i,
    input dcqmem_we_i,
    input [3:0] dcqmem_sel_i,
    input tagcomp_miss,
    input dcsb_ack_i,
    input dcsb_err_i,
    output [31:0] saved_addr,
    output [31:0] dc_addr,
    output [3:0] dcram_we,
    output dcfsm_biu_read,
    output dcfsm_biu_write,
    output dcfsm_first_hit_ack,
    output dcfsm_first_miss_ack,
    output dcfsm_first_miss_err,
    output dcfsm_burst,
    output dcfsm_tag_we
);

reg pending;
reg pending_we;
reg pending_ci;
reg pending_hit;
reg [31:0] saved_addr_r;

wire new_req;
wire read_hit;
wire start_bus_read;
wire start_bus_write;

assign new_req = dc_en & dcqmem_cycstb_i & ~pending;
assign read_hit = new_req & ~dcqmem_we_i & ~dcqmem_ci_i & ~tagcomp_miss;
assign start_bus_read = new_req & ~dcqmem_we_i & (dcqmem_ci_i | tagcomp_miss);
assign start_bus_write = new_req & dcqmem_we_i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pending <= 1'b0;
        pending_we <= 1'b0;
        pending_ci <= 1'b0;
        pending_hit <= 1'b0;
        saved_addr_r <= 32'b0;
    end
    else if (!dc_en) begin
        pending <= 1'b0;
        pending_we <= 1'b0;
        pending_ci <= 1'b0;
        pending_hit <= 1'b0;
        saved_addr_r <= dcqmem_adr_i;
    end
    else begin
        if (new_req && (start_bus_read | start_bus_write)) begin
            pending <= 1'b1;
            pending_we <= dcqmem_we_i;
            pending_ci <= dcqmem_ci_i;
            pending_hit <= ~dcqmem_ci_i & ~tagcomp_miss;
            saved_addr_r <= dcqmem_adr_i;
        end
        else if (pending && (dcsb_ack_i | dcsb_err_i)) begin
            pending <= 1'b0;
        end
        else if (!pending) begin
            saved_addr_r <= dcqmem_adr_i;
        end
    end
end

assign saved_addr = pending ? saved_addr_r : dcqmem_adr_i;
assign dc_addr = pending ? saved_addr_r : dcqmem_adr_i;
assign dcfsm_biu_read = pending & ~pending_we;
assign dcfsm_biu_write = pending & pending_we;
assign dcfsm_first_hit_ack = read_hit | (pending & pending_we & pending_hit & dcsb_ack_i);
assign dcfsm_first_miss_ack = pending & dcsb_ack_i & ~(pending_we & pending_hit);
assign dcfsm_first_miss_err = pending & dcsb_err_i;
assign dcfsm_burst = 1'b0;
assign dcfsm_tag_we = pending & ~pending_we & ~pending_ci & dcsb_ack_i;
assign dcram_we = (new_req & dcqmem_we_i & ~dcqmem_ci_i & ~tagcomp_miss) ? dcqmem_sel_i :
                  ((pending & ~pending_we & ~pending_ci & dcsb_ack_i) ? 4'b1111 : 4'b0000);

endmodule

module or1200_dc_ram(
    input clk,
    input [31:0] addr,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

reg [31:0] mem [0:2047];
wire [10:0] word_addr;

assign word_addr = addr[12:2];
assign dataout = mem[word_addr];

always @(posedge clk) begin
    if (we[0])
        mem[word_addr][7:0] <= datain[7:0];
    if (we[1])
        mem[word_addr][15:8] <= datain[15:8];
    if (we[2])
        mem[word_addr][23:16] <= datain[23:16];
    if (we[3])
        mem[word_addr][31:24] <= datain[31:24];
end

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
wire [`OR1200_MBIST_CTRL_WIDTH - 1:0] unused_mbist_ctrl;
assign unused_mbist_ctrl = mbist_ctrl_i;
`endif

endmodule

module or1200_dc_tag(
    input clk,
    input rst,
    input en,
    input we,
    input [12:4] addr,
    input [31:12] datain,
    output tag_v,
    output [18:0] tag
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

reg [19:0] mem [0:511];
integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < 512; i = i + 1)
            mem[i] <= 20'b0;
    end
    else if (en && we) begin
        mem[addr] <= datain;
    end
end

assign {tag_v, tag} = mem[addr];

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
wire [`OR1200_MBIST_CTRL_WIDTH - 1:0] unused_mbist_ctrl;
assign unused_mbist_ctrl = mbist_ctrl_i;
`endif

endmodule

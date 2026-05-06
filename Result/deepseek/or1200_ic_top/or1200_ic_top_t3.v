module or1200_ic_top(
    input clk,
    input rst,
    output [31:0] icbiu_dat_o,
    output [31:0] icbiu_adr_o,
    output icbiu_cyc_o,
    output icbiu_stb_o,
    output icbiu_we_o,
    output [3:0] icbiu_sel_o,
    output icbiu_cab_o,
    input [31:0] icbiu_dat_i,
    input icbiu_ack_i,
    input icbiu_err_i,
    input ic_en,
    input [31:0] icqmem_adr_i,
    input icqmem_cycstb_i,
    input icqmem_ci_i,
    input [3:0] icqmem_sel_i,
    input [3:0] icqmem_tag_i,
    output [31:0] icqmem_dat_o,
    output icqmem_ack_o,
    output icqmem_rty_o,
    output icqmem_err_o,
    output [3:0] icqmem_tag_o,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input spr_cs,
    input spr_write,
    input [31:0] spr_dat_i
);

parameter OR1200_ITAG_BE = 4'b1111;

// Internal wires
wire [31:0] ic_addr;
wire [31:0] saved_addr;
wire icfsm_biu_read;
wire icfsm_burst;
wire icfsm_first_hit_ack;
wire icfsm_first_miss_ack;
wire icfsm_first_miss_err;
wire icram_we;
wire icfsm_tag_we;
wire tagcomp_miss;
wire [31:0] from_icram;
wire tag_v;
wire [18:0] tag;
wire ic_inv;
wire ictag_en;
wire ictag_we;
wire [8:0] ictag_addr;
wire [31:0] icqmem_dat_o_int;
reg [31:0] icqmem_dat_o;
reg icqmem_ack_o;
reg icqmem_err_o;
reg [3:0] icqmem_tag_o;
reg icqmem_rty_o;
reg [31:0] icbiu_dat_o;
reg icbiu_cyc_o;
reg icbiu_stb_o;
reg [3:0] icbiu_sel_o;
reg icbiu_cab_o;

// Address mux
assign ic_addr = icfsm_biu_read ? saved_addr : icqmem_adr_i;

// Tag comparison combinational logic
wire [3:0] tag31_28 = tag[18:15];
wire [4:0] tag27_23 = tag[14:10];
wire [4:0] tag22_18 = tag[9:5];
wire [4:0] tag17_13 = tag[4:0];
reg tagcomp_miss_reg;
always @(*) begin
    if (!tag_v)
        tagcomp_miss_reg = 1'b1;
    else if (tag31_28 != saved_addr[31:28])
        tagcomp_miss_reg = 1'b1;
    else if (tag27_23 != saved_addr[27:23])
        tagcomp_miss_reg = 1'b1;
    else if (tag22_18 != saved_addr[22:18])
        tagcomp_miss_reg = 1'b1;
    else if (tag17_13 != saved_addr[17:13])
        tagcomp_miss_reg = 1'b1;
    else
        tagcomp_miss_reg = 1'b0;
end
assign tagcomp_miss = tagcomp_miss_reg;

// SPR invalidation
assign ic_inv = spr_cs & spr_write;

// Tag RAM enable and write enable
assign ictag_en = ic_inv | ic_en;
assign ictag_we = icfsm_tag_we | ic_inv;

// Tag RAM address mux (write vs read)
assign ictag_addr = ic_inv ? spr_dat_i[12:4] : ic_addr[12:4];

// Tag RAM write data (valid inverted for invalidation)
wire [18:0] ictag_write_tag;
wire ictag_write_valid;
assign ictag_write_valid = ~ic_inv; // invalidation writes valid=0, refill writes valid=1
assign ictag_write_tag = ic_addr[31:13];

// Output muxes for BIU interface
wire icbiu_cyc_stb_comb;
wire [3:0] icbiu_sel_comb;
wire icbiu_cab_comb;
assign icbiu_cyc_stb_comb = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
assign icbiu_sel_comb = (ic_en & icfsm_biu_read) ? 4'b1111 : icqmem_sel_i;
assign icbiu_cab_comb = ic_en ? icfsm_burst : 1'b0;

always @(*) begin
    icbiu_dat_o = 32'd0;
    icbiu_cyc_o = icbiu_cyc_stb_comb;
    icbiu_stb_o = icbiu_cyc_stb_comb;
    icbiu_sel_o = icbiu_sel_comb;
    icbiu_cab_o = icbiu_cab_comb;
end

assign icbiu_we_o = 1'b0; // never write
assign icbiu_adr_o = ic_addr;

// QMEM response
reg icqmem_ack_reg, icqmem_err_reg;
wire [31:0] icqmem_dat_mux;
assign icqmem_dat_mux = (!ic_en) ? icbiu_dat_i :
                         (ic_en & icfsm_first_miss_ack) ? icbiu_dat_i : from_icram;

always @(*) begin
    icqmem_ack_o = ic_en ? (icfsm_first_hit_ack | icfsm_first_miss_ack) : icbiu_ack_i;
    icqmem_err_o = ic_en ? icfsm_first_miss_err : icbiu_err_i;
    icqmem_rty_o = ~icqmem_ack_o & ~icqmem_err_o;
    icqmem_dat_o = icqmem_dat_mux;
    // Tag output: error override
    icqmem_tag_o = icqmem_err_o ? OR1200_ITAG_BE : icqmem_tag_i;
end

// Submodule instantiations

or1200_ic_fsm u_ic_fsm(
    .clk(clk),
    .rst(rst),
    .ic_en(ic_en),
    .icqmem_cycstb_i(icqmem_cycstb_i),
    .icqmem_ci_i(icqmem_ci_i),
    .tagcomp_miss(tagcomp_miss),
    .icbiu_ack_i(icbiu_ack_i),
    .icbiu_err_i(icbiu_err_i),
    .icfsm_biu_read(icfsm_biu_read),
    .icfsm_burst(icfsm_burst),
    .icfsm_first_hit_ack(icfsm_first_hit_ack),
    .icfsm_first_miss_ack(icfsm_first_miss_ack),
    .icfsm_first_miss_err(icfsm_first_miss_err),
    .icram_we(icram_we),
    .icfsm_tag_we(icfsm_tag_we),
    .saved_addr(saved_addr)
);

or1200_ic_ram u_ic_ram(
    .clk(clk),
    .rst(rst),
    .addr(ic_addr[12:2]),
    .en(ic_en),
    .we(icram_we),
    .dat_i(icbiu_dat_i),
    .dat_o(from_icram)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_dram),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_ic_tag u_ic_tag(
    .clk(clk),
    .rst(rst),
    .addr(ictag_addr),
    .en(ictag_en),
    .we(ictag_we),
    .valid_in(ictag_write_valid),
    .tag_in(ictag_write_tag),
    .tag_v(tag_v),
    .tag(tag)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(mbist_so_dram),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

`ifdef OR1200_BIST
wire mbist_so_dram;
assign mbist_so_o = (OR1200_BIST) ? mbist_so_dram : 1'b0; // simplify, but actual chaining done in instantiations
`else
wire mbist_so_dummy;
`endif

endmodule

// Note: Submodule interfaces are defined here for completeness (though typically in separate files).
// For the top-level to compile, these submodules must exist. They are provided for simulation/synthesis.

// or1200_ic_fsm
module or1200_ic_fsm(
    input clk,
    input rst,
    input ic_en,
    input icqmem_cycstb_i,
    input icqmem_ci_i,
    input tagcomp_miss,
    input icbiu_ack_i,
    input icbiu_err_i,
    output reg icfsm_biu_read,
    output reg icfsm_burst,
    output reg icfsm_first_hit_ack,
    output reg icfsm_first_miss_ack,
    output reg icfsm_first_miss_err,
    output reg icram_we,
    output reg icfsm_tag_we,
    output reg [31:0] saved_addr
);
// Placeholder: implement actual FSM states and transitions
always @(posedge clk or posedge rst) begin
    if (rst) begin
        icfsm_biu_read <= 0;
        icfsm_burst <= 0;
        icfsm_first_hit_ack <= 0;
        icfsm_first_miss_ack <= 0;
        icfsm_first_miss_err <= 0;
        icram_we <= 0;
        icfsm_tag_we <= 0;
        saved_addr <= 0;
    end else begin
        // Minimal stub: always acknowledge hit
        icfsm_first_hit_ack <= icqmem_cycstb_i & ~tagcomp_miss & ic_en;
        icfsm_first_miss_ack <= 0;
        icfsm_first_miss_err <= 0;
        icram_we <= 0;
        icfsm_biu_read <= 0;
        icfsm_burst <= 0;
        icfsm_tag_we <= 0;
        saved_addr <= 0;
    end
end
endmodule

// or1200_ic_ram
module or1200_ic_ram(
    input clk,
    input rst,
    input [10:0] addr,
    input en,
    input we,
    input [31:0] dat_i,
    output [31:0] dat_o
);
reg [31:0] mem [0:2047];
reg [31:0] dat_o_reg;
always @(posedge clk) begin
    if (en & we) mem[addr] <= dat_i;
    if (en) dat_o_reg <= mem[addr];
end
assign dat_o = dat_o_reg;
endmodule

// or1200_ic_tag
module or1200_ic_tag(
    input clk,
    input rst,
    input [8:0] addr,
    input en,
    input we,
    input valid_in,
    input [18:0] tag_in,
    output tag_v,
    output [18:0] tag
);
reg tag_v_reg;
reg [18:0] tag_reg;
reg [18:0] mem_tag [0:511];
reg mem_v [0:511];
reg tag_v_out;
reg [18:0] tag_out;
always @(posedge clk) begin
    if (en & we) begin
        mem_v[addr] <= valid_in;
        mem_tag[addr] <= tag_in;
    end
    if (en) begin
        tag_v_out <= mem_v[addr];
        tag_out <= mem_tag[addr];
    end
end
assign tag_v = tag_v_out;
assign tag = tag_out;
endmodule

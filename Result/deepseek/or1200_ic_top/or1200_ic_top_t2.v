// or1200_ic_top - Instruction cache top-level module
module or1200_ic_top(
    // Rst, clk and clock control
    input clk,
    input rst,

    // External i/f
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

    // Internal i/f
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
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // SPRs
    input spr_cs,
    input spr_write,
    input [31:0] spr_dat_i
);

    // Local declarations
    wire [31:0] ic_addr;
    wire [31:0] saved_addr;
    wire [31:0] from_icram;
    wire [18:0] tag;
    wire tag_v;
    reg tagcomp_miss;
    wire icfsm_first_hit_ack;
    wire icfsm_first_miss_ack;
    wire icfsm_first_miss_err;
    wire icfsm_biu_read;
    wire icfsm_burst;
    wire icfsm_tag_we;
    wire icram_we;
    wire ic_inv;

    // FSM instance
    or1200_ic_fsm ic_fsm (
        .clk(clk),
        .rst(rst),
        .ic_en(ic_en),
        .icqmem_cycstb_i(icqmem_cycstb_i),
        .icqmem_ci_i(icqmem_ci_i),
        .icqmem_adr_i(icqmem_adr_i),
        .icbiu_ack_i(icbiu_ack_i),
        .icbiu_err_i(icbiu_err_i),
        .tagcomp_miss(tagcomp_miss),
        .saved_addr(saved_addr),
        .icfsm_first_hit_ack(icfsm_first_hit_ack),
        .icfsm_first_miss_ack(icfsm_first_miss_ack),
        .icfsm_first_miss_err(icfsm_first_miss_err),
        .icfsm_biu_read(icfsm_biu_read),
        .icfsm_burst(icfsm_burst),
        .icfsm_tag_we(icfsm_tag_we),
        .icram_we(icram_we)
    );

    // Address selection
    assign ic_addr = icfsm_biu_read ? saved_addr : icqmem_adr_i;

    // External BIU outputs
    assign icbiu_adr_o = ic_addr;
    assign icbiu_we_o = 1'b0;
    assign icbiu_dat_o = 32'h0;

    assign icbiu_cyc_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
    assign icbiu_stb_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
    assign icbiu_cab_o = ic_en ? icfsm_burst : 1'b0;
    assign icbiu_sel_o = ic_en ? (icfsm_biu_read ? 4'b1111 : icqmem_sel_i) : icqmem_sel_i;

    // Data RAM instance
    or1200_ic_ram ic_ram (
        .clk(clk),
        .rst(rst),
        .ic_en(ic_en),
        .ic_addr(ic_addr[12:2]),
        .icbiu_dat_i(icbiu_dat_i),
        .icram_we(icram_we),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_si_i),
        .mbist_ctrl_i(mbist_ctrl_i),
        .mbist_so_o(mbist_so_ram),
`endif
        .from_icram(from_icram)
    );

    // SPR invalidation logic
    assign ic_inv = spr_cs & spr_write;

    // Tag RAM enable and write strobe
    wire ictag_en = ic_inv | ic_en;
    wire ictag_we = icfsm_tag_we | ic_inv;

    // Tag RAM write address selection
    wire [8:0] ictag_wr_addr = ic_inv ? spr_dat_i[12:4] : ic_addr[12:4];

    // Tag RAM write data: tag field from ic_addr[31:13], valid bit is ~ic_inv
    wire [19:0] ictag_din = {ic_addr[31:13], ~ic_inv};

    // Tag RAM instance
    or1200_ic_tag ic_tag (
        .clk(clk),
        .rst(rst),
        .en(ictag_en),
        .we(ictag_we),
        .addr(ictag_wr_addr),
        .din(ictag_din),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_so_ram),
        .mbist_ctrl_i(mbist_ctrl_i),
        .mbist_so_o(mbist_so_o),
`endif
        .tag(tag),
        .tag_v(tag_v)
    );

    // Tag comparison logic
    always @* begin
        if (!tag_v)
            tagcomp_miss = 1'b1;
        else if (tag[3:0] != saved_addr[31:28])
            tagcomp_miss = 1'b1;
        else if (tag[8:4] != saved_addr[27:23])
            tagcomp_miss = 1'b1;
        else if (tag[13:9] != saved_addr[22:18])
            tagcomp_miss = 1'b1;
        else if (tag[18:14] != saved_addr[17:13])
            tagcomp_miss = 1'b1;
        else
            tagcomp_miss = 1'b0;
    end

    // CPU/QMEM response logic
    assign icqmem_ack_o = ic_en ? (icfsm_first_hit_ack | icfsm_first_miss_ack) : icbiu_ack_i;
    assign icqmem_err_o = ic_en ? icfsm_first_miss_err : icbiu_err_i;
    assign icqmem_rty_o = ~icqmem_ack_o & ~icqmem_err_o;

    // CPU/QMEM tag output
    wire [3:0] OR1200_ITAG_BE = 4'b0001; // Bus error tag value
    assign icqmem_tag_o = icqmem_err_o ? OR1200_ITAG_BE : icqmem_tag_i;

    // CPU/QMEM data output mux
    assign icqmem_dat_o = ic_en ? (icfsm_first_miss_ack ? icbiu_dat_i : from_icram) : icbiu_dat_i;

endmodule

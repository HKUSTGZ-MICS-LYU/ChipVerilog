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

    wire [31:0] saved_addr;
    wire icfsm_biu_read;
    wire icfsm_burst;
    wire icfsm_first_hit_ack;
    wire icfsm_first_miss_ack;
    wire icfsm_first_miss_err;
    wire icfsm_tag_we;
    wire icram_we;

    wire [31:0] ic_addr;
    wire [31:0] from_icram;
    wire tag_v;
    wire [18:0] tag;
    wire tagcomp_miss;
    reg tagcomp_miss;
    wire ic_inv;
    wire ictag_we;
    wire [8:0] ictag_wadr;
    wire ictag_wdat_v;
    wire ictag_en;
    wire icram_en;

    assign ic_inv = spr_cs & spr_write;

    assign ic_addr = icfsm_biu_read ? saved_addr : icqmem_adr_i;

    assign icbiu_adr_o = ic_addr;
    assign icbiu_we_o = 1'b0;
    assign icbiu_dat_o = 32'h00000000;

    assign icbiu_cyc_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
    assign icbiu_stb_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
    assign icbiu_sel_o = (ic_en & icfsm_biu_read) ? 4'b1111 : icqmem_sel_i;
    assign icbiu_cab_o = ic_en ? icfsm_burst : 1'b0;

    assign icqmem_ack_o = ic_en ? (icfsm_first_hit_ack | icfsm_first_miss_ack) : icbiu_ack_i;
    assign icqmem_err_o = ic_en ? icfsm_first_miss_err : icbiu_err_i;
    assign icqmem_rty_o = ~icqmem_ack_o & ~icqmem_err_o;

    assign icqmem_tag_o = icqmem_err_o ? 4'b0001 : icqmem_tag_i;

    assign icqmem_dat_o = (~ic_en | icfsm_first_miss_ack) ? icbiu_dat_i : from_icram;

    assign ictag_we = icfsm_tag_we | ic_inv;
    assign ictag_wadr = ic_inv ? spr_dat_i[12:4] : ic_addr[12:4];
    assign ictag_wdat_v = ~ic_inv;
    assign ictag_en = ic_inv | ic_en;

    assign icram_en = ic_en;

    always @* begin
        if (!tag_v) begin
            tagcomp_miss = 1'b1;
        end else begin
            if (tag[18:15] != saved_addr[31:28] ||
                tag[14:10] != saved_addr[27:23] ||
                tag[9:5]   != saved_addr[22:18] ||
                tag[4:0]   != saved_addr[17:13]) begin
                tagcomp_miss = 1'b1;
            end else begin
                tagcomp_miss = 1'b0;
            end
        end
    end

    or1200_ic_fsm ic_fsm (
        .clk(clk),
        .rst(rst),
        .ic_en(ic_en),
        .icqmem_adr_i(icqmem_adr_i),
        .icqmem_cycstb_i(icqmem_cycstb_i),
        .icqmem_ci_i(icqmem_ci_i),
        .icbiu_ack_i(icbiu_ack_i),
        .icbiu_err_i(icbiu_err_i),
        .tagcomp_miss(tagcomp_miss),
        .ic_addr(ic_addr),
        .saved_addr(saved_addr),
        .icfsm_biu_read(icfsm_biu_read),
        .icfsm_burst(icfsm_burst),
        .icfsm_first_hit_ack(icfsm_first_hit_ack),
        .icfsm_first_miss_ack(icfsm_first_miss_ack),
        .icfsm_first_miss_err(icfsm_first_miss_err),
        .icfsm_tag_we(icfsm_tag_we),
        .icram_we(icram_we)
    );

    or1200_ic_ram ic_ram (
        .clk(clk),
        .rst(rst),
        .en(icram_en),
        .adr(ic_addr[12:2]),
        .we(icram_we),
        .dat_i(icbiu_dat_i),
        .dat_o(from_icram)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(icram_mbist_so),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

    or1200_ic_tag ic_tag (
        .clk(clk),
        .rst(rst),
        .en(ictag_en),
        .adr(ictag_wadr),
        .we(ictag_we),
        .dat_v(ictag_wdat_v),
        .dat_tag(ic_addr[31:13]),
        .tag_v(tag_v),
        .tag(tag)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(icram_mbist_so),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

`ifndef OR1200_BIST
    assign mbist_so_o = 1'b0;
`endif

endmodule

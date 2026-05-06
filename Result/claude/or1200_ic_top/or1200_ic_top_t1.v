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

    wire tag_v;
    wire [18:0] tag;
    wire [31:0] to_icram;
    wire [31:0] from_icram;
    wire [31:0] saved_addr;
    wire [3:0] icram_we;
    wire ictag_we;
    wire [31:0] ic_addr;
    wire icfsm_biu_read;
    reg tagcomp_miss;
    wire [12:4] ictag_addr;
    wire ictag_en;
    wire ictag_v;
    wire ic_inv;
    wire icfsm_first_hit_ack;
    wire icfsm_first_miss_ack;
    wire icfsm_first_miss_err;
    wire icfsm_burst;
    wire icfsm_tag_we;
`ifdef OR1200_BIST
    wire mbist_ram_so;
    wire mbist_tag_so;
    wire mbist_ram_si = mbist_si_i;
    wire mbist_tag_si = mbist_ram_so;
`endif
    wire tag_comp_3;
    wire tag_comp_2;
    wire tag_comp_1;
    wire tag_comp_0;
    wire [12:2] addr_ic_ram;
    wire [31:12] ic_tag_datain;

    assign icbiu_we_o = 1'b0;
    assign icbiu_dat_o = 32'b0;

    assign addr_ic_ram = (ic_addr[12:2]);
    assign ic_tag_datain = ic_addr[31:12];

    assign ic_addr = icfsm_biu_read ? saved_addr : icqmem_adr_i;

    always @(*) begin
        tagcomp_miss = 1'b0;
        if (ic_en) begin
            if (~tag_v || (tag[18:12] != ic_addr[31:25]) ||
                (tag[11:5] != ic_addr[24:18]) ||
                (tag[4] != ic_addr[17]) ||
                (tag[3:0] != ic_addr[16:13])) begin
                tagcomp_miss = 1'b1;
            end
        end
    end

    assign tag_comp_0 = tagcomp_miss;
    assign tag_comp_1 = tag_comp_0;
    assign tag_comp_2 = tag_comp_1;
    assign tag_comp_3 = tag_comp_2;

    assign ic_inv = spr_cs & spr_write;

    assign ictag_addr = ic_inv ? spr_dat_i[12:4] : ic_addr[12:4];

    assign ictag_v = ic_inv ? 1'b0 : ictag_en;

    assign ictag_we = ic_inv | icfsm_tag_we;

    assign icbiu_adr_o = ic_addr;

    assign icbiu_cyc_o = ic_en ? (icfsm_biu_read | (icqmem_cycstb_i & ~ic_en)) : icqmem_cycstb_i;

    assign icbiu_stb_o = ic_en ? (icfsm_biu_read | (icqmem_cycstb_i & ~ic_en)) : icqmem_cycstb_i;

    assign icbiu_sel_o = ic_en ? (icfsm_biu_read ? 4'b1111 : icqmem_sel_i) : icqmem_sel_i;

    assign icbiu_cab_o = ic_en ? (icfsm_biu_read & icfsm_burst) : 1'b0;

    assign icqmem_dat_o = (icfsm_first_miss_ack | ~ic_en) ? icbiu_dat_i : from_icram;

    assign icqmem_ack_o = ic_en ? (icfsm_first_hit_ack | icfsm_first_miss_ack) : icbiu_ack_i;

    assign icqmem_rty_o = ~icqmem_ack_o & ~icqmem_err_o;

    assign icqmem_err_o = ic_en ? (icfsm_first_miss_err) : icbiu_err_i;

    assign icqmem_tag_o = icqmem_tag_i;

    assign to_icram = icbiu_dat_i;

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_tag_so;
`endif

endmodule

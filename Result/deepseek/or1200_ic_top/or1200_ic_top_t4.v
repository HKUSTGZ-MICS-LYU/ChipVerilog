module or1200_ic_top (
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

    //----------------------------------------------------------------
    // Local parameters
    //----------------------------------------------------------------
    localparam OR1200_ITAG_BE = 4'hF;

    //----------------------------------------------------------------
    // Internal wires and regs
    //----------------------------------------------------------------
    wire [31:0] saved_addr;
    wire        icfsm_first_hit_ack;
    wire        icfsm_first_miss_ack;
    wire        icfsm_first_miss_err;
    wire        icfsm_biu_read;
    wire        icfsm_burst;
    wire        icfsm_tag_we;
    wire        icram_we;
    wire        tagcomp_miss;

    wire        ic_inv;
    wire        ictag_we;
    wire        ictag_en;
    wire [8:0]  ictag_addr;   // address for tag RAM write (9 bits from address bits [12:4])
    wire [19:0] ictag_din;    // tag RAM write data: [19] = valid, [18:0] = tag

    wire [31:0] ic_addr;
    wire [31:0] from_icram;
    wire        tag_v;
    wire [18:0] tag;

    //----------------------------------------------------------------
    // Address mux
    //----------------------------------------------------------------
    assign ic_addr = icfsm_biu_read ? saved_addr : icqmem_adr_i;

    //----------------------------------------------------------------
    // BIU interface – external output control
    //----------------------------------------------------------------
    assign icbiu_dat_o = 32'b0;
    assign icbiu_we_o  = 1'b0;

    assign icbiu_cyc_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
    assign icbiu_stb_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
    assign icbiu_cab_o = ic_en ? icfsm_burst   : 1'b0;

    assign icbiu_sel_o = ic_en ? (icfsm_biu_read ? 4'b1111 : icqmem_sel_i) : icqmem_sel_i;

    assign icbiu_adr_o = ic_addr;

    //----------------------------------------------------------------
    // CPU/QMEM side response
    //----------------------------------------------------------------
    assign icqmem_ack_o = ic_en ? (icfsm_first_hit_ack | icfsm_first_miss_ack) : icbiu_ack_i;
    assign icqmem_err_o = ic_en ? icfsm_first_miss_err : icbiu_err_i;
    assign icqmem_rty_o = ~icqmem_ack_o & ~icqmem_err_o;
    assign icqmem_tag_o = icqmem_err_o ? OR1200_ITAG_BE : icqmem_tag_i;

    // Data return mux:
    // When cache disabled: direct from BIU data
    // When cache enabled and first miss ack: also direct from BIU data
    // Otherwise (cache enabled, not first miss ack): from cache data RAM
    assign icqmem_dat_o = (!ic_en)                          ? icbiu_dat_i :
                          (ic_en && icfsm_first_miss_ack)   ? icbiu_dat_i :
                                                              from_icram;

    //----------------------------------------------------------------
    // Tag comparison
    //----------------------------------------------------------------
    assign tagcomp_miss = ~tag_v | (tag[18:0] != saved_addr[31:13]);

    //----------------------------------------------------------------
    // SPR invalidation
    //----------------------------------------------------------------
    assign ic_inv = spr_cs & spr_write;

    assign ictag_en = ic_inv | ic_en;
    assign ictag_we = icfsm_tag_we | ic_inv;

    // Tag RAM write address mux: invalidation uses spr_dat_i[12:4], normal uses ic_addr[12:4]
    assign ictag_addr = ic_inv ? spr_dat_i[12:4] : ic_addr[12:4];

    // Tag RAM write data: normal {ic_addr[31:13], 1'b1}; invalidation {spr_dat_i[31:13], 1'b0}
    // Note: when invalidation, valid bit is 0; tag field from spr_dat_i is used.
    assign ictag_din = ic_inv ? {spr_dat_i[31:13], 1'b0} : {ic_addr[31:13], 1'b1};

    //----------------------------------------------------------------
    // Submodule instantiations
    //----------------------------------------------------------------

    // Instruction cache FSM
    or1200_ic_fsm u_ic_fsm (
        .clk(clk),
        .rst(rst),
        .ic_en(ic_en),
        .icqmem_cycstb_i(icqmem_cycstb_i),
        .icqmem_ci_i(icqmem_ci_i),
        .tagcomp_miss(tagcomp_miss),
        .icbiu_ack_i(icbiu_ack_i),
        .icbiu_err_i(icbiu_err_i),
        .saved_addr(saved_addr),
        .icfsm_first_hit_ack(icfsm_first_hit_ack),
        .icfsm_first_miss_ack(icfsm_first_miss_ack),
        .icfsm_first_miss_err(icfsm_first_miss_err),
        .icfsm_biu_read(icfsm_biu_read),
        .icfsm_burst(icfsm_burst),
        .icfsm_tag_we(icfsm_tag_we),
        .icram_we(icram_we)
    );

    // Instruction cache data RAM
    or1200_ic_ram u_ic_ram (
        .clk(clk),
        .rst(rst),
        .en(ic_en),
        .we(icram_we),
        .addr(ic_addr[12:2]),   // 11-bit address (word-aligned)
        .din(icbiu_dat_i),
        .dout(from_icram)
`ifdef OR1200_BIST
        ,
        .mbist_si(mbist_si_i),            // BIST input to data RAM
        .mbist_so(),                       // data RAM BIST output – connected to tag RAM
        .mbist_ctrl(mbist_ctrl_i)
`endif
    );

    // Instruction cache tag RAM
    // In BIST mode, the scan input to tag RAM comes from data RAM's scan output
`ifdef OR1200_BIST
    wire mbist_so_icram;
    assign u_ic_ram.mbist_so = mbist_so_icram;
`endif
    or1200_ic_tag u_ic_tag (
        .clk(clk),
        .rst(rst),
        .en(ictag_en),
        .we(ictag_we),
        .addr(ictag_addr),      // 9-bit address (line index)
        .din(ictag_din),
        .dout({tag_v, tag})
`ifdef OR1200_BIST
        ,
        .mbist_si(`ifdef OR1200_BIST mbist_so_icram `else 1'b0 `endif),
        .mbist_so(mbist_so_o),
        .mbist_ctrl(mbist_ctrl_i)
`endif
    );

`ifdef OR1200_BIST
    // Connect BIST chain: mbist_si -> data RAM -> tag RAM -> mbist_so
    // The data RAM's scan output is captured above.
    assign u_ic_ram.mbist_so = mbist_so_icram;
`endif

endmodule

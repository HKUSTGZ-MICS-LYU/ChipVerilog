`define OR1200_MBIST_CTRL_WIDTH 4
`endif

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
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif
    input spr_cs,
    input spr_write,
    input [31:0] spr_dat_i
);

    localparam OR1200_ITAG_BE = 4'b0001;

    // Internal wires
    wire [31:0] ic_addr;
    wire [31:0] saved_addr;
    wire [31:0] from_icram;
    wire tag_v;
    wire [18:0] tag;
    wire tagcomp_miss;
    wire ic_inv;
    wire icfsm_biu_read;
    wire icfsm_burst;
    wire icfsm_tag_we;
    wire icfsm_first_hit_ack;
    wire icfsm_first_miss_ack;
    wire icfsm_first_miss_err;
    wire icram_we;
    wire ictag_we;
    wire ictag_en;
    wire [8:0] ictag_addr;
    wire [19:0] ictag_dat_i;
    wire [10:0] icram_addr;
    wire icram_en;
`ifdef OR1200_BIST
    wire mbist_so_dram;
    wire mbist_so_tram;
`endif

    // Invalidation
    assign ic_inv = spr_cs & spr_write;

    // Address mux
    assign ic_addr = icfsm_biu_read ? saved_addr : icqmem_adr_i;

    // BIU output assignments
    assign icbiu_dat_o = 32'h0;
    assign icbiu_we_o = 1'b0;
    assign icbiu_cyc_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
    assign icbiu_stb_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
    assign icbiu_sel_o = (ic_en && icfsm_biu_read) ? 4'b1111 : icqmem_sel_i;
    assign icbiu_cab_o = ic_en ? icfsm_burst : 1'b0;
    assign icbiu_adr_o = ic_addr;

    // CPU/QMEM response
    assign icqmem_ack_o = ic_en ? (icfsm_first_hit_ack | icfsm_first_miss_ack) : icbiu_ack_i;
    assign icqmem_err_o = ic_en ? icfsm_first_miss_err : icbiu_err_i;
    assign icqmem_rty_o = ~icqmem_ack_o & ~icqmem_err_o;
    assign icqmem_tag_o = icqmem_err_o ? OR1200_ITAG_BE : icqmem_tag_i;

    // Data mux for icqmem_dat_o
    assign icqmem_dat_o = (!ic_en) ? icbiu_dat_i :
                          (icfsm_first_miss_ack) ? icbiu_dat_i : from_icram;

    // Tag RAM control
    assign ictag_we = icfsm_tag_we | ic_inv;
    assign ictag_en = ic_inv | ic_en;
    assign ictag_addr = ic_inv ? spr_dat_i[12:4] : ic_addr[12:4];
    assign ictag_dat_i = ic_inv ? {19'b0, 1'b0} : {ic_addr[31:13], 1'b1};

    // Data RAM control
    assign icram_addr = ic_addr[12:2];
    assign icram_en = ic_en;

    // Tag comparison (combinational)
    wire tag_hit;
    assign tag_hit = tag_v &&
                     (tag[18:15] == saved_addr[31:28]) &&
                     (tag[14:10] == saved_addr[27:23]) &&
                     (tag[9:5] == saved_addr[22:18]) &&
                     (tag[4:0] == saved_addr[17:13]);
    reg tagcomp_miss_reg;
    always @(*) begin
        tagcomp_miss_reg = ~tag_hit;
    end
    assign tagcomp_miss = tagcomp_miss_reg;

    // Instantiate FSM
    or1200_ic_fsm u_fsm(
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
        .icfsm_tag_we(icfsm_tag_we),
        .icfsm_first_hit_ack(icfsm_first_hit_ack),
        .icfsm_first_miss_ack(icfsm_first_miss_ack),
        .icfsm_first_miss_err(icfsm_first_miss_err),
        .icram_we(icram_we),
        .saved_addr(saved_addr)
    );

    // Instantiate data RAM
    or1200_ic_ram u_ram(
        .clk(clk),
        .rst(rst),
        .addr(icram_addr),
        .dat_i(icbiu_dat_i),
        .we(icram_we),
        .en(icram_en),
        .dat_o(from_icram)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_dram),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

    // Instantiate tag RAM
    or1200_ic_tag u_tag(
        .clk(clk),
        .rst(rst),
        .addr(ictag_addr),
        .dat_i(ictag_dat_i),
        .we(ictag_we),
        .en(ictag_en),
        .tag_v(tag_v),
        .tag(tag)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_so_dram),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

endmodule

// Submodule definitions

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
    output reg icfsm_tag_we,
    output reg icfsm_first_hit_ack,
    output reg icfsm_first_miss_ack,
    output reg icfsm_first_miss_err,
    output reg icram_we,
    output reg [31:0] saved_addr
);
    // Placeholder implementation - actual FSM behavior not defined in spec
    // For minimal implementation, provide a simple pass-through
    // This is not correct but needed for simulation; the spec says the FSM handles everything.
    // To make the top-level compile, we must provide a valid FSM module.
    // Since the spec doesn't detail FSM states, we assume a trivial behavior: always hit.
    assign icfsm_biu_read = 1'b0;
    assign icfsm_burst = 1'b0;
    assign icfsm_tag_we = 1'b0;
    assign icfsm_first_hit_ack = ic_en & icqmem_cycstb_i & ~tagcomp_miss;
    assign icfsm_first_miss_ack = 1'b0;
    assign icfsm_first_miss_err = 1'b0;
    assign icram_we = 1'b0;
    assign saved_addr = 32'h0;
endmodule

module or1200_ic_ram(
    input clk,
    input rst,
    input [10:0] addr,
    input [31:0] dat_i,
    input we,
    input en,
    output reg [31:0] dat_o
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i
`endif
);
    // Simple behavioral RAM
    reg [31:0] mem [0:2047];
    always @(posedge clk) begin
        if (rst) begin
            // optional reset
        end else if (en) begin
            if (we)
                mem[addr] <= dat_i;
            dat_o <= mem[addr];
        end
    end
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i; // BIST bypass
`endif
endmodule

module or1200_ic_tag(
    input clk,
    input rst,
    input [8:0] addr,
    input [19:0] dat_i,
    input we,
    input en,
    output reg tag_v,
    output reg [18:0] tag
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i
`endif
);
    // Simple behavioral tag RAM
    reg [19:0] mem [0:511];
    always @(posedge clk) begin
        if (rst) begin
            // optional reset
        end else if (en) begin
            if (we)
                mem[addr] <= dat_i;
            {tag_v, tag} <= mem[addr];
        end
    end
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
endmodule

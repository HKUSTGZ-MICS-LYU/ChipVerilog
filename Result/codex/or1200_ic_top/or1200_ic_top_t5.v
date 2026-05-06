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

wire [31:0] from_icram;
wire [18:0] tag;
wire tag_v;
wire [31:0] saved_addr;
wire [31:0] ic_addr;
wire icfsm_biu_read;
wire icfsm_burst;
wire icram_we;
wire icfsm_tag_we;
wire icfsm_first_hit_ack;
wire icfsm_first_miss_ack;
wire icfsm_first_miss_err;
wire ic_inv;
wire ictag_we;
wire ictag_en;
wire [8:0] ictag_addr;
wire ictag_v_in;
reg tagcomp_miss;
`ifdef OR1200_BIST
wire mbist_ram_so;
`endif

assign ic_inv = spr_cs & spr_write;
assign ic_addr = icfsm_biu_read ? saved_addr : icqmem_adr_i;
assign ictag_we = icfsm_tag_we | ic_inv;
assign ictag_en = ic_inv | ic_en;
assign ictag_addr = ic_inv ? spr_dat_i[12:4] : ic_addr[12:4];
assign ictag_v_in = ~ic_inv;

always @* begin
    tagcomp_miss = 1'b1;
    if (tag_v &&
        (tag[18:15] == saved_addr[31:28]) &&
        (tag[14:10] == saved_addr[27:23]) &&
        (tag[9:5] == saved_addr[22:18]) &&
        (tag[4:0] == saved_addr[17:13])) begin
        tagcomp_miss = 1'b0;
    end
end

assign icbiu_dat_o = 32'h0000_0000;
assign icbiu_adr_o = ic_addr;
assign icbiu_we_o = 1'b0;
assign icbiu_cyc_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
assign icbiu_stb_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
assign icbiu_cab_o = ic_en ? icfsm_burst : 1'b0;
assign icbiu_sel_o = ic_en ? (icfsm_biu_read ? 4'b1111 : icqmem_sel_i) : icqmem_sel_i;

assign icqmem_ack_o = ic_en ? (icfsm_first_hit_ack | icfsm_first_miss_ack) : icbiu_ack_i;
assign icqmem_err_o = ic_en ? icfsm_first_miss_err : icbiu_err_i;
assign icqmem_rty_o = ~icqmem_ack_o & ~icqmem_err_o;
assign icqmem_tag_o = icqmem_err_o ? `OR1200_ITAG_BE : icqmem_tag_i;
assign icqmem_dat_o = (!ic_en || icfsm_first_miss_ack) ? icbiu_dat_i : from_icram;

or1200_ic_fsm u_ic_fsm(
    .clk(clk),
    .rst(rst),
    .ic_en(ic_en),
    .icqmem_adr_i(icqmem_adr_i),
    .icqmem_cycstb_i(icqmem_cycstb_i),
    .icqmem_ci_i(icqmem_ci_i),
    .tagcomp_miss(tagcomp_miss),
    .icbiu_ack_i(icbiu_ack_i),
    .icbiu_err_i(icbiu_err_i),
    .saved_addr(saved_addr),
    .icram_we(icram_we),
    .tag_we(icfsm_tag_we),
    .biu_read(icfsm_biu_read),
    .burst(icfsm_burst),
    .first_hit_ack(icfsm_first_hit_ack),
    .first_miss_ack(icfsm_first_miss_ack),
    .first_miss_err(icfsm_first_miss_err)
);

or1200_ic_ram u_ic_ram(
    .clk(clk),
    .rst(rst),
    .en(ic_en),
    .addr(ic_addr[12:2]),
    .dat_i(icbiu_dat_i),
    .we(icram_we),
    .dat_o(from_icram)
`ifdef OR1200_BIST
    , .mbist_si_i(mbist_si_i)
    , .mbist_so_o(mbist_ram_so)
    , .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_ic_tag u_ic_tag(
    .clk(clk),
    .rst(rst),
    .en(ictag_en),
    .addr(ictag_addr),
    .tag_dat_i(ic_addr[31:13]),
    .tag_v_i(ictag_v_in),
    .we(ictag_we),
    .tag_v_o(tag_v),
    .tag_dat_o(tag)
`ifdef OR1200_BIST
    , .mbist_si_i(mbist_ram_so)
    , .mbist_so_o(mbist_so_o)
    , .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

endmodule

module or1200_ic_fsm(
    input clk,
    input rst,
    input ic_en,
    input [31:0] icqmem_adr_i,
    input icqmem_cycstb_i,
    input icqmem_ci_i,
    input tagcomp_miss,
    input icbiu_ack_i,
    input icbiu_err_i,
    output [31:0] saved_addr,
    output icram_we,
    output tag_we,
    output biu_read,
    output burst,
    output first_hit_ack,
    output first_miss_ack,
    output first_miss_err
);

localparam [0:0] S_IDLE = 1'b0;
localparam [0:0] S_MISS = 1'b1;

reg state;
reg miss_ci;
reg [31:0] miss_base_addr;
reg [1:0] miss_req_word;
reg [1:0] refill_count;
wire [1:0] refill_word;
wire [31:0] refill_addr;
wire hit_req;
wire miss_req;
wire last_refill_beat;

assign hit_req = ic_en & icqmem_cycstb_i & ~icqmem_ci_i & ~tagcomp_miss & (state == S_IDLE);
assign miss_req = ic_en & icqmem_cycstb_i & (icqmem_ci_i | tagcomp_miss) & (state == S_IDLE);
assign refill_word = miss_req_word + refill_count;
assign refill_addr = {miss_base_addr[31:4], refill_word, 2'b00};
assign saved_addr = (state == S_MISS) ? refill_addr : icqmem_adr_i;
assign biu_read = (state == S_MISS);
assign burst = (state == S_MISS) & ~miss_ci;
assign first_hit_ack = hit_req;
assign first_miss_ack = (state == S_MISS) & icbiu_ack_i & (refill_count == 2'b00);
assign first_miss_err = (state == S_MISS) & icbiu_err_i & (refill_count == 2'b00);
assign icram_we = (state == S_MISS) & icbiu_ack_i & ~miss_ci;
assign last_refill_beat = miss_ci | (refill_count == 2'b11);
assign tag_we = (state == S_MISS) & icbiu_ack_i & ~miss_ci & (refill_count == 2'b11);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;
        miss_ci <= 1'b0;
        miss_base_addr <= 32'h0000_0000;
        miss_req_word <= 2'b00;
        refill_count <= 2'b00;
    end
    else begin
        case (state)
            S_IDLE: begin
                refill_count <= 2'b00;
                if (miss_req) begin
                    state <= S_MISS;
                    miss_ci <= icqmem_ci_i;
                    miss_base_addr <= {icqmem_adr_i[31:4], 4'b0000};
                    miss_req_word <= icqmem_adr_i[3:2];
                end
            end
            S_MISS: begin
                if (icbiu_err_i) begin
                    state <= S_IDLE;
                    refill_count <= 2'b00;
                end
                else if (icbiu_ack_i) begin
                    if (last_refill_beat) begin
                        state <= S_IDLE;
                        refill_count <= 2'b00;
                    end
                    else begin
                        refill_count <= refill_count + 2'b01;
                    end
                end
            end
        endcase
    end
end

endmodule

module or1200_ic_ram(
    input clk,
    input rst,
    input en,
    input [10:0] addr,
    input [31:0] dat_i,
    input we,
    output [31:0] dat_o
`ifdef OR1200_BIST
    , input mbist_si_i
    , output mbist_so_o
    , input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

reg [31:0] mem [0:2047];

assign dat_o = en ? mem[addr] : 32'h0000_0000;

always @(posedge clk) begin
    if (en && we) begin
        mem[addr] <= dat_i;
    end
end

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

endmodule

module or1200_ic_tag(
    input clk,
    input rst,
    input en,
    input [8:0] addr,
    input [18:0] tag_dat_i,
    input tag_v_i,
    input we,
    output tag_v_o,
    output [18:0] tag_dat_o
`ifdef OR1200_BIST
    , input mbist_si_i
    , output mbist_so_o
    , input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

reg [19:0] mem [0:511];
wire [19:0] tag_word;

assign tag_word = en ? mem[addr] : 20'h00000;
assign tag_v_o = tag_word[0];
assign tag_dat_o = tag_word[19:1];

always @(posedge clk) begin
    if (en && we) begin
        mem[addr] <= {tag_dat_i, tag_v_i};
    end
end

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

endmodule

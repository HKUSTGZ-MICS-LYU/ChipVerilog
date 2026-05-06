`ifndef OR1200_ITAG_BE
`define OR1200_ITAG_BE 4'h1
`endif

`ifdef OR1200_BIST
`ifndef OR1200_MBIST_CTRL_WIDTH
`define OR1200_MBIST_CTRL_WIDTH 3
`endif
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
wire icfsm_first_hit_ack;
wire icfsm_first_miss_ack;
wire icfsm_first_miss_err;
wire icfsm_biu_read;
wire icfsm_burst;
wire icram_we;
wire icfsm_tag_we;
wire ic_inv;
wire ictag_en;
wire ictag_we;
wire [31:0] ic_addr;
wire [8:0] ictag_addr;
wire [18:0] ictag_dat;
wire ictag_v;
reg tagcomp_miss;
`ifdef OR1200_BIST
wire icram_mbist_so;
`endif

assign ic_inv = spr_cs & spr_write;
assign ictag_en = ic_inv | ic_en;
assign ictag_we = icfsm_tag_we | ic_inv;
assign ic_addr = icfsm_biu_read ? saved_addr : icqmem_adr_i;
assign ictag_addr = ic_inv ? spr_dat_i[12:4] : ic_addr[12:4];
assign ictag_dat = ic_inv ? spr_dat_i[31:13] : ic_addr[31:13];
assign ictag_v = ~ic_inv;

always @* begin
    if (!tag_v)
        tagcomp_miss = 1'b1;
    else if (tag[18:15] != saved_addr[31:28])
        tagcomp_miss = 1'b1;
    else if (tag[14:10] != saved_addr[27:23])
        tagcomp_miss = 1'b1;
    else if (tag[9:5] != saved_addr[22:18])
        tagcomp_miss = 1'b1;
    else if (tag[4:0] != saved_addr[17:13])
        tagcomp_miss = 1'b1;
    else
        tagcomp_miss = 1'b0;
end

assign icbiu_dat_o = 32'b0;
assign icbiu_adr_o = ic_addr;
assign icbiu_cyc_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
assign icbiu_stb_o = ic_en ? icfsm_biu_read : icqmem_cycstb_i;
assign icbiu_we_o = 1'b0;
assign icbiu_sel_o = (ic_en && icfsm_biu_read) ? 4'b1111 : icqmem_sel_i;
assign icbiu_cab_o = ic_en ? icfsm_burst : 1'b0;

assign icqmem_dat_o = (!ic_en || icfsm_first_miss_ack) ? icbiu_dat_i : from_icram;
assign icqmem_ack_o = ic_en ? (icfsm_first_hit_ack | icfsm_first_miss_ack) : icbiu_ack_i;
assign icqmem_err_o = ic_en ? icfsm_first_miss_err : icbiu_err_i;
assign icqmem_rty_o = ~icqmem_ack_o & ~icqmem_err_o;
assign icqmem_tag_o = icqmem_err_o ? `OR1200_ITAG_BE : icqmem_tag_i;

or1200_ic_fsm u_ic_fsm(
    .clk(clk),
    .rst(rst),
    .icqmem_adr_i(icqmem_adr_i),
    .icqmem_cycstb_i(icqmem_cycstb_i),
    .icqmem_ci_i(icqmem_ci_i),
    .tagcomp_miss(tagcomp_miss),
    .icbiu_ack_i(icbiu_ack_i),
    .icbiu_err_i(icbiu_err_i),
    .saved_addr_o(saved_addr),
    .icfsm_first_hit_ack_o(icfsm_first_hit_ack),
    .icfsm_first_miss_ack_o(icfsm_first_miss_ack),
    .icfsm_first_miss_err_o(icfsm_first_miss_err),
    .icfsm_biu_read_o(icfsm_biu_read),
    .icfsm_burst_o(icfsm_burst),
    .icram_we_o(icram_we),
    .ictag_we_o(icfsm_tag_we)
);

or1200_ic_ram u_ic_ram(
    .clk(clk),
    .rst(rst),
    .en(ic_en),
    .we(icram_we),
    .addr(ic_addr[12:2]),
    .dat_i(icbiu_dat_i),
    .dat_o(from_icram)
`ifdef OR1200_BIST
    , .mbist_si_i(mbist_si_i),
    .mbist_so_o(icram_mbist_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_ic_tag u_ic_tag(
    .clk(clk),
    .rst(rst),
    .en(ictag_en),
    .we(ictag_we),
    .addr(ictag_addr),
    .tag_dat_i(ictag_dat),
    .tag_v_i(ictag_v),
    .tag_dat_o(tag),
    .tag_v_o(tag_v)
`ifdef OR1200_BIST
    , .mbist_si_i(icram_mbist_so),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

endmodule

module or1200_ic_fsm(
    input clk,
    input rst,
    input [31:0] icqmem_adr_i,
    input icqmem_cycstb_i,
    input icqmem_ci_i,
    input tagcomp_miss,
    input icbiu_ack_i,
    input icbiu_err_i,
    output [31:0] saved_addr_o,
    output icfsm_first_hit_ack_o,
    output icfsm_first_miss_ack_o,
    output icfsm_first_miss_err_o,
    output icfsm_biu_read_o,
    output icfsm_burst_o,
    output icram_we_o,
    output ictag_we_o
);

localparam [1:0] S_IDLE = 2'd0;
localparam [1:0] S_CI   = 2'd1;
localparam [1:0] S_FILL = 2'd2;

reg [1:0] state;
reg [31:0] ci_addr;
reg [31:0] miss_addr;
reg [1:0] refill_word;
reg [2:0] refill_count;
reg [31:0] saved_addr_r;

assign saved_addr_o = saved_addr_r;
assign icfsm_first_hit_ack_o = (state == S_IDLE) & icqmem_cycstb_i & ~icqmem_ci_i & ~tagcomp_miss;
assign icfsm_first_miss_ack_o = ((state == S_CI) & icbiu_ack_i) |
                                ((state == S_FILL) & icbiu_ack_i & (refill_count == 3'd0));
assign icfsm_first_miss_err_o = ((state == S_CI) & icbiu_err_i) |
                                ((state == S_FILL) & icbiu_err_i & (refill_count == 3'd0));
assign icfsm_biu_read_o = (state == S_CI) | (state == S_FILL);
assign icfsm_burst_o = (state == S_FILL);
assign icram_we_o = (state == S_FILL) & icbiu_ack_i;
assign ictag_we_o = (state == S_FILL) & icbiu_ack_i & (refill_count == 3'd3);

always @* begin
    case (state)
        S_CI:   saved_addr_r = ci_addr;
        S_FILL: saved_addr_r = {miss_addr[31:4], refill_word, 2'b00};
        default: saved_addr_r = icqmem_adr_i;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;
        ci_addr <= 32'b0;
        miss_addr <= 32'b0;
        refill_word <= 2'b00;
        refill_count <= 3'b000;
    end else begin
        case (state)
            S_IDLE: begin
                if (icqmem_cycstb_i && icqmem_ci_i) begin
                    state <= S_CI;
                    ci_addr <= icqmem_adr_i;
                end else if (icqmem_cycstb_i && tagcomp_miss) begin
                    state <= S_FILL;
                    miss_addr <= icqmem_adr_i;
                    refill_word <= icqmem_adr_i[3:2];
                    refill_count <= 3'b000;
                end
            end
            S_CI: begin
                if (icbiu_ack_i || icbiu_err_i)
                    state <= S_IDLE;
            end
            S_FILL: begin
                if (icbiu_err_i) begin
                    state <= S_IDLE;
                end else if (icbiu_ack_i) begin
                    if (refill_count == 3'd3) begin
                        state <= S_IDLE;
                    end else begin
                        refill_count <= refill_count + 3'd1;
                        refill_word <= refill_word + 2'd1;
                    end
                end
            end
            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule

module or1200_ic_ram(
    input clk,
    input rst,
    input en,
    input we,
    input [10:0] addr,
    input [31:0] dat_i,
    output [31:0] dat_o
`ifdef OR1200_BIST
    , input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

reg [31:0] mem [0:2047];

assign dat_o = en ? mem[addr] : 32'b0;

always @(posedge clk) begin
    if (we && en)
        mem[addr] <= dat_i;
end

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
wire [`OR1200_MBIST_CTRL_WIDTH - 1:0] unused_mbist_ctrl;
assign unused_mbist_ctrl = mbist_ctrl_i;
`endif
wire unused_rst;
assign unused_rst = rst;

endmodule

module or1200_ic_tag(
    input clk,
    input rst,
    input en,
    input we,
    input [8:0] addr,
    input [18:0] tag_dat_i,
    input tag_v_i,
    output [18:0] tag_dat_o,
    output tag_v_o
`ifdef OR1200_BIST
    , input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

reg [18:0] tag_mem [0:511];
reg valid_mem [0:511];
integer i;

assign tag_dat_o = en ? tag_mem[addr] : 19'b0;
assign tag_v_o = en ? valid_mem[addr] : 1'b0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < 512; i = i + 1) begin
            tag_mem[i] <= 19'b0;
            valid_mem[i] <= 1'b0;
        end
    end else if (we && en) begin
        tag_mem[addr] <= tag_dat_i;
        valid_mem[addr] <= tag_v_i;
    end
end

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
wire [`OR1200_MBIST_CTRL_WIDTH - 1:0] unused_mbist_ctrl;
assign unused_mbist_ctrl = mbist_ctrl_i;
`endif

endmodule

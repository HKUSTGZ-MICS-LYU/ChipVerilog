module or1200_qmem_top(
    input clk,
    input rst,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input [31:0] qmemimmu_adr_i,
    input qmemimmu_cycstb_i,
    input qmemimmu_ci_i,
    input [3:0] qmemicpu_sel_i,
    input [3:0] qmemicpu_tag_i,
    output [31:0] qmemicpu_dat_o,
    output qmemicpu_ack_o,
    output qmemimmu_rty_o,
    output qmemimmu_err_o,
    output [3:0] qmemimmu_tag_o,
    output [31:0] icqmem_adr_o,
    output icqmem_cycstb_o,
    output icqmem_ci_o,
    output [3:0] icqmem_sel_o,
    output [3:0] icqmem_tag_o,
    input [31:0] icqmem_dat_i,
    input icqmem_ack_i,
    input icqmem_rty_i,
    input icqmem_err_i,
    input [3:0] icqmem_tag_i,
    input [31:0] qmemdmmu_adr_i,
    input qmemdmmu_cycstb_i,
    input qmemdmmu_ci_i,
    input qmemdcpu_we_i,
    input [3:0] qmemdcpu_sel_i,
    input [3:0] qmemdcpu_tag_i,
    input [31:0] qmemdcpu_dat_i,
    output [31:0] qmemdcpu_dat_o,
    output qmemdcpu_ack_o,
    output qmemdcpu_rty_o,
    output qmemdmmu_err_o,
    output [3:0] qmemdmmu_tag_o,
    output [31:0] dcqmem_adr_o,
    output dcqmem_cycstb_o,
    output dcqmem_ci_o,
    output dcqmem_we_o,
    output [3:0] dcqmem_sel_o,
    output [3:0] dcqmem_tag_o,
    output [31:0] dcqmem_dat_o,
    input [31:0] dcqmem_dat_i,
    input dcqmem_ack_i,
    input dcqmem_rty_i,
    input dcqmem_err_i,
    input [3:0] dcqmem_tag_i
);

`ifdef OR1200_QMEM_IMPLEMENTED
    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] STORE = 3'd1;
    localparam [2:0] LOAD  = 3'd2;
    localparam [2:0] FETCH = 3'd3;

    wire iaddr_qmem_hit;
    wire daddr_qmem_hit;
    reg [2:0] state;
    reg qmem_dack;
    reg qmem_iack;
    wire [31:0] qmem_di;
    wire [31:0] qmem_do;
    wire qmem_en;
    wire qmem_we;
    wire [3:0] qmem_sel;
    wire [31:0] qmem_addr;
    wire qmem_ack;
`ifdef OR1200_BIST
    wire mbist_so_qmem;
`endif

`ifdef OR1200_QMEM_IADDR
    assign iaddr_qmem_hit = ((qmemimmu_adr_i & `OR1200_QMEM_IMASK) == `OR1200_QMEM_IADDR);
`else
    assign iaddr_qmem_hit = 1'b0;
`endif

`ifdef OR1200_QMEM_DADDR
    assign daddr_qmem_hit = ((qmemdmmu_adr_i & `OR1200_QMEM_DMASK) == `OR1200_QMEM_DADDR);
`else
    assign daddr_qmem_hit = 1'b0;
`endif

    assign icqmem_adr_o    = iaddr_qmem_hit ? 32'b0 : qmemimmu_adr_i;
    assign icqmem_cycstb_o = iaddr_qmem_hit ? 1'b0  : qmemimmu_cycstb_i;
    assign icqmem_ci_o     = iaddr_qmem_hit ? 1'b0  : qmemimmu_ci_i;
    assign icqmem_sel_o    = iaddr_qmem_hit ? 4'b0  : qmemicpu_sel_i;
    assign icqmem_tag_o    = iaddr_qmem_hit ? 4'b0  : qmemicpu_tag_i;

    assign qmemicpu_dat_o  = qmem_iack ? qmem_do      : icqmem_dat_i;
    assign qmemicpu_ack_o  = qmem_iack ? 1'b1         : icqmem_ack_i;
    assign qmemimmu_rty_o  = qmem_iack ? 1'b0         : icqmem_rty_i;
    assign qmemimmu_err_o  = qmem_iack ? 1'b0         : icqmem_err_i;
    assign qmemimmu_tag_o  = qmem_iack ? 4'b0         : icqmem_tag_i;

    assign dcqmem_adr_o    = daddr_qmem_hit ? 32'b0 : qmemdmmu_adr_i;
    assign dcqmem_cycstb_o = daddr_qmem_hit ? 1'b0  : qmemdmmu_cycstb_i;
    assign dcqmem_ci_o     = daddr_qmem_hit ? 1'b0  : qmemdmmu_ci_i;
    assign dcqmem_we_o     = daddr_qmem_hit ? 1'b0  : qmemdcpu_we_i;
    assign dcqmem_sel_o    = daddr_qmem_hit ? 4'b0  : qmemdcpu_sel_i;
    assign dcqmem_tag_o    = daddr_qmem_hit ? 4'b0  : qmemdcpu_tag_i;
    assign dcqmem_dat_o    = daddr_qmem_hit ? 32'b0 : qmemdcpu_dat_i;

    assign qmemdcpu_dat_o  = daddr_qmem_hit ? qmem_do      : dcqmem_dat_i;
    assign qmemdcpu_ack_o  = daddr_qmem_hit ? qmem_dack    : dcqmem_ack_i;
    assign qmemdcpu_rty_o  = daddr_qmem_hit ? ~qmem_dack   : dcqmem_rty_i;
    assign qmemdmmu_err_o  = daddr_qmem_hit ? 1'b0         : dcqmem_err_i;
    assign qmemdmmu_tag_o  = daddr_qmem_hit ? 4'b0         : dcqmem_tag_i;

    assign qmem_en   = (qmemimmu_cycstb_i & iaddr_qmem_hit) |
                       (qmemdmmu_cycstb_i & daddr_qmem_hit);
    assign qmem_we   = qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i;
    assign qmem_di   = qmemdcpu_dat_i;
    assign qmem_addr = (qmemdmmu_cycstb_i & daddr_qmem_hit) ? qmemdmmu_adr_i : qmemimmu_adr_i;
`ifdef OR1200_QMEM_BSEL
    assign qmem_sel  = (qmemdmmu_cycstb_i & daddr_qmem_hit) ? qmemdcpu_sel_i : qmemicpu_sel_i;
`else
    assign qmem_sel  = 4'hf;
`endif

`ifndef OR1200_QMEM_ACK
    assign qmem_ack = 1'b1;
`endif

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            qmem_dack <= 1'b0;
            qmem_iack <= 1'b0;
        end else if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i & qmem_ack) begin
            state <= STORE;
            qmem_dack <= 1'b1;
            qmem_iack <= 1'b0;
        end else if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmem_ack) begin
            state <= LOAD;
            qmem_dack <= 1'b1;
            qmem_iack <= 1'b0;
        end else if (qmemimmu_cycstb_i & iaddr_qmem_hit & qmem_ack) begin
            state <= FETCH;
            qmem_dack <= 1'b0;
            qmem_iack <= 1'b1;
        end else begin
            state <= IDLE;
            qmem_dack <= 1'b0;
            qmem_iack <= 1'b0;
        end
    end

    or1200_spram_2048x32 qmem_ram (
        .clk(clk),
        .ce(qmem_en),
        .we(qmem_we),
        .oe(1'b1),
        .addr(qmem_addr[12:2]),
        .di(qmem_di),
        .do(qmem_do)
`ifdef OR1200_QMEM_BSEL
      , .sel(qmem_sel)
`endif
`ifdef OR1200_QMEM_ACK
      , .ack(qmem_ack)
`endif
`ifdef OR1200_BIST
      , .mbist_si_i(mbist_si_i)
      , .mbist_so_o(mbist_so_qmem)
      , .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_so_qmem;
`endif

`else
    assign icqmem_adr_o    = qmemimmu_adr_i;
    assign icqmem_cycstb_o = qmemimmu_cycstb_i;
    assign icqmem_ci_o     = qmemimmu_ci_i;
    assign icqmem_sel_o    = qmemicpu_sel_i;
    assign icqmem_tag_o    = qmemicpu_tag_i;

    assign qmemicpu_dat_o  = icqmem_dat_i;
    assign qmemicpu_ack_o  = icqmem_ack_i;
    assign qmemimmu_rty_o  = icqmem_rty_i;
    assign qmemimmu_err_o  = icqmem_err_i;
    assign qmemimmu_tag_o  = icqmem_tag_i;

    assign dcqmem_adr_o    = qmemdmmu_adr_i;
    assign dcqmem_cycstb_o = qmemdmmu_cycstb_i;
    assign dcqmem_ci_o     = qmemdmmu_ci_i;
    assign dcqmem_we_o     = qmemdcpu_we_i;
    assign dcqmem_sel_o    = qmemdcpu_sel_i;
    assign dcqmem_tag_o    = qmemdcpu_tag_i;
    assign dcqmem_dat_o    = qmemdcpu_dat_i;

    assign qmemdcpu_dat_o  = dcqmem_dat_i;
    assign qmemdcpu_ack_o  = dcqmem_ack_i;
    assign qmemdcpu_rty_o  = dcqmem_rty_i;
    assign qmemdmmu_err_o  = dcqmem_err_i;
    assign qmemdmmu_tag_o  = dcqmem_tag_i;
`ifdef OR1200_BIST
    assign mbist_so_o = 1'b0;
`endif
`endif

endmodule

module or1200_spram_2048x32(
    input clk,
    input ce,
    input we,
    input oe,
    input [10:0] addr,
    input [31:0] di,
    output reg [31:0] do
`ifdef OR1200_QMEM_BSEL
  , input [3:0] sel
`endif
`ifdef OR1200_QMEM_ACK
  , output ack
`endif
`ifdef OR1200_BIST
  , input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

    reg [31:0] mem [0:2047];

    always @(posedge clk) begin
        if (ce) begin
            if (we) begin
`ifdef OR1200_QMEM_BSEL
                if (sel[0])
                    mem[addr][7:0] <= di[7:0];
                if (sel[1])
                    mem[addr][15:8] <= di[15:8];
                if (sel[2])
                    mem[addr][23:16] <= di[23:16];
                if (sel[3])
                    mem[addr][31:24] <= di[31:24];
`else
                mem[addr] <= di;
`endif
            end
            if (oe)
                do <= mem[addr];
        end
    end

`ifdef OR1200_QMEM_ACK
    assign ack = ce;
`endif
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

endmodule

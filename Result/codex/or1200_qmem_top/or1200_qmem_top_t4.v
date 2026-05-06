`include "or1200_defines.v"

module or1200_qmem_top(
    input         clk,
    input         rst,
`ifdef OR1200_BIST
    input         mbist_si_i,
    output        mbist_so_o,
    input  [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input  [31:0] qmemimmu_adr_i,
    input         qmemimmu_cycstb_i,
    input         qmemimmu_ci_i,
    input  [3:0]  qmemicpu_sel_i,
    input  [3:0]  qmemicpu_tag_i,
    output [31:0] qmemicpu_dat_o,
    output        qmemicpu_ack_o,
    output        qmemimmu_rty_o,
    output        qmemimmu_err_o,
    output [3:0]  qmemimmu_tag_o,
    output [31:0] icqmem_adr_o,
    output        icqmem_cycstb_o,
    output        icqmem_ci_o,
    output [3:0]  icqmem_sel_o,
    output [3:0]  icqmem_tag_o,
    input  [31:0] icqmem_dat_i,
    input         icqmem_ack_i,
    input         icqmem_rty_i,
    input         icqmem_err_i,
    input  [3:0]  icqmem_tag_i,
    input  [31:0] qmemdmmu_adr_i,
    input         qmemdmmu_cycstb_i,
    input         qmemdmmu_ci_i,
    input         qmemdcpu_we_i,
    input  [3:0]  qmemdcpu_sel_i,
    input  [3:0]  qmemdcpu_tag_i,
    input  [31:0] qmemdcpu_dat_i,
    output [31:0] qmemdcpu_dat_o,
    output        qmemdcpu_ack_o,
    output        qmemdcpu_rty_o,
    output        qmemdmmu_err_o,
    output [3:0]  qmemdmmu_tag_o,
    output [31:0] dcqmem_adr_o,
    output        dcqmem_cycstb_o,
    output        dcqmem_ci_o,
    output        dcqmem_we_o,
    output [3:0]  dcqmem_sel_o,
    output [3:0]  dcqmem_tag_o,
    output [31:0] dcqmem_dat_o,
    input  [31:0] dcqmem_dat_i,
    input         dcqmem_ack_i,
    input         dcqmem_rty_i,
    input         dcqmem_err_i,
    input  [3:0]  dcqmem_tag_i
);

`ifdef OR1200_QMEM_IMPLEMENTED
reg [31:0] qmem [0:2047];
reg [1:0] state;
reg qmem_iack;
reg qmem_dack;
wire iaddr_qmem_hit = ((qmemimmu_adr_i & `OR1200_QMEM_IMASK) == (`OR1200_QMEM_IADDR & `OR1200_QMEM_IMASK));
wire daddr_qmem_hit = ((qmemdmmu_adr_i & `OR1200_QMEM_DMASK) == (`OR1200_QMEM_DADDR & `OR1200_QMEM_DMASK));
wire ireq = iaddr_qmem_hit & qmemimmu_cycstb_i;
wire dreq = daddr_qmem_hit & qmemdmmu_cycstb_i;
wire [31:0] qmem_addr = dreq ? qmemdmmu_adr_i : qmemimmu_adr_i;
wire [10:0] qmem_word_addr = qmem_addr[12:2];
wire [31:0] qmem_do = qmem[qmem_word_addr];
localparam IDLE=2'd0, STORE=2'd1, LOAD=2'd2, FETCH=2'd3;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        qmem_iack <= 1'b0;
        qmem_dack <= 1'b0;
    end else begin
        qmem_iack <= 1'b0;
        qmem_dack <= 1'b0;
        if (dreq && qmemdcpu_we_i) begin
            state <= STORE;
            qmem_dack <= 1'b1;
            qmem[qmemdmmu_adr_i[12:2]] <= qmemdcpu_dat_i;
        end else if (dreq) begin
            state <= LOAD;
            qmem_dack <= 1'b1;
        end else if (ireq) begin
            state <= FETCH;
            qmem_iack <= 1'b1;
        end else begin
            state <= IDLE;
        end
    end
end

assign qmemicpu_dat_o = iaddr_qmem_hit ? qmem_do : icqmem_dat_i;
assign qmemicpu_ack_o = iaddr_qmem_hit ? qmem_iack : icqmem_ack_i;
assign qmemimmu_rty_o = iaddr_qmem_hit ? 1'b0 : icqmem_rty_i;
assign qmemimmu_err_o = iaddr_qmem_hit ? 1'b0 : icqmem_err_i;
assign qmemimmu_tag_o = iaddr_qmem_hit ? 4'b0 : icqmem_tag_i;
assign icqmem_adr_o = iaddr_qmem_hit ? 32'b0 : qmemimmu_adr_i;
assign icqmem_cycstb_o = iaddr_qmem_hit ? 1'b0 : qmemimmu_cycstb_i;
assign icqmem_ci_o = iaddr_qmem_hit ? 1'b0 : qmemimmu_ci_i;
assign icqmem_sel_o = iaddr_qmem_hit ? 4'b0 : qmemicpu_sel_i;
assign icqmem_tag_o = iaddr_qmem_hit ? 4'b0 : qmemicpu_tag_i;

assign qmemdcpu_dat_o = daddr_qmem_hit ? qmem_do : dcqmem_dat_i;
assign qmemdcpu_ack_o = daddr_qmem_hit ? qmem_dack : dcqmem_ack_i;
assign qmemdcpu_rty_o = daddr_qmem_hit ? 1'b0 : dcqmem_rty_i;
assign qmemdmmu_err_o = daddr_qmem_hit ? 1'b0 : dcqmem_err_i;
assign qmemdmmu_tag_o = daddr_qmem_hit ? 4'b0 : dcqmem_tag_i;
assign dcqmem_adr_o = daddr_qmem_hit ? 32'b0 : qmemdmmu_adr_i;
assign dcqmem_cycstb_o = daddr_qmem_hit ? 1'b0 : qmemdmmu_cycstb_i;
assign dcqmem_ci_o = daddr_qmem_hit ? 1'b0 : qmemdmmu_ci_i;
assign dcqmem_we_o = daddr_qmem_hit ? 1'b0 : qmemdcpu_we_i;
assign dcqmem_sel_o = daddr_qmem_hit ? 4'b0 : qmemdcpu_sel_i;
assign dcqmem_tag_o = daddr_qmem_hit ? 4'b0 : qmemdcpu_tag_i;
assign dcqmem_dat_o = daddr_qmem_hit ? 32'b0 : qmemdcpu_dat_i;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
`else
assign qmemicpu_dat_o = icqmem_dat_i;
assign qmemicpu_ack_o = icqmem_ack_i;
assign qmemimmu_rty_o = icqmem_rty_i;
assign qmemimmu_err_o = icqmem_err_i;
assign qmemimmu_tag_o = icqmem_tag_i;
assign icqmem_adr_o = qmemimmu_adr_i;
assign icqmem_cycstb_o = qmemimmu_cycstb_i;
assign icqmem_ci_o = qmemimmu_ci_i;
assign icqmem_sel_o = qmemicpu_sel_i;
assign icqmem_tag_o = qmemicpu_tag_i;
assign qmemdcpu_dat_o = dcqmem_dat_i;
assign qmemdcpu_ack_o = dcqmem_ack_i;
assign qmemdcpu_rty_o = dcqmem_rty_i;
assign qmemdmmu_err_o = dcqmem_err_i;
assign qmemdmmu_tag_o = dcqmem_tag_i;
assign dcqmem_adr_o = qmemdmmu_adr_i;
assign dcqmem_cycstb_o = qmemdmmu_cycstb_i;
assign dcqmem_ci_o = qmemdmmu_ci_i;
assign dcqmem_we_o = qmemdcpu_we_i;
assign dcqmem_sel_o = qmemdcpu_sel_i;
assign dcqmem_tag_o = qmemdcpu_tag_i;
assign dcqmem_dat_o = qmemdcpu_dat_i;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
`endif

endmodule

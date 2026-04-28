`include "timescale.v"
`include "or1200_defines.v"

module or1200_qmem_top(
    clk, rst,
`ifdef OR1200_BIST
    mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif
    qmemimmu_adr_i, qmemimmu_cycstb_i, qmemimmu_ci_i,
    qmemicpu_sel_i, qmemicpu_tag_i,
    qmemicpu_dat_o, qmemicpu_ack_o,
    qmemimmu_rty_o, qmemimmu_err_o, qmemimmu_tag_o,
    icqmem_adr_o, icqmem_cycstb_o, icqmem_ci_o,
    icqmem_sel_o, icqmem_tag_o,
    icqmem_dat_i, icqmem_ack_i, icqmem_rty_i, icqmem_err_i, icqmem_tag_i,
    qmemdmmu_adr_i, qmemdmmu_cycstb_i, qmemdmmu_ci_i,
    qmemdcpu_we_i, qmemdcpu_sel_i, qmemdcpu_tag_i, qmemdcpu_dat_i,
    qmemdcpu_dat_o, qmemdcpu_ack_o, qmemdcpu_rty_o,
    qmemdmmu_err_o, qmemdmmu_tag_o,
    dcqmem_adr_o, dcqmem_cycstb_o, dcqmem_ci_o, dcqmem_we_o,
    dcqmem_sel_o, dcqmem_tag_o, dcqmem_dat_o,
    dcqmem_dat_i, dcqmem_ack_i, dcqmem_rty_i, dcqmem_err_i, dcqmem_tag_i
);

input         clk, rst;
`ifdef OR1200_BIST
input         mbist_si_i;
output        mbist_so_o;
input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i;
`endif
input  [31:0] qmemimmu_adr_i;
input         qmemimmu_cycstb_i, qmemimmu_ci_i;
input  [3:0]  qmemicpu_sel_i, qmemicpu_tag_i;
output [31:0] qmemicpu_dat_o;
output        qmemicpu_ack_o, qmemimmu_rty_o, qmemimmu_err_o;
output [3:0]  qmemimmu_tag_o;
output [31:0] icqmem_adr_o;
output        icqmem_cycstb_o, icqmem_ci_o;
output [3:0]  icqmem_sel_o, icqmem_tag_o;
input  [31:0] icqmem_dat_i;
input         icqmem_ack_i, icqmem_rty_i, icqmem_err_i;
input  [3:0]  icqmem_tag_i;
input  [31:0] qmemdmmu_adr_i;
input         qmemdmmu_cycstb_i, qmemdmmu_ci_i, qmemdcpu_we_i;
input  [3:0]  qmemdcpu_sel_i, qmemdcpu_tag_i;
input  [31:0] qmemdcpu_dat_i;
output [31:0] qmemdcpu_dat_o;
output        qmemdcpu_ack_o, qmemdcpu_rty_o, qmemdmmu_err_o;
output [3:0]  qmemdmmu_tag_o;
output [31:0] dcqmem_adr_o;
output        dcqmem_cycstb_o, dcqmem_ci_o, dcqmem_we_o;
output [3:0]  dcqmem_sel_o, dcqmem_tag_o;
output [31:0] dcqmem_dat_o;
input  [31:0] dcqmem_dat_i;
input         dcqmem_ack_i, dcqmem_rty_i, dcqmem_err_i;
input  [3:0]  dcqmem_tag_i;

`ifdef OR1200_QMEM_IMPLEMENTED

// FSM states
`define OR1200_QMEMFSM_IDLE  3'd0
`define OR1200_QMEMFSM_STORE 3'd1
`define OR1200_QMEMFSM_LOAD  3'd2
`define OR1200_QMEMFSM_FETCH 3'd3

reg [2:0] state;
reg       qmem_dack, qmem_iack;

// Address hit detection
`ifdef OR1200_QMEM_IADDR
wire iaddr_qmem_hit = ((qmemimmu_adr_i & `OR1200_QMEM_IMASK) == `OR1200_QMEM_IADDR);
`else
wire iaddr_qmem_hit = 1'b0;
`endif

`ifdef OR1200_QMEM_DADDR
wire daddr_qmem_hit = ((qmemdmmu_adr_i & `OR1200_QMEM_DMASK) == `OR1200_QMEM_DADDR);
`else
wire daddr_qmem_hit = 1'b0;
`endif

// Local RAM control
wire qmem_en   = (qmemimmu_cycstb_i & iaddr_qmem_hit) |
                 (qmemdmmu_cycstb_i & daddr_qmem_hit);
wire qmem_we   = qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i;
wire [31:0] qmem_di   = qmemdcpu_dat_i;
wire [31:0] qmem_addr = (qmemdmmu_cycstb_i & daddr_qmem_hit) ?
                        qmemdmmu_adr_i : qmemimmu_adr_i;

`ifdef OR1200_QMEM_BSEL
wire [3:0] qmem_sel = (qmemdmmu_cycstb_i & daddr_qmem_hit) ?
                      qmemdcpu_sel_i : qmemicpu_sel_i;
`else
wire [3:0] qmem_sel = 4'b1111;
`endif

`ifdef OR1200_QMEM_ACK
wire qmem_ack;
`else
wire qmem_ack = 1'b1;
`endif

wire [31:0] qmem_do;

// FSM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state     <= `OR1200_QMEMFSM_IDLE;
        qmem_dack <= 1'b0;
        qmem_iack <= 1'b0;
    end else begin
        // Priority: data write > data read > instruction fetch
        if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i & qmem_ack) begin
            state     <= `OR1200_QMEMFSM_STORE;
            qmem_dack <= 1'b1;
            qmem_iack <= 1'b0;
        end
        else if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmem_ack) begin
            state     <= `OR1200_QMEMFSM_LOAD;
            qmem_dack <= 1'b1;
            qmem_iack <= 1'b0;
        end
        else if (qmemimmu_cycstb_i & iaddr_qmem_hit & qmem_ack) begin
            state     <= `OR1200_QMEMFSM_FETCH;
            qmem_iack <= 1'b1;
            qmem_dack <= 1'b0;
        end
        else begin
            state     <= `OR1200_QMEMFSM_IDLE;
            qmem_dack <= 1'b0;
            qmem_iack <= 1'b0;
        end
    end
end

// IC request: forward if instruction miss, suppress if hit
assign icqmem_adr_o    = iaddr_qmem_hit ? 32'h0 : qmemimmu_adr_i;
assign icqmem_cycstb_o = iaddr_qmem_hit ? 1'b0  : qmemimmu_cycstb_i;
assign icqmem_ci_o     = iaddr_qmem_hit ? 1'b0  : qmemimmu_ci_i;
assign icqmem_sel_o    = iaddr_qmem_hit ? 4'h0  : qmemicpu_sel_i;
assign icqmem_tag_o    = iaddr_qmem_hit ? 4'h0  : qmemicpu_tag_i;

// Instruction-side return (gated by qmem_iack)
assign qmemicpu_dat_o  = qmem_iack ? qmem_do     : icqmem_dat_i;
assign qmemicpu_ack_o  = qmem_iack ? 1'b1        : icqmem_ack_i;
assign qmemimmu_rty_o  = qmem_iack ? 1'b0        : icqmem_rty_i;
assign qmemimmu_err_o  = qmem_iack ? 1'b0        : icqmem_err_i;
assign qmemimmu_tag_o  = qmem_iack ? 4'h0        : icqmem_tag_i;

// DC request: forward if data miss, suppress if hit
assign dcqmem_adr_o    = daddr_qmem_hit ? 32'h0 : qmemdmmu_adr_i;
assign dcqmem_cycstb_o = daddr_qmem_hit ? 1'b0  : qmemdmmu_cycstb_i;
assign dcqmem_ci_o     = daddr_qmem_hit ? 1'b0  : qmemdmmu_ci_i;
assign dcqmem_we_o     = daddr_qmem_hit ? 1'b0  : qmemdcpu_we_i;
assign dcqmem_sel_o    = daddr_qmem_hit ? 4'h0  : qmemdcpu_sel_i;
assign dcqmem_tag_o    = daddr_qmem_hit ? 4'h0  : qmemdcpu_tag_i;
assign dcqmem_dat_o    = daddr_qmem_hit ? 32'h0 : qmemdcpu_dat_i;

// Data-side return
assign qmemdcpu_dat_o  = daddr_qmem_hit ? qmem_do    : dcqmem_dat_i;
assign qmemdcpu_ack_o  = daddr_qmem_hit ? qmem_dack  : dcqmem_ack_i;
assign qmemdcpu_rty_o  = daddr_qmem_hit ? ~qmem_dack : dcqmem_rty_i;
assign qmemdmmu_err_o  = daddr_qmem_hit ? 1'b0       : dcqmem_err_i;
assign qmemdmmu_tag_o  = daddr_qmem_hit ? 4'h0       : dcqmem_tag_i;

// QMEM SRAM
or1200_spram_2048x32 or1200_qmem_ram(
    .clk(clk),
    .rst(rst),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .ce(qmem_en),
    .we(qmem_we),
    .oe(1'b1),
    .addr(qmem_addr[12:2]),
    .di(qmem_di),
    .doq(qmem_do)
);

`ifdef OR1200_QMEM_ACK
assign qmem_ack = qmem_do_valid; // placeholder if RAM provides ack
`endif

`else // !OR1200_QMEM_IMPLEMENTED

// Pure pass-through
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
assign mbist_so_o = mbist_si_i;
`endif

`endif // OR1200_QMEM_IMPLEMENTED

endmodule
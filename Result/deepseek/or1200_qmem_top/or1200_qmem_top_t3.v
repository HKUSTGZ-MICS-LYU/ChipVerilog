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

// Internal signals
wire iaddr_qmem_hit;
wire daddr_qmem_hit;
reg [1:0] state;
reg qmem_dack;
reg qmem_iack;
wire [31:0] qmem_di;
wire [31:0] qmem_do;
wire qmem_en;
wire qmem_we;
wire [3:0] qmem_sel;
wire [31:0] qmem_addr;
wire qmem_ack_q; // renamed to avoid conflict with the assign below

`ifdef OR1200_QMEM_IMPLEMENTED

// Parameters for FSM states
localparam IDLE = 2'b00;
localparam STORE = 2'b01;
localparam LOAD = 2'b10;
localparam FETCH = 2'b11;

// Address hit detection
`ifdef OR1200_QMEM_IADDR
assign iaddr_qmem_hit = (qmemimmu_adr_i & `OR1200_QMEM_IMASK) == `OR1200_QMEM_IADDR;
`else
assign iaddr_qmem_hit = 1'b0;
`endif

`ifdef OR1200_QMEM_DADDR
assign daddr_qmem_hit = (qmemdmmu_adr_i & `OR1200_QMEM_DMASK) == `OR1200_QMEM_DADDR;
`else
assign daddr_qmem_hit = 1'b0;
`endif

// qmem_en: valid QMEM request from either side
assign qmem_en = (qmemimmu_cycstb_i & iaddr_qmem_hit) | (qmemdmmu_cycstb_i & daddr_qmem_hit);

// qmem_we: data-side write only
assign qmem_we = qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i;

// qmem_di: always from data write data
assign qmem_di = qmemdcpu_dat_i;

// qmem_addr: data side gets priority
assign qmem_addr = (qmemdmmu_cycstb_i & daddr_qmem_hit) ? qmemdmmu_adr_i : qmemimmu_adr_i;

// qmem_sel: conditionally from data or instruction 
`ifdef OR1200_QMEM_BSEL
assign qmem_sel = (qmemdmmu_cycstb_i & daddr_qmem_hit) ? qmemdcpu_sel_i : qmemicpu_sel_i;
`else
assign qmem_sel = 4'b1111; // default all bytes enabled if not used
`endif

// qmem_ack: either from RAM or tied to 1
`ifdef OR1200_QMEM_ACK
wire qmem_ack;
// Connect the RAM's ack output to qmem_ack.
// The RAM instantiation below will have qmem_ack as output.
assign qmem_ack = qmem_ack_q; // qmem_ack_q comes from RAM, see instantiation
`else
wire qmem_ack = 1'b1;
`endif

// FSM for local ack generation
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        qmem_dack <= 1'b0;
        qmem_iack <= 1'b0;
    end else begin
        // Default: stay in same state unless new request
        // Priority: data write, then data read, then instruction fetch
        if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i & qmem_ack) begin
            state <= STORE;
            qmem_dack <= 1'b1;
            qmem_iack <= 1'b0;
        end else if (qmemdmmu_cycstb_i & daddr_qmem_hit & ~qmemdcpu_we_i & qmem_ack) begin
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
end

// Instruction-side outputs to IC: forced to 0 on hit, pass-through on miss
assign icqmem_adr_o    = iaddr_qmem_hit ? 32'd0 : qmemimmu_adr_i;
assign icqmem_cycstb_o = iaddr_qmem_hit ? 1'b0   : qmemimmu_cycstb_i;
assign icqmem_ci_o     = iaddr_qmem_hit ? 1'b0   : qmemimmu_ci_i;
assign icqmem_sel_o    = iaddr_qmem_hit ? 4'd0   : qmemicpu_sel_i;
assign icqmem_tag_o    = iaddr_qmem_hit ? 4'd0   : qmemicpu_tag_i;

// Instruction-side return: local if qmem_iack, else from IC
assign qmemicpu_dat_o  = qmem_iack ? qmem_do : icqmem_dat_i;
assign qmemicpu_ack_o  = qmem_iack ? 1'b1   : icqmem_ack_i;
assign qmemimmu_rty_o  = qmem_iack ? 1'b0   : icqmem_rty_i;
assign qmemimmu_err_o  = qmem_iack ? 1'b0   : icqmem_err_i;
assign qmemimmu_tag_o  = qmem_iack ? 4'd0   : icqmem_tag_i;

// Data-side outputs to DC: forced to 0 on hit, pass-through on miss
assign dcqmem_adr_o    = daddr_qmem_hit ? 32'd0 : qmemdmmu_adr_i;
assign dcqmem_cycstb_o = daddr_qmem_hit ? 1'b0   : qmemdmmu_cycstb_i;
assign dcqmem_ci_o     = daddr_qmem_hit ? 1'b0   : qmemdmmu_ci_i;
assign dcqmem_we_o     = daddr_qmem_hit ? 1'b0   : qmemdcpu_we_i;
assign dcqmem_sel_o    = daddr_qmem_hit ? 4'd0   : qmemdcpu_sel_i;
assign dcqmem_tag_o    = daddr_qmem_hit ? 4'd0   : qmemdcpu_tag_i;
assign dcqmem_dat_o    = daddr_qmem_hit ? 32'd0  : qmemdcpu_dat_i;

// Data-side return: dat always from RAM if hit, but ack/rty/tag/error as specified
assign qmemdcpu_dat_o  = daddr_qmem_hit ? qmem_do : dcqmem_dat_i;
assign qmemdcpu_ack_o  = daddr_qmem_hit ? qmem_dack : dcqmem_ack_i;
assign qmemdcpu_rty_o  = daddr_qmem_hit ? ~qmem_dack : dcqmem_rty_i;
assign qmemdmmu_err_o  = daddr_qmem_hit ? 1'b0 : dcqmem_err_i;
assign qmemdmmu_tag_o  = daddr_qmem_hit ? 4'd0 : dcqmem_tag_i;

// Instantiate the single-port SRAM
// The RAM module is assumed to have ports: clk, rst, addr, di, do, en, we, sel, ack, and optional BIST
// We'll set output enable to 1 (fixed) as per specification.
`ifdef OR1200_QMEM_ACK
// If ack is used, we need to capture the ack from RAM
wire qmem_ack_from_ram;
assign qmem_ack_q = qmem_ack_from_ram;
`else
wire qmem_ack_unused;
assign qmem_ack_q = 1'b1; // tie high if not used
`endif

or1200_spram_2048x32 #(
`ifdef OR1200_BIST
    .BIST_EN(1)
`else
    .BIST_EN(0)
`endif
) qmem_ram (
    .clk(clk),
    .rst(rst),
    .addr(qmem_addr[12:2]),
    .di(qmem_di),
    .do(qmem_do),
    .en(qmem_en),
    .we(qmem_we),
    .sel(qmem_sel),
`ifdef OR1200_QMEM_ACK
    .ack(qmem_ack_from_ram),
`endif
    .oe(1'b1)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

`else // OR1200_QMEM_IMPLEMENTED not defined -> pass-through

// No local RAM, no hit detection, no FSM.
// Instruction side: CPU/IMMU -> IC
assign icqmem_adr_o    = qmemimmu_adr_i;
assign icqmem_cycstb_o = qmemimmu_cycstb_i;
assign icqmem_ci_o     = qmemimmu_ci_i;
assign icqmem_sel_o    = qmemicpu_sel_i;
assign icqmem_tag_o    = qmemicpu_tag_i;
// Instruction return: IC -> CPU/IMMU
assign qmemicpu_dat_o  = icqmem_dat_i;
assign qmemicpu_ack_o  = icqmem_ack_i;
assign qmemimmu_rty_o  = icqmem_rty_i;
assign qmemimmu_err_o  = icqmem_err_i;
assign qmemimmu_tag_o  = icqmem_tag_i;

// Data side: CPU/DMMU -> DC
assign dcqmem_adr_o    = qmemdmmu_adr_i;
assign dcqmem_cycstb_o = qmemdmmu_cycstb_i;
assign dcqmem_ci_o     = qmemdmmu_ci_i;
assign dcqmem_we_o     = qmemdcpu_we_i;
assign dcqmem_sel_o    = qmemdcpu_sel_i;
assign dcqmem_tag_o    = qmemdcpu_tag_i;
assign dcqmem_dat_o    = qmemdcpu_dat_i;
// Data return: DC -> CPU/DMMU
assign qmemdcpu_dat_o  = dcqmem_dat_i;
assign qmemdcpu_ack_o  = dcqmem_ack_i;
assign qmemdcpu_rty_o  = dcqmem_rty_i;
assign qmemdmmu_err_o  = dcqmem_err_i;
assign qmemdmmu_tag_o  = dcqmem_tag_i;

// Tie unused internal signals
assign iaddr_qmem_hit = 1'b0;
assign daddr_qmem_hit = 1'b0;
assign qmem_en = 1'b0;
assign qmem_we = 1'b0;
assign qmem_sel = 4'd0;
assign qmem_addr = 32'd0;
assign qmem_di = 32'd0;
assign qmem_ack = 1'b0; // not used

`endif // OR1200_QMEM_IMPLEMENTED

endmodule

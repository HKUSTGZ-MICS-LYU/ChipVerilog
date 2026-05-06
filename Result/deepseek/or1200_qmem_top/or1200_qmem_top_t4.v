module or1200_qmem_top (
    input clk,
    input rst,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
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

endmodule
`endif

`ifdef OR1200_QMEM_IMPLEMENTED
module or1200_qmem_top (
    input clk,
    input rst,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
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
    wire iaddr_qmem_hit;
    wire daddr_qmem_hit;
    localparam [2:0] IDLE  = 3'b000,
                     STORE = 3'b001,
                     LOAD  = 3'b010,
                     FETCH = 3'b011;
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

    // Address hit detection
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

    // Local RAM control signals
    assign qmem_en = (qmemimmu_cycstb_i & iaddr_qmem_hit) | (qmemdmmu_cycstb_i & daddr_qmem_hit);
    assign qmem_we = qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i;
    assign qmem_di = qmemdcpu_dat_i;
    assign qmem_addr = (qmemdmmu_cycstb_i & daddr_qmem_hit) ? qmemdmmu_adr_i : qmemimmu_adr_i;

`ifdef OR1200_QMEM_BSEL
    assign qmem_sel = (qmemdmmu_cycstb_i & daddr_qmem_hit) ? qmemdcpu_sel_i : qmemicpu_sel_i;
`else
    assign qmem_sel = qmemicpu_sel_i;
`endif

`ifdef OR1200_QMEM_ACK
    // The RAM would drive this; assume 1 for now
    assign qmem_ack = 1'b1;
`else
    assign qmem_ack = 1'b1;
`endif

    // FSM for local acknowledge
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            qmem_dack <= 1'b0;
            qmem_iack <= 1'b0;
        end else begin
            if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i & qmem_ack) begin
                state <= STORE;
            end else if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmem_ack) begin
                state <= LOAD;
            end else if (qmemimmu_cycstb_i & iaddr_qmem_hit & qmem_ack) begin
                state <= FETCH;
            end else begin
                state <= IDLE;
            end
            // Local dack and iack derived from state
            qmem_dack <= (state == STORE) || (state == LOAD);
            qmem_iack <= (state == FETCH);
        end
    end

    // Single-port SRAM instantiation (2048x32)
`ifdef OR1200_BIST
    or1200_spram_2048x32 qmem_ram (
        .clk    (clk),
        .rst    (rst),
        .ce     (qmem_en),
        .we     (qmem_we),
        .oe     (1'b1),
        .addr   (qmem_addr[12:2]),
        .di     (qmem_di),
        .doq    (qmem_do),
        .mbist_si_i    (mbist_si_i),
        .mbist_so_o    (mbist_so_o),
        .mbist_ctrl_i  (mbist_ctrl_i)
    );
`else
    or1200_spram_2048x32 qmem_ram (
        .clk    (clk),
        .rst    (rst),
        .ce     (qmem_en),
        .we     (qmem_we),
        .oe     (1'b1),
        .addr   (qmem_addr[12:2]),
        .di     (qmem_di),
        .doq    (qmem_do)
    );
`endif

    // Instruction-side output signals
    // IC path
    assign icqmem_adr_o    = iaddr_qmem_hit ? 32'b0 : qmemimmu_adr_i;
    assign icqmem_cycstb_o = iaddr_qmem_hit ? 1'b0 : qmemimmu_cycstb_i;
    assign icqmem_ci_o     = iaddr_qmem_hit ? 1'b0 : qmemimmu_ci_i;
    assign icqmem_sel_o    = iaddr_qmem_hit ? 4'b0 : qmemicpu_sel_i;
    assign icqmem_tag_o    = iaddr_qmem_hit ? 4'b0 : qmemicpu_tag_i;
    // CPU return path
    assign qmemicpu_dat_o  = qmem_iack ? qmem_do : icqmem_dat_i;
    assign qmemicpu_ack_o  = qmem_iack ? 1'b1 : icqmem_ack_i;
    assign qmemimmu_rty_o  = qmem_iack ? 1'b0 : icqmem_rty_i;
    assign qmemimmu_err_o  = qmem_iack ? 1'b0 : icqmem_err_i;
    assign qmemimmu_tag_o  = qmem_iack ? 4'b0 : icqmem_tag_i;

    // Data-side output signals
    // DC path
    assign dcqmem_adr_o    = daddr_qmem_hit ? 32'b0 : qmemdmmu_adr_i;
    assign dcqmem_cycstb_o = daddr_qmem_hit ? 1'b0 : qmemdmmu_cycstb_i;
    assign dcqmem_ci_o     = daddr_qmem_hit ? 1'b0 : qmemdmmu_ci_i;
    assign dcqmem_we_o     = daddr_qmem_hit ? 1'b0 : qmemdcpu_we_i;
    assign dcqmem_sel_o    = daddr_qmem_hit ? 4'b0 : qmemdcpu_sel_i;
    assign dcqmem_tag_o    = daddr_qmem_hit ? 4'b0 : qmemdcpu_tag_i;
    assign dcqmem_dat_o    = daddr_qmem_hit ? 32'b0 : qmemdcpu_dat_i;
    // CPU return path
    assign qmemdcpu_dat_o  = daddr_qmem_hit ? qmem_do : dcqmem_dat_i;
    assign qmemdcpu_ack_o  = daddr_qmem_hit ? qmem_dack : dcqmem_ack_i;
    assign qmemdcpu_rty_o  = daddr_qmem_hit ? ~qmem_dack : dcqmem_rty_i;
    assign qmemdmmu_err_o  = daddr_qmem_hit ? 1'b0 : dcqmem_err_i;
    assign qmemdmmu_tag_o  = daddr_qmem_hit ? 4'b0 : dcqmem_tag_i;

endmodule
`endif

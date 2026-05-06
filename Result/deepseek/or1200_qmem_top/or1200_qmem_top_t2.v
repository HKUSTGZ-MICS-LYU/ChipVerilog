// or1200_qmem_top.v -- QMEM top-level interface module for OR1200

module or1200_qmem_top(
    // Rst, clk and clock control
    input clk,
    input rst,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // QMEM and CPU/IMMU
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

    // QMEM and IC
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

    // QMEM and CPU/DMMU
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

    // QMEM and DC
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

    // Local QMEM address hit signals
    wire iaddr_qmem_hit;
    wire daddr_qmem_hit;

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

    // Qualified local request signals
    wire ireq_qmem = qmemimmu_cycstb_i & iaddr_qmem_hit;
    wire dreq_qmem = qmemdmmu_cycstb_i & daddr_qmem_hit;
    wire dwr_qmem  = dreq_qmem & qmemdcpu_we_i;

    // Local SRAM control signals
    wire qmem_en;
    wire qmem_we;
    wire [3:0]  qmem_sel;
    wire [31:0] qmem_addr;
    wire [31:0] qmem_di;
    wire [31:0] qmem_do;
    wire qmem_ack;

    // qmem_ack: always 1 when QMEM_ACK is not defined, else connected to RAM ack
`ifdef OR1200_QMEM_ACK
    // In this implementation, the RAM does not provide an explicit ack output, so we tie to 1.
    // If a real RAM ack signal were available, it would be connected here.
    assign qmem_ack = 1'b1;
`else
    assign qmem_ack = 1'b1;
`endif

    // qmem_en is asserted if any qualified access exists
    assign qmem_en = ireq_qmem | dreq_qmem;

    // qmem_we is asserted only for a valid data write
    assign qmem_we = dwr_qmem;

    // qmem_di always from data write data
    assign qmem_di = qmemdcpu_dat_i;

    // qmem_addr: priority to data side
    assign qmem_addr = dreq_qmem ? qmemdmmu_adr_i : qmemimmu_adr_i;

    // qmem_sel: priority to data side when BSEL is defined
`ifdef OR1200_QMEM_BSEL
    assign qmem_sel = dreq_qmem ? qmemdcpu_sel_i : qmemicpu_sel_i;
`else
    assign qmem_sel = 4'b0; // not used if no byte select
`endif

    // Instantiate the single-port SRAM
    or1200_spram_2048x32 qmem_ram (
        .clk(clk),
        .ce(qmem_en),
        .we(qmem_we),
        .oe(1'b1),
        .addr(qmem_addr[12:2]),
        .di(qmem_di),
        .do(qmem_do)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

    // FSM state definitions
    localparam [2:0] IDLE  = 3'd0,
                     STORE = 3'd1,
                     LOAD  = 3'd2,
                     FETCH = 3'd3;

    reg [2:0] state;
    reg qmem_dack;
    reg qmem_iack;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            qmem_dack <= 1'b0;
            qmem_iack <= 1'b0;
        end else begin
            // Default values
            qmem_dack <= 1'b0;
            qmem_iack <= 1'b0;

            // Priority arbitration: data write > data read > instruction fetch
            if (dwr_qmem & qmem_ack) begin
                // Data write request
                state <= STORE;
                qmem_dack <= 1'b1;
                qmem_iack <= 1'b0;
            end else if (dreq_qmem & qmem_ack) begin
                // Data read request (non-write)
                state <= LOAD;
                qmem_dack <= 1'b1;
                qmem_iack <= 1'b0;
            end else if (ireq_qmem & qmem_ack) begin
                // Instruction fetch request
                state <= FETCH;
                qmem_dack <= 1'b0;
                qmem_iack <= 1'b1;
            end else begin
                // No valid acknowledged request
                state <= IDLE;
                qmem_dack <= 1'b0;
                qmem_iack <= 1'b0;
            end
        end
    end

    // --- IC request path ---
    assign icqmem_adr_o    = iaddr_qmem_hit ? 32'd0 : qmemimmu_adr_i;
    assign icqmem_cycstb_o = iaddr_qmem_hit ? 1'b0  : qmemimmu_cycstb_i;
    assign icqmem_ci_o     = iaddr_qmem_hit ? 1'b0  : qmemimmu_ci_i;
    assign icqmem_sel_o    = iaddr_qmem_hit ? 4'd0  : qmemicpu_sel_i;
    assign icqmem_tag_o    = iaddr_qmem_hit ? 4'd0  : qmemicpu_tag_i;

    // --- Instruction-side return path ---
    assign qmemicpu_dat_o  = qmem_iack ? qmem_do       : icqmem_dat_i;
    assign qmemicpu_ack_o  = qmem_iack ? 1'b1          : icqmem_ack_i;
    assign qmemimmu_rty_o  = qmem_iack ? 1'b0          : icqmem_rty_i;
    assign qmemimmu_err_o  = qmem_iack ? 1'b0          : icqmem_err_i;
    assign qmemimmu_tag_o  = qmem_iack ? 4'd0          : icqmem_tag_i;

    // --- DC request path ---
    assign dcqmem_adr_o    = daddr_qmem_hit ? 32'd0 : qmemdmmu_adr_i;
    assign dcqmem_cycstb_o = daddr_qmem_hit ? 1'b0  : qmemdmmu_cycstb_i;
    assign dcqmem_ci_o     = daddr_qmem_hit ? 1'b0  : qmemdmmu_ci_i;
    assign dcqmem_we_o     = daddr_qmem_hit ? 1'b0  : qmemdcpu_we_i;
    assign dcqmem_sel_o    = daddr_qmem_hit ? 4'd0  : qmemdcpu_sel_i;
    assign dcqmem_tag_o    = daddr_qmem_hit ? 4'd0  : qmemdcpu_tag_i;
    assign dcqmem_dat_o    = daddr_qmem_hit ? 32'd0 : qmemdcpu_dat_i;

    // --- Data-side return path ---
    assign qmemdcpu_dat_o  = daddr_qmem_hit ? qmem_do       : dcqmem_dat_i;
    assign qmemdcpu_ack_o  = daddr_qmem_hit ? qmem_dack     : dcqmem_ack_i;
    assign qmemdcpu_rty_o  = daddr_qmem_hit ? ~qmem_dack    : dcqmem_rty_i;
    assign qmemdmmu_err_o  = daddr_qmem_hit ? 1'b0          : dcqmem_err_i;
    assign qmemdmmu_tag_o  = daddr_qmem_hit ? 4'd0          : dcqmem_tag_i;

`else // !OR1200_QMEM_IMPLEMENTED

    // Pure pass-through mode

    // IC direction
    assign icqmem_adr_o    = qmemimmu_adr_i;
    assign icqmem_cycstb_o = qmemimmu_cycstb_i;
    assign icqmem_ci_o     = qmemimmu_ci_i;
    assign icqmem_sel_o    = qmemicpu_sel_i;
    assign icqmem_tag_o    = qmemicpu_tag_i;

    // Instruction-side return
    assign qmemicpu_dat_o  = icqmem_dat_i;
    assign qmemicpu_ack_o  = icqmem_ack_i;
    assign qmemimmu_rty_o  = icqmem_rty_i;
    assign qmemimmu_err_o  = icqmem_err_i;
    assign qmemimmu_tag_o  = icqmem_tag_i;

    // DC direction
    assign dcqmem_adr_o    = qmemdmmu_adr_i;
    assign dcqmem_cycstb_o = qmemdmmu_cycstb_i;
    assign dcqmem_ci_o     = qmemdmmu_ci_i;
    assign dcqmem_we_o     = qmemdcpu_we_i;
    assign dcqmem_sel_o    = qmemdcpu_sel_i;
    assign dcqmem_tag_o    = qmemdcpu_tag_i;
    assign dcqmem_dat_o    = qmemdcpu_dat_i;

    // Data-side return
    assign qmemdcpu_dat_o  = dcqmem_dat_i;
    assign qmemdcpu_ack_o  = dcqmem_ack_i;
    assign qmemdcpu_rty_o  = dcqmem_rty_i;
    assign qmemdmmu_err_o  = dcqmem_err_i;
    assign qmemdmmu_tag_o  = dcqmem_tag_i;

`ifdef OR1200_BIST
    // Still need to drive mbist_so_o when QMEM not implemented
    assign mbist_so_o = 1'b0;
`endif

`endif // OR1200_QMEM_IMPLEMENTED

endmodule

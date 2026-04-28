`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_qmem_top (
    input         clk,
    input         rst,

`ifdef OR1200_BIST
    input                                mbist_si_i,
    output                               mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif

    // QMEM and CPU/IMMU
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

    // QMEM and IC
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

    // QMEM and CPU/DMMU
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

    // QMEM and DC
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

    //--------------------------------------------------------------------------
    // FSM state encoding
    //--------------------------------------------------------------------------
    localparam [2:0]
        IDLE  = 3'd0,
        STORE = 3'd1,
        LOAD  = 3'd2,
        FETCH = 3'd3;

    //--------------------------------------------------------------------------
    // Address hit detection
    //--------------------------------------------------------------------------
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

    //--------------------------------------------------------------------------
    // Local RAM control signals
    //--------------------------------------------------------------------------
    // Data-side has a valid QMEM request
    wire dside_qmem_req = qmemdmmu_cycstb_i & daddr_qmem_hit;
    // Instruction-side has a valid QMEM request
    wire iside_qmem_req = qmemimmu_cycstb_i & iaddr_qmem_hit;

    // RAM enable: either side has valid QMEM request
    wire qmem_en = dside_qmem_req | iside_qmem_req;

    // RAM write enable: data-side valid write
    wire qmem_we = dside_qmem_req & qmemdcpu_we_i;

    // RAM address: data side has priority over instruction side
    wire [31:0] qmem_addr = dside_qmem_req ? qmemdmmu_adr_i : qmemimmu_adr_i;

    // RAM write data: always from data side
    wire [31:0] qmem_di = qmemdcpu_dat_i;

    // Byte select
`ifdef OR1200_QMEM_BSEL
    wire [3:0] qmem_sel = dside_qmem_req ? qmemdcpu_sel_i : qmemicpu_sel_i;
`else
    wire [3:0] qmem_sel = 4'b1111;
`endif

    // RAM acknowledge
`ifdef OR1200_QMEM_ACK
    wire qmem_ack;    // driven by RAM instance below
`else
    wire qmem_ack = 1'b1;
`endif

    // RAM read data output
    wire [31:0] qmem_do;

    //--------------------------------------------------------------------------
    // FSM: arbitrate local QMEM acknowledge
    // Priority: data write > data read > instruction fetch
    //--------------------------------------------------------------------------
    reg [2:0] state;
    reg       qmem_dack;
    reg       qmem_iack;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            qmem_dack <= 1'b0;
            qmem_iack <= 1'b0;
        end else begin
            // Data write: highest priority
            if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i & qmem_ack) begin
                state     <= STORE;
                qmem_dack <= 1'b1;
                qmem_iack <= 1'b0;
            end
            // Data read: second priority
            else if (qmemdmmu_cycstb_i & daddr_qmem_hit & ~qmemdcpu_we_i & qmem_ack) begin
                state     <= LOAD;
                qmem_dack <= 1'b1;
                qmem_iack <= 1'b0;
            end
            // Instruction fetch: lowest priority
            else if (qmemimmu_cycstb_i & iaddr_qmem_hit & qmem_ack) begin
                state     <= FETCH;
                qmem_dack <= 1'b0;
                qmem_iack <= 1'b1;
            end
            // No active acknowledged QMEM request
            else begin
                state     <= IDLE;
                qmem_dack <= 1'b0;
                qmem_iack <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Instruction-side: IC request forwarding (blocked on QMEM hit)
    //--------------------------------------------------------------------------
    assign icqmem_adr_o    = iaddr_qmem_hit ? 32'h0         : qmemimmu_adr_i;
    assign icqmem_cycstb_o = iaddr_qmem_hit ? 1'b0          : qmemimmu_cycstb_i;
    assign icqmem_ci_o     = iaddr_qmem_hit ? 1'b0          : qmemimmu_ci_i;
    assign icqmem_sel_o    = iaddr_qmem_hit ? 4'h0          : qmemicpu_sel_i;
    assign icqmem_tag_o    = iaddr_qmem_hit ? 4'h0          : qmemicpu_tag_i;

    // Instruction-side return: qmem_iack gates local vs IC response
    assign qmemicpu_dat_o  = qmem_iack ? qmem_do     : icqmem_dat_i;
    assign qmemicpu_ack_o  = qmem_iack ? 1'b1        : icqmem_ack_i;
    assign qmemimmu_rty_o  = qmem_iack ? 1'b0        : icqmem_rty_i;
    assign qmemimmu_err_o  = qmem_iack ? 1'b0        : icqmem_err_i;
    assign qmemimmu_tag_o  = qmem_iack ? 4'h0        : icqmem_tag_i;

    //--------------------------------------------------------------------------
    // Data-side: DC request forwarding (blocked on QMEM hit)
    //--------------------------------------------------------------------------
    assign dcqmem_adr_o    = daddr_qmem_hit ? 32'h0          : qmemdmmu_adr_i;
    assign dcqmem_cycstb_o = daddr_qmem_hit ? 1'b0           : qmemdmmu_cycstb_i;
    assign dcqmem_ci_o     = daddr_qmem_hit ? 1'b0           : qmemdmmu_ci_i;
    assign dcqmem_we_o     = daddr_qmem_hit ? 1'b0           : qmemdcpu_we_i;
    assign dcqmem_sel_o    = daddr_qmem_hit ? 4'h0           : qmemdcpu_sel_i;
    assign dcqmem_tag_o    = daddr_qmem_hit ? 4'h0           : qmemdcpu_tag_i;
    assign dcqmem_dat_o    = daddr_qmem_hit ? 32'h0          : qmemdcpu_dat_i;

    // Data-side return:
    // Data bus: select local RAM whenever data address hits QMEM
    assign qmemdcpu_dat_o  = daddr_qmem_hit ? qmem_do        : dcqmem_dat_i;
    // Ack/rty: controlled by qmem_dack on QMEM hit, else DC response
    assign qmemdcpu_ack_o  = daddr_qmem_hit ? qmem_dack      : dcqmem_ack_i;
    assign qmemdcpu_rty_o  = daddr_qmem_hit ? ~qmem_dack     : dcqmem_rty_i;
    // Error and tag: forced 0 on QMEM hit
    assign qmemdmmu_err_o  = daddr_qmem_hit ? 1'b0           : dcqmem_err_i;
    assign qmemdmmu_tag_o  = daddr_qmem_hit ? 4'h0           : dcqmem_tag_i;

    //--------------------------------------------------------------------------
    // Local SRAM: or1200_spram_2048x32
    // Word-addressed via qmem_addr[12:2] → 2048 × 32-bit entries
    //--------------------------------------------------------------------------
    or1200_spram_2048x32 or1200_qmem_ram (
        .clk  (clk),
        .rst  (rst),
        .ce   (qmem_en),
        .we   (qmem_we),
        .oe   (1'b1),
        .addr (qmem_addr[12:2]),
        .di   (qmem_di),
        .doq  (qmem_do)
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_so_o),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

`ifdef OR1200_QMEM_ACK
    // When RAM drives ack, connect it here (placeholder — depends on RAM macro)
    // assign qmem_ack = <ram_ack_output>;
`endif

`else   // OR1200_QMEM_IMPLEMENTED not defined: pure pass-through

    //--------------------------------------------------------------------------
    // Instruction side: transparent forwarding to IC
    //--------------------------------------------------------------------------
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

    //--------------------------------------------------------------------------
    // Data side: transparent forwarding to DC
    //--------------------------------------------------------------------------
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

`endif  // OR1200_QMEM_IMPLEMENTED

endmodule
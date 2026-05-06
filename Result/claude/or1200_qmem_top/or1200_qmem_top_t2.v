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

`ifdef OR1200_QMEM_ENABLED

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
    
    localparam IDLE  = 3'b000;
    localparam STORE = 3'b001;
    localparam LOAD  = 3'b010;
    localparam FETCH = 3'b011;
    
    `ifdef OR1200_QMEM_AWIDTH
        localparam QMEM_AWIDTH = `OR1200_QMEM_AWIDTH;
    `else
        localparam QMEM_AWIDTH = 13;
    `endif
    
    `ifdef OR1200_QMEM_DWIDTH
        localparam QMEM_DWIDTH = `OR1200_QMEM_DWIDTH;
    `else
        localparam QMEM_DWIDTH = 32;
    `endif
    
    `ifdef OR1200_QMEM_IADDR_BASE
        localparam QMEM_IADDR_BASE = `OR1200_QMEM_IADDR_BASE;
    `else
        localparam QMEM_IADDR_BASE = 32'h00000000;
    `endif
    
    `ifdef OR1200_QMEM_DADDR_BASE
        localparam QMEM_DADDR_BASE = `OR1200_QMEM_DADDR_BASE;
    `else
        localparam QMEM_DADDR_BASE = 32'h00000000;
    `endif
    
    assign iaddr_qmem_hit = (qmemimmu_adr_i >= QMEM_IADDR_BASE) &&
                             (qmemimmu_adr_i < (QMEM_IADDR_BASE + (1 << QMEM_AWIDTH)));
    
    assign daddr_qmem_hit = (qmemdmmu_adr_i >= QMEM_DADDR_BASE) &&
                             (qmemdmmu_adr_i < (QMEM_DADDR_BASE + (1 << QMEM_AWIDTH)));
    
    assign qmem_addr = daddr_qmem_hit ? qmemdmmu_adr_i : qmemimmu_adr_i;
    assign qmem_di = qmemdcpu_dat_i;
    assign qmem_en = (daddr_qmem_hit && qmemdmmu_cycstb_i) || 
                     (iaddr_qmem_hit && qmemimmu_cycstb_i);
    assign qmem_we = daddr_qmem_hit && qmemdcpu_we_i && qmemdmmu_cycstb_i;
    assign qmem_sel = daddr_qmem_hit ? qmemdcpu_sel_i : 4'h0;
    assign qmem_ack = 1'b1;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            qmem_dack <= 1'b0;
            qmem_iack <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    qmem_dack <= 1'b0;
                    qmem_iack <= 1'b0;
                    
                    if (daddr_qmem_hit && qmemdmmu_cycstb_i && qmemdcpu_we_i && qmem_ack) begin
                        state <= STORE;
                        qmem_dack <= 1'b1;
                    end else if (daddr_qmem_hit && qmemdmmu_cycstb_i && ~qmemdcpu_we_i && qmem_ack) begin
                        state <= LOAD;
                        qmem_dack <= 1'b1;
                    end else if (iaddr_qmem_hit && qmemimmu_cycstb_i && qmem_ack) begin
                        state <= FETCH;
                        qmem_iack <= 1'b1;
                    end
                end
                
                STORE: begin
                    qmem_iack <= 1'b0;
                    
                    if (daddr_qmem_hit && qmemdmmu_cycstb_i && qmemdcpu_we_i && qmem_ack) begin
                        qmem_dack <= 1'b1;
                    end else if (daddr_qmem_hit && qmemdmmu_cycstb_i && ~qmemdcpu_we_i && qmem_ack) begin
                        state <= LOAD;
                        qmem_dack <= 1'b1;
                    end else if (iaddr_qmem_hit && qmemimmu_cycstb_i && qmem_ack) begin
                        state <= FETCH;
                        qmem_dack <= 1'b0;
                        qmem_iack <= 1'b1;
                    end else begin
                        state <= IDLE;
                        qmem_dack <= 1'b0;
                    end
                end
                
                LOAD: begin
                    qmem_iack <= 1'b0;
                    
                    if (daddr_qmem_hit && qmemdmmu_cycstb_i && qmemdcpu_we_i && qmem_ack) begin
                        state <= STORE;
                        qmem_dack <= 1'b0;
                    end else if (daddr_qmem_hit && qmemdmmu_cycstb_i && ~qmemdcpu_we_i && qmem_ack) begin
                        qmem_dack <= 1'b1;
                    end else if (iaddr_qmem_hit && qmemimmu_cycstb_i && qmem_ack) begin
                        state <= FETCH;
                        qmem_dack <= 1'b0;
                        qmem_iack <= 1'b1;
                    end else begin
                        state <= IDLE;
                        qmem_dack <= 1'b0;
                    end
                end
                
                FETCH: begin
                    qmem_dack <= 1'b0;
                    
                    if (daddr_qmem_hit && qmemdmmu_cycstb_i && qmemdcpu_we_i && qmem_ack) begin
                        state <= STORE;
                        qmem_iack <= 1'b0;
                        qmem_dack <= 1'b1;
                    end else if (daddr_qmem_hit && qmemdmmu_cycstb_i && ~qmemdcpu_we_i && qmem_ack) begin
                        state <= LOAD;
                        qmem_iack <= 1'b0;
                        qmem_dack <= 1'b1;
                    end else if (iaddr_qmem_hit && qmemimmu_cycstb_i && qmem_ack) begin
                        qmem_iack <= 1'b1;
                    end else begin
                        state <= IDLE;
                        qmem_iack <= 1'b0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    qmem_dack <= 1'b0;
                    qmem_iack <= 1'b0;
                end
            endcase
        end
    end
    
    wire [QMEM_AWIDTH-3:0] qmem_word_addr = qmem_addr[QMEM_AWIDTH-1:2];
    
    or1200_qmem_data_bram #(
        .DATA_WIDTH(QMEM_DWIDTH),
        .ADDR_WIDTH(QMEM_AWIDTH-2)
    ) qmem_ram (
        .clk(clk),
        .en(qmem_en),
        .we(qmem_we),
        .addr(qmem_word_addr),
        .din(qmem_di),
        .dout(qmem_do),
        .sel(qmem_sel)
    );
    
    assign qmemicpu_dat_o = iaddr_qmem_hit ? qmem_do : icqmem_dat_i;
    assign qmemicpu_ack_o = iaddr_qmem_hit ? qmem_iack : 1'b0;
    assign qmemimmu_rty_o = iaddr_qmem_hit ? 1'b0 : icqmem_rty_i;
    assign qmemimmu_err_o = iaddr_qmem_hit ? 1'b0 : icqmem_err_i;
    assign qmemimmu_tag_o = iaddr_qmem_hit ? 4'h0 : icqmem_tag_i;
    
    assign icqmem_adr_o = iaddr_qmem_hit ? 32'h0 : qmemimmu_adr_i;
    assign icqmem_cycstb_o = iaddr_qmem_hit ? 1'b0 : qmemimmu_cycstb_i;
    assign icqmem_ci_o = iaddr_qmem_hit ? 1'b0 : qmemimmu_ci_i;
    assign icqmem_sel_o = iaddr_qmem_hit ? 4'h0 : qmemicpu_sel_i;
    assign icqmem_tag_o = iaddr_qmem_hit ? 4'h0 : qmemicpu_tag_i;
    
    assign qmemdcpu_dat_o = daddr_qmem_hit ? qmem_do : dcqmem_dat_i;
    assign qmemdcpu_ack_o = daddr_qmem_hit ? qmem_dack : 1'b0;
    assign qmemdcpu_rty_o = daddr_qmem_hit ? 1'b0 : dcqmem_rty_i;
    assign qmemdmmu_err_o = daddr_qmem_hit ? 1'b0 : dcqmem_err_i;
    assign qmemdmmu_tag_o = daddr_qmem_hit ? 4'h0 : dcqmem_tag_i;
    
    assign dcqmem_adr_o = daddr_qmem_hit ? 32'h0 : qmemdmmu_adr_i;
    assign dcqmem_cycstb_o = daddr_qmem_hit ? 1'b0 : qmemdmmu_cycstb_i;
    assign dcqmem_ci_o = daddr_qmem_hit ? 1'b0 : qmemdmmu_ci_i;
    assign dcqmem_we_o = daddr_qmem_hit ? 1'b0 : qmemdcpu_we_i;
    assign dcqmem_sel_o = daddr_qmem_hit ? 4'h0 : qmemdcpu_sel_i;
    assign dcqmem_tag_o = daddr_qmem_hit ? 4'h0 : qmemdcpu_tag_i;
    assign dcqmem_dat_o = daddr_qmem_hit ? 32'h0 : qmemdcpu_dat_i;

`else

    assign qmemicpu_dat_o = icqmem_dat_i;
    assign qmemicpu_ack_o = 1'b0;
    assign qmemimmu_rty_o = icqmem_rty_i;
    assign qmemimmu_err_o = icqmem_err_i;
    assign qmemimmu_tag_o = icqmem_tag_i;
    
    assign icqmem_adr_o = qmemimmu_adr_i;
    assign icqmem_cycstb_o = qmemimmu_cycstb_i;
    assign icqmem_ci_o = qmemimmu_ci_i;
    assign icqmem_sel_o = qmemicpu_sel_i;
    assign icqmem_tag_o = qmemicpu_tag_i;
    
    assign qmemdcpu_dat_o = dcqmem_dat_i;
    assign qmemdcpu_ack_o = 1'b0;
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

`endif

endmodule

module or1200_qmem_data_bram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 11
) (
    input clk,
    input en,
    input we,
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout,
    input [3:0] sel
);
    reg [DATA_WIDTH-1:0] mem [(1 << ADDR_WIDTH) - 1:0];
    reg [DATA_WIDTH-1:0] dout_reg;
    
    always @(posedge clk) begin
        if (en) begin
            if (we) begin
                if (sel[0]) mem[addr][7:0]   <= din[7:0];
                if (sel[1]) mem[addr][15:8]  <= din[15:8];
                if (sel[2]) mem[addr][23:16] <= din[23:16];
                if (sel[3]) mem[addr][31:24] <= din[31:24];
            end
            dout_reg <= mem[addr];
        end
    end
    
    assign dout = dout_reg;

endmodule

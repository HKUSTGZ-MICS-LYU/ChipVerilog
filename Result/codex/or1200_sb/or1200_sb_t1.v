module or1200_sb(
    input         clk,
    input         rst,
    input  [31:0] dcsb_dat_i,
    input  [31:0] dcsb_adr_i,
    input         dcsb_cyc_i,
    input         dcsb_stb_i,
    input         dcsb_we_i,
    input  [3:0]  dcsb_sel_i,
    input         dcsb_cab_i,
    output [31:0] dcsb_dat_o,
    output        dcsb_ack_o,
    output        dcsb_err_o,
    output [31:0] sbbiu_dat_o,
    output [31:0] sbbiu_adr_o,
    output        sbbiu_cyc_o,
    output        sbbiu_stb_o,
    output        sbbiu_we_o,
    output [3:0]  sbbiu_sel_o,
    output        sbbiu_cab_o,
    input  [31:0] sbbiu_dat_i,
    input         sbbiu_ack_i,
    input         sbbiu_err_i
);

`ifdef OR1200_SB_IMPLEMENTED
    wire [67:0] fifo_dat_i;
    wire [67:0] fifo_dat_o;
    wire        fifo_wr;
    wire        fifo_rd;
    wire        fifo_full;
    wire        fifo_empty;
    wire        sel_sb;
    reg         outstanding_store;
    reg         fifo_wr_ack;

    reg  [67:0] fifo_mem [0:1];
    reg         fifo_head;
    reg         fifo_tail;
    reg  [1:0]  fifo_count;
    reg  [67:0] active_store;

    wire [67:0] fifo_head_dat;
    wire        rd_fire;
    wire        wr_fire;
    wire        store_done;

    assign fifo_dat_i   = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};
    assign fifo_head_dat = fifo_head ? fifo_mem[1] : fifo_mem[0];
    assign fifo_dat_o   = outstanding_store ? active_store : fifo_head_dat;
    assign fifo_full    = (fifo_count == 2'd2);
    assign fifo_empty   = (fifo_count == 2'd0);
    assign fifo_wr      = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;
    assign fifo_rd      = ~outstanding_store;
    assign sel_sb       = ~fifo_empty | (fifo_empty & outstanding_store);
    assign rd_fire      = fifo_rd & ~fifo_empty;
    assign wr_fire      = fifo_wr;
    assign store_done   = sbbiu_ack_i | sbbiu_err_i;

    assign dcsb_dat_o   = sbbiu_dat_i;
    assign dcsb_ack_o   = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
    assign dcsb_err_o   = sel_sb ? 1'b0 : sbbiu_err_i;

    assign sbbiu_dat_o  = sel_sb ? fifo_dat_o[63:32] : dcsb_dat_i;
    assign sbbiu_adr_o  = sel_sb ? fifo_dat_o[31:0]  : dcsb_adr_i;
    assign sbbiu_cyc_o  = sel_sb ? 1'b1 : (dcsb_cyc_i & ~dcsb_we_i);
    assign sbbiu_stb_o  = sel_sb ? 1'b1 : (dcsb_stb_i & ~dcsb_we_i);
    assign sbbiu_we_o   = sel_sb ? 1'b1 : dcsb_we_i;
    assign sbbiu_sel_o  = sel_sb ? fifo_dat_o[67:64] : dcsb_sel_i;
    assign sbbiu_cab_o  = sel_sb ? 1'b0 : dcsb_cab_i;

    always @(posedge clk) begin
        if (rst) begin
            outstanding_store <= 1'b0;
            fifo_wr_ack       <= 1'b0;
            fifo_head         <= 1'b0;
            fifo_tail         <= 1'b0;
            fifo_count        <= 2'd0;
            active_store      <= 68'd0;
            fifo_mem[0]       <= 68'd0;
            fifo_mem[1]       <= 68'd0;
        end else begin
            fifo_wr_ack <= fifo_wr;

            if (rd_fire && ~store_done)
                active_store <= fifo_head_dat;

            case ({wr_fire, rd_fire})
                2'b10: begin
                    if (fifo_tail)
                        fifo_mem[1] <= fifo_dat_i;
                    else
                        fifo_mem[0] <= fifo_dat_i;
                    fifo_tail  <= ~fifo_tail;
                    fifo_count <= fifo_count + 2'd1;
                end
                2'b01: begin
                    fifo_head  <= ~fifo_head;
                    fifo_count <= fifo_count - 2'd1;
                end
                2'b11: begin
                    if (fifo_tail)
                        fifo_mem[1] <= fifo_dat_i;
                    else
                        fifo_mem[0] <= fifo_dat_i;
                    fifo_tail <= ~fifo_tail;
                    fifo_head <= ~fifo_head;
                end
                default: begin
                end
            endcase

            if (store_done)
                outstanding_store <= 1'b0;
            else if (sel_sb | fifo_wr)
                outstanding_store <= 1'b1;
        end
    end
`else
    assign dcsb_dat_o  = sbbiu_dat_i;
    assign dcsb_ack_o  = sbbiu_ack_i;
    assign dcsb_err_o  = sbbiu_err_i;

    assign sbbiu_dat_o = dcsb_dat_i;
    assign sbbiu_adr_o = dcsb_adr_i;
    assign sbbiu_cyc_o = dcsb_cyc_i;
    assign sbbiu_stb_o = dcsb_stb_i;
    assign sbbiu_we_o  = dcsb_we_i;
    assign sbbiu_sel_o = dcsb_sel_i;
    assign sbbiu_cab_o = dcsb_cab_i;
`endif

endmodule

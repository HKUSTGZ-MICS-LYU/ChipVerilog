`define OR1200_SB_IMPLEMENTED 1
`endif

module or1200_sb (
    input wire clk,
    input wire rst,
    input wire [31:0] dcsb_dat_i,
    input wire [31:0] dcsb_adr_i,
    input wire dcsb_cyc_i,
    input wire dcsb_stb_i,
    input wire dcsb_we_i,
    input wire [3:0] dcsb_sel_i,
    input wire dcsb_cab_i,
    output reg [31:0] dcsb_dat_o,
    output reg dcsb_ack_o,
    output reg dcsb_err_o,
    output reg [31:0] sbbiu_dat_o,
    output reg [31:0] sbbiu_adr_o,
    output reg sbbiu_cyc_o,
    output reg sbbiu_stb_o,
    output reg sbbiu_we_o,
    output reg [3:0] sbbiu_sel_o,
    output reg sbbiu_cab_o,
    input wire [31:0] sbbiu_dat_i,
    input wire sbbiu_ack_i,
    input wire sbbiu_err_i
);

`ifdef OR1200_SB_IMPLEMENTED

    // FIFO signals
    wire [67:0] fifo_dat_i;
    wire [67:0] fifo_dat_o;
    wire fifo_wr;
    wire fifo_rd;
    wire fifo_full;
    wire fifo_empty;

    // Internal registers
    reg outstanding_store;
    reg fifo_wr_ack;
    reg [67:0] sb_store_reg;
    reg state;

    localparam IDLE = 1'b0;
    localparam WAIT_ACK = 1'b1;

    // FIFO data input
    assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};

    // FIFO write condition
    assign fifo_wr = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;

    // FIFO read condition (one-cycle pulse when starting a transaction)
    assign fifo_rd = (state == IDLE) & ~fifo_empty;

    // sel_sb: select store buffer path
    wire sel_sb;
    assign sel_sb = (~fifo_empty) | (fifo_empty & outstanding_store);

    // FIFO instance
    or1200_sb_fifo #(.DEPTH(4)) fifo_inst (
        .clk(clk),
        .rst(rst),
        .din(fifo_dat_i),
        .wr(fifo_wr),
        .rd(fifo_rd),
        .dout(fifo_dat_o),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    // outstanding_store and state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            outstanding_store <= 1'b0;
            state <= IDLE;
            sb_store_reg <= 68'b0;
            sbbiu_cyc_o <= 1'b0;
            sbbiu_stb_o <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (~fifo_empty) begin
                        // Start a new store transaction
                        state <= WAIT_ACK;
                        outstanding_store <= 1'b1;
                        sb_store_reg <= fifo_dat_o;
                        sbbiu_cyc_o <= 1'b1;
                        sbbiu_stb_o <= 1'b1;
                    end else begin
                        // Remain idle; deassert BIU signals if previously asserted
                        if (outstanding_store && sbbiu_ack_i) begin
                            // This case shouldn't occur in IDLE, but safe
                            outstanding_store <= 1'b0;
                            sbbiu_cyc_o <= 1'b0;
                            sbbiu_stb_o <= 1'b0;
                        end
                    end
                end
                WAIT_ACK: begin
                    if (sbbiu_ack_i) begin
                        state <= IDLE;
                        outstanding_store <= 1'b0;
                        sbbiu_cyc_o <= 1'b0;
                        sbbiu_stb_o <= 1'b0;
                    end else begin
                        // Keep holding transaction
                    end
                end
            endcase
        end
    end

    // fifo_wr_ack generation
    always @(posedge clk or posedge rst) begin
        if (rst)
            fifo_wr_ack <= 1'b0;
        else
            fifo_wr_ack <= fifo_wr;  // one-cycle pulse after write
    end

    // BIU output mux (combinatorial)
    always @(*) begin
        if (sel_sb) begin
            // Store buffer path
            sbbiu_dat_o = sb_store_reg[63:32];
            sbbiu_adr_o = sb_store_reg[31:0];
            sbbiu_sel_o = sb_store_reg[67:64];
            sbbiu_we_o = 1'b1;
            sbbiu_cab_o = 1'b0;
            // cyc and stb are driven by state machine
        end else begin
            // Direct pass-through
            sbbiu_dat_o = dcsb_dat_i;
            sbbiu_adr_o = dcsb_adr_i;
            sbbiu_sel_o = dcsb_sel_i;
            sbbiu_we_o = dcsb_we_i;
            sbbiu_cab_o = dcsb_cab_i;
            // cyc and stb: note that when sel_sb=0, we can directly pass DC signals
            // But we need to avoid driving BIU if SB path was active? sel_sb=0 ensures no conflict.
            // However, the state machine may still be driving sbbiu_cyc_o/stb_o if in WAIT_ACK.
            // But sel_sb=0 only when fifo_empty=1 and outstanding_store=0, so state machine will
            // be in IDLE and will not be driving cyc/stb. So we can safely use generated values.
            sbbiu_cyc_o = dcsb_cyc_i;
            sbbiu_stb_o = dcsb_stb_i;
        end
    end

    // DC response outputs
    always @(*) begin
        dcsb_dat_o = sbbiu_dat_i;
        if (sel_sb) begin
            dcsb_ack_o = fifo_wr_ack;
            dcsb_err_o = 1'b0;
        end else begin
            dcsb_ack_o = sbbiu_ack_i;
            dcsb_err_o = sbbiu_err_i;
        end
    end

`else // !OR1200_SB_IMPLEMENTED

    // Direct pass-through (no store buffer)
    always @(*) begin
        sbbiu_dat_o = dcsb_dat_i;
        sbbiu_adr_o = dcsb_adr_i;
        sbbiu_cyc_o = dcsb_cyc_i;
        sbbiu_stb_o = dcsb_stb_i;
        sbbiu_we_o = dcsb_we_i;
        sbbiu_sel_o = dcsb_sel_i;
        sbbiu_cab_o = dcsb_cab_i;
        dcsb_dat_o = sbbiu_dat_i;
        dcsb_ack_o = sbbiu_ack_i;
        dcsb_err_o = sbbiu_err_i;
    end

`endif

endmodule

// FIFO module (simple synchronous FIFO)
`ifdef OR1200_SB_IMPLEMENTED
module or1200_sb_fifo #(
    parameter DEPTH = 4
)(
    input wire clk,
    input wire rst,
    input wire [67:0] din,
    input wire wr,
    input wire rd,
    output reg [67:0] dout,
    output reg full,
    output reg empty
);
    reg [67:0] mem [0:DEPTH-1];
    reg [$clog2(DEPTH):0] wp;
    reg [$clog2(DEPTH):0] rp;
    wire [$clog2(DEPTH)-1:0] wp_addr = wp[$clog2(DEPTH)-1:0];
    wire [$clog2(DEPTH)-1:0] rp_addr = rp[$clog2(DEPTH)-1:0];
    wire wp_msb = wp[$clog2(DEPTH)];
    wire rp_msb = rp[$clog2(DEPTH)];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wp <= 0;
            rp <= 0;
            full <= 1'b0;
            empty <= 1'b1;
        end else begin
            // Write
            if (wr && !full) begin
                mem[wp_addr] <= din;
                wp <= wp + 1;
            end
            // Read
            if (rd && !empty) begin
                dout <= mem[rp_addr];
                rp <= rp + 1;
            end
            // Update flags
            full <= ((wp_msb == ~rp_msb) && (wp_addr == rp_addr));
            empty <= (wp == rp);
        end
    end
endmodule
`endif

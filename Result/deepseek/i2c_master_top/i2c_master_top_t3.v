module i2c_master_top (
    input wire wb_clk_i,
    input wire wb_rst_i,
    input wire arst_i,
    input wire [2:0] wb_adr_i,
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_we_i,
    input wire wb_stb_i,
    input wire wb_cyc_i,
    output reg wb_ack_o,
    output reg wb_inta_o,
    input wire scl_pad_i,
    output wire scl_pad_o,
    output wire scl_padoen_o,
    input wire sda_pad_i,
    output wire sda_pad_o,
    output wire sda_padoen_o
);

    parameter ARST_LVL = 1'b1;

    wire rst_i;
    assign rst_i = arst_i ^ ARST_LVL;

    reg [15:0] prer;
    reg [7:0] ctr;
    reg [7:0] txr;
    reg [7:0] cr;
    reg al;
    reg rxack;
    reg tip;
    reg irq_flag;

    wire ena;
    assign ena = ctr[7];
    wire ien;
    assign ien = ctr[6];

    wire wb_wacc;
    assign wb_wacc = wb_we_i & wb_ack_o;

    wire sta, sto, rd, wr, ack, iack;
    assign sta  = cr[7];
    assign sto  = cr[6];
    assign rd   = cr[5];
    assign wr   = cr[4];
    assign ack  = cr[3];
    assign iack = cr[0];

    wire done, i2c_al, i2c_busy, irxack;
    wire [7:0] rxr;

    i2c_master_byte_ctrl byte_ctrl (
        .clk(wb_clk_i),
        .nReset(rst_i),
        .ena(ena),
        .clk_cnt(prer),
        .start(sta),
        .stop(sto),
        .read(rd),
        .write(wr),
        .ack_in(ack),
        .din(txr),
        .cmd_ack(done),
        .i2c_busy(i2c_busy),
        .i2c_al(i2c_al),
        .dout(rxr),
        .i2c_ack(irxack),
        .scl_pad_i(scl_pad_i),
        .scl_pad_o(scl_pad_o),
        .scl_padoen_o(scl_padoen_o),
        .sda_pad_i(sda_pad_i),
        .sda_pad_o(sda_pad_o),
        .sda_padoen_o(sda_padoen_o)
    );

    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            prer <= 16'hffff;
            ctr <= 8'h00;
            txr <= 8'h00;
            cr <= 8'h00;
            al <= 1'b0;
            rxack <= 1'b0;
            tip <= 1'b0;
            irq_flag <= 1'b0;
            wb_ack_o <= 1'b0;
            wb_inta_o <= 1'b0;
        end else if (wb_rst_i) begin
            prer <= 16'hffff;
            ctr <= 8'h00;
            txr <= 8'h00;
            cr <= 8'h00;
            al <= 1'b0;
            rxack <= 1'b0;
            tip <= 1'b0;
            irq_flag <= 1'b0;
            wb_ack_o <= 1'b0;
            wb_inta_o <= 1'b0;
        end else begin
            // Wishbone acknowledge
            wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;

            // Register writes
            if (wb_wacc) begin
                case (wb_adr_i)
                    3'b000: prer[7:0] <= wb_dat_i;
                    3'b001: prer[15:8] <= wb_dat_i;
                    3'b010: ctr <= wb_dat_i;
                    3'b011: txr <= wb_dat_i;
                    3'b100: if (ena) cr <= wb_dat_i;
                endcase
            end

            // Command auto-clear
            if (done | i2c_al) begin
                cr[7:4] <= 4'b0000;
                cr[2:0] <= 3'b000;
            end

            // Status updates
            rxack <= irxack;
            tip <= rd | wr;
            irq_flag <= (done | i2c_al | irq_flag) & ~iack;
            al <= i2c_al | (al & ~sta);

            // Interrupt output
            wb_inta_o <= irq_flag & ien;
        end
    end

    // Read data mux (registered on output in the always block above, but we need combinatorial for dat_o)
    // Actually wb_dat_o is registered in separate always block per spec "updated on every rising edge"
    always @(posedge wb_clk_i) begin
        case (wb_adr_i)
            3'b000: wb_dat_o <= prer[7:0];
            3'b001: wb_dat_o <= prer[15:8];
            3'b010: wb_dat_o <= ctr;
            3'b011: wb_dat_o <= rxr;
            3'b100: wb_dat_o <= {rxack, i2c_busy, al, 3'b000, tip, irq_flag};
            3'b101: wb_dat_o <= txr;
            3'b110: wb_dat_o <= cr;
            3'b111: wb_dat_o <= 8'h00;
        endcase
    end

endmodule

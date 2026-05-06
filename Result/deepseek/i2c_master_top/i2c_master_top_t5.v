module i2c_master_top #(
    parameter ARST_LVL = 1
) (
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

    // Internal asynchronous reset (active low)
    wire rst_i = arst_i ^ ARST_LVL;

    // Internal registers
    reg [15:0] prer;
    reg [7:0] ctr;   // ctr[7] = EN, ctr[6] = IEN
    reg [7:0] txr;
    reg [7:0] cr;    // cr[7]=STA, cr[6]=STO, cr[5]=RD, cr[4]=WR, cr[3]=ACK, cr[0]=IACK
    reg [7:0] rxr;   // from byte_ctrl
    reg [7:0] sr;    // assembled status

    // Internal status bits
    reg rxack;
    reg tip;
    reg irq_flag;
    reg al;

    // Wire to byte controller
    wire done;
    wire irxack;
    wire [7:0] rxr_wire;
    wire i2c_busy;
    wire i2c_al;

    // Decoded command signals
    wire sta = cr[7];
    wire sto = cr[6];
    wire rd  = cr[5];
    wire wr  = cr[4];
    wire ack = cr[3];
    wire iack= cr[0];

    wire core_en = ctr[7];
    wire ien = ctr[6];

    // Wishbone handshake
    wire wb_wacc = wb_we_i & wb_ack_o;

    // Wishbone acknowledge
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            wb_ack_o <= 1'b0;
        else if (wb_rst_i)
            wb_ack_o <= 1'b0;
        else
            wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
    end

    // Read data output (registered)
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            wb_dat_o <= 8'h00;
        else if (wb_rst_i)
            wb_dat_o <= 8'h00;
        else begin
            case (wb_adr_i)
                3'b000: wb_dat_o <= prer[7:0];
                3'b001: wb_dat_o <= prer[15:8];
                3'b010: wb_dat_o <= ctr;
                3'b011: wb_dat_o <= rxr_wire;  // RXR at address 0x03
                3'b100: wb_dat_o <= sr;         // SR at address 0x04
                3'b101: wb_dat_o <= txr;        // TXR read back at 0x05
                3'b110: wb_dat_o <= cr;         // CR read back at 0x06
                3'b111: wb_dat_o <= 8'h00;
                default: wb_dat_o <= 8'h00;
            endcase
        end
    end

    // Register writes (regular registers)
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            prer <= 16'hffff;
            ctr <= 8'h00;
            txr <= 8'h00;
        end else if (wb_rst_i) begin
            prer <= 16'hffff;
            ctr <= 8'h00;
            txr <= 8'h00;
        end else if (wb_wacc) begin
            case (wb_adr_i)
                3'b000: prer[7:0] <= wb_dat_i;
                3'b001: prer[15:8] <= wb_dat_i;
                3'b010: ctr <= wb_dat_i;
                3'b011: txr <= wb_dat_i;
                default: ; // no others
            endcase
        end
    end

    // Command register cr (write only if core_en, auto-clear)
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            cr <= 8'h00;
        else if (wb_rst_i)
            cr <= 8'h00;
        else if (wb_wacc && (wb_adr_i == 3'b100) && core_en)
            cr <= wb_dat_i;
        else if (done || i2c_al)
            cr[7:0] <= 8'h00; // clear all bits
    end

    // rxack, tip, irq_flag, al
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            rxack <= 1'b0;
            tip <= 1'b0;
            irq_flag <= 1'b0;
            al <= 1'b0;
        end else if (wb_rst_i) begin
            rxack <= 1'b0;
            tip <= 1'b0;
            irq_flag <= 1'b0;
            al <= 1'b0;
        end else begin
            // rxack samples irxack from byte_ctrl on each cycle
            rxack <= irxack;

            // tip = rd | wr
            tip <= rd | wr;

            // irq_flag: set on done or i2c_al, clear on IACK write
            if (done || i2c_al)
                irq_flag <= 1'b1;
            else if (iack && wb_wacc && (wb_adr_i == 3'b100))
                irq_flag <= 1'b0;

            // al: latch i2c_al, clear on new START (STA)
            if (i2c_al)
                al <= 1'b1;
            else if (sta)
                al <= 1'b0;
        end
    end

    // Status register assembly
    always @* begin
        sr[7] = rxack;
        sr[6] = i2c_busy;
        sr[5] = al;
        sr[4] = 1'b0;
        sr[3] = 1'b0;
        sr[2] = 1'b0;
        sr[1] = tip;
        sr[0] = irq_flag;
    end

    // Interrupt output
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            wb_inta_o <= 1'b0;
        else if (wb_rst_i)
            wb_inta_o <= 1'b0;
        else
            wb_inta_o <= irq_flag & ien;
    end

    // Instantiate i2c_master_byte_ctrl
    i2c_master_byte_ctrl byte_ctrl_inst (
        .clk(wb_clk_i),
        .nReset(rst_i),
        .ena(1'b1),          // always enabled
        .clk_cnt(prer),
        .start(sta),
        .stop(sto),
        .read(rd),
        .write(wr),
        .ack_in(ack),
        .din(txr),
        .cmd_ack(done),
        .irxack(irxack),
        .rxr(rxr_wire),
        .i2c_busy(i2c_busy),
        .i2c_al(i2c_al),
        .scl_i(scl_pad_i),
        .sda_i(sda_pad_i),
        .scl_o(scl_pad_o),
        .sda_o(sda_pad_o),
        .scl_oen(scl_padoen_o),
        .sda_oen(sda_padoen_o)
    );

endmodule

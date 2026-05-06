module i2c_master_top (
    wb_clk_i, wb_rst_i, arst_i, wb_adr_i, wb_dat_i, wb_dat_o,
    wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_inta_o,
    scl_pad_i, scl_pad_o, scl_padoen_o, sda_pad_i, sda_pad_o, sda_padoen_o
);
    parameter ARST_LVL = 1'b1;

    input  wire        wb_clk_i;
    input  wire        wb_rst_i;
    input  wire        arst_i;
    input  wire [2:0]  wb_adr_i;
    input  wire [7:0]  wb_dat_i;
    output reg  [7:0]  wb_dat_o;
    input  wire        wb_we_i;
    input  wire        wb_stb_i;
    input  wire        wb_cyc_i;
    output reg         wb_ack_o;
    output reg         wb_inta_o;
    input  wire        scl_pad_i;
    output wire        scl_pad_o;
    output wire        scl_padoen_o;
    input  wire        sda_pad_i;
    output wire        sda_pad_o;
    output wire        sda_padoen_o;

    // Internal resets
    wire rst_i;           // active-low asynchronous reset
    wire wb_rst_sync;     // synchronous reset from Wishbone

    assign rst_i = arst_i ^ ARST_LVL;

    // Wishbone internal signals
    wire wb_wacc;  // qualified write access
    assign wb_wacc = wb_we_i & wb_ack_o;

    // Register declarations
    reg [15:0] prer;
    reg [7:0]  ctr;
    reg [7:0]  txr;
    reg [7:0]  cr;
    reg        al;
    reg        rxack;
    reg        tip;
    reg        irq_flag;

    // Intermediate command bits
    wire core_en;
    wire ien;
    wire sta, sto, rd, wr, ack, iack;

    assign core_en = ctr[7];
    assign ien     = ctr[6];

    assign sta  = cr[7];
    assign sto  = cr[6];
    assign rd   = cr[5];
    assign wr   = cr[4];
    assign ack  = cr[3];
    assign iack = cr[0];

    // Byte controller interface
    wire [15:0] clk_cnt;
    wire [7:0]  din;
    wire        cmd_ack;  // done from byte_ctrl
    wire        i2c_busy;
    wire        i2c_al;
    wire        irxack;
    wire [7:0]  rxr;

    assign clk_cnt = prer;
    assign din     = txr;

    // Status register assembly
    wire [7:0] sr;
    assign sr = {rxack, i2c_busy, al, 3'b000, tip, irq_flag};

    // Wishbone acknowledge generation
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            wb_ack_o <= 1'b0;
        end else if (wb_rst_i) begin
            wb_ack_o <= 1'b0;
        end else begin
            wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
        end
    end

    // Wishbone read data output
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            wb_dat_o <= 8'h00;
        end else if (wb_rst_i) begin
            wb_dat_o <= 8'h00;
        end else begin
            case (wb_adr_i)
                3'b000:  wb_dat_o <= prer[7:0];
                3'b001:  wb_dat_o <= prer[15:8];
                3'b010:  wb_dat_o <= ctr;
                3'b011:  wb_dat_o <= rxr;
                3'b100:  wb_dat_o <= sr;
                3'b101:  wb_dat_o <= txr;
                3'b110:  wb_dat_o <= cr;
                3'b111:  wb_dat_o <= 8'h00;
                default: wb_dat_o <= 8'h00;
            endcase
        end
    end

    // Register writes (prer, ctr, txr)
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            prer <= 16'hffff;
            ctr  <= 8'h00;
            txr  <= 8'h00;
        end else if (wb_rst_i) begin
            prer <= 16'hffff;
            ctr  <= 8'h00;
            txr  <= 8'h00;
        end else if (wb_wacc) begin
            case (wb_adr_i)
                3'b000: prer[7:0]   <= wb_dat_i;
                3'b001: prer[15:8]  <= wb_dat_i;
                3'b010: ctr         <= wb_dat_i;
                3'b011: txr         <= wb_dat_i;
                default: ;
            endcase
        end
    end

    // Command register (cr) write - only when core enabled
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            cr <= 8'h00;
        end else if (wb_rst_i) begin
            cr <= 8'h00;
        end else if (wb_wacc && (wb_adr_i == 3'b100) && core_en) begin
            cr <= wb_dat_i;
        end else if (cmd_ack || i2c_al) begin
            // Clear command bits when done or arbitration lost
            cr[7:4] <= 4'b0000;
            cr[2:1] <= 2'b00;
            cr[0]   <= 1'b0;
        end
    end

    // Status bits: al, rxack, tip, irq_flag
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            al      <= 1'b0;
            rxack   <= 1'b0;
            tip     <= 1'b0;
            irq_flag <= 1'b0;
        end else if (wb_rst_i) begin
            al      <= 1'b0;
            rxack   <= 1'b0;
            tip     <= 1'b0;
            irq_flag <= 1'b0;
        end else begin
            // rxack latches irxack every cycle
            rxack <= irxack;

            // tip: set by rd or wr, cleared when command done or al
            tip <= (rd | wr) & ~(cmd_ack | i2c_al);

            // al: set on i2c_al, cleared on sta
            al <= i2c_al | (al & ~sta);

            // irq_flag: set on done or al, cleared on iack
            irq_flag <= (cmd_ack | i2c_al | irq_flag) & ~iack;
        end
    end

    // Interrupt output
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            wb_inta_o <= 1'b0;
        end else if (wb_rst_i) begin
            wb_inta_o <= 1'b0;
        end else begin
            wb_inta_o <= irq_flag & ien;
        end
    end

    // I2C Master Byte Controller instance
    i2c_master_byte_ctrl byte_ctrl (
        .clk      (wb_clk_i),
        .nReset   (rst_i),
        .rst      (wb_rst_i),
        .clk_cnt  (clk_cnt),
        .start    (sta),
        .stop     (sto),
        .read     (rd),
        .write    (wr),
        .ack_in   (ack),
        .din      (din),
        .cmd_ack  (cmd_ack),
        .ack_out  (irxack),
        .dout     (rxr),
        .i2c_busy (i2c_busy),
        .i2c_al   (i2c_al),
        .scl_i    (scl_pad_i),
        .scl_o    (scl_pad_o),
        .scl_oen  (scl_padoen_o),
        .sda_i    (sda_pad_i),
        .sda_o    (sda_pad_o),
        .sda_oen  (sda_padoen_o)
    );

endmodule

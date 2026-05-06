module i2c_master_top (
    input           wb_clk_i,
    input           wb_rst_i,
    input           arst_i,
    input   [2:0]   wb_adr_i,
    input   [7:0]   wb_dat_i,
    output  [7:0]   wb_dat_o,
    input           wb_we_i,
    input           wb_stb_i,
    input           wb_cyc_i,
    output          wb_ack_o,
    output          wb_inta_o,
    input           scl_pad_i,
    output          scl_pad_o,
    output          scl_padoen_o,
    input           sda_pad_i,
    output          sda_pad_o,
    output          sda_padoen_o
);

    parameter ARST_LVL = 1'b1;

    // Internal signals
    wire            rst_i;
    wire            core_en;
    wire            ien;
    wire            wb_wacc;
    reg             wb_ack_o;
    reg     [7:0]   wb_dat_o;
    reg     [15:0]  prer;
    reg     [7:0]   ctr;
    reg     [7:0]   txr;
    reg     [7:0]   cr;
    reg             al;
    reg             rxack;
    reg             tip;
    reg             irq_flag;
    reg             wb_inta_o;

    // Byte controller signals
    wire    [7:0]   rxr;
    wire            done;
    wire            i2c_busy;
    wire            i2c_al;
    wire            irxack;
    wire    [15:0]  clk_cnt;

    // Command register bits
    wire            sta;
    wire            sto;
    wire            rd;
    wire            wr;
    wire            ack;
    wire            iack;

    // Asynchronous reset normalization
    assign rst_i = arst_i ^ ARST_LVL;

    // Core enable and interrupt enable
    assign core_en = ctr[7];
    assign ien     = ctr[6];

    // Wishbone write access qualification
    assign wb_wacc = wb_we_i & wb_ack_o;

    // ----------------------------------------------------------------
    // Wishbone acknowledge generation
    // ----------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            wb_ack_o <= 1'b0;
        end else if (wb_rst_i) begin
            wb_ack_o <= 1'b0;
        end else begin
            wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
        end
    end

    // ----------------------------------------------------------------
    // Wishbone read data output
    // ----------------------------------------------------------------
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
                3'b100:  wb_dat_o <= {rxack, i2c_busy, al, 3'h0, tip, irq_flag}; // sr
                3'b101:  wb_dat_o <= txr;
                3'b110:  wb_dat_o <= cr;
                default: wb_dat_o <= 8'h00;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // Register writes (PRER, CTR, TXR)
    // ----------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            prer <= 16'hffff;
        end else if (wb_rst_i) begin
            prer <= 16'hffff;
        end else if (wb_wacc) begin
            case (wb_adr_i)
                3'b000: prer[7:0]   <= wb_dat_i;
                3'b001: prer[15:8]  <= wb_dat_i;
                default: /* no change */ ;
            endcase
        end
    end

    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            ctr <= 8'h00;
        end else if (wb_rst_i) begin
            ctr <= 8'h00;
        end else if (wb_wacc && (wb_adr_i == 3'b010)) begin
            ctr <= wb_dat_i;
        end
    end

    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            txr <= 8'h00;
        end else if (wb_rst_i) begin
            txr <= 8'h00;
        end else if (wb_wacc && (wb_adr_i == 3'b011)) begin
            txr <= wb_dat_i;
        end
    end

    // ----------------------------------------------------------------
    // Command register write and auto-clear
    // ----------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            cr <= 8'h00;
        end else if (wb_rst_i) begin
            cr <= 8'h00;
        end else if (wb_wacc && (wb_adr_i == 3'b100) && core_en) begin
            cr <= wb_dat_i;
        end else if (done || i2c_al) begin
            // Auto-clear command bits upon completion or arbitration loss
            cr[7:4] <= 4'h0;
            cr[2:0] <= 3'h0;
        end
    end

    // Decode command register bits
    assign iack = cr[0];
    assign ack  = cr[3];
    assign wr   = cr[4];
    assign rd   = cr[5];
    assign sto  = cr[6];
    assign sta  = cr[7];

    // ----------------------------------------------------------------
    // Status bit latching
    // ----------------------------------------------------------------
    // al
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            al <= 1'b0;
        end else if (wb_rst_i) begin
            al <= 1'b0;
        end else begin
            al <= i2c_al | (al & ~sta);
        end
    end

    // tip
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            tip <= 1'b0;
        end else if (wb_rst_i) begin
            tip <= 1'b0;
        end else begin
            tip <= rd | wr;
        end
    end

    // irq_flag
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            irq_flag <= 1'b0;
        end else if (wb_rst_i) begin
            irq_flag <= 1'b0;
        end else begin
            irq_flag <= (done | i2c_al | irq_flag) & ~iack;
        end
    end

    // rxack
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            rxack <= 1'b0;
        end else if (wb_rst_i) begin
            rxack <= 1'b0;
        end else begin
            rxack <= irxack;
        end
    end

    // ----------------------------------------------------------------
    // Interrupt output generation
    // ----------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            wb_inta_o <= 1'b0;
        end else if (wb_rst_i) begin
            wb_inta_o <= 1'b0;
        end else begin
            wb_inta_o <= irq_flag & ien;
        end
    end

    // ----------------------------------------------------------------
    // Prescale value to byte controller
    // ----------------------------------------------------------------
    assign clk_cnt = prer;

    // ----------------------------------------------------------------
    // Byte controller instantiation
    // ----------------------------------------------------------------
    i2c_master_byte_ctrl byte_ctrl (
        .clk      (wb_clk_i),
        .nReset   (rst_i),
        .ena      (core_en),
        .clk_cnt  (clk_cnt),
        .start    (sta),
        .stop     (sto),
        .read     (rd),
        .write    (wr),
        .ack_in   (ack),
        .din      (txr),
        .cmd_ack  (done),
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

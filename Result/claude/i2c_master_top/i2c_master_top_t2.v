//////////////////////////////////////////////////////////////////////
////                                                              ////
////  i2c_master_top.v                                            ////
////                                                              ////
////  Wishbone top-level interface for the OpenCores I2C master.  ////
////  Provides host register access (prescale, control, tx,      ////
////  command, status, receive, interrupt) and instantiates       ////
////  i2c_master_byte_ctrl to perform actual I2C transfers.       ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

module i2c_master_top #(
    parameter ARST_LVL = 1'b0   // asynchronous reset active level
) (
    // Wishbone interface
    input             wb_clk_i,     // Wishbone clock
    input             wb_rst_i,     // synchronous active-high reset
    input             arst_i,       // asynchronous reset (polarity set by ARST_LVL)
    input      [ 2:0] wb_adr_i,     // register address
    input      [ 7:0] wb_dat_i,     // write data
    output reg [ 7:0] wb_dat_o,     // read data
    input             wb_we_i,      // write enable
    input             wb_stb_i,     // strobe
    input             wb_cyc_i,     // cycle valid
    output reg        wb_ack_o,     // acknowledge
    output reg        wb_inta_o,    // interrupt request

    // I2C pad interface
    input             scl_pad_i,    // SCL pad input
    output            scl_pad_o,    // SCL pad output
    output            scl_padoen_o, // SCL pad output-enable (active low)
    input             sda_pad_i,    // SDA pad input
    output            sda_pad_o,    // SDA pad output
    output            sda_padoen_o  // SDA pad output-enable (active low)
);

    //------------------------------------------------------------------
    // Normalize asynchronous reset to active-low internal signal
    //------------------------------------------------------------------
    wire rst_i = arst_i ^ ARST_LVL;   // rst_i = 0 => active reset

    //------------------------------------------------------------------
    // Internal registers
    //------------------------------------------------------------------
    reg [15:0] prer;   // clock prescale register
    reg [ 7:0] ctr;    // control register
    reg [ 7:0] txr;    // transmit register
    reg [ 7:0] cr;     // command register

    // Status bits latched in the top-level
    reg        al;         // arbitration lost (latched)
    reg        rxack;      // slave acknowledge (latched from byte ctrl)
    reg        tip;        // transfer in progress
    reg        irq_flag;   // interrupt pending flag

    // Decoded control fields
    wire       core_en = ctr[7];
    wire       ien     = ctr[6];

    // Decoded command bits
    wire       sta  = cr[7];   // START
    wire       sto  = cr[6];   // STOP
    wire       rd   = cr[5];   // READ
    wire       wr   = cr[4];   // WRITE
    wire       ack  = cr[3];   // ACK/NACK
    wire       iack = cr[0];   // interrupt acknowledge

    //------------------------------------------------------------------
    // Byte controller interface signals
    //------------------------------------------------------------------
    wire        done;      // byte command complete (= cmd_ack)
    wire        irxack;    // raw slave ACK from byte controller
    wire [ 7:0] rxr;       // received byte from byte controller
    wire        i2c_busy;  // bus busy from bit controller
    wire        i2c_al;    // arbitration lost from bit controller

    //------------------------------------------------------------------
    // Wishbone acknowledge generation
    //   wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o
    //------------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            wb_ack_o <= 1'b0;
        else if (wb_rst_i)
            wb_ack_o <= 1'b0;
        else
            wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
    end

    // Qualified write strobe: write only on an acknowledged write cycle
    wire wb_wacc = wb_we_i & wb_ack_o;

    //------------------------------------------------------------------
    // Register writes
    //------------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            prer <= 16'hffff;
            ctr  <= 8'h00;
            txr  <= 8'h00;
            cr   <= 8'h00;
        end else if (wb_rst_i) begin
            prer <= 16'hffff;
            ctr  <= 8'h00;
            txr  <= 8'h00;
            cr   <= 8'h00;
        end else begin
            // Auto-clear: command bits and IACK are cleared on done or i2c_al
            if (done | i2c_al)
                cr <= 8'h00;   // clear STA, STO, RD, WR, ACK, reserved, IACK
            else if (wb_wacc) begin
                case (wb_adr_i)
                    3'b000: prer[ 7:0] <= wb_dat_i;
                    3'b001: prer[15:8] <= wb_dat_i;
                    3'b010: ctr        <= wb_dat_i;
                    3'b011: txr        <= wb_dat_i;
                    3'b100: if (core_en) cr <= wb_dat_i;  // CR only when enabled
                    default: ;
                endcase
            end
        end
    end

    //------------------------------------------------------------------
    // Registered read-data output
    //   Updated every clock according to current address
    //------------------------------------------------------------------
    wire [7:0] sr = {rxack, i2c_busy, al, 3'h0, tip, irq_flag};

    always @(posedge wb_clk_i) begin
        case (wb_adr_i)
            3'b000: wb_dat_o <= prer[ 7:0];
            3'b001: wb_dat_o <= prer[15:8];
            3'b010: wb_dat_o <= ctr;
            3'b011: wb_dat_o <= rxr;         // receive register
            3'b100: wb_dat_o <= sr;          // status register
            3'b101: wb_dat_o <= txr;         // txr readback (non-standard)
            3'b110: wb_dat_o <= cr;          // cr readback  (non-standard)
            3'b111: wb_dat_o <= 8'h00;
        endcase
    end

    //------------------------------------------------------------------
    // Status bit: rxack — latch slave ACK after each transfer
    //------------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            rxack <= 1'b0;
        else if (wb_rst_i)
            rxack <= 1'b0;
        else if (done)
            rxack <= irxack;
    end

    //------------------------------------------------------------------
    // Status bit: tip — transfer in progress
    //   Set while rd or wr command bits are active
    //------------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            tip <= 1'b0;
        else if (wb_rst_i)
            tip <= 1'b0;
        else
            tip <= rd | wr;
    end

    //------------------------------------------------------------------
    // Status bit: irq_flag
    //   Set on done or i2c_al; cleared by IACK write
    //------------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            irq_flag <= 1'b0;
        else if (wb_rst_i)
            irq_flag <= 1'b0;
        else
            irq_flag <= (done | i2c_al | irq_flag) & ~iack;
    end

    //------------------------------------------------------------------
    // Status bit: al — arbitration lost (latched until next START)
    //------------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            al <= 1'b0;
        else if (wb_rst_i)
            al <= 1'b0;
        else
            al <= i2c_al | (al & ~sta);
    end

    //------------------------------------------------------------------
    // Wishbone interrupt output
    //   Asserted when irq_flag is set AND interrupt enable (IEN) is on
    //------------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            wb_inta_o <= 1'b0;
        else if (wb_rst_i)
            wb_inta_o <= 1'b0;
        else
            wb_inta_o <= irq_flag & ien;
    end

    //------------------------------------------------------------------
    // Instantiate byte-level controller
    //------------------------------------------------------------------
    i2c_master_byte_ctrl byte_controller (
        .clk     (wb_clk_i),
        .rst     (wb_rst_i),
        .nReset  (rst_i),
        .ena     (core_en),
        .clk_cnt (prer),

        // Byte-level command inputs
        .start   (sta),
        .stop    (sto),
        .read    (rd),
        .write   (wr),
        .ack_in  (ack),
        .din     (txr),

        // Byte-level command outputs
        .cmd_ack (done),
        .ack_out (irxack),
        .dout    (rxr),

        // Status outputs
        .i2c_busy (i2c_busy),
        .i2c_al   (i2c_al),

        // I2C pad interface
        .scl_i   (scl_pad_i),
        .scl_o   (scl_pad_o),
        .scl_oen (scl_padoen_o),
        .sda_i   (sda_pad_i),
        .sda_o   (sda_pad_o),
        .sda_oen (sda_padoen_o)
    );

endmodule

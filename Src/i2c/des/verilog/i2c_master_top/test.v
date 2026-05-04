/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE rev.B2 compliant I2C Master Top-level interface   ////
////                                                             ////
////  Description:                                               ////
////  Wishbone register/control wrapper for the I2C master core. ////
////  Provides register read/write interface to the host for     ////
////  configuration, command issue, status reading, and          ////
////  interrupt handling. The actual I2C bit-level timing is     ////
////  performed by the instantiated i2c_master_byte_ctrl.        ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

`timescale 1ns / 10ps

module i2c_master_top(
    wb_clk_i, wb_rst_i, arst_i, wb_adr_i, wb_dat_i, wb_dat_o,
    wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_inta_o,
    scl_pad_i, scl_pad_o, scl_padoen_o,
    sda_pad_i, sda_pad_o, sda_padoen_o
);

    // ---------------------------------------------------------------
    // Parameters
    // ---------------------------------------------------------------
    // ARST_LVL selects the active level of the asynchronous reset arst_i.
    // Default: 1'b0 means arst_i is active-low.
    parameter ARST_LVL = 1'b0;

    // ---------------------------------------------------------------
    // Wishbone interface
    // ---------------------------------------------------------------
    input        wb_clk_i;       // master clock
    input        wb_rst_i;       // synchronous active-high reset
    input        arst_i;         // asynchronous reset (level set by ARST_LVL)
    input  [2:0] wb_adr_i;       // register address
    input  [7:0] wb_dat_i;       // write data
    output [7:0] wb_dat_o;       // read data
    input        wb_we_i;        // write enable
    input        wb_stb_i;       // strobe
    input        wb_cyc_i;       // bus cycle
    output       wb_ack_o;       // bus cycle acknowledge
    output       wb_inta_o;      // interrupt request

    reg [7:0] wb_dat_o;
    reg       wb_ack_o;
    reg       wb_inta_o;

    // ---------------------------------------------------------------
    // I2C signals (pad interface)
    // ---------------------------------------------------------------
    input  scl_pad_i;       // SCL line input
    output scl_pad_o;       // SCL line output
    output scl_padoen_o;    // SCL output enable, active low
    input  sda_pad_i;       // SDA line input
    output sda_pad_o;       // SDA line output
    output sda_padoen_o;    // SDA output enable, active low

    // ---------------------------------------------------------------
    // Internal registers
    // ---------------------------------------------------------------
    reg  [15:0] prer;       // clock prescale register
    reg  [ 7:0] ctr;        // control register
    reg  [ 7:0] txr;        // transmit register
    wire [ 7:0] rxr;        // receive register (from byte controller)
    reg  [ 7:0] cr;         // command register
    wire [ 7:0] sr;         // status register

    // Decoded command and control signals
    wire        done;       // byte command completed (cmd_ack from byte ctrl)
    wire        core_en;    // core enable bit
    wire        ien;        // interrupt enable bit

    // Status bits
    reg         tip;        // transfer in progress
    reg         irq_flag;   // interrupt pending flag
    wire        i2c_busy;   // bus busy from byte controller
    wire        i2c_al;     // arbitration lost from byte controller
    reg         al;         // latched arbitration lost
    wire        irxack;     // received acknowledge from byte controller
    reg         rxack;      // latched received acknowledge

    // Decoded command bits
    wire        sta;        // generate (repeated) start
    wire        sto;        // generate stop
    wire        rd;         // read from slave
    wire        wr;         // write to slave
    wire        ack;        // ACK/NACK select for receive
    wire        iack;       // interrupt acknowledge

    // Internal reset
    wire        rst_i;      // normalized active-low asynchronous reset
    wire        wb_wacc;    // qualified write access

    // ---------------------------------------------------------------
    // Module body
    // ---------------------------------------------------------------

    // Generate the internal reset.
    // arst_i is asynchronous and its active level is configurable.
    // After XOR with ARST_LVL, rst_i is active-low (i.e., 1'b0 means reset asserted).
    assign rst_i = arst_i ^ ARST_LVL;

    // Qualified write access. Internal registers may only be updated
    // during an acknowledged Wishbone write cycle.
    assign wb_wacc = wb_we_i & wb_ack_o;

    // ---------------------------------------------------------------
    // Generate registered Wishbone acknowledge.
    // wb_ack_o pulses high for one cycle for every valid bus access,
    // because of the ~wb_ack_o feedback term.
    // ---------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            wb_ack_o <= 1'b0;
        else if (wb_rst_i)
            wb_ack_o <= 1'b0;
        else
            wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
    end

    // ---------------------------------------------------------------
    // Registered read-data output.
    // wb_dat_o is updated on every rising clock edge based on wb_adr_i.
    // Standard mapping:
    //   0x00: PRER[7:0]
    //   0x01: PRER[15:8]
    //   0x02: CTR
    //   0x03: RXR
    //   0x04: SR
    // RTL extensions (not in standard register map):
    //   0x05: TXR readback
    //   0x06: CR  readback
    //   0x07: 0x00 (reserved)
    // ---------------------------------------------------------------
    always @(posedge wb_clk_i) begin
        case (wb_adr_i) // synopsys parallel_case
            3'b000: wb_dat_o <= prer[ 7:0];
            3'b001: wb_dat_o <= prer[15:8];
            3'b010: wb_dat_o <= ctr;
            3'b011: wb_dat_o <= rxr;        // receive register
            3'b100: wb_dat_o <= sr;         // status register
            3'b101: wb_dat_o <= txr;        // RTL extension
            3'b110: wb_dat_o <= cr;         // RTL extension
            3'b111: wb_dat_o <= 8'h00;      // reserved
        endcase
    end

    // ---------------------------------------------------------------
    // Regular register writes (PRER, CTR, TXR).
    // CR is handled separately because it has gating on core_en
    // and special auto-clear behavior.
    // ---------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            // Asynchronous reset values per specification:
            // prescale register reset to 0xFFFF, others cleared.
            prer <= 16'hffff;
            ctr  <=  8'h00;
            txr  <=  8'h00;
        end
        else if (wb_rst_i) begin
            // Synchronous Wishbone reset, same reset values.
            prer <= 16'hffff;
            ctr  <=  8'h00;
            txr  <=  8'h00;
        end
        else if (wb_wacc) begin
            case (wb_adr_i) // synopsys parallel_case
                3'b000: prer[ 7:0] <= wb_dat_i;
                3'b001: prer[15:8] <= wb_dat_i;
                3'b010: ctr        <= wb_dat_i;
                3'b011: txr        <= wb_dat_i;
                default: ;
            endcase
        end
    end

    // ---------------------------------------------------------------
    // Command register CR.
    // Special behavior:
    //   - Host writes are gated by core_en (CTR[7]).
    //   - STA/STO/RD/WR command bits cleared when byte controller
    //     completes (done) or arbitration is lost (i2c_al).
    //   - IACK and reserved CR[2:1] always self-clear next cycle.
    // ---------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            cr <= 8'h00;
        else if (wb_rst_i)
            cr <= 8'h00;
        else if (wb_wacc) begin
            // Command register can only be written when the core is enabled.
            if (core_en && (wb_adr_i == 3'b100))
                cr <= wb_dat_i;
        end
        else begin
            // Auto-clear behavior:
            // When the byte controller signals done, or arbitration is lost,
            // clear the command bits STA/STO/RD/WR.
            if (done | i2c_al)
                cr[7:4] <= 4'h0;

            // The interrupt acknowledge and reserved bits self-clear so
            // that they pulse for one cycle only.
            cr[2:1] <= 2'b0;
            cr[0]   <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Decode control register and command register
    // ---------------------------------------------------------------
    assign core_en = ctr[7];   // I2C core enable
    assign ien     = ctr[6];   // interrupt enable

    assign sta  = cr[7];       // START command
    assign sto  = cr[6];       // STOP command
    assign rd   = cr[5];       // READ command
    assign wr   = cr[4];       // WRITE command
    assign ack  = cr[3];       // ACK/NACK select for receive
    assign iack = cr[0];       // interrupt acknowledge

    // ---------------------------------------------------------------
    // Instantiate the byte-level controller.
    // It performs the actual I2C byte transfers using SCL/SDA.
    // ---------------------------------------------------------------
    i2c_master_byte_ctrl byte_controller (
        .clk      ( wb_clk_i     ),
        .rst      ( wb_rst_i     ),
        .nReset   ( rst_i        ),
        .ena      ( core_en      ),
        .clk_cnt  ( prer         ),
        .start    ( sta          ),
        .stop     ( sto          ),
        .read     ( rd           ),
        .write    ( wr           ),
        .ack_in   ( ack          ),
        .din      ( txr          ),
        .cmd_ack  ( done         ),
        .ack_out  ( irxack       ),
        .dout     ( rxr          ),
        .i2c_busy ( i2c_busy     ),
        .i2c_al   ( i2c_al       ),
        .scl_i    ( scl_pad_i    ),
        .scl_o    ( scl_pad_o    ),
        .scl_oen  ( scl_padoen_o ),
        .sda_i    ( sda_pad_i    ),
        .sda_o    ( sda_pad_o    ),
        .sda_oen  ( sda_padoen_o )
    );

    // ---------------------------------------------------------------
    // Status bits maintenance
    // ---------------------------------------------------------------

    // Latched received-acknowledge status.
    // RxACK = 1 means no acknowledge received (NACK).
    // RxACK = 0 means acknowledge received (ACK).
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i) begin
            al       <= 1'b0;
            rxack    <= 1'b0;
            tip      <= 1'b0;
            irq_flag <= 1'b0;
        end
        else if (wb_rst_i) begin
            al       <= 1'b0;
            rxack    <= 1'b0;
            tip      <= 1'b0;
            irq_flag <= 1'b0;
        end
        else begin
            // Arbitration-lost status: set by i2c_al, cleared on new START.
            al       <= i2c_al | (al & ~sta);

            // Received-ACK status sampled from the byte controller.
            rxack    <= irxack;

            // Transfer-in-progress reflects whether a read or write
            // command is currently active.
            tip      <= (rd | wr);

            // Interrupt flag: set on byte-command completion or arbitration
            // loss; cleared by host writing IACK.
            irq_flag <= (done | i2c_al | irq_flag) & ~iack;
        end
    end

    // ---------------------------------------------------------------
    // Wishbone interrupt output.
    // Asserted when interrupt is pending and IEN is enabled.
    // ---------------------------------------------------------------
    always @(posedge wb_clk_i or negedge rst_i) begin
        if (!rst_i)
            wb_inta_o <= 1'b0;
        else if (wb_rst_i)
            wb_inta_o <= 1'b0;
        else
            wb_inta_o <= irq_flag & ien;
    end

    // ---------------------------------------------------------------
    // Assemble the status register.
    //   sr[7]   = rxack
    //   sr[6]   = i2c_busy
    //   sr[5]   = al
    //   sr[4:2] = 3'h0  (reserved)
    //   sr[1]   = tip
    //   sr[0]   = irq_flag
    // ---------------------------------------------------------------
    assign sr[7]   = rxack;
    assign sr[6]   = i2c_busy;
    assign sr[5]   = al;
    assign sr[4:2] = 3'h0;
    assign sr[1]   = tip;
    assign sr[0]   = irq_flag;

endmodule
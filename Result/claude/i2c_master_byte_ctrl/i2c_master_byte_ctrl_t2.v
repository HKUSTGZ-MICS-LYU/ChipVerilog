//////////////////////////////////////////////////////////////////////
////                                                              ////
////  i2c_master_byte_ctrl.v                                      ////
////                                                              ////
////  I2C Master Byte-Level Controller                            ////
////                                                              ////
////  Sequences byte-level I2C operations (START, STOP, READ,    ////
////  WRITE) by issuing bit-level commands to i2c_master_bit_ctrl.////
////  Handles 8-bit shift register, ACK/NACK phase, optional     ////
////  STOP generation, and cmd_ack completion signaling.         ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

// Bit-level command encodings (must match i2c_master_bit_ctrl)
`define I2C_CMD_NOP   4'b0000
`define I2C_CMD_START 4'b0001
`define I2C_CMD_STOP  4'b0010
`define I2C_CMD_WRITE 4'b0100
`define I2C_CMD_READ  4'b1000

module i2c_master_byte_ctrl (
    input             clk,       // master clock
    input             rst,       // synchronous active-high reset
    input             nReset,    // asynchronous active-low reset
    input             ena,       // core enable (passed to bit controller)
    input      [15:0] clk_cnt,   // SCL prescale (4x SCL), passed to bit controller

    // Byte-level command inputs
    input             start,     // generate START/repeated START before operation
    input             stop,      // generate STOP after operation
    input             read,      // read one byte from I2C bus
    input             write,     // write one byte to I2C bus
    input             ack_in,    // master ACK/NACK sent after read (0=ACK, 1=NACK)
    input      [ 7:0] din,       // byte to transmit

    // Byte-level command outputs
    output reg        cmd_ack,   // byte-command completion pulse
    output reg        ack_out,   // slave ACK/NACK captured after write (0=ACK,1=NACK)
    output     [ 7:0] dout,      // received byte (= shift register sr)

    // Status from bit controller
    output            i2c_busy,  // I2C bus busy
    output            i2c_al,    // arbitration lost

    // I2C pad signals (passed through bit controller)
    input             scl_i,
    output            scl_o,
    output            scl_oen,
    input             sda_i,
    output            sda_o,
    output            sda_oen
);

    //------------------------------------------------------------------
    // Internal signals to/from bit controller
    //------------------------------------------------------------------
    reg  [ 3:0] core_cmd;    // bit-level command
    reg         core_txd;    // transmit bit to bit controller
    wire        core_ack;    // bit-command completion from bit controller
    wire        core_rxd;    // received bit from bit controller

    //------------------------------------------------------------------
    // Instantiate bit-level controller
    //------------------------------------------------------------------
    i2c_master_bit_ctrl bit_controller (
        .clk     (clk),
        .rst     (rst),
        .nReset  (nReset),
        .ena     (ena),
        .clk_cnt (clk_cnt),
        .cmd     (core_cmd),
        .cmd_ack (core_ack),
        .busy    (i2c_busy),
        .al      (i2c_al),
        .din     (core_txd),
        .dout    (core_rxd),
        .scl_i   (scl_i),
        .scl_o   (scl_o),
        .scl_oen (scl_oen),
        .sda_i   (sda_i),
        .sda_o   (sda_o),
        .sda_oen (sda_oen)
    );

    //------------------------------------------------------------------
    // Shift register and bit counter
    //------------------------------------------------------------------
    reg [7:0] sr;       // 8-bit DataIO shift register
    reg [2:0] dcnt;     // 3-bit bit counter (counts down from 7)
    wire      cnt_done; // asserted when dcnt == 0

    assign cnt_done = (dcnt == 3'h0);
    assign dout     = sr;   // received byte always readable from sr

    //------------------------------------------------------------------
    // Datapath: shift register and bit counter
    //------------------------------------------------------------------
    reg ld;    // load sr from din, dcnt from 7
    reg shift; // shift sr left, insert core_rxd into LSB, decrement dcnt

    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            sr   <= 8'h0;
            dcnt <= 3'h0;
        end else if (rst) begin
            sr   <= 8'h0;
            dcnt <= 3'h0;
        end else begin
            if (ld) begin
                sr   <= din;
                dcnt <= 3'h7;
            end else if (shift) begin
                sr   <= {sr[6:0], core_rxd};  // MSB-first tx, LSB-first rx shift
                dcnt <= dcnt - 3'h1;
            end
        end
    end

    //------------------------------------------------------------------
    // core_txd: default to sr[7] (MSB-first) except during ACK phase
    // where ack_in is driven. Overridden combinatorially in FSM.
    //------------------------------------------------------------------

    //------------------------------------------------------------------
    // Command launch condition
    //------------------------------------------------------------------
    wire go = (read | write | stop) & ~cmd_ack;

    //------------------------------------------------------------------
    // FSM state encoding
    //------------------------------------------------------------------
    parameter [2:0]
        ST_IDLE  = 3'b000,
        ST_START = 3'b001,
        ST_READ  = 3'b010,
        ST_WRITE = 3'b011,
        ST_ACK   = 3'b100,
        ST_STOP  = 3'b101;

    reg [2:0] c_state;

    //------------------------------------------------------------------
    // FSM
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            c_state  <= ST_IDLE;
            core_cmd <= `I2C_CMD_NOP;
            core_txd <= 1'b0;
            cmd_ack  <= 1'b0;
            ack_out  <= 1'b0;
            ld       <= 1'b0;
            shift    <= 1'b0;
        end else if (rst | i2c_al) begin
            // Synchronous reset or arbitration lost: abort to idle
            c_state  <= ST_IDLE;
            core_cmd <= `I2C_CMD_NOP;
            core_txd <= 1'b0;
            cmd_ack  <= 1'b0;
            ack_out  <= 1'b0;
            ld       <= 1'b0;
            shift    <= 1'b0;
        end else begin
            // Default: clear one-cycle strobes
            cmd_ack <= 1'b0;
            ld      <= 1'b0;
            shift   <= 1'b0;

            case (c_state)

                //------------------------------------------------------
                // ST_IDLE: wait for a byte-level command
                //------------------------------------------------------
                ST_IDLE: begin
                    if (go) begin
                        // Load shift register and bit counter
                        ld <= 1'b1;

                        if (start) begin
                            // Issue START to bit controller first
                            core_cmd <= `I2C_CMD_START;
                            c_state  <= ST_START;
                        end else if (read) begin
                            core_cmd <= `I2C_CMD_READ;
                            core_txd <= ack_in;
                            c_state  <= ST_READ;
                        end else if (write) begin
                            core_cmd <= `I2C_CMD_WRITE;
                            core_txd <= din[7];   // MSB first (sr not yet loaded)
                            c_state  <= ST_WRITE;
                        end else begin
                            // stop only
                            core_cmd <= `I2C_CMD_STOP;
                            c_state  <= ST_STOP;
                        end
                    end else begin
                        core_cmd <= `I2C_CMD_NOP;
                    end
                end

                //------------------------------------------------------
                // ST_START: wait for START/repeated START to complete
                //------------------------------------------------------
                ST_START: begin
                    if (core_ack) begin
                        if (read) begin
                            core_cmd <= `I2C_CMD_READ;
                            core_txd <= ack_in;
                            c_state  <= ST_READ;
                        end else begin
                            core_cmd <= `I2C_CMD_WRITE;
                            core_txd <= sr[7];    // MSB of loaded shift register
                            c_state  <= ST_WRITE;
                        end
                    end
                end

                //------------------------------------------------------
                // ST_WRITE: transmit 8 bits MSB-first, then read slave ACK
                //------------------------------------------------------
                ST_WRITE: begin
                    if (core_ack) begin
                        if (cnt_done) begin
                            // All 8 bits sent — sample slave ACK/NACK
                            core_cmd <= `I2C_CMD_READ;
                            c_state  <= ST_ACK;
                        end else begin
                            // More bits to send
                            shift    <= 1'b1;
                            core_cmd <= `I2C_CMD_WRITE;
                            // sr will be shifted next cycle; drive current sr[7]
                            // After shift: new MSB is sr[6], but shift is async-registered,
                            // so we need to use sr[6] as the next bit to transmit.
                            core_txd <= sr[6];
                        end
                    end else begin
                        // Waiting — keep driving current MSB
                        core_txd <= sr[7];
                    end
                end

                //------------------------------------------------------
                // ST_READ: receive 8 bits, then send master ACK/NACK
                //------------------------------------------------------
                ST_READ: begin
                    if (core_ack) begin
                        shift <= 1'b1;   // shift core_rxd into sr

                        if (cnt_done) begin
                            // All 8 bits received — send master ACK/NACK
                            core_cmd <= `I2C_CMD_WRITE;
                            core_txd <= ack_in;
                            c_state  <= ST_ACK;
                        end else begin
                            core_cmd <= `I2C_CMD_READ;
                            core_txd <= ack_in;
                        end
                    end
                end

                //------------------------------------------------------
                // ST_ACK: handle the 9th (ACK/NACK) bit
                //   - after WRITE: bit controller just READ the slave ACK
                //   - after READ:  bit controller just WROTE the master ACK
                //------------------------------------------------------
                ST_ACK: begin
                    if (core_ack) begin
                        // Capture slave ACK (meaningful after write transfer)
                        ack_out <= core_rxd;

                        if (stop) begin
                            core_cmd <= `I2C_CMD_STOP;
                            c_state  <= ST_STOP;
                        end else begin
                            core_cmd <= `I2C_CMD_NOP;
                            cmd_ack  <= 1'b1;
                            c_state  <= ST_IDLE;
                        end
                    end
                end

                //------------------------------------------------------
                // ST_STOP: wait for STOP condition to complete
                //------------------------------------------------------
                ST_STOP: begin
                    if (core_ack) begin
                        core_cmd <= `I2C_CMD_NOP;
                        cmd_ack  <= 1'b1;
                        c_state  <= ST_IDLE;
                    end
                end

                default: c_state <= ST_IDLE;

            endcase
        end
    end

endmodule

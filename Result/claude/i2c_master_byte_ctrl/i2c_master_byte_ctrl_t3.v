//////////////////////////////////////////////////////////////////////
////                                                              ////
////  i2c_master_byte_ctrl.v                                       ////
////                                                              ////
////  Byte-level command controller for the OpenCores I2C master. ////
////  Receives byte-level requests (start/stop/read/write/ack_in/  ////
////  din) and translates them into bit-level commands (START,    ////
////  STOP, READ, WRITE, NOP) for the i2c_master_bit_ctrl.        ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`timescale 1ns / 10ps

module i2c_master_byte_ctrl (
    clk, rst, nReset, ena, clk_cnt,
    start, stop, read, write, ack_in, din,
    cmd_ack, ack_out, dout, i2c_busy, i2c_al,
    scl_i, scl_o, scl_oen, sda_i, sda_o, sda_oen
);

    //
    // inputs & outputs
    //
    input         clk;
    input         rst;
    input         nReset;
    input         ena;
    input  [15:0] clk_cnt;

    // control inputs
    input         start;
    input         stop;
    input         read;
    input         write;
    input         ack_in;
    input  [ 7:0] din;

    // status outputs
    output        cmd_ack;
    reg           cmd_ack;
    output        ack_out;
    reg           ack_out;
    output [ 7:0] dout;
    output        i2c_busy;
    output        i2c_al;

    // I2C signals
    input         scl_i;
    output        scl_o;
    output        scl_oen;
    input         sda_i;
    output        sda_o;
    output        sda_oen;

    //
    // bit controller commands
    //
    parameter [3:0] I2C_CMD_NOP   = 4'b0000;
    parameter [3:0] I2C_CMD_START = 4'b0001;
    parameter [3:0] I2C_CMD_STOP  = 4'b0010;
    parameter [3:0] I2C_CMD_READ  = 4'b0100;
    parameter [3:0] I2C_CMD_WRITE = 4'b1000;

    //
    // FSM states
    //
    parameter [4:0] ST_IDLE  = 5'b0_0000;
    parameter [4:0] ST_START = 5'b0_0001;
    parameter [4:0] ST_READ  = 5'b0_0010;
    parameter [4:0] ST_WRITE = 5'b0_0100;
    parameter [4:0] ST_ACK   = 5'b0_1000;
    parameter [4:0] ST_STOP  = 5'b1_0000;

    //
    // internal signals
    //
    reg  [3:0] core_cmd;
    reg        core_txd;
    wire       core_ack;
    wire       core_rxd;

    reg  [7:0] sr;        // 8-bit shift register
    reg  [2:0] dcnt;      // data bit counter
    wire       cnt_done;  // counter done

    reg        shift;     // shift sr
    reg        ld;        // load sr from din

    reg  [4:0] c_state;   // current FSM state

    wire       go;        // command launch condition

    //
    // shift register: load on `ld`, shift left and insert core_rxd on `shift`
    //
    always @(posedge clk or negedge nReset) begin
        if (!nReset)
            sr <= 8'h00;
        else if (rst)
            sr <= 8'h00;
        else if (ld)
            sr <= din;
        else if (shift)
            sr <= {sr[6:0], core_rxd};
    end

    assign dout = sr;

    //
    // bit counter
    //
    always @(posedge clk or negedge nReset) begin
        if (!nReset)
            dcnt <= 3'h0;
        else if (rst)
            dcnt <= 3'h0;
        else if (ld)
            dcnt <= 3'h7;
        else if (shift)
            dcnt <= dcnt - 3'h1;
    end

    assign cnt_done = ~(|dcnt);

    //
    // command launch condition
    //
    assign go = (read | write | stop) & ~cmd_ack;

    //
    // FSM
    //
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            core_cmd <= I2C_CMD_NOP;
            core_txd <= 1'b0;
            shift    <= 1'b0;
            ld       <= 1'b0;
            cmd_ack  <= 1'b0;
            ack_out  <= 1'b0;
            c_state  <= ST_IDLE;
        end
        else if (rst | i2c_al) begin
            core_cmd <= I2C_CMD_NOP;
            core_txd <= 1'b0;
            shift    <= 1'b0;
            ld       <= 1'b0;
            cmd_ack  <= 1'b0;
            ack_out  <= 1'b0;
            c_state  <= ST_IDLE;
        end
        else begin
            // default values
            cmd_ack <= 1'b0;
            shift   <= 1'b0;
            ld      <= 1'b0;

            case (c_state)
                ST_IDLE: begin
                    if (go) begin
                        // priority: start > read > write > stop
                        if (start) begin
                            c_state  <= ST_START;
                            core_cmd <= I2C_CMD_START;
                        end
                        else if (read) begin
                            c_state  <= ST_READ;
                            core_cmd <= I2C_CMD_READ;
                        end
                        else if (write) begin
                            c_state  <= ST_WRITE;
                            core_cmd <= I2C_CMD_WRITE;
                        end
                        else begin // stop
                            c_state  <= ST_STOP;
                            core_cmd <= I2C_CMD_STOP;
                        end

                        ld <= 1'b1; // load shift register and counter
                    end
                end

                ST_START: begin
                    if (core_ack) begin
                        if (read) begin
                            c_state  <= ST_READ;
                            core_cmd <= I2C_CMD_READ;
                        end
                        else begin
                            c_state  <= ST_WRITE;
                            core_cmd <= I2C_CMD_WRITE;
                        end

                        // transmit MSB-first; drive sr[7] for write
                        core_txd <= sr[7];
                    end
                end

                ST_WRITE: begin
                    if (core_ack) begin
                        if (cnt_done) begin
                            // last data bit transmitted; sample slave ACK
                            c_state  <= ST_ACK;
                            core_cmd <= I2C_CMD_READ;
                        end
                        else begin
                            // shift to next bit
                            c_state  <= ST_WRITE;
                            core_cmd <= I2C_CMD_WRITE;
                            shift    <= 1'b1;
                        end

                        core_txd <= sr[7];
                    end
                end

                ST_READ: begin
                    if (core_ack) begin
                        if (cnt_done) begin
                            // last data bit received; send master ACK/NACK
                            c_state  <= ST_ACK;
                            core_cmd <= I2C_CMD_WRITE;
                            core_txd <= ack_in;
                        end
                        else begin
                            c_state  <= ST_READ;
                            core_cmd <= I2C_CMD_READ;
                            core_txd <= ack_in; // not used during read
                        end

                        shift <= 1'b1;
                    end
                end

                ST_ACK: begin
                    if (core_ack) begin
                        // capture slave ACK/NACK (relevant for write phase)
                        ack_out <= core_rxd;

                        // generate STOP if requested, otherwise idle
                        if (stop) begin
                            c_state  <= ST_STOP;
                            core_cmd <= I2C_CMD_STOP;
                        end
                        else begin
                            c_state  <= ST_IDLE;
                            core_cmd <= I2C_CMD_NOP;
                            cmd_ack  <= 1'b1;
                        end

                        // hold SDA high (release) during ack -> stop transition
                        core_txd <= 1'b1;
                    end
                    else begin
                        // keep ack_in / 1 driven through core_txd
                        core_txd <= ack_in;
                    end
                end

                ST_STOP: begin
                    if (core_ack) begin
                        c_state  <= ST_IDLE;
                        core_cmd <= I2C_CMD_NOP;
                        cmd_ack  <= 1'b1;
                    end
                end

                default: begin
                    c_state  <= ST_IDLE;
                    core_cmd <= I2C_CMD_NOP;
                end
            endcase
        end
    end

    //
    // hookup bit-level I2C controller
    //
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

endmodule
//////////////////////////////////////////////////////////////////////
////                                                              ////
////  i2c_master_bit_ctrl                                          ////
////                                                              ////
////  Bit-level controller of the OpenCores I2C master core.       ////
////  Translates bit commands (START/STOP/READ/WRITE) from the    ////
////  byte-level controller into timed SCL/SDA open-drain         ////
////  control sequences.                                          ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`timescale 1ns / 10ps

module i2c_master_bit_ctrl (
    input             clk,      // system clock
    input             rst,      // synchronous active high reset
    input             nReset,   // asynchronous active low reset
    input             ena,      // core enable signal

    input      [15:0] clk_cnt,  // clock prescale value

    input      [ 3:0] cmd,      // command (from byte controller)
    output reg        cmd_ack,  // command complete acknowledge
    output reg        busy,     // i2c bus busy
    output reg        al,       // i2c bus arbitration lost

    input             din,
    output reg        dout,

    input             scl_i,    // i2c clock line input
    output            scl_o,    // i2c clock line output
    output reg        scl_oen,  // i2c clock line output enable (active low)
    input             sda_i,    // i2c data line input
    output            sda_o,    // i2c data line output
    output reg        sda_oen   // i2c data line output enable (active low)
);

    //
    // Command parameters
    //
    parameter [3:0] I2C_CMD_NOP   = 4'b0000;
    parameter [3:0] I2C_CMD_START = 4'b0001;
    parameter [3:0] I2C_CMD_STOP  = 4'b0010;
    parameter [3:0] I2C_CMD_READ  = 4'b0100;
    parameter [3:0] I2C_CMD_WRITE = 4'b1000;

    //
    // FSM state encoding
    //
    parameter [17:0] idle    = 18'b0_0000_0000_0000_0000_0;
    parameter [17:0] start_a = 18'b0_0000_0000_0000_0000_1;
    parameter [17:0] start_b = 18'b0_0000_0000_0000_0001_0;
    parameter [17:0] start_c = 18'b0_0000_0000_0000_0010_0;
    parameter [17:0] start_d = 18'b0_0000_0000_0000_0100_0;
    parameter [17:0] start_e = 18'b0_0000_0000_0000_1000_0;
    parameter [17:0] stop_a  = 18'b0_0000_0000_0001_0000_0;
    parameter [17:0] stop_b  = 18'b0_0000_0000_0010_0000_0;
    parameter [17:0] stop_c  = 18'b0_0000_0000_0100_0000_0;
    parameter [17:0] stop_d  = 18'b0_0000_0000_1000_0000_0;
    parameter [17:0] rd_a    = 18'b0_0000_0001_0000_0000_0;
    parameter [17:0] rd_b    = 18'b0_0000_0010_0000_0000_0;
    parameter [17:0] rd_c    = 18'b0_0000_0100_0000_0000_0;
    parameter [17:0] rd_d    = 18'b0_0000_1000_0000_0000_0;
    parameter [17:0] wr_a    = 18'b0_0001_0000_0000_0000_0;
    parameter [17:0] wr_b    = 18'b0_0010_0000_0000_0000_0;
    parameter [17:0] wr_c    = 18'b0_0100_0000_0000_0000_0;
    parameter [17:0] wr_d    = 18'b0_1000_0000_0000_0000_0;

    //
    // Internal signals
    //
    reg [17:0] c_state;            // current state of FSM

    reg        sSCL, sSDA;         // synchronized (filtered) SCL and SDA inputs
    reg        dSCL, dSDA;         // delayed versions of sSCL and sSDA
    reg [ 1:0] cSCL, cSDA;         // capture stage (2-stage sync) of SCL and SDA
    reg [ 2:0] fSCL, fSDA;         // filter shift registers for SCL and SDA

    reg        clk_en;             // clock enable signal (FSM advance tick)
    reg        slave_wait;         // slave is stretching SCL low

    reg [15:0] cnt;                // clock divider counter
    reg [13:0] filter_cnt;         // input filter counter

    reg        sta_condition;      // start condition detected
    reg        sto_condition;      // stop condition detected

    reg        sda_chk;            // check SDA during arbitration

    wire       scl_sync;           // multi-master SCL synchronization signal
    wire       cmd_stop;           // commanded STOP

    //
    // Open-drain outputs: line is pulled low only via output-enables
    //
    assign scl_o = 1'b0;
    assign sda_o = 1'b0;

    //
    // Whether the current command is a STOP
    //
    assign cmd_stop = (cmd == I2C_CMD_STOP);

    //
    // Multi-master clock synchronization:
    // detect a falling edge on filtered SCL while we have released SCL high.
    //
    assign scl_sync = dSCL & ~sSCL & scl_oen;

    //
    // Slave clock stretching:
    // we have released SCL high but filtered SCL input is still low.
    //
    always @(posedge clk or negedge nReset)
        if (!nReset)
            slave_wait <= 1'b0;
        else
            slave_wait <= (scl_oen & ~dSCL & ~sSCL) | (slave_wait & ~sSCL);

    //
    // Clock divider / bit-timing generator
    //
    always @(posedge clk or negedge nReset)
        if (!nReset) begin
            cnt    <= 16'h0;
            clk_en <= 1'b1;
        end
        else if (rst) begin
            cnt    <= 16'h0;
            clk_en <= 1'b1;
        end
        else if (~|cnt || !ena || scl_sync) begin
            cnt    <= clk_cnt;
            clk_en <= 1'b1;
        end
        else if (slave_wait) begin
            cnt    <= cnt;
            clk_en <= 1'b0;
        end
        else begin
            cnt    <= cnt - 16'h1;
            clk_en <= 1'b0;
        end

    //
    // Two-stage synchronization of raw SCL/SDA inputs
    // (reduces metastability risk)
    //
    always @(posedge clk or negedge nReset)
        if (!nReset) begin
            cSCL <= 2'b11;
            cSDA <= 2'b11;
        end
        else if (rst) begin
            cSCL <= 2'b11;
            cSDA <= 2'b11;
        end
        else begin
            cSCL <= {cSCL[0], scl_i};
            cSDA <= {cSDA[0], sda_i};
        end

    //
    // Input filter counter:
    // sample period is derived from clk_cnt >> 2.
    //
    always @(posedge clk or negedge nReset)
        if (!nReset)
            filter_cnt <= 14'h0;
        else if (rst || !ena)
            filter_cnt <= 14'h0;
        else if (~|filter_cnt)
            filter_cnt <= clk_cnt >> 2;
        else
            filter_cnt <= filter_cnt - 14'h1;

    //
    // Filter shift registers - shift in new sync samples when filter_cnt expires.
    //
    always @(posedge clk or negedge nReset)
        if (!nReset) begin
            fSCL <= 3'b111;
            fSDA <= 3'b111;
        end
        else if (rst) begin
            fSCL <= 3'b111;
            fSDA <= 3'b111;
        end
        else if (~|filter_cnt) begin
            fSCL <= {fSCL[1:0], cSCL[1]};
            fSDA <= {fSDA[1:0], cSDA[1]};
        end

    //
    // Majority filter on SCL/SDA: stable internal versions of the bus.
    //
    always @(posedge clk or negedge nReset)
        if (!nReset) begin
            sSCL <= 1'b1;
            sSDA <= 1'b1;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
        end
        else if (rst) begin
            sSCL <= 1'b1;
            sSDA <= 1'b1;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
        end
        else begin
            sSCL <= (fSCL[2] & fSCL[1]) | (fSCL[2] & fSCL[0]) | (fSCL[1] & fSCL[0]);
            sSDA <= (fSDA[2] & fSDA[1]) | (fSDA[2] & fSDA[0]) | (fSDA[1] & fSDA[0]);
            dSCL <= sSCL;
            dSDA <= sSDA;
        end

    //
    // START / STOP detection
    //
    always @(posedge clk or negedge nReset)
        if (!nReset) begin
            sta_condition <= 1'b0;
            sto_condition <= 1'b0;
        end
        else if (rst) begin
            sta_condition <= 1'b0;
            sto_condition <= 1'b0;
        end
        else begin
            sta_condition <= ~sSDA &  dSDA & sSCL;
            sto_condition <=  sSDA & ~dSDA & sSCL;
        end

    //
    // Bus busy tracking
    //
    always @(posedge clk or negedge nReset)
        if (!nReset)
            busy <= 1'b0;
        else if (rst)
            busy <= 1'b0;
        else
            busy <= (sta_condition | busy) & ~sto_condition;

    //
    // Arbitration-lost detection
    //
    reg cmd_stop_r;
    always @(posedge clk or negedge nReset)
        if (!nReset)
            cmd_stop_r <= 1'b0;
        else if (rst)
            cmd_stop_r <= 1'b0;
        else if (clk_en)
            cmd_stop_r <= cmd_stop;

    always @(posedge clk or negedge nReset)
        if (!nReset)
            al <= 1'b0;
        else if (rst)
            al <= 1'b0;
        else
            al <= (sda_chk & ~sSDA & sda_oen) |
                  (|c_state & sto_condition & ~cmd_stop_r);

    //
    // Read data sampling: capture filtered SDA on rising edge of filtered SCL
    //
    always @(posedge clk or negedge nReset)
        if (!nReset)
            dout <= 1'b0;
        else if (rst)
            dout <= 1'b0;
        else if (sSCL & ~dSCL)
            dout <= sSDA;

    //
    // Main bit-level command FSM
    //
    always @(posedge clk or negedge nReset)
        if (!nReset) begin
            c_state <= idle;
            cmd_ack <= 1'b0;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            sda_chk <= 1'b0;
        end
        else if (rst || al) begin
            c_state <= idle;
            cmd_ack <= 1'b0;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            sda_chk <= 1'b0;
        end
        else begin
            // default: deassert cmd_ack each cycle (it is a 1-cycle pulse)
            cmd_ack <= 1'b0;

            if (clk_en)
                case (c_state)
                    // ---------------- IDLE ----------------
                    idle:
                    begin
                        case (cmd)
                            I2C_CMD_START: c_state <= start_a;
                            I2C_CMD_STOP:  c_state <= stop_a;
                            I2C_CMD_WRITE: c_state <= wr_a;
                            I2C_CMD_READ:  c_state <= rd_a;
                            default:       c_state <= idle;
                        endcase
                        scl_oen <= scl_oen;
                        sda_oen <= sda_oen;
                        sda_chk <= 1'b0;
                    end

                    // ---------------- START ----------------
                    start_a:
                    begin
                        c_state <= start_b;
                        scl_oen <= scl_oen;   // keep SCL as-is
                        sda_oen <= 1'b1;      // release SDA
                        sda_chk <= 1'b0;
                    end

                    start_b:
                    begin
                        c_state <= start_c;
                        scl_oen <= 1'b1;      // release SCL high
                        sda_oen <= 1'b1;      // SDA high
                        sda_chk <= 1'b0;
                    end

                    start_c:
                    begin
                        c_state <= start_d;
                        scl_oen <= 1'b1;      // SCL high
                        sda_oen <= 1'b0;      // pull SDA low while SCL high -> START
                        sda_chk <= 1'b0;
                    end

                    start_d:
                    begin
                        c_state <= start_e;
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b0;
                        sda_chk <= 1'b0;
                    end

                    start_e:
                    begin
                        c_state <= idle;
                        cmd_ack <= 1'b1;
                        scl_oen <= 1'b0;      // pull SCL low
                        sda_oen <= 1'b0;
                        sda_chk <= 1'b0;
                    end

                    // ---------------- STOP ----------------
                    stop_a:
                    begin
                        c_state <= stop_b;
                        scl_oen <= 1'b0;      // SCL low
                        sda_oen <= 1'b0;      // SDA low
                        sda_chk <= 1'b0;
                    end

                    stop_b:
                    begin
                        c_state <= stop_c;
                        scl_oen <= 1'b1;      // release SCL high
                        sda_oen <= 1'b0;      // SDA still low
                        sda_chk <= 1'b0;
                    end

                    stop_c:
                    begin
                        c_state <= stop_d;
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b0;
                        sda_chk <= 1'b0;
                    end

                    stop_d:
                    begin
                        c_state <= idle;
                        cmd_ack <= 1'b1;
                        scl_oen <= 1'b1;      // SCL high
                        sda_oen <= 1'b1;      // SDA released high while SCL high -> STOP
                        sda_chk <= 1'b0;
                    end

                    // ---------------- READ ----------------
                    rd_a:
                    begin
                        c_state <= rd_b;
                        scl_oen <= 1'b0;      // SCL low
                        sda_oen <= 1'b1;      // release SDA so slave can drive
                        sda_chk <= 1'b0;
                    end

                    rd_b:
                    begin
                        c_state <= rd_c;
                        scl_oen <= 1'b1;      // release SCL high
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                    end

                    rd_c:
                    begin
                        c_state <= rd_d;
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                    end

                    rd_d:
                    begin
                        c_state <= idle;
                        cmd_ack <= 1'b1;
                        scl_oen <= 1'b0;      // SCL low
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                    end

                    // ---------------- WRITE ----------------
                    wr_a:
                    begin
                        c_state <= wr_b;
                        scl_oen <= 1'b0;      // SCL low
                        sda_oen <= din;       // drive SDA according to din
                        sda_chk <= 1'b0;
                    end

                    wr_b:
                    begin
                        c_state <= wr_c;
                        scl_oen <= 1'b1;      // release SCL high
                        sda_oen <= din;
                        sda_chk <= 1'b0;
                    end

                    wr_c:
                    begin
                        c_state <= wr_d;
                        scl_oen <= 1'b1;
                        sda_oen <= din;
                        sda_chk <= 1'b1;      // arbitration check during high phase
                    end

                    wr_d:
                    begin
                        c_state <= idle;
                        cmd_ack <= 1'b1;
                        scl_oen <= 1'b0;      // SCL low again
                        sda_oen <= din;
                        sda_chk <= 1'b0;
                    end

                    default: c_state <= idle;
                endcase
        end

endmodule
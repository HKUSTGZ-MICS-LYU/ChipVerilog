//////////////////////////////////////////////////////////////////////
////                                                              ////
////  i2c_master_bit_ctrl.v                                       ////
////                                                              ////
////  I2C Master Bit-Level Controller                             ////
////                                                              ////
////  Translates bit-level commands (START, STOP, READ, WRITE)   ////
////  from the byte controller into timed SCL/SDA sequences.     ////
////  Implements open-drain bus control, clock stretching,        ////
////  multi-master synchronization, glitch filtering,            ////
////  arbitration-lost detection, and START/STOP detection.      ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

// Command encodings
`define I2C_CMD_NOP   4'b0000
`define I2C_CMD_START 4'b0001
`define I2C_CMD_STOP  4'b0010
`define I2C_CMD_WRITE 4'b0100
`define I2C_CMD_READ  4'b1000

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
    output            scl_o,    // i2c clock line output (constant low)
    output reg        scl_oen,  // i2c clock line output enable (active low)
    input             sda_i,    // i2c data line input
    output            sda_o,    // i2c data line output (constant low)
    output reg        sda_oen,  // i2c data line output enable (active low)
    output reg        sda_chk   // enable SDA arbitration check
);

    //------------------------------------------------------------------
    // Open-drain: always drive constant low; line level set by oen
    //------------------------------------------------------------------
    assign scl_o = 1'b0;
    assign sda_o = 1'b0;

    //------------------------------------------------------------------
    // FSM state encoding
    //------------------------------------------------------------------
    // Using one-hot-like named parameters for clarity
    parameter [4:0]
        idle    = 5'b00000,
        // START states
        start_a = 5'b00001,
        start_b = 5'b00010,
        start_c = 5'b00011,
        start_d = 5'b00100,
        start_e = 5'b00101,
        // STOP states
        stop_a  = 5'b00110,
        stop_b  = 5'b00111,
        stop_c  = 5'b01000,
        stop_d  = 5'b01001,
        // READ states
        read_a  = 5'b01010,
        read_b  = 5'b01011,
        read_c  = 5'b01100,
        read_d  = 5'b01101,
        // WRITE states
        write_a = 5'b01110,
        write_b = 5'b01111,
        write_c = 5'b10000,
        write_d = 5'b10001;

    reg [4:0] c_state;   // current FSM state

    //------------------------------------------------------------------
    // Clock divider / bit-timing generator
    //------------------------------------------------------------------
    reg        clk_en;
    reg [15:0] cnt;
    reg        slave_wait;
    reg        scl_sync;

    // Two-stage synchronizers for SCL and SDA inputs
    reg [1:0] cSCL, cSDA;

    // Three-sample filter shift registers
    reg [2:0] fSCL, fSDA;
    reg [15:0] filter_cnt;

    // Filtered (majority-voted) bus signals
    reg sSCL, sSDA;

    // Delayed filtered signals (for edge detection)
    reg dSCL, dSDA;

    // START / STOP condition flags
    reg sta_condition, sto_condition;

    //------------------------------------------------------------------
    // Stage 1: Two-stage input synchronizers
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            cSCL <= 2'b11;
            cSDA <= 2'b11;
        end else if (rst) begin
            cSCL <= 2'b11;
            cSDA <= 2'b11;
        end else begin
            cSCL <= {cSCL[0], scl_i};
            cSDA <= {cSDA[0], sda_i};
        end
    end

    //------------------------------------------------------------------
    // Stage 2: Digital glitch filter
    //   filter_cnt derived from clk_cnt >> 2
    //   Shift new samples into fSCL/fSDA on filter_cnt expiry
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            filter_cnt <= 16'h0;
            fSCL       <= 3'b111;
            fSDA       <= 3'b111;
        end else if (rst) begin
            filter_cnt <= 16'h0;
            fSCL       <= 3'b111;
            fSDA       <= 3'b111;
        end else if (!ena) begin
            filter_cnt <= clk_cnt >> 2;
        end else begin
            if (filter_cnt == 16'h0) begin
                filter_cnt <= clk_cnt >> 2;
                fSCL       <= {fSCL[1:0], cSCL[1]};
                fSDA       <= {fSDA[1:0], cSDA[1]};
            end else begin
                filter_cnt <= filter_cnt - 16'h1;
            end
        end
    end

    // Majority vote for filtered outputs
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            sSCL <= 1'b1;
            sSDA <= 1'b1;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
        end else if (rst) begin
            sSCL <= 1'b1;
            sSDA <= 1'b1;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
        end else begin
            dSCL <= sSCL;
            dSDA <= sSDA;
            sSCL <= (fSCL[2] & fSCL[1]) | (fSCL[2] & fSCL[0]) | (fSCL[1] & fSCL[0]);
            sSDA <= (fSDA[2] & fSDA[1]) | (fSDA[2] & fSDA[0]) | (fSDA[1] & fSDA[0]);
        end
    end

    //------------------------------------------------------------------
    // START / STOP condition detection
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            sta_condition <= 1'b0;
            sto_condition <= 1'b0;
        end else if (rst) begin
            sta_condition <= 1'b0;
            sto_condition <= 1'b0;
        end else begin
            // SDA falls while SCL high => START
            sta_condition <= ~sSDA &  dSDA & sSCL;
            // SDA rises while SCL high => STOP
            sto_condition <=  sSDA & ~dSDA & sSCL;
        end
    end

    //------------------------------------------------------------------
    // Bus busy flag
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset)
            busy <= 1'b0;
        else if (rst)
            busy <= 1'b0;
        else
            busy <= (sta_condition | busy) & ~sto_condition;
    end

    //------------------------------------------------------------------
    // Slave clock stretching detection
    //   slave_wait: master released SCL (scl_oen=1) but sSCL still low
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset)
            slave_wait <= 1'b0;
        else if (rst)
            slave_wait <= 1'b0;
        else
            slave_wait <= scl_oen & ~sSCL;
    end

    //------------------------------------------------------------------
    // Multi-master clock synchronization
    //   scl_sync: SCL falls externally while master has released it
    //   (falling edge on sSCL while scl_oen=1, i.e. dSCL=1, sSCL=0, scl_oen=1)
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset)
            scl_sync <= 1'b0;
        else if (rst)
            scl_sync <= 1'b0;
        else
            scl_sync <= dSCL & ~sSCL & scl_oen;
    end

    //------------------------------------------------------------------
    // Clock divider / clk_en generator
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            cnt    <= 16'h0;
            clk_en <= 1'b1;
        end else if (rst) begin
            cnt    <= 16'h0;
            clk_en <= 1'b1;
        end else begin
            clk_en <= 1'b0; // default: not enabled

            if (!ena) begin
                // Core disabled: reload counter
                cnt <= clk_cnt;
            end else if (slave_wait) begin
                // Slave stretching: hold counter, no clk_en
                cnt <= cnt;
            end else if (scl_sync) begin
                // Sync to external SCL fall: reload
                cnt    <= clk_cnt;
                clk_en <= 1'b0;
            end else if (cnt == 16'h0) begin
                // Counter expired: reload and pulse clk_en
                cnt    <= clk_cnt;
                clk_en <= 1'b1;
            end else begin
                cnt <= cnt - 16'h1;
            end
        end
    end

    //------------------------------------------------------------------
    // Read data sampling: capture sSDA on rising edge of sSCL
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset)
            dout <= 1'b0;
        else if (rst)
            dout <= 1'b0;
        else if (sSCL & ~dSCL)   // rising edge of filtered SCL
            dout <= sSDA;
    end

    //------------------------------------------------------------------
    // Arbitration lost detection
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            al <= 1'b0;
        end else if (rst) begin
            al <= 1'b0;
        end else begin
            // Lost arbitration if:
            //  (a) sda_chk active and we expect SDA high but see it low, OR
            //  (b) unexpected STOP during active command (not a STOP cmd)
            al <= (sda_chk & ~sSDA & sda_oen) |
                  (sto_condition & (c_state != idle) & (cmd != `I2C_CMD_STOP));
        end
    end

    //------------------------------------------------------------------
    // Command FSM
    //------------------------------------------------------------------
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            c_state <= idle;
            cmd_ack <= 1'b0;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            sda_chk <= 1'b0;
        end else if (rst | al) begin
            // Synchronous reset or arbitration lost: return to idle
            c_state <= idle;
            cmd_ack <= 1'b0;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            sda_chk <= 1'b0;
        end else begin
            cmd_ack <= 1'b0;   // default: no ack
            sda_chk <= 1'b0;   // default: no arb check

            if (clk_en) begin
                case (c_state)

                    //----------------------------------------------
                    // IDLE: decode command
                    //----------------------------------------------
                    idle: begin
                        case (cmd)
                            `I2C_CMD_START: c_state <= start_a;
                            `I2C_CMD_STOP:  c_state <= stop_a;
                            `I2C_CMD_WRITE: c_state <= write_a;
                            `I2C_CMD_READ:  c_state <= read_a;
                            default:        c_state <= idle;
                        endcase
                    end

                    //----------------------------------------------
                    // START sequence
                    //   a: release SCL (if not already), release SDA
                    //   b: check SCL/SDA released (may need to wait)
                    //   c: pull SDA low while SCL high  => START
                    //   d: pull SCL low
                    //   e: assert cmd_ack, back to idle
                    //----------------------------------------------
                    start_a: begin
                        // Release SDA and SCL to idle high
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b1;
                        c_state <= start_b;
                    end

                    start_b: begin
                        // SCL high, SDA high — verify bus free
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b1;
                        c_state <= start_c;
                    end

                    start_c: begin
                        // Drive SDA low while SCL remains high => START condition
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b0;  // pull SDA low
                        c_state <= start_d;
                    end

                    start_d: begin
                        // Hold SDA low, pull SCL low
                        scl_oen <= 1'b0;  // pull SCL low
                        sda_oen <= 1'b0;
                        c_state <= start_e;
                    end

                    start_e: begin
                        // Release SDA, keep SCL low — done
                        scl_oen <= 1'b0;
                        sda_oen <= 1'b1;
                        cmd_ack <= 1'b1;
                        c_state <= idle;
                    end

                    //----------------------------------------------
                    // STOP sequence
                    //   a: drive SDA low, keep SCL low
                    //   b: release SCL high
                    //   c: release SDA high while SCL high => STOP
                    //   d: assert cmd_ack, back to idle
                    //----------------------------------------------
                    stop_a: begin
                        // SDA low, SCL low
                        scl_oen <= 1'b0;
                        sda_oen <= 1'b0;
                        c_state <= stop_b;
                    end

                    stop_b: begin
                        // Release SCL high (slave may stretch)
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b0;
                        c_state <= stop_c;
                    end

                    stop_c: begin
                        // SCL high, now release SDA high => STOP condition
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b1;
                        c_state <= stop_d;
                    end

                    stop_d: begin
                        // Hold, then ack
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b1;
                        cmd_ack <= 1'b1;
                        c_state <= idle;
                    end

                    //----------------------------------------------
                    // READ sequence
                    //   a: release SDA (slave drives), SCL low
                    //   b: release SCL high (sample window)
                    //   c: hold SCL high (sSDA captured into dout by edge detect)
                    //   d: pull SCL low, ack
                    //----------------------------------------------
                    read_a: begin
                        scl_oen <= 1'b0;
                        sda_oen <= 1'b1;  // release SDA
                        c_state <= read_b;
                    end

                    read_b: begin
                        scl_oen <= 1'b1;  // release SCL high
                        sda_oen <= 1'b1;
                        c_state <= read_c;
                    end

                    read_c: begin
                        // SCL high stable — dout captured by rising-edge logic
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b1;
                        c_state <= read_d;
                    end

                    read_d: begin
                        scl_oen <= 1'b0;  // pull SCL low
                        sda_oen <= 1'b1;
                        cmd_ack <= 1'b1;
                        c_state <= idle;
                    end

                    //----------------------------------------------
                    // WRITE sequence
                    //   a: set SDA per din, SCL low
                    //   b: release SCL high
                    //   c: SCL high stable — check arbitration
                    //   d: pull SCL low, ack
                    //----------------------------------------------
                    write_a: begin
                        scl_oen <= 1'b0;
                        sda_oen <= din;   // 1=release high, 0=drive low
                        c_state <= write_b;
                    end

                    write_b: begin
                        scl_oen <= 1'b1;  // release SCL high
                        sda_oen <= din;
                        c_state <= write_c;
                    end

                    write_c: begin
                        // SCL high, stable — arbitration check active
                        scl_oen <= 1'b1;
                        sda_oen <= din;
                        sda_chk <= 1'b1;  // enable arbitration check
                        c_state <= write_d;
                    end

                    write_d: begin
                        scl_oen <= 1'b0;  // pull SCL low
                        sda_oen <= din;
                        sda_chk <= 1'b0;
                        cmd_ack <= 1'b1;
                        c_state <= idle;
                    end

                    default: c_state <= idle;

                endcase
            end
        end
    end

endmodule

// i2c_master_bit_ctrl - Bit-level controller for OpenCores I2C master core
// Supports START, STOP, WRITE, READ, clock stretching, arbitration, filtering

module i2c_master_bit_ctrl (
    input             clk,
    input             rst,
    input             nReset,
    input             ena,

    input      [15:0] clk_cnt,

    input      [ 3:0] cmd,
    output reg        cmd_ack,
    output reg        busy,
    output reg        al,

    input             din,
    output reg        dout,

    input             scl_i,
    output            scl_o,
    output reg        scl_oen,
    input             sda_i,
    output            sda_o,
    output reg        sda_oen
);

    // Constant low drive for open-drain outputs
    assign scl_o = 1'b0;
    assign sda_o = 1'b0;

    // Command encoding (matching original I2C master specification)
    localparam [3:0] I2C_CMD_NOP   = 4'b0000;
    localparam [3:0] I2C_CMD_START = 4'b0001;
    localparam [3:0] I2C_CMD_STOP  = 4'b0010;
    localparam [3:0] I2C_CMD_READ  = 4'b0011;
    localparam [3:0] I2C_CMD_WRITE = 4'b0100;

    // FSM states
    localparam [3:0] ST_IDLE      = 4'd0;
    localparam [3:0] ST_START_A   = 4'd1;
    localparam [3:0] ST_START_B   = 4'd2;
    localparam [3:0] ST_START_C   = 4'd3;
    localparam [3:0] ST_START_D   = 4'd4;
    localparam [3:0] ST_START_E   = 4'd5;
    localparam [3:0] ST_STOP_A    = 4'd6;
    localparam [3:0] ST_STOP_B    = 4'd7;
    localparam [3:0] ST_STOP_C    = 4'd8;
    localparam [3:0] ST_STOP_D    = 4'd9;
    localparam [3:0] ST_READ_A    = 4'd10;
    localparam [3:0] ST_READ_B    = 4'd11;
    localparam [3:0] ST_READ_C    = 4'd12;
    localparam [3:0] ST_READ_D    = 4'd13;
    localparam [3:0] ST_WRITE_A   = 4'd14;
    localparam [3:0] ST_WRITE_B   = 4'd15;
    localparam [3:0] ST_WRITE_C   = 4'd16;
    localparam [3:0] ST_WRITE_D   = 4'd17;

    reg [3:0] c_state, n_state;

    // Timing counter
    reg [15:0] cnt;
    wire       clk_en;
    wire       cnt_done;

    // Input synchronization and filtering
    reg [1:0] cSCL, cSDA;           // two-stage synchronizers
    reg [2:0] fSCL, fSDA;           // filter shift registers (3 samples)
    reg [4:0] filter_cnt;
    wire      filter_tick;
    wire      sSCL, sSDA;           // filtered outputs (majority vote)
    reg       dSCL, dSDA;           // delayed versions for edge detection

    // Bus condition detection
    wire      sta_condition;
    wire      sto_condition;

    // Clock stretching and synchronization
    wire      slave_wait;
    wire      scl_sync;

    // Arbitration checking
    reg       sda_chk;

    // Internal FSM control signals
    reg       cmd_stop;

    // Filter majority function
    function majority;
        input [2:0] votes;
        begin
            majority = (votes[0] & votes[1]) | (votes[0] & votes[2]) | (votes[1] & votes[2]);
        end
    endfunction

    assign sSCL = majority(fSCL);
    assign sSDA = majority(fSDA);

    // Filter tick generation: clk_cnt >> 2
    // filter_cnt counts up from 0 to (clk_cnt[15:2] - 1) or similar, tick when expires
    // Using a simple approach: filter tick when filter_cnt == 0
    assign filter_tick = (filter_cnt == 5'd0);

    // Clock enable generation
    assign cnt_done = (cnt == 16'd0);
    assign clk_en = cnt_done;

    // Slave wait and clock sync detection
    // slave_wait: master released SCL (scl_oen=1) but sSCL still low
    assign slave_wait = scl_oen && !sSCL;

    // scl_sync: falling edge on sSCL while master has released SCL (scl_oen=1)
    // dSCL is previous filtered SCL
    wire scl_falling = dSCL && !sSCL;
    assign scl_sync = scl_oen && scl_falling;

    // START and STOP condition detection
    assign sta_condition = !sSDA && dSDA && sSCL;
    assign sto_condition = sSDA && !dSDA && sSCL;

    // Sequential logic: synchronization, filtering, counters, delayed signals
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            cSCL <= 2'b11;
            cSDA <= 2'b11;
            fSCL <= 3'b111;
            fSDA <= 3'b111;
            filter_cnt <= 5'd0;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
            cnt <= 16'd0;
            busy <= 1'b0;
            al <= 1'b0;
            cmd_ack <= 1'b0;
            dout <= 1'b1;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            sda_chk <= 1'b0;
            cmd_stop <= 1'b0;
            c_state <= ST_IDLE;
        end else if (rst) begin
            cSCL <= 2'b11;
            cSDA <= 2'b11;
            fSCL <= 3'b111;
            fSDA <= 3'b111;
            filter_cnt <= 5'd0;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
            cnt <= clk_cnt;
            busy <= 1'b0;
            al <= 1'b0;
            cmd_ack <= 1'b0;
            dout <= 1'b1;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            sda_chk <= 1'b0;
            cmd_stop <= 1'b0;
            c_state <= ST_IDLE;
        end else begin
            // Synchronizer update
            cSCL <= {cSCL[0], scl_i};
            cSDA <= {cSDA[0], sda_i};

            // Filter counter and shift registers
            if (!ena || filter_tick) begin
                filter_cnt <= clk_cnt[15:2]; // reload with clk_cnt >> 2
                fSCL <= {fSCL[1:0], cSCL[1]};
                fSDA <= {fSDA[1:0], cSDA[1]};
            end else begin
                filter_cnt <= filter_cnt - 5'd1;
            end

            // Delayed filtered signals
            dSCL <= sSCL;
            dSDA <= sSDA;

            // Busy flag management
            if (sta_condition)
                busy <= 1'b1;
            else if (sto_condition)
                busy <= 1'b0;

            // Arbitration lost detection
            // Case 1: sda_chk asserted and expected SDA high but sSDA low
            // Case 2: unexpected STOP during active command (not STOP command)
            if (sda_chk && sda_oen && !sSDA)
                al <= 1'b1;
            else if (sto_condition && (c_state != ST_IDLE) && !cmd_stop)
                al <= 1'b1;
            else if (rst || !nReset)
                al <= 1'b0;

            // cmd_ack pulse (one cycle)
            cmd_ack <= 1'b0; // default clear, set in FSM combinational logic

            // dout capture on rising edge of filtered SCL
            if (dSCL == 1'b0 && sSCL == 1'b1)
                dout <= sSDA;

            // Counter logic
            if (!ena || rst) begin
                cnt <= clk_cnt;
            end else if (cnt_done || scl_sync) begin
                cnt <= clk_cnt;
            end else if (slave_wait) begin
                cnt <= cnt; // hold
            end else begin
                cnt <= cnt - 16'd1;
            end

            // FSM state update (only advance on clk_en, unless reset)
            if (clk_en || al)
                c_state <= n_state;

            // cmd_stop flag for arbitration check
            if (c_state == ST_IDLE && cmd == I2C_CMD_STOP && clk_en)
                cmd_stop <= 1'b1;
            else if (c_state == ST_IDLE)
                cmd_stop <= 1'b0;
        end
    end

    // Combinational FSM next state and output logic
    always @* begin
        // Default assignments
        n_state   = c_state;
        scl_oen   = 1'b1;
        sda_oen   = 1'b1;
        sda_chk   = 1'b0;
        cmd_ack   = 1'b0;

        case (c_state)
            ST_IDLE: begin
                if (clk_en && !al) begin
                    case (cmd)
                        I2C_CMD_START: n_state = ST_START_A;
                        I2C_CMD_STOP:  n_state = ST_STOP_A;
                        I2C_CMD_READ:  n_state = ST_READ_A;
                        I2C_CMD_WRITE: n_state = ST_WRITE_A;
                        default:       n_state = ST_IDLE;
                    endcase
                end
                // Release both lines in idle
                scl_oen = 1'b1;
                sda_oen = 1'b1;
            end

            // START sequence
            ST_START_A: begin
                // Release SDA and SCL high
                sda_oen = 1'b1;
                scl_oen = 1'b1;
                n_state = ST_START_B;
            end
            ST_START_B: begin
                // Pull SDA low while SCL high
                sda_oen = 1'b0;
                scl_oen = 1'b1;
                n_state = ST_START_C;
            end
            ST_START_C: begin
                // Pull SCL low
                sda_oen = 1'b0;
                scl_oen = 1'b0;
                n_state = ST_START_D;
            end
            ST_START_D: begin
                // Keep SCL low, release SDA
                sda_oen = 1'b1;
                scl_oen = 1'b0;
                n_state = ST_START_E;
            end
            ST_START_E: begin
                // Keep SCL low, SDA released
                sda_oen = 1'b1;
                scl_oen = 1'b0;
                n_state = ST_IDLE;
                cmd_ack = 1'b1;
            end

            // STOP sequence
            ST_STOP_A: begin
                // Drive SDA low
                sda_oen = 1'b0;
                scl_oen = 1'b0;
                n_state = ST_STOP_B;
            end
            ST_STOP_B: begin
                // Release SCL high
                sda_oen = 1'b0;
                scl_oen = 1'b1;
                n_state = ST_STOP_C;
            end
            ST_STOP_C: begin
                // Release SDA high while SCL high
                sda_oen = 1'b1;
                scl_oen = 1'b1;
                n_state = ST_STOP_D;
            end
            ST_STOP_D: begin
                // Both released
                sda_oen = 1'b1;
                scl_oen = 1'b1;
                n_state = ST_IDLE;
                cmd_ack = 1'b1;
            end

            // READ sequence
            ST_READ_A: begin
                // Release SDA, drive SCL low
                sda_oen = 1'b1;
                scl_oen = 1'b0;
                n_state = ST_READ_B;
            end
            ST_READ_B: begin
                // Release SCL high (sampling window)
                sda_oen = 1'b1;
                scl_oen = 1'b1;
                n_state = ST_READ_C;
            end
            ST_READ_C: begin
                // Keep SCL high for a period
                sda_oen = 1'b1;
                scl_oen = 1'b1;
                n_state = ST_READ_D;
            end
            ST_READ_D: begin
                // Pull SCL low
                sda_oen = 1'b1;
                scl_oen = 1'b0;
                n_state = ST_IDLE;
                cmd_ack = 1'b1;
            end

            // WRITE sequence
            ST_WRITE_A: begin
                // Set SDA according to din
                sda_oen = din;  // din=0 -> drive low, din=1 -> release high
                scl_oen = 1'b0;
                n_state = ST_WRITE_B;
            end
            ST_WRITE_B: begin
                // Release SCL high
                sda_oen = din;
                scl_oen = 1'b1;
                n_state = ST_WRITE_C;
            end
            ST_WRITE_C: begin
                // SCL high, check arbitration
                sda_oen = din;
                scl_oen = 1'b1;
                sda_chk = 1'b1;
                n_state = ST_WRITE_D;
            end
            ST_WRITE_D: begin
                // Pull SCL low
                sda_oen = din;
                scl_oen = 1'b0;
                n_state = ST_IDLE;
                cmd_ack = 1'b1;
            end

            default: begin
                n_state = ST_IDLE;
            end
        endcase

        // If arbitration lost, force idle and release lines
        if (al) begin
            n_state = ST_IDLE;
            scl_oen = 1'b1;
            sda_oen = 1'b1;
            sda_chk = 1'b0;
            // cmd_ack remains 0 when arbitration lost
        end
    end

endmodule

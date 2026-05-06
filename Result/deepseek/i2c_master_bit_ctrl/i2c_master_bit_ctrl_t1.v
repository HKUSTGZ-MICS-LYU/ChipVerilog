// i2c_master_bit_ctrl - I2C Master Bit-Level Controller
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

    // I2C command encodings
    localparam [3:0] I2C_CMD_NOP   = 4'h0,
                     I2C_CMD_START = 4'h1,
                     I2C_CMD_STOP  = 4'h2,
                     I2C_CMD_READ  = 4'h3,
                     I2C_CMD_WRITE = 4'h4;

    // FSM states
    localparam [3:0] ST_IDLE  = 4'd0,
                     ST_START = 4'd1,
                     ST_STOP  = 4'd2,
                     ST_READ  = 4'd3,
                     ST_WRITE = 4'd4;

    // Internal signals
    reg [15:0] cnt;
    wire       clk_en;
    reg        slave_wait;
    reg        scl_sync;

    // Synchronization and filtering
    reg        cSCL, cSDA;
    reg [1:0]  fSCL_hist, fSDA_hist;
    wire       sSCL, sSDA;
    reg        dSCL, dSDA;
    wire       sta_condition, sto_condition;

    // Filter counter
    reg [13:0] filter_cnt;
    wire       filter_tick;

    // FSM
    reg [3:0]  state, next_state;
    reg        sda_chk;
    reg        cmd_ack_int;

    // Asynchronous reset
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            cSCL       <= 1'b1;
            cSDA       <= 1'b1;
            fSCL_hist  <= 2'b11;
            fSDA_hist  <= 2'b11;
            dSCL       <= 1'b1;
            dSDA       <= 1'b1;
            filter_cnt <= 14'd0;
            cnt        <= 16'd0;
            state      <= ST_IDLE;
            scl_oen    <= 1'b1;
            sda_oen    <= 1'b1;
            sda_chk    <= 1'b0;
            cmd_ack    <= 1'b0;
            al         <= 1'b0;
            busy       <= 1'b0;
            dout       <= 1'b1;
            slave_wait <= 1'b0;
            scl_sync   <= 1'b0;
        end else if (rst) begin
            cSCL       <= 1'b1;
            cSDA       <= 1'b1;
            fSCL_hist  <= 2'b11;
            fSDA_hist  <= 2'b11;
            dSCL       <= 1'b1;
            dSDA       <= 1'b1;
            filter_cnt <= 14'd0;
            cnt        <= 16'd0;
            state      <= ST_IDLE;
            scl_oen    <= 1'b1;
            sda_oen    <= 1'b1;
            sda_chk    <= 1'b0;
            cmd_ack    <= 1'b0;
            al         <= 1'b0;
            busy       <= 1'b0;
            dout       <= 1'b1;
            slave_wait <= 1'b0;
            scl_sync   <= 1'b0;
        end else begin
            // Input synchronization first stage
            cSCL <= scl_i;
            cSDA <= sda_i;

            // Filter counter
            if (!ena || filter_tick) begin
                filter_cnt <= clk_cnt[15:2];
            end else begin
                filter_cnt <= filter_cnt - 14'd1;
            end

            // Filter shift and delayed versions
            if (filter_tick || !ena) begin
                fSCL_hist <= {fSCL_hist[0], cSCL};
                fSDA_hist <= {fSDA_hist[0], cSDA};
                dSCL      <= sSCL;
                dSDA      <= sSDA;
            end

            // Clock divider and FSM control
            if (!ena || (cnt == 16'd0) || scl_sync) begin
                cnt <= clk_cnt;
            end else if (!slave_wait) begin
                cnt <= cnt - 16'd1;
            end

            // Slave wait detection
            slave_wait <= (scl_oen == 1'b1) && (sSCL == 1'b0);

            // Clock synchronization
            scl_sync <= (scl_oen == 1'b1) && (dSCL == 1'b1) && (sSCL == 1'b0);

            // Bus busy tracking
            if (sta_condition)
                busy <= 1'b1;
            else if (sto_condition)
                busy <= 1'b0;

            // Read data sampling on rising edge of filtered SCL
            if (~dSCL & sSCL)
                dout <= sSDA;

            // Arbitration lost detection
            if (sda_chk && sda_oen && !sSDA)
                al <= 1'b1;
            else if (sto_condition && state != ST_IDLE && state != ST_STOP)
                al <= 1'b1;

            // FSM state update
            state <= next_state;

            // Command acknowledge
            cmd_ack <= cmd_ack_int;

            // Default FSM outputs
            if (state == ST_IDLE) begin
                case (cmd)
                    I2C_CMD_START: begin
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                    end
                    I2C_CMD_STOP: begin
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b0;
                        sda_chk <= 1'b0;
                    end
                    I2C_CMD_READ: begin
                        scl_oen <= 1'b0;
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                    end
                    I2C_CMD_WRITE: begin
                        scl_oen <= 1'b0;
                        sda_oen <= ~din;
                        sda_chk <= 1'b0;
                    end
                    default: begin
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                    end
                endcase
            end else if (state == ST_START) begin
                if (!clk_en) begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                end else begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                end
                sda_chk <= 1'b0;
            end else if (state == ST_STOP) begin
                if (!clk_en) begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                end else begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                end
                sda_chk <= 1'b0;
            end else if (state == ST_READ) begin
                if (!clk_en) begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                end else begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                end
                sda_chk <= 1'b0;
            end else if (state == ST_WRITE) begin
                if (!clk_en) begin
                    scl_oen <= 1'b1;
                    sda_oen <= ~din;
                    sda_chk <= 1'b1;
                end else begin
                    scl_oen <= 1'b0;
                    sda_oen <= ~din;
                    sda_chk <= 1'b0;
                end
            end
        end
    end

    // Filter tick
    assign filter_tick = (filter_cnt == 14'd0);

    // Majority filter
    assign sSCL = (fSCL_hist == 2'b00) ? 1'b0 :
                  (fSCL_hist == 2'b11) ? 1'b1 : sSCL;
    assign sSDA = (fSDA_hist == 2'b00) ? 1'b0 :
                  (fSDA_hist == 2'b11) ? 1'b1 : sSDA;

    // START and STOP condition detection
    assign sta_condition = ~sSDA & dSDA & sSCL;
    assign sto_condition =  sSDA & ~dSDA & sSCL;

    // Clock enable
    assign clk_en = (cnt == 16'd0);

    // FSM next state logic
    always @(*) begin
        next_state  = state;
        cmd_ack_int = 1'b0;

        case (state)
            ST_IDLE: begin
                if (clk_en) begin
                    case (cmd)
                        I2C_CMD_START: next_state = ST_START;
                        I2C_CMD_STOP:  next_state = ST_STOP;
                        I2C_CMD_READ:  next_state = ST_READ;
                        I2C_CMD_WRITE: next_state = ST_WRITE;
                        default:       next_state = ST_IDLE;
                    endcase
                end
            end

            ST_START: begin
                if (clk_en) begin
                    next_state  = ST_IDLE;
                    cmd_ack_int = 1'b1;
                end
            end

            ST_STOP: begin
                if (clk_en) begin
                    next_state  = ST_IDLE;
                    cmd_ack_int = 1'b1;
                end
            end

            ST_READ: begin
                if (clk_en) begin
                    next_state  = ST_IDLE;
                    cmd_ack_int = 1'b1;
                end
            end

            ST_WRITE: begin
                if (clk_en) begin
                    next_state  = ST_IDLE;
                    cmd_ack_int = 1'b1;
                end
            end

            default: next_state = ST_IDLE;
        endcase

        // Arbitration lost forces idle
        if (al) begin
            next_state  = ST_IDLE;
            cmd_ack_int = 1'b0;
        end
    end

endmodule

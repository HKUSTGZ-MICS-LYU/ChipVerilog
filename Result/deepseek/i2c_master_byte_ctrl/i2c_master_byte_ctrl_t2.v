module i2c_master_byte_ctrl (
    clk,
    rst,
    nReset,
    ena,
    clk_cnt,
    start,
    stop,
    read,
    write,
    ack_in,
    din,
    cmd_ack,
    ack_out,
    dout,
    i2c_busy,
    i2c_al,
    scl_i,
    scl_o,
    scl_oen,
    sda_i,
    sda_o,
    sda_oen
);
    input           clk;
    input           rst;
    input           nReset;
    input           ena;
    input  [15:0]   clk_cnt;
    input           start;
    input           stop;
    input           read;
    input           write;
    input           ack_in;
    input  [7:0]    din;
    output          cmd_ack;
    output          ack_out;
    output [7:0]    dout;
    output          i2c_busy;
    output          i2c_al;
    input           scl_i;
    output          scl_o;
    output          scl_oen;
    input           sda_i;
    output          sda_o;
    output          sda_oen;

    // Internal signals
    wire            core_cmd;
    wire            core_txd;
    wire            core_ack;
    wire            core_rxd;

    // FSM states
    localparam [2:0]
        ST_IDLE  = 3'b000,
        ST_START = 3'b001,
        ST_WRITE = 3'b010,
        ST_READ  = 3'b011,
        ST_ACK   = 3'b100,
        ST_STOP  = 3'b101;

    // FSM state register
    reg [2:0] c_state;
    reg [2:0] n_state;

    // Shift register, bit counter
    reg [7:0] sr;
    reg [2:0] dcnt;

    // Command and control registers
    reg       ld;
    reg       shift;
    reg       cmd_ack;
    reg       ack_out;
    reg       go;
    wire      cnt_done;

    // Bit controller command values
    localparam [3:0]
        I2C_CMD_NOP   = 4'b0000,
        I2C_CMD_START = 4'b0001,
        I2C_CMD_STOP  = 4'b0010,
        I2C_CMD_READ  = 4'b0100,
        I2C_CMD_WRITE = 4'b1000;

    // Core command register
    reg [3:0] core_cmd_reg;

    // Output assignments
    assign dout = sr;
    assign cnt_done = (dcnt == 3'b000);

    // go condition
    always @(*) begin
        go = (read | write | stop) & ~cmd_ack;
    end

    // Next state logic
    always @(*) begin
        n_state = c_state;
        case (c_state)
            ST_IDLE: begin
                if (go) begin
                    if (start)
                        n_state = ST_START;
                    else if (read)
                        n_state = ST_READ;
                    else if (write)
                        n_state = ST_WRITE;
                    else
                        n_state = ST_STOP;
                end
            end
            ST_START: begin
                if (core_ack) begin
                    if (read)
                        n_state = ST_READ;
                    else
                        n_state = ST_WRITE;
                end
            end
            ST_WRITE: begin
                if (core_ack) begin
                    if (cnt_done)
                        n_state = ST_ACK;
                end
            end
            ST_READ: begin
                if (core_ack) begin
                    if (cnt_done)
                        n_state = ST_ACK;
                end
            end
            ST_ACK: begin
                if (core_ack) begin
                    if (stop)
                        n_state = ST_STOP;
                    else
                        n_state = ST_IDLE;
                end
            end
            ST_STOP: begin
                if (core_ack)
                    n_state = ST_IDLE;
            end
            default: n_state = ST_IDLE;
        endcase
    end

    // FSM, datapath, and output registers
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            c_state <= ST_IDLE;
            sr      <= 8'd0;
            dcnt    <= 3'd0;
            ld      <= 1'b0;
            shift   <= 1'b0;
            cmd_ack <= 1'b0;
            ack_out <= 1'b0;
            core_cmd_reg <= I2C_CMD_NOP;
        end else if (rst | i2c_al) begin
            c_state <= ST_IDLE;
            sr      <= 8'd0;
            dcnt    <= 3'd0;
            ld      <= 1'b0;
            shift   <= 1'b0;
            cmd_ack <= 1'b0;
            ack_out <= 1'b0;
            core_cmd_reg <= I2C_CMD_NOP;
        end else begin
            // Default assignments
            ld      <= 1'b0;
            shift   <= 1'b0;
            cmd_ack <= 1'b0;

            // FSM state update
            c_state <= n_state;

            // State-dependent operations
            case (c_state)
                ST_IDLE: begin
                    if (go) begin
                        ld <= 1'b1;
                        if (start)
                            core_cmd_reg <= I2C_CMD_START;
                        else if (read)
                            core_cmd_reg <= I2C_CMD_READ;
                        else if (write)
                            core_cmd_reg <= I2C_CMD_WRITE;
                        else
                            core_cmd_reg <= I2C_CMD_STOP;
                    end else begin
                        core_cmd_reg <= I2C_CMD_NOP;
                    end
                end
                ST_START: begin
                    if (core_ack) begin
                        if (read)
                            core_cmd_reg <= I2C_CMD_READ;
                        else
                            core_cmd_reg <= I2C_CMD_WRITE;
                    end
                end
                ST_WRITE: begin
                    if (core_ack) begin
                        if (!cnt_done) begin
                            shift <= 1'b1;
                            core_cmd_reg <= I2C_CMD_WRITE;
                        end else begin
                            // Entering ACK phase
                            core_cmd_reg <= I2C_CMD_READ;
                        end
                    end
                end
                ST_READ: begin
                    if (core_ack) begin
                        if (!cnt_done) begin
                            shift <= 1'b1;
                            core_cmd_reg <= I2C_CMD_READ;
                        end else begin
                            // Entering ACK phase
                            core_cmd_reg <= I2C_CMD_WRITE;
                        end
                    end
                end
                ST_ACK: begin
                    if (core_ack) begin
                        // Capture ack_out if we were reading (i.e., coming from write)
                        // This assignment handles both cases: after write we sample, after read we don't care.
                        ack_out <= core_rxd;
                        if (stop) begin
                            core_cmd_reg <= I2C_CMD_STOP;
                        end else begin
                            core_cmd_reg <= I2C_CMD_NOP;
                            cmd_ack <= 1'b1;
                        end
                    end
                end
                ST_STOP: begin
                    if (core_ack) begin
                        core_cmd_reg <= I2C_CMD_NOP;
                        cmd_ack <= 1'b1;
                    end
                end
                default: begin
                    core_cmd_reg <= I2C_CMD_NOP;
                end
            endcase

            // Shift register and bit counter update
            if (ld) begin
                sr   <= din;
                dcnt <= 3'd7;
            end else if (shift) begin
                sr   <= {sr[6:0], core_rxd};
                dcnt <= dcnt - 3'd1;
            end
        end
    end

    // Instantiate bit controller
    i2c_master_bit_ctrl bit_controller (
        .clk     (clk),
        .rst     (rst),
        .nReset  (nReset),
        .ena     (ena),
        .clk_cnt (clk_cnt),
        .cmd     (core_cmd_reg),
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

    // Core transmit data: during write, MSB; during read ACK, ack_in
    assign core_txd = (c_state == ST_ACK) ? ack_in : sr[7];

endmodule

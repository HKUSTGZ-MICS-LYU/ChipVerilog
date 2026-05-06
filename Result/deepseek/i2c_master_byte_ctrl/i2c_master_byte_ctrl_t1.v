// i2c_master_byte_ctrl module
module i2c_master_byte_ctrl (
    input  wire          clk,
    input  wire          rst,
    input  wire          nReset,
    input  wire          ena,
    input  wire [15:0]   clk_cnt,
    input  wire          start,
    input  wire          stop,
    input  wire          read,
    input  wire          write,
    input  wire          ack_in,
    input  wire [7:0]    din,
    output reg           cmd_ack,
    output reg           ack_out,
    output wire [7:0]    dout,
    output wire          i2c_busy,
    output wire          i2c_al,
    input  wire          scl_i,
    output wire          scl_o,
    output wire          scl_oen,
    input  wire          sda_i,
    output wire          sda_o,
    output wire          sda_oen
);

    // FSM state encoding
    localparam ST_IDLE  = 3'd0;
    localparam ST_START = 3'd1;
    localparam ST_READ  = 3'd2;
    localparam ST_WRITE = 3'd3;
    localparam ST_ACK   = 3'd4;
    localparam ST_STOP  = 3'd5;

    // I2C bit-level commands
    localparam I2C_CMD_NOP   = 2'd0;
    localparam I2C_CMD_START = 2'd1;
    localparam I2C_CMD_STOP  = 2'd2;
    localparam I2C_CMD_READ  = 2'd3;
    localparam I2C_CMD_WRITE = 2'd4;

    // Internal signals
    reg [2:0]  state, nxt_state;
    reg [7:0]  sr;
    reg [2:0]  dcnt;
    reg        ld, shift;
    wire       go;
    wire       cnt_done;
    reg  [2:0] core_cmd;
    wire       core_ack;
    reg        core_txd;
    wire       core_rxd;

    // Assign go: command launch condition
    assign go = (read | write | stop) & ~cmd_ack;

    // Assign cnt_done: bit counter reached zero
    assign cnt_done = (dcnt == 3'd0);

    // Instantiate i2c_master_bit_ctrl
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

    // dout is directly connected to sr
    assign dout = sr;

    // Sequential logic: state, shift register, bit counter, ack_out, cmd_ack
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            // asynchronous active-low reset
            state   <= ST_IDLE;
            sr      <= 8'd0;
            dcnt    <= 3'd0;
            ack_out <= 1'b0;
            cmd_ack <= 1'b0;
        end else begin
            if (rst | i2c_al) begin
                // synchronous reset or abort on arbitration lost
                state   <= ST_IDLE;
                sr      <= 8'd0;
                dcnt    <= 3'd0;
                ack_out <= 1'b0;
                cmd_ack <= 1'b0;
            end else begin
                // default assignments
                cmd_ack <= 1'b0;

                // load and shift control
                if (ld) begin
                    sr   <= din;
                    dcnt <= 3'd7;
                end else if (shift) begin
                    sr   <= {sr[6:0], core_rxd};
                    dcnt <= dcnt - 3'd1;
                end

                // state update
                state <= nxt_state;

                // capture ack_out during ST_ACK write-transfer (read command)
                if (state == ST_ACK && core_ack && read == 1'b0) begin
                    ack_out <= core_rxd;
                end else if (!nReset || rst || i2c_al) begin
                    ack_out <= 1'b0;
                end

                // cmd_ack generation
                if ((state == ST_ACK && core_ack && stop == 1'b0) ||
                    (state == ST_STOP && core_ack)) begin
                    cmd_ack <= 1'b1;
                end
            end
        end
    end

    // Combinational FSM: next state, commands, load/shift signals
    always @* begin
        // Default values
        nxt_state = state;
        core_cmd  = I2C_CMD_NOP;
        core_txd  = sr[7];
        ld        = 1'b0;
        shift     = 1'b0;

        case (state)
            ST_IDLE: begin
                if (go) begin
                    ld = 1'b1;
                    if (start) begin
                        nxt_state = ST_START;
                        core_cmd  = I2C_CMD_START;
                    end else if (read) begin
                        nxt_state = ST_READ;
                        core_cmd  = I2C_CMD_READ;
                    end else if (write) begin
                        nxt_state = ST_WRITE;
                        core_cmd  = I2C_CMD_WRITE;
                    end else begin
                        // stop only
                        nxt_state = ST_STOP;
                        core_cmd  = I2C_CMD_STOP;
                    end
                end else begin
                    nxt_state = ST_IDLE;
                    core_cmd  = I2C_CMD_NOP;
                end
            end

            ST_START: begin
                core_cmd = I2C_CMD_START;
                if (core_ack) begin
                    if (read) begin
                        nxt_state = ST_READ;
                        core_cmd  = I2C_CMD_READ;
                    end else begin
                        nxt_state = ST_WRITE;
                        core_cmd  = I2C_CMD_WRITE;
                    end
                end
            end

            ST_WRITE: begin
                core_cmd = I2C_CMD_WRITE;
                core_txd = sr[7];
                if (core_ack) begin
                    if (cnt_done) begin
                        nxt_state = ST_ACK;
                        core_cmd  = I2C_CMD_READ; // to sample slave ACK/NACK
                    end else begin
                        shift     = 1'b1;
                        nxt_state = ST_WRITE;
                    end
                end
            end

            ST_READ: begin
                core_cmd = I2C_CMD_READ;
                if (core_ack) begin
                    if (cnt_done) begin
                        nxt_state = ST_ACK;
                        core_cmd  = I2C_CMD_WRITE; // to send master ACK/NACK
                        core_txd  = ack_in;
                    end else begin
                        shift     = 1'b1;
                        nxt_state = ST_READ;
                    end
                end
            end

            ST_ACK: begin
                // Core command already set by previous state (READ or WRITE)
                // core_txd is driven by ack_in for read transfers; sr[7] for write transfers is default.
                if (state == ST_ACK) begin
                    if (read) begin
                        core_txd = ack_in;
                    end else begin
                        core_txd = sr[7];
                    end
                end
                if (core_ack) begin
                    if (stop) begin
                        nxt_state = ST_STOP;
                        core_cmd  = I2C_CMD_STOP;
                    end else begin
                        nxt_state = ST_IDLE;
                        core_cmd  = I2C_CMD_NOP;
                    end
                end
            end

            ST_STOP: begin
                core_cmd = I2C_CMD_STOP;
                if (core_ack) begin
                    nxt_state = ST_IDLE;
                    core_cmd  = I2C_CMD_NOP;
                end
            end

            default: begin
                nxt_state = ST_IDLE;
                core_cmd  = I2C_CMD_NOP;
            end
        endcase
    end

endmodule

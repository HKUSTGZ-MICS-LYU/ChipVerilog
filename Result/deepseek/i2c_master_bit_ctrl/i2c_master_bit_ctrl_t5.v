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
    output            scl_oen,
    input             sda_i,
    output            sda_o,
    output            sda_oen
);

// Parameters for I2C commands
localparam I2C_CMD_START = 4'b1000;
localparam I2C_CMD_STOP  = 4'b1001;
localparam I2C_CMD_WRITE = 4'b1010;
localparam I2C_CMD_READ  = 4'b1011;

// FSM states
localparam IDLE   = 4'd0;
localparam STRT_A = 4'd1;
localparam STRT_B = 4'd2;
localparam STRT_C = 4'd3;
localparam STOP_A = 4'd4;
localparam STOP_B = 4'd5;
localparam STOP_C = 4'd6;
localparam READ_A = 4'd7;
localparam READ_B = 4'd8;
localparam WRIT_A = 4'd9;
localparam WRIT_B = 4'd10;
localparam WRIT_C = 4'd11;

// Input synchronization registers
reg cSCL1, cSCL2, cSDA1, cSDA2;

// Filter shift registers
reg [2:0] fSCL, fSDA;

// Filtered bus signals
wire sSCL, sSDA;

// Delayed filtered signals for edge detection
reg dSCL, dSDA;

// Clock divider counter and enable
reg [15:0] cnt;
reg clk_en;

// Filter counter
reg [15:0] filter_cnt;
wire filter_tick;

// Slave and synchronization signals
wire slave_wait;
wire scl_sync;

// Condition detection wires
wire sta_condition;
wire sto_condition;
wire rising_scl;

// Arbitration check enable
wire sda_chk;

// FSM state register
reg [3:0] state, next_state;

// Output enable registers (assignments are combinational)
reg scl_oen_reg, sda_oen_reg;

// Assign constant low drive outputs
assign scl_o = 1'b0;
assign sda_o = 1'b0;

// Output enables
assign scl_oen = scl_oen_reg;
assign sda_oen = sda_oen_reg;

// ---------------------
// 1. Input synchronization and glitch filtering
// ---------------------
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        cSCL1 <= 1'b0;
        cSCL2 <= 1'b0;
        cSDA1 <= 1'b0;
        cSDA2 <= 1'b0;
    end else if (rst) begin
        cSCL1 <= 1'b0;
        cSCL2 <= 1'b0;
        cSDA1 <= 1'b0;
        cSDA2 <= 1'b0;
    end else begin
        cSCL1 <= scl_i;
        cSCL2 <= cSCL1;
        cSDA1 <= sda_i;
        cSDA2 <= cSDA1;
    end
end

// Filter tick generation
assign filter_tick = (filter_cnt == 16'd0);

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        filter_cnt <= clk_cnt[15:2];
    end else if (rst) begin
        filter_cnt <= clk_cnt[15:2];
    end else if (!ena) begin
        filter_cnt <= clk_cnt[15:2];
    end else if (filter_tick) begin
        filter_cnt <= clk_cnt[15:2];
    end else begin
        filter_cnt <= filter_cnt - 1'b1;
    end
end

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        fSCL <= 3'b111;
        fSDA <= 3'b111;
    end else if (rst) begin
        fSCL <= 3'b111;
        fSDA <= 3'b111;
    end else if (filter_tick && ena) begin
        fSCL <= {fSCL[1:0], cSCL2};
        fSDA <= {fSDA[1:0], cSDA2};
    end
end

assign sSCL = (fSCL[0] & fSCL[1]) | (fSCL[0] & fSCL[2]) | (fSCL[1] & fSCL[2]);
assign sSDA = (fSDA[0] & fSDA[1]) | (fSDA[0] & fSDA[2]) | (fSDA[1] & fSDA[2]);

// Delayed versions for edge detection
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        dSCL <= 1'b0;
        dSDA <= 1'b0;
    end else if (rst) begin
        dSCL <= 1'b0;
        dSDA <= 1'b0;
    end else begin
        dSCL <= sSCL;
        dSDA <= sSDA;
    end
end

// Detect conditions
assign sta_condition = (~sSDA & dSDA & sSCL);
assign sto_condition = (sSDA & ~dSDA & sSCL);
assign rising_scl   = (sSCL & ~dSCL);
assign slave_wait   = scl_oen_reg & (~sSCL);
assign scl_sync     = (~sSCL & dSCL) & scl_oen_reg;

// ---------------------
// 2. Clock divider
// ---------------------
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        cnt <= clk_cnt;
        clk_en <= 1'b0;
    end else if (rst) begin
        cnt <= clk_cnt;
        clk_en <= 1'b0;
    end else if (!ena) begin
        cnt <= clk_cnt;
        clk_en <= 1'b0;
    end else if (scl_sync) begin
        cnt <= clk_cnt;
        clk_en <= 1'b0;
    end else if (cnt == 16'd0) begin
        cnt <= clk_cnt;
        clk_en <= 1'b1;
    end else if (slave_wait) begin
        cnt <= cnt;
        clk_en <= 1'b0;
    end else begin
        cnt <= cnt - 1'b1;
        clk_en <= 1'b0;
    end
end

// ---------------------
// 3. Bus busy
// ---------------------
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        busy <= 1'b0;
    end else if (rst) begin
        busy <= 1'b0;
    end else if (sta_condition) begin
        busy <= 1'b1;
    end else if (sto_condition) begin
        busy <= 1'b0;
    end
end

// ---------------------
// 4. Arbitration lost
// ---------------------
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        al <= 1'b0;
    end else if (rst) begin
        al <= 1'b0;
    end else if (sda_chk & ~sSDA & ~sda_oen_reg) begin
        al <= 1'b1;
    end else if (sto_condition & (state != IDLE) & (state != STOP_A) & (state != STOP_B) & (state != STOP_C)) begin
        al <= 1'b1;
    end else if (state == IDLE) begin
        al <= 1'b0;
    end
end

// ---------------------
// 5. Read data sampling
// ---------------------
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        dout <= 1'b0;
    end else if (rst) begin
        dout <= 1'b0;
    end else if (rising_scl) begin
        dout <= sSDA;
    end
end

// ---------------------
// 6. FSM state update
// ---------------------
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        state <= IDLE;
    end else if (rst) begin
        state <= IDLE;
    end else if (al) begin
        state <= IDLE;
    end else if (clk_en) begin
        state <= next_state;
    end
end

// ---------------------
// 7. FSM next state and output logic
// ---------------------
always @(*) begin
    next_state = state;
    scl_oen_reg = 1'b1;
    sda_oen_reg = 1'b1;
    cmd_ack = 1'b0;
    sda_chk = 1'b0;

    case (state)
        IDLE: begin
            // Outputs released
            case (cmd)
                I2C_CMD_START: next_state = STRT_A;
                I2C_CMD_STOP:  next_state = STOP_A;
                I2C_CMD_READ:  next_state = READ_A;
                I2C_CMD_WRITE: next_state = WRIT_A;
                default:       next_state = IDLE;
            endcase
        end

        // START sequence
        STRT_A: begin
            scl_oen_reg = 1'b1;  // release SCL
            sda_oen_reg = 1'b1;  // release SDA
            next_state = STRT_B;
        end
        STRT_B: begin
            scl_oen_reg = 1'b1;  // SCL high
            sda_oen_reg = 1'b0;  // pull SDA low
            next_state = STRT_C;
        end
        STRT_C: begin
            scl_oen_reg = 1'b0;  // pull SCL low
            sda_oen_reg = 1'b0;  // keep SDA low
            cmd_ack = 1'b1;
            next_state = IDLE;
        end

        // STOP sequence
        STOP_A: begin
            scl_oen_reg = 1'b1;  // release SCL
            sda_oen_reg = 1'b0;  // ensure SDA low (drive low)
            next_state = STOP_B;
        end
        STOP_B: begin
            scl_oen_reg = 1'b1;  // SCL high (already released)
            sda_oen_reg = 1'b0;  // keep SDA low
            next_state = STOP_C;
        end
        STOP_C: begin
            scl_oen_reg = 1'b1;  // SCL high
            sda_oen_reg = 1'b1;  // release SDA -> stop condition
            cmd_ack = 1'b1;
            next_state = IDLE;
        end

        // READ sequence
        READ_A: begin
            scl_oen_reg = 1'b1;  // release SCL
            sda_oen_reg = 1'b1;  // release SDA (slave drives)
            next_state = READ_B;
        end
        READ_B: begin
            scl_oen_reg = 1'b0;  // pull SCL low
            sda_oen_reg = 1'b1;  // keep SDA released
            cmd_ack = 1'b1;
            next_state = IDLE;
        end

        // WRITE sequence
        WRIT_A: begin
            scl_oen_reg = 1'b0;  // start with SCL low
            sda_oen_reg = (din == 1'b0) ? 1'b0 : 1'b1;  // drive SDA according to din
            next_state = WRIT_B;
        end
        WRIT_B: begin
            scl_oen_reg = 1'b1;  // release SCL high
            sda_oen_reg = (din == 1'b0) ? 1'b0 : 1'b1;  // maintain SDA
            sda_chk = 1'b1;  // enable arbitration check during this phase
            next_state = WRIT_C;
        end
        WRIT_C: begin
            scl_oen_reg = 1'b0;  // pull SCL low
            sda_oen_reg = (din == 1'b0) ? 1'b0 : 1'b1;  // maintain SDA
            cmd_ack = 1'b1;
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule

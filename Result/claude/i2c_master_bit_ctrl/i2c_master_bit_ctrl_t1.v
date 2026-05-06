module i2c_master_bit_ctrl (
    input             clk,      // system clock
    input             rst,      // synchronous active high reset
    input             nReset,   // asynchronous active low reset
    input             ena,      // core enable signal

    input      [15:0] clk_cnt,  // clock prescale value

    input      [ 3:0] cmd,      // command (from byte controller)
    output            cmd_ack,  // command complete acknowledge
    output            busy,     // i2c bus busy
    output            al,       // i2c bus arbitration lost

    input             din,      // data bit to transmit
    output            dout,     // received data bit

    input             scl_i,    // i2c clock line input
    output            scl_o,    // i2c clock line output
    output            scl_oen,  // i2c clock line output enable (active low)
    input             sda_i,    // i2c data line input
    output            sda_o,    // i2c data line output
    output            sda_oen   // i2c data line output enable (active low)
);

    // Command definitions
    localparam I2C_CMD_NOP    = 4'b0000;
    localparam I2C_CMD_START  = 4'b0001;
    localparam I2C_CMD_STOP   = 4'b0010;
    localparam I2C_CMD_READ   = 4'b0100;
    localparam I2C_CMD_WRITE  = 4'b1000;

    // FSM states
    localparam STATE_IDLE     = 3'b000;
    localparam STATE_START1   = 3'b001;
    localparam STATE_START2   = 3'b010;
    localparam STATE_STOP1    = 3'b011;
    localparam STATE_STOP2    = 3'b100;
    localparam STATE_READ     = 3'b101;
    localparam STATE_WRITE    = 3'b110;

    // Input synchronization and filtering registers
    reg cSCL, cSDA;           // captured SCL/SDA
    reg [2:0] fSCL, fSDA;     // filter shift registers
    reg sSCL, sSDA;           // filtered outputs (majority function)
    reg dSCL, dSDA;           // delayed filtered outputs
    
    // Clock divider and timing
    reg [15:0] cnt;           // prescale counter
    wire clk_en;              // timing enable
    reg [7:0] filter_cnt;     // input filter counter
    
    // Status and control signals
    reg busy_r;               // registered busy flag
    reg al_r;                 // registered arbitration lost flag
    reg cmd_ack_r;            // registered command acknowledge
    reg dout_r;               // registered read data output
    
    // FSM state
    reg [2:0] state;
    
    // Slave clock stretching and synchronization
    wire slave_wait;          // SCL is held low by slave/other master
    wire scl_sync;            // Falling edge on SCL detected
    
    // Condition detection
    wire sta_condition;       // START condition detected
    wire sto_condition;       // STOP condition detected
    
    // Arbitration checking
    reg sda_chk;              // Enable SDA arbitration checking
    
    // Open-drain outputs
    reg scl_oen_r;
    reg sda_oen_r;

    // ===== Reset and Initialization =====
    
    always @(negedge nReset or posedge clk) begin
        if (!nReset) begin
            // Asynchronous reset
            state <= STATE_IDLE;
            cmd_ack_r <= 1'b0;
            al_r <= 1'b0;
            busy_r <= 1'b0;
            scl_oen_r <= 1'b1;
            sda_oen_r <= 1'b1;
            cnt <= 16'h0000;
            filter_cnt <= 8'h00;
            cSCL <= 1'b1;
            cSDA <= 1'b1;
            fSCL <= 3'b111;
            fSDA <= 3'b111;
            sSCL <= 1'b1;
            sSDA <= 1'b1;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
            dout_r <= 1'b1;
            sda_chk <= 1'b0;
        end
        else if (rst) begin
            // Synchronous reset
            state <= STATE_IDLE;
            cmd_ack_r <= 1'b0;
            al_r <= 1'b0;
            busy_r <= 1'b0;
            scl_oen_r <= 1'b1;
            sda_oen_r <= 1'b1;
            cnt <= clk_cnt;
            filter_cnt <= 8'h00;
            cSCL <= 1'b1;
            cSDA <= 1'b1;
            fSCL <= 3'b111;
            fSDA <= 3'b111;
            sSCL <= 1'b1;
            sSDA <= 1'b1;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
            dout_r <= 1'b1;
            sda_chk <= 1'b0;
        end
        else begin
            // Normal operation
            
            // Stage 1: Capture raw inputs
            cSCL <= scl_i;
            cSDA <= sda_i;
            
            // Stage 2: Input filtering
            if (filter_cnt == 8'h00) begin
                fSCL <= {fSCL[1:0], cSCL};
                fSDA <= {fSDA[1:0], cSDA};
                filter_cnt <= clk_cnt[15:2];  // clk_cnt >> 2
            end
            else begin
                filter_cnt <= filter_cnt - 1'b1;
            end
            
            // Compute filtered outputs using majority function
            sSCL <= (fSCL[2] & fSCL[1]) | (fSCL[2] & fSCL[0]) | (fSCL[1] & fSCL[0]);
            sSDA <= (fSDA[2] & fSDA[1]) | (fSDA[2] & fSDA[0]) | (fSDA[1] & fSDA[0]);
            
            // Delay filtered outputs for edge detection
            dSCL <= sSCL;
            dSDA <= sSDA;
            
            // Bus status tracking
            if (sta_condition) begin
                busy_r <= 1'b1;
            end
            else if (sto_condition) begin
                busy_r <= 1'b0;
            end
            
            // Arbitration lost detection
            if (al_r) begin
                // Arbitration lost: release both lines
                scl_oen_r <= 1'b1;
                sda_oen_r <= 1'b1;
            end
            else if (sda_chk & ~sSDA) begin
                // SDA arbitration check failed
                al_r <= 1'b1;
            end
            else if (sto_condition & (state != STATE_IDLE) & (cmd != I2C_CMD_STOP)) begin
                // Unexpected STOP condition during active command
                al_r <= 1'b1;
            end
            
            // Read data sampling: capture filtered SDA on SCL rising edge
            if (~dSCL & sSCL) begin
                dout_r <= sSDA;
            end
            
            // Clock divider and timing
            if (rst | ~ena | clk_en | scl_sync) begin
                cnt <= clk_cnt;
            end
            else if (~slave_wait) begin
                cnt <= cnt - 1'b1;
            end
            
            // Clear command acknowledge after one cycle
            cmd_ack_r <= 1'b0;
            
            // Command FSM
            if (clk_en & ~al_r) begin
                sda_chk <= 1'b0;  // Clear arbitration check by default
                
                case (state)
                    STATE_IDLE: begin
                        case (cmd)
                            I2C_CMD_START: begin
                                state <= STATE_START1;
                                scl_oen_r <= 1'b1;  // Release SCL
                                sda_oen_r <= 1'b1;  // Release SDA
                            end
                            I2C_CMD_STOP: begin
                                state <= STATE_STOP1;
                                scl_oen_r <= 1'b0;  // Drive SCL low
                                sda_oen_r <= 1'b0;  // Drive SDA low
                            end
                            I2C_CMD_READ: begin
                                state <= STATE_READ;
                                scl_oen_r <= 1'b1;  // Release SCL
                                sda_oen_r <= 1'b1;  // Release SDA for slave
                            end
                            I2C_CMD_WRITE: begin
                                state <= STATE_WRITE;
                                scl_oen_r <= ~din;   // Drive/release SDA per din
                                sda_oen_r <= ~din;
                            end
                            default: begin
                                // NOP or unknown command
                                state <= STATE_IDLE;
                            end
                        endcase
                    end
                    
                    STATE_START1: begin
                        // START: Wait for SCL and SDA to be released high
                        if (sSCL & sSDA) begin
                            sda_oen_r <= 1'b0;  // Drive SDA low
                            state <= STATE_START2;
                        end
                    end
                    
                    STATE_START2: begin
                        // START: SDA driven low while SCL high; now drive SCL low
                        scl_oen_r <= 1'b0;  // Drive SCL low
                        cmd_ack_r <= 1'b1;  // Assert command complete
                        state <= STATE_IDLE;
                    end
                    
                    STATE_STOP1: begin
                        // STOP: Wait for SCL to be released high
                        if (sSCL) begin
                            sda_oen_r <= 1'b1;  // Release SDA high
                            state <= STATE_STOP2;
                        end
                    end
                    
                    STATE_STOP2: begin
                        // STOP: SDA released high while SCL high
                        cmd_ack_r <= 1'b1;  // Assert command complete
                        state <= STATE_IDLE;
                    end
                    
                    STATE_READ: begin
                        // READ: SCL is released high for sample window, then drive low
                        scl_oen_r <= 1'b0;  // Drive SCL low
                        cmd_ack_r <= 1'b1;  // Assert command complete
                        state <= STATE_IDLE;
                    end
                    
                    STATE_WRITE: begin
                        // WRITE: SDA is held per din, SCL released then driven low
                        scl_oen_r <= 1'b0;  // Drive SCL low
                        sda_chk <= 1'b1;    // Enable arbitration checking
                        cmd_ack_r <= 1'b1;  // Assert command complete
                        state <= STATE_IDLE;
                    end
                    
                    default: begin
                        state <= STATE_IDLE;
                    end
                endcase
            end
        end
    end

    // ===== Combinational Logic =====
    
    // Timing enable: counter has expired, reset, or multi-master sync
    assign clk_en = (cnt == 16'h0000);
    
    // Slave clock stretching: SCL released but held low by slave/other master
    assign slave_wait = ~scl_oen_r & ~sSCL;
    
    // Multi-master clock synchronization: SCL falls while this master released it
    assign scl_sync = ~scl_oen_r & dSCL & ~sSCL;
    
    // START condition: SDA falls while SCL is high
    assign sta_condition = dSDA & ~sSDA & sSCL;
    
    // STOP condition: SDA rises while SCL is high
    assign sto_condition = ~dSDA & sSDA & sSCL;
    
    // Open-drain outputs: constant low drive, controlled by output enables
    assign scl_o = 1'b0;
    assign sda_o = 1'b0;
    assign scl_oen = scl_oen_r;
    assign sda_oen = sda_oen_r;
    
    // Output status and control signals
    assign cmd_ack = cmd_ack_r;
    assign busy = busy_r;
    assign al = al_r;
    assign dout = dout_r;

endmodule
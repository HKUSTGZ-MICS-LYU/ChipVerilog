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

localparam [3:0] I2C_CMD_NOP   = 4'b0000;
localparam [3:0] I2C_CMD_START = 4'b0001;
localparam [3:0] I2C_CMD_STOP  = 4'b0010;
localparam [3:0] I2C_CMD_READ  = 4'b0100;
localparam [3:0] I2C_CMD_WRITE = 4'b1000;

localparam [4:0] ST_IDLE    = 5'd0;
localparam [4:0] ST_START_A = 5'd1;
localparam [4:0] ST_START_B = 5'd2;
localparam [4:0] ST_START_C = 5'd3;
localparam [4:0] ST_START_D = 5'd4;
localparam [4:0] ST_STOP_A  = 5'd5;
localparam [4:0] ST_STOP_B  = 5'd6;
localparam [4:0] ST_STOP_C  = 5'd7;
localparam [4:0] ST_STOP_D  = 5'd8;
localparam [4:0] ST_READ_A  = 5'd9;
localparam [4:0] ST_READ_B  = 5'd10;
localparam [4:0] ST_READ_C  = 5'd11;
localparam [4:0] ST_READ_D  = 5'd12;
localparam [4:0] ST_WRITE_A = 5'd13;
localparam [4:0] ST_WRITE_B = 5'd14;
localparam [4:0] ST_WRITE_C = 5'd15;
localparam [4:0] ST_WRITE_D = 5'd16;

reg [15:0] cnt;
reg [15:0] filter_cnt;
reg [4:0]  state;
reg [1:0]  cSCL;
reg [1:0]  cSDA;
reg [2:0]  fSCL;
reg [2:0]  fSDA;
reg        sSCL;
reg        sSDA;
reg        dSCL;
reg        dSDA;
reg        clk_en;
reg        slave_wait;
reg        scl_oen_d;
reg        sda_chk;

wire [15:0] filter_reload;
wire        sta_condition;
wire        sto_condition;
wire        scl_sync;
wire        stop_cmd_state;
wire        arbitration_lost;
wire        valid_cmd;

function majority3;
    input [2:0] value;
    begin
        majority3 = (value[2] & value[1]) | (value[2] & value[0]) | (value[1] & value[0]);
    end
endfunction

assign scl_o = 1'b0;
assign sda_o = 1'b0;

assign filter_reload     = ((clk_cnt >> 2) == 16'd0) ? 16'd1 : (clk_cnt >> 2);
assign sta_condition     = ~sSDA & dSDA & sSCL;
assign sto_condition     = sSDA & ~dSDA & sSCL;
assign scl_sync          = dSCL & ~sSCL & scl_oen;
assign stop_cmd_state    = (state == ST_STOP_A) | (state == ST_STOP_B) | (state == ST_STOP_C) | (state == ST_STOP_D);
assign arbitration_lost  = (sda_chk & sda_oen & ~sSDA) | (sto_condition & (state != ST_IDLE) & ~stop_cmd_state);
assign valid_cmd         = (cmd == I2C_CMD_START) | (cmd == I2C_CMD_STOP) | (cmd == I2C_CMD_READ) | (cmd == I2C_CMD_WRITE);

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        cSCL       <= 2'b11;
        cSDA       <= 2'b11;
        fSCL       <= 3'b111;
        fSDA       <= 3'b111;
        sSCL       <= 1'b1;
        sSDA       <= 1'b1;
        dSCL       <= 1'b1;
        dSDA       <= 1'b1;
        filter_cnt <= 16'd0;
    end else if (rst) begin
        cSCL       <= 2'b11;
        cSDA       <= 2'b11;
        fSCL       <= 3'b111;
        fSDA       <= 3'b111;
        sSCL       <= 1'b1;
        sSDA       <= 1'b1;
        dSCL       <= 1'b1;
        dSDA       <= 1'b1;
        filter_cnt <= 16'd0;
    end else begin
        cSCL <= {cSCL[0], scl_i};
        cSDA <= {cSDA[0], sda_i};
        dSCL <= sSCL;
        dSDA <= sSDA;

        if (!ena) begin
            filter_cnt <= filter_reload;
        end else if (filter_cnt == 16'd0) begin
            filter_cnt <= filter_reload;
            fSCL <= {fSCL[1:0], cSCL[1]};
            fSDA <= {fSDA[1:0], cSDA[1]};
            sSCL <= majority3({fSCL[1:0], cSCL[1]});
            sSDA <= majority3({fSDA[1:0], cSDA[1]});
        end else begin
            filter_cnt <= filter_cnt - 16'd1;
        end
    end
end

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        scl_oen_d  <= 1'b1;
        slave_wait <= 1'b0;
    end else if (rst) begin
        scl_oen_d  <= 1'b1;
        slave_wait <= 1'b0;
    end else begin
        scl_oen_d <= scl_oen;
        if (!ena) begin
            slave_wait <= 1'b0;
        end else begin
            slave_wait <= (scl_oen & ~scl_oen_d & ~sSCL) | (slave_wait & ~sSCL);
        end
    end
end

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        cnt    <= 16'd0;
        clk_en <= 1'b0;
    end else if (rst) begin
        cnt    <= 16'd0;
        clk_en <= 1'b0;
    end else if (!ena) begin
        cnt    <= clk_cnt;
        clk_en <= 1'b0;
    end else if (slave_wait) begin
        cnt    <= cnt;
        clk_en <= 1'b0;
    end else if (scl_sync) begin
        cnt    <= clk_cnt;
        clk_en <= 1'b0;
    end else if (cnt == 16'd0) begin
        cnt    <= clk_cnt;
        clk_en <= 1'b1;
    end else begin
        cnt    <= cnt - 16'd1;
        clk_en <= 1'b0;
    end
end

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        busy <= 1'b0;
        al   <= 1'b0;
        dout <= 1'b0;
    end else if (rst) begin
        busy <= 1'b0;
        al   <= 1'b0;
        dout <= 1'b0;
    end else begin
        if (sta_condition) begin
            busy <= 1'b1;
        end else if (sto_condition) begin
            busy <= 1'b0;
        end

        if (~dSCL & sSCL) begin
            dout <= sSDA;
        end

        if (arbitration_lost) begin
            al <= 1'b1;
        end else if ((state == ST_IDLE) && clk_en && valid_cmd) begin
            al <= 1'b0;
        end
    end
end

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        state   <= ST_IDLE;
        cmd_ack <= 1'b0;
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        sda_chk <= 1'b0;
    end else if (rst) begin
        state   <= ST_IDLE;
        cmd_ack <= 1'b0;
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        sda_chk <= 1'b0;
    end else begin
        cmd_ack <= 1'b0;

        if (arbitration_lost) begin
            state   <= ST_IDLE;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            sda_chk <= 1'b0;
        end else if (clk_en) begin
            case (state)
                ST_IDLE: begin
                    sda_chk <= 1'b0;
                    case (cmd)
                        I2C_CMD_START: begin
                            state   <= ST_START_A;
                            scl_oen <= 1'b1;
                            sda_oen <= 1'b1;
                        end
                        I2C_CMD_STOP: begin
                            state   <= ST_STOP_A;
                            scl_oen <= 1'b0;
                            sda_oen <= 1'b0;
                        end
                        I2C_CMD_READ: begin
                            state   <= ST_READ_A;
                            scl_oen <= 1'b0;
                            sda_oen <= 1'b1;
                        end
                        I2C_CMD_WRITE: begin
                            state   <= ST_WRITE_A;
                            scl_oen <= 1'b0;
                            sda_oen <= din;
                        end
                        default: begin
                            state <= ST_IDLE;
                        end
                    endcase
                end

                ST_START_A: begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    state   <= ST_START_B;
                end
                ST_START_B: begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    state   <= ST_START_C;
                end
                ST_START_C: begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    state   <= ST_START_D;
                end
                ST_START_D: begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                    state   <= ST_IDLE;
                    cmd_ack <= 1'b1;
                end

                ST_STOP_A: begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    state   <= ST_STOP_B;
                end
                ST_STOP_B: begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    state   <= ST_STOP_C;
                end
                ST_STOP_C: begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    state   <= ST_STOP_D;
                end
                ST_STOP_D: begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    state   <= ST_IDLE;
                    cmd_ack <= 1'b1;
                end

                ST_READ_A: begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    state   <= ST_READ_B;
                end
                ST_READ_B: begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    state   <= ST_READ_C;
                end
                ST_READ_C: begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    state   <= ST_READ_D;
                end
                ST_READ_D: begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    state   <= ST_IDLE;
                    cmd_ack <= 1'b1;
                end

                ST_WRITE_A: begin
                    scl_oen <= 1'b0;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                    state   <= ST_WRITE_B;
                end
                ST_WRITE_B: begin
                    scl_oen <= 1'b1;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                    state   <= ST_WRITE_C;
                end
                ST_WRITE_C: begin
                    scl_oen <= 1'b1;
                    sda_oen <= din;
                    sda_chk <= 1'b1;
                    state   <= ST_WRITE_D;
                end
                ST_WRITE_D: begin
                    scl_oen <= 1'b0;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                    state   <= ST_IDLE;
                    cmd_ack <= 1'b1;
                end

                default: begin
                    state   <= ST_IDLE;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end
            endcase
        end
    end
end

endmodule

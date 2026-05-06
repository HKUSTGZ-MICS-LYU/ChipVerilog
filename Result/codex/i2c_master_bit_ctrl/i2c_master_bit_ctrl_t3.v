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

localparam [3:0] I2C_CMD_START = 4'b0001;
localparam [3:0] I2C_CMD_STOP  = 4'b0010;
localparam [3:0] I2C_CMD_READ  = 4'b0100;
localparam [3:0] I2C_CMD_WRITE = 4'b1000;

localparam [3:0] ST_IDLE   = 4'd0;
localparam [3:0] ST_STA1   = 4'd1;
localparam [3:0] ST_STA2   = 4'd2;
localparam [3:0] ST_STA3   = 4'd3;
localparam [3:0] ST_STO1   = 4'd4;
localparam [3:0] ST_STO2   = 4'd5;
localparam [3:0] ST_RD1    = 4'd6;
localparam [3:0] ST_RD2    = 4'd7;
localparam [3:0] ST_WR1    = 4'd8;
localparam [3:0] ST_WR2    = 4'd9;

reg  [3:0] state;
reg  [3:0] cmd_reg;
reg        din_reg;
reg        sda_chk;
reg        clk_en;
reg [15:0] cnt;
reg [15:0] filter_cnt;
reg  [1:0] cSCL;
reg  [1:0] cSDA;
reg  [2:0] fSCL;
reg  [2:0] fSDA;
reg        sSCL;
reg        sSDA;
reg        dSCL;
reg        dSDA;
reg        dscl_oen;
reg        slave_wait;

wire [15:0] filter_reload;
wire [2:0]  fSCL_next;
wire [2:0]  fSDA_next;
wire        sta_condition;
wire        sto_condition;
wire        scl_sync;
wire        al_event;

function majority3;
    input [2:0] sample;
    begin
        majority3 = (sample[2] & sample[1]) |
                    (sample[2] & sample[0]) |
                    (sample[1] & sample[0]);
    end
endfunction

assign scl_o = 1'b0;
assign sda_o = 1'b0;

assign filter_reload = (clk_cnt >> 2);
assign fSCL_next     = {fSCL[1:0], cSCL[1]};
assign fSDA_next     = {fSDA[1:0], cSDA[1]};
assign sta_condition = ~sSDA &  dSDA & sSCL;
assign sto_condition =  sSDA & ~dSDA & sSCL;
assign scl_sync      =  dSCL & ~sSCL & scl_oen;
assign al_event      = (sda_chk & sda_oen & ~sSDA) |
                       ((state != ST_IDLE) & sto_condition & (cmd_reg != I2C_CMD_STOP));

always @(posedge clk or negedge nReset)
begin
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

always @(posedge clk or negedge nReset)
begin
    if (!nReset) begin
        filter_cnt <= 16'd0;
        fSCL       <= 3'b111;
        fSDA       <= 3'b111;
        sSCL       <= 1'b1;
        sSDA       <= 1'b1;
        dSCL       <= 1'b1;
        dSDA       <= 1'b1;
    end else if (rst) begin
        filter_cnt <= 16'd0;
        fSCL       <= 3'b111;
        fSDA       <= 3'b111;
        sSCL       <= 1'b1;
        sSDA       <= 1'b1;
        dSCL       <= 1'b1;
        dSDA       <= 1'b1;
    end else begin
        dSCL <= sSCL;
        dSDA <= sSDA;

        if (!ena) begin
            filter_cnt <= filter_reload;
        end else if (filter_cnt == 16'd0) begin
            filter_cnt <= filter_reload;
            fSCL       <= fSCL_next;
            fSDA       <= fSDA_next;
            sSCL       <= majority3(fSCL_next);
            sSDA       <= majority3(fSDA_next);
        end else begin
            filter_cnt <= filter_cnt - 16'd1;
        end
    end
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset) begin
        busy <= 1'b0;
    end else if (rst) begin
        busy <= 1'b0;
    end else begin
        busy <= (busy | sta_condition) & ~sto_condition;
    end
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset) begin
        dout <= 1'b0;
    end else if (rst) begin
        dout <= 1'b0;
    end else if (sSCL & ~dSCL) begin
        dout <= sSDA;
    end
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset) begin
        dscl_oen  <= 1'b1;
        slave_wait <= 1'b0;
    end else if (rst) begin
        dscl_oen  <= 1'b1;
        slave_wait <= 1'b0;
    end else begin
        dscl_oen  <= scl_oen;
        slave_wait <= ((scl_oen & ~dscl_oen) & ~sSCL) |
                      (slave_wait & ~sSCL);
    end
end

always @(posedge clk or negedge nReset)
begin
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
    end else if (scl_sync || (cnt == 16'd0)) begin
        cnt    <= clk_cnt;
        clk_en <= 1'b1;
    end else begin
        cnt    <= cnt - 16'd1;
        clk_en <= 1'b0;
    end
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset) begin
        state   <= ST_IDLE;
        cmd_reg <= 4'd0;
        din_reg <= 1'b1;
        cmd_ack <= 1'b0;
        al      <= 1'b0;
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        sda_chk <= 1'b0;
    end else if (rst) begin
        state   <= ST_IDLE;
        cmd_reg <= 4'd0;
        din_reg <= 1'b1;
        cmd_ack <= 1'b0;
        al      <= 1'b0;
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        sda_chk <= 1'b0;
    end else begin
        cmd_ack <= 1'b0;
        al      <= al_event;

        if (al_event) begin
            state   <= ST_IDLE;
            cmd_reg <= 4'd0;
            sda_chk <= 1'b0;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
        end else if (clk_en) begin
            case (state)
                ST_IDLE: begin
                    sda_chk <= 1'b0;
                    case (cmd)
                        I2C_CMD_START: begin
                            state   <= ST_STA1;
                            cmd_reg <= I2C_CMD_START;
                            scl_oen <= 1'b1;
                            sda_oen <= 1'b1;
                        end
                        I2C_CMD_STOP: begin
                            state   <= ST_STO1;
                            cmd_reg <= I2C_CMD_STOP;
                            scl_oen <= 1'b0;
                            sda_oen <= 1'b0;
                        end
                        I2C_CMD_READ: begin
                            state   <= ST_RD1;
                            cmd_reg <= I2C_CMD_READ;
                            scl_oen <= 1'b0;
                            sda_oen <= 1'b1;
                        end
                        I2C_CMD_WRITE: begin
                            state   <= ST_WR1;
                            cmd_reg <= I2C_CMD_WRITE;
                            din_reg <= din;
                            scl_oen <= 1'b0;
                            sda_oen <= din;
                        end
                        default: begin
                            state   <= ST_IDLE;
                            cmd_reg <= 4'd0;
                        end
                    endcase
                end

                ST_STA1: begin
                    state   <= ST_STA2;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                end

                ST_STA2: begin
                    state   <= ST_STA3;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                end

                ST_STA3: begin
                    state   <= ST_IDLE;
                    cmd_reg <= 4'd0;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    cmd_ack <= 1'b1;
                end

                ST_STO1: begin
                    state   <= ST_STO2;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                end

                ST_STO2: begin
                    state   <= ST_IDLE;
                    cmd_reg <= 4'd0;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    cmd_ack <= 1'b1;
                end

                ST_RD1: begin
                    state   <= ST_RD2;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                end

                ST_RD2: begin
                    state   <= ST_IDLE;
                    cmd_reg <= 4'd0;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    cmd_ack <= 1'b1;
                end

                ST_WR1: begin
                    state   <= ST_WR2;
                    scl_oen <= 1'b1;
                    sda_oen <= din_reg;
                    sda_chk <= 1'b1;
                end

                ST_WR2: begin
                    state   <= ST_IDLE;
                    cmd_reg <= 4'd0;
                    scl_oen <= 1'b0;
                    sda_oen <= din_reg;
                    sda_chk <= 1'b0;
                    cmd_ack <= 1'b1;
                end

                default: begin
                    state   <= ST_IDLE;
                    cmd_reg <= 4'd0;
                    sda_chk <= 1'b0;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                end
            endcase
        end
    end
end

endmodule

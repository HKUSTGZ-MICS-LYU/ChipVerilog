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
localparam [4:0] ST_STOP_A  = 5'd4;
localparam [4:0] ST_STOP_B  = 5'd5;
localparam [4:0] ST_STOP_C  = 5'd6;
localparam [4:0] ST_READ_A  = 5'd7;
localparam [4:0] ST_READ_B  = 5'd8;
localparam [4:0] ST_READ_C  = 5'd9;
localparam [4:0] ST_READ_D  = 5'd10;
localparam [4:0] ST_WRITE_A = 5'd11;
localparam [4:0] ST_WRITE_B = 5'd12;
localparam [4:0] ST_WRITE_C = 5'd13;
localparam [4:0] ST_WRITE_D = 5'd14;

reg  [4:0]  c_state;
reg  [15:0] cnt;
reg         clk_en;
reg  [1:0]  cSCL;
reg  [1:0]  cSDA;
reg  [2:0]  fSCL;
reg  [2:0]  fSDA;
reg         sSCL;
reg         sSDA;
reg         dSCL;
reg         dSDA;
reg  [15:0] filter_cnt;
reg         dscl_oen;
reg         slave_wait;
reg         sda_chk;
reg         din_reg;

wire [15:0] filter_reload;
wire [2:0]  fSCL_next;
wire [2:0]  fSDA_next;
wire        sta_condition;
wire        sto_condition;
wire        scl_sync;
wire        stop_state_active;
wire        al_sda;
wire        al_stop;
wire        al_set;

function majority3;
    input [2:0] value;
    begin
        majority3 = (value[2] & value[1]) |
                    (value[2] & value[0]) |
                    (value[1] & value[0]);
    end
endfunction

assign scl_o = 1'b0;
assign sda_o = 1'b0;
assign filter_reload = (clk_cnt >> 2);
assign fSCL_next = {fSCL[1:0], cSCL[1]};
assign fSDA_next = {fSDA[1:0], cSDA[1]};
assign sta_condition = ~sSDA &  dSDA & sSCL;
assign sto_condition =  sSDA & ~dSDA & sSCL;
assign scl_sync = dSCL & ~sSCL & scl_oen;
assign stop_state_active = (c_state == ST_STOP_A) |
                           (c_state == ST_STOP_B) |
                           (c_state == ST_STOP_C);
assign al_sda = sda_chk & sda_oen & ~sSDA;
assign al_stop = sto_condition & (c_state != ST_IDLE) & ~stop_state_active;
assign al_set = al_sda | al_stop;

always @(posedge clk or negedge nReset)
begin
    if (!nReset)
    begin
        cSCL       <= 2'b11;
        cSDA       <= 2'b11;
        fSCL       <= 3'b111;
        fSDA       <= 3'b111;
        sSCL       <= 1'b1;
        sSDA       <= 1'b1;
        dSCL       <= 1'b1;
        dSDA       <= 1'b1;
        filter_cnt <= 16'd0;
    end
    else if (rst)
    begin
        cSCL       <= 2'b11;
        cSDA       <= 2'b11;
        fSCL       <= 3'b111;
        fSDA       <= 3'b111;
        sSCL       <= 1'b1;
        sSDA       <= 1'b1;
        dSCL       <= 1'b1;
        dSDA       <= 1'b1;
        filter_cnt <= 16'd0;
    end
    else
    begin
        cSCL <= {cSCL[0], scl_i};
        cSDA <= {cSDA[0], sda_i};

        if (!ena)
        begin
            fSCL       <= 3'b111;
            fSDA       <= 3'b111;
            sSCL       <= 1'b1;
            sSDA       <= 1'b1;
            dSCL       <= 1'b1;
            dSDA       <= 1'b1;
            filter_cnt <= filter_reload;
        end
        else
        begin
            dSCL <= sSCL;
            dSDA <= sSDA;

            if (filter_cnt == 16'd0)
            begin
                filter_cnt <= filter_reload;
                fSCL <= fSCL_next;
                fSDA <= fSDA_next;
                sSCL <= majority3(fSCL_next);
                sSDA <= majority3(fSDA_next);
            end
            else
            begin
                filter_cnt <= filter_cnt - 16'd1;
            end
        end
    end
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset)
    begin
        dscl_oen  <= 1'b1;
        slave_wait <= 1'b0;
    end
    else if (rst)
    begin
        dscl_oen  <= 1'b1;
        slave_wait <= 1'b0;
    end
    else if (!ena)
    begin
        dscl_oen  <= 1'b1;
        slave_wait <= 1'b0;
    end
    else
    begin
        dscl_oen <= scl_oen;
        slave_wait <= (slave_wait & ~sSCL) |
                      (scl_oen & ~dscl_oen & ~sSCL);
    end
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset)
    begin
        cnt    <= 16'd0;
        clk_en <= 1'b0;
    end
    else if (rst)
    begin
        cnt    <= 16'd0;
        clk_en <= 1'b0;
    end
    else if (!ena)
    begin
        cnt    <= clk_cnt;
        clk_en <= 1'b0;
    end
    else if ((cnt == 16'd0) || scl_sync)
    begin
        cnt    <= clk_cnt;
        clk_en <= 1'b1;
    end
    else if (slave_wait)
    begin
        cnt    <= cnt;
        clk_en <= 1'b0;
    end
    else
    begin
        cnt    <= cnt - 16'd1;
        clk_en <= 1'b0;
    end
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset)
        busy <= 1'b0;
    else if (rst)
        busy <= 1'b0;
    else if (sta_condition)
        busy <= 1'b1;
    else if (sto_condition)
        busy <= 1'b0;
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset)
        dout <= 1'b0;
    else if (rst)
        dout <= 1'b0;
    else if (~dSCL & sSCL)
        dout <= sSDA;
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset)
        al <= 1'b0;
    else if (rst)
        al <= 1'b0;
    else if (al_set)
        al <= 1'b1;
end

always @(posedge clk or negedge nReset)
begin
    if (!nReset)
    begin
        c_state  <= ST_IDLE;
        cmd_ack  <= 1'b0;
        scl_oen  <= 1'b1;
        sda_oen  <= 1'b1;
        sda_chk  <= 1'b0;
        din_reg  <= 1'b1;
    end
    else if (rst)
    begin
        c_state  <= ST_IDLE;
        cmd_ack  <= 1'b0;
        scl_oen  <= 1'b1;
        sda_oen  <= 1'b1;
        sda_chk  <= 1'b0;
        din_reg  <= 1'b1;
    end
    else if (!ena)
    begin
        c_state  <= ST_IDLE;
        cmd_ack  <= 1'b0;
        scl_oen  <= 1'b1;
        sda_oen  <= 1'b1;
        sda_chk  <= 1'b0;
    end
    else if (al_set)
    begin
        c_state  <= ST_IDLE;
        cmd_ack  <= 1'b0;
        scl_oen  <= 1'b1;
        sda_oen  <= 1'b1;
        sda_chk  <= 1'b0;
    end
    else
    begin
        cmd_ack <= 1'b0;

        if (clk_en)
        begin
            case (c_state)
                ST_IDLE:
                begin
                    sda_chk <= 1'b0;
                    case (cmd)
                        I2C_CMD_START:
                        begin
                            c_state <= ST_START_A;
                            scl_oen <= 1'b1;
                            sda_oen <= 1'b1;
                        end

                        I2C_CMD_STOP:
                        begin
                            c_state <= ST_STOP_A;
                            scl_oen <= 1'b0;
                            sda_oen <= 1'b0;
                        end

                        I2C_CMD_READ:
                        begin
                            c_state <= ST_READ_A;
                            scl_oen <= 1'b0;
                            sda_oen <= 1'b1;
                        end

                        I2C_CMD_WRITE:
                        begin
                            c_state <= ST_WRITE_A;
                            din_reg <= din;
                            scl_oen <= 1'b0;
                            sda_oen <= din;
                        end

                        default:
                        begin
                            c_state <= ST_IDLE;
                        end
                    endcase
                end

                ST_START_A:
                begin
                    c_state <= ST_START_B;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end

                ST_START_B:
                begin
                    c_state <= ST_START_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                end

                ST_START_C:
                begin
                    c_state <= ST_IDLE;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                    cmd_ack <= 1'b1;
                end

                ST_STOP_A:
                begin
                    c_state <= ST_STOP_B;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                end

                ST_STOP_B:
                begin
                    c_state <= ST_STOP_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                end

                ST_STOP_C:
                begin
                    c_state <= ST_IDLE;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    cmd_ack <= 1'b1;
                end

                ST_READ_A:
                begin
                    c_state <= ST_READ_B;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end

                ST_READ_B:
                begin
                    c_state <= ST_READ_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end

                ST_READ_C:
                begin
                    c_state <= ST_READ_D;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end

                ST_READ_D:
                begin
                    c_state <= ST_IDLE;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    cmd_ack <= 1'b1;
                end

                ST_WRITE_A:
                begin
                    c_state <= ST_WRITE_B;
                    scl_oen <= 1'b0;
                    sda_oen <= din_reg;
                    sda_chk <= 1'b0;
                end

                ST_WRITE_B:
                begin
                    c_state <= ST_WRITE_C;
                    scl_oen <= 1'b1;
                    sda_oen <= din_reg;
                    sda_chk <= 1'b0;
                end

                ST_WRITE_C:
                begin
                    c_state <= ST_WRITE_D;
                    scl_oen <= 1'b1;
                    sda_oen <= din_reg;
                    sda_chk <= 1'b1;
                end

                ST_WRITE_D:
                begin
                    c_state <= ST_IDLE;
                    scl_oen <= 1'b0;
                    sda_oen <= din_reg;
                    sda_chk <= 1'b0;
                    cmd_ack <= 1'b1;
                end

                default:
                begin
                    c_state <= ST_IDLE;
                    sda_chk <= 1'b0;
                end
            endcase
        end
    end
end

endmodule

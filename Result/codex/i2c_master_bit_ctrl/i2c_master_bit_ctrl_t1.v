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

localparam [3:0] CMD_WRITE = 4'b0001;
localparam [3:0] CMD_READ  = 4'b0010;
localparam [3:0] CMD_STOP  = 4'b0100;
localparam [3:0] CMD_START = 4'b1000;

localparam [3:0] ST_IDLE    = 4'd0;
localparam [3:0] ST_START_A = 4'd1;
localparam [3:0] ST_START_B = 4'd2;
localparam [3:0] ST_START_C = 4'd3;
localparam [3:0] ST_STOP_A  = 4'd4;
localparam [3:0] ST_STOP_B  = 4'd5;
localparam [3:0] ST_STOP_C  = 4'd6;
localparam [3:0] ST_READ_A  = 4'd7;
localparam [3:0] ST_READ_B  = 4'd8;
localparam [3:0] ST_READ_C  = 4'd9;
localparam [3:0] ST_READ_D  = 4'd10;
localparam [3:0] ST_WRITE_A = 4'd11;
localparam [3:0] ST_WRITE_B = 4'd12;
localparam [3:0] ST_WRITE_C = 4'd13;
localparam [3:0] ST_WRITE_D = 4'd14;

reg [3:0]  state;
reg [15:0] cnt;
reg [13:0] filter_cnt;
reg [1:0]  cSCL;
reg [1:0]  cSDA;
reg [2:0]  fSCL;
reg [2:0]  fSDA;
reg        dSCL;
reg        dSDA;
reg        dscl_oen;
reg        slave_wait;
reg        sda_chk;

wire       clk_en;
wire [13:0] filter_load;
wire       sSCL;
wire       sSDA;
wire       sta_condition;
wire       sto_condition;
wire       scl_sync;
wire       stop_cmd_active;
wire       arbitration_lost;

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
assign clk_en = (cnt == 16'h0000);
assign filter_load = clk_cnt[15:2];
assign sSCL = majority3(fSCL);
assign sSDA = majority3(fSDA);
assign sta_condition = ~sSDA & dSDA & sSCL;
assign sto_condition = sSDA & ~dSDA & sSCL;
assign scl_sync = scl_oen & ~sSCL & dSCL;
assign stop_cmd_active = (state == ST_STOP_A) |
                         (state == ST_STOP_B) |
                         (state == ST_STOP_C);
assign arbitration_lost = (sda_chk & sda_oen & ~sSDA) |
                          ((state != ST_IDLE) & sto_condition & ~stop_cmd_active);

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        cSCL      <= 2'b11;
        cSDA      <= 2'b11;
        fSCL      <= 3'b111;
        fSDA      <= 3'b111;
        dSCL      <= 1'b1;
        dSDA      <= 1'b1;
        dscl_oen  <= 1'b1;
        filter_cnt <= 14'd0;
        slave_wait <= 1'b0;
    end else if (rst) begin
        cSCL      <= 2'b11;
        cSDA      <= 2'b11;
        fSCL      <= 3'b111;
        fSDA      <= 3'b111;
        dSCL      <= 1'b1;
        dSDA      <= 1'b1;
        dscl_oen  <= 1'b1;
        filter_cnt <= 14'd0;
        slave_wait <= 1'b0;
    end else begin
        cSCL <= {cSCL[0], scl_i};
        cSDA <= {cSDA[0], sda_i};
        dSCL <= sSCL;
        dSDA <= sSDA;
        dscl_oen <= scl_oen;

        if (!ena) begin
            filter_cnt <= filter_load;
        end else if (filter_cnt == 14'd0) begin
            filter_cnt <= filter_load;
            fSCL <= {fSCL[1:0], cSCL[1]};
            fSDA <= {fSDA[1:0], cSDA[1]};
        end else begin
            filter_cnt <= filter_cnt - 14'd1;
        end

        slave_wait <= ((scl_oen & ~dscl_oen) & ~sSCL) |
                      (slave_wait & ~sSCL);
    end
end

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        cnt <= 16'd0;
    end else if (rst) begin
        cnt <= 16'd0;
    end else if (!ena || scl_sync || (cnt == 16'd0)) begin
        cnt <= clk_cnt;
    end else if (slave_wait) begin
        cnt <= cnt;
    end else begin
        cnt <= cnt - 16'd1;
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
        if (sSCL & ~dSCL)
            dout <= sSDA;

        if (sta_condition)
            busy <= 1'b1;
        else if (sto_condition)
            busy <= 1'b0;

        al <= arbitration_lost;
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
                        CMD_START: begin
                            state   <= ST_START_A;
                            scl_oen <= 1'b1;
                            sda_oen <= 1'b1;
                        end
                        CMD_STOP: begin
                            state   <= ST_STOP_A;
                            scl_oen <= 1'b0;
                            sda_oen <= 1'b0;
                        end
                        CMD_READ: begin
                            state   <= ST_READ_A;
                            scl_oen <= 1'b0;
                            sda_oen <= 1'b1;
                        end
                        CMD_WRITE: begin
                            state   <= ST_WRITE_A;
                            scl_oen <= 1'b0;
                            sda_oen <= din;
                        end
                        default: begin
                            state   <= ST_IDLE;
                            scl_oen <= scl_oen;
                            sda_oen <= sda_oen;
                        end
                    endcase
                end

                ST_START_A: begin
                    state   <= ST_START_B;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                end
                ST_START_B: begin
                    state   <= ST_START_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                end
                ST_START_C: begin
                    state   <= ST_IDLE;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    cmd_ack <= 1'b1;
                end

                ST_STOP_A: begin
                    state   <= ST_STOP_B;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                end
                ST_STOP_B: begin
                    state   <= ST_STOP_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                end
                ST_STOP_C: begin
                    state   <= ST_IDLE;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    cmd_ack <= 1'b1;
                end

                ST_READ_A: begin
                    state   <= ST_READ_B;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                end
                ST_READ_B: begin
                    state   <= ST_READ_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                end
                ST_READ_C: begin
                    state   <= ST_READ_D;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                end
                ST_READ_D: begin
                    state   <= ST_IDLE;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    cmd_ack <= 1'b1;
                end

                ST_WRITE_A: begin
                    state   <= ST_WRITE_B;
                    scl_oen <= 1'b0;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                end
                ST_WRITE_B: begin
                    state   <= ST_WRITE_C;
                    scl_oen <= 1'b1;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                end
                ST_WRITE_C: begin
                    state   <= ST_WRITE_D;
                    scl_oen <= 1'b1;
                    sda_oen <= din;
                    sda_chk <= 1'b1;
                end
                ST_WRITE_D: begin
                    state   <= ST_IDLE;
                    scl_oen <= 1'b0;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
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

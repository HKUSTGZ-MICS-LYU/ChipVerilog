module i2c_master_top(
    wb_clk_i,
    wb_rst_i,
    arst_i,
    wb_adr_i,
    wb_dat_i,
    wb_dat_o,
    wb_we_i,
    wb_stb_i,
    wb_cyc_i,
    wb_ack_o,
    wb_inta_o,
    scl_pad_i,
    scl_pad_o,
    scl_padoen_o,
    sda_pad_i,
    sda_pad_o,
    sda_padoen_o
);

parameter ARST_LVL = 1'b0;

input        wb_clk_i;
input        wb_rst_i;
input        arst_i;
input  [2:0] wb_adr_i;
input  [7:0] wb_dat_i;
output [7:0] wb_dat_o;
reg    [7:0] wb_dat_o;
input        wb_we_i;
input        wb_stb_i;
input        wb_cyc_i;
output       wb_ack_o;
reg          wb_ack_o;
output       wb_inta_o;
reg          wb_inta_o;
input        scl_pad_i;
output       scl_pad_o;
output       scl_padoen_o;
input        sda_pad_i;
output       sda_pad_o;
output       sda_padoen_o;

reg  [15:0] prer;
reg   [7:0] ctr;
reg   [7:0] txr;
reg   [7:0] cr;
reg         al;
reg         rxack;
reg         tip;
reg         irq_flag;

wire        rst_i;
wire        wb_wacc;
wire        core_en;
wire        ien;
wire        sta;
wire        sto;
wire        rd;
wire        wr;
wire        ack;
wire        iack;
wire  [7:0] rxr;
wire  [7:0] sr;
wire        done;
wire        irxack;
wire        i2c_busy;
wire        i2c_al;

assign rst_i   = arst_i ^ ARST_LVL;
assign wb_wacc = wb_we_i & wb_ack_o;
assign core_en = ctr[7];
assign ien     = ctr[6];
assign sta     = cr[7];
assign sto     = cr[6];
assign rd      = cr[5];
assign wr      = cr[4];
assign ack     = cr[3];
assign iack    = cr[0];
assign sr      = {rxack, i2c_busy, al, 3'b000, tip, irq_flag};

always @(posedge wb_clk_i or negedge rst_i)
begin
    if (!rst_i)
        wb_ack_o <= 1'b0;
    else if (wb_rst_i)
        wb_ack_o <= 1'b0;
    else
        wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
end

always @(posedge wb_clk_i)
begin
    case (wb_adr_i)
        3'b000: wb_dat_o <= prer[7:0];
        3'b001: wb_dat_o <= prer[15:8];
        3'b010: wb_dat_o <= ctr;
        3'b011: wb_dat_o <= rxr;
        3'b100: wb_dat_o <= sr;
        3'b101: wb_dat_o <= txr;
        3'b110: wb_dat_o <= cr;
        default: wb_dat_o <= 8'h00;
    endcase
end

always @(posedge wb_clk_i or negedge rst_i)
begin
    if (!rst_i) begin
        prer <= 16'hffff;
        ctr  <= 8'h00;
        txr  <= 8'h00;
    end else if (wb_rst_i) begin
        prer <= 16'hffff;
        ctr  <= 8'h00;
        txr  <= 8'h00;
    end else if (wb_wacc) begin
        case (wb_adr_i)
            3'b000: prer[7:0]  <= wb_dat_i;
            3'b001: prer[15:8] <= wb_dat_i;
            3'b010: ctr        <= wb_dat_i;
            3'b011: txr        <= wb_dat_i;
            default: begin end
        endcase
    end
end

always @(posedge wb_clk_i or negedge rst_i)
begin
    if (!rst_i)
        cr <= 8'h00;
    else if (wb_rst_i)
        cr <= 8'h00;
    else if (wb_wacc && core_en && (wb_adr_i == 3'b100))
        cr <= wb_dat_i;
    else begin
        if (done || i2c_al)
            cr[7:4] <= 4'b0000;
        cr[2:1] <= 2'b00;
        cr[0]   <= 1'b0;
    end
end

always @(posedge wb_clk_i or negedge rst_i)
begin
    if (!rst_i) begin
        al       <= 1'b0;
        rxack    <= 1'b0;
        tip      <= 1'b0;
        irq_flag <= 1'b0;
        wb_inta_o <= 1'b0;
    end else if (wb_rst_i) begin
        al       <= 1'b0;
        rxack    <= 1'b0;
        tip      <= 1'b0;
        irq_flag <= 1'b0;
        wb_inta_o <= 1'b0;
    end else begin
        al       <= i2c_al | (al & ~sta);
        rxack    <= irxack;
        tip      <= rd | wr;
        irq_flag <= (done | i2c_al | irq_flag) & ~iack;
        wb_inta_o <= irq_flag & ien;
    end
end

i2c_master_byte_ctrl byte_controller (
    .clk      (wb_clk_i),
    .rst      (wb_rst_i),
    .nReset   (rst_i),
    .ena      (core_en),
    .clk_cnt  (prer),
    .start    (sta),
    .stop     (sto),
    .read     (rd),
    .write    (wr),
    .ack_in   (ack),
    .din      (txr),
    .cmd_ack  (done),
    .ack_out  (irxack),
    .dout     (rxr),
    .i2c_busy (i2c_busy),
    .i2c_al   (i2c_al),
    .scl_i    (scl_pad_i),
    .scl_o    (scl_pad_o),
    .scl_oen  (scl_padoen_o),
    .sda_i    (sda_pad_i),
    .sda_o    (sda_pad_o),
    .sda_oen  (sda_padoen_o)
);

endmodule

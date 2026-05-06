module or1200_sprs (
    input clk,
    input rst,
    input flagforw,
    input flag_we,
    output flag,
    input cyforw,
    input cy_we,
    output carry,
    input [31:0] addrbase,
    input [15:0] addrofs,
    input [31:0] dat_i,
    input [3:0] alu_op,
    input [2:0] branch_op,
    input [31:0] epcr,
    input [31:0] eear,
    input [15:0] esr,
    input except_started,
    output reg [31:0] to_wbmux,
    output epcr_we,
    output eear_we,
    output esr_we,
    output pc_we,
    output sr_we,
    output reg [15:0] to_sr,
    output reg [15:0] sr,
    input [31:0] spr_dat_cfgr,
    input [31:0] spr_dat_rf,
    input [31:0] spr_dat_npc,
    input [31:0] spr_dat_ppc,
    input [31:0] spr_dat_mac,
    input [31:0] spr_dat_pic,
    input [31:0] spr_dat_tt,
    input [31:0] spr_dat_pm,
    input [31:0] spr_dat_dmmu,
    input [31:0] spr_dat_immu,
    input [31:0] spr_dat_du,
    output reg [31:0] spr_addr,
    output reg [31:0] spr_dat_o,
    output [31:0] spr_cs,
    output spr_we,
    input [31:0] du_addr,
    input [31:0] du_dat_du,
    input du_read,
    input du_write,
    output reg [31:0] du_dat_cpu
);

    localparam OR1200_ALUOP_MTSR = 4'b1001;
    localparam OR1200_ALUOP_MFSR = 4'b1010;
    localparam INIT_SR = 16'h0001;

    wire du_access;
    wire [3:0] sprs_op;
    wire read_spr;
    wire write_spr;
    wire rfe;
    wire [31:0] unqualified_cs;
    wire sys_cs;
    wire cfgr_sel;
    wire rf_sel;
    wire npc_sel;
    wire ppc_sel;
    wire sr_sel;
    wire epcr_sel;
    wire eear_sel;
    wire esr_sel;
    reg [31:0] sys_data;
    integer i;

    assign du_access = du_read | du_write;

    assign sprs_op = du_access ? (du_write ? OR1200_ALUOP_MTSR : OR1200_ALUOP_MFSR) : alu_op;

    assign read_spr = (sprs_op == OR1200_ALUOP_MFSR);
    assign write_spr = (sprs_op == OR1200_ALUOP_MTSR);

    assign rfe = (branch_op == 3'b001);

    // SPR address
    always @(*) begin
        if (du_access)
            spr_addr = du_addr;
        else
            spr_addr = addrbase | {16'h0000, addrofs};
    end

    // SPR write data
    always @(*) begin
        if (du_write)
            spr_dat_o = du_dat_du;
        else
            spr_dat_o = dat_i;
    end

    // Debug unit read data return
    always @(*) begin
        if (du_write)
            du_dat_cpu = du_dat_du;
        else if (du_read)
            du_dat_cpu = to_wbmux;
        else
            du_dat_cpu = dat_i;
    end

    // SPR write enable
    assign spr_we = du_write | write_spr;

    // Group chip-select
    assign unqualified_cs = 32'b1 << spr_addr[15:11];
    assign spr_cs = unqualified_cs & {32{read_spr | write_spr}};

    assign sys_cs = spr_cs[0];

    // System group register select signals
    assign cfgr_sel = sys_cs & (spr_addr[15:4] == 12'h000);
    assign npc_sel = sys_cs & (spr_addr[15:0] == 16'h0010);
    assign sr_sel = sys_cs & (spr_addr[15:0] == 16'h0011);
    assign ppc_sel = sys_cs & (spr_addr[15:0] == 16'h0012);
    assign epcr_sel = sys_cs & (spr_addr[15:0] == 16'h0013);
    assign eear_sel = sys_cs & (spr_addr[15:0] == 16'h0014);
    assign esr_sel = sys_cs & (spr_addr[15:0] == 16'h0015);
    assign rf_sel = sys_cs & (spr_addr[15:0] == 16'h0020);

    // Register write enables
    assign pc_we = write_spr & (npc_sel | ppc_sel);
    assign epcr_we = write_spr & epcr_sel;
    assign eear_we = write_spr & eear_sel;
    assign esr_we = write_spr & esr_sel;
    assign sr_we = (write_spr & sr_sel) | rfe | flag_we | cy_we;

    // System group read data multiplexing
    always @(*) begin
        sys_data = {32{cfgr_sel & read_spr}} & spr_dat_cfgr;
        sys_data = sys_data | ({32{rf_sel & read_spr}} & spr_dat_rf);
        sys_data = sys_data | ({32{npc_sel & read_spr}} & spr_dat_npc);
        sys_data = sys_data | ({32{ppc_sel & read_spr}} & spr_dat_ppc);
        sys_data = sys_data | ({32{sr_sel & read_spr}} & {16'b0, sr});
        sys_data = sys_data | ({32{epcr_sel & read_spr}} & epcr);
        sys_data = sys_data | ({32{eear_sel & read_spr}} & eear);
        sys_data = sys_data | ({32{esr_sel & read_spr}} & {16'b0, esr});
    end

    // SPR read data path to writeback
    always @(*) begin
        if (write_spr)
            to_wbmux = 32'd0;
        else if (read_spr) begin
            case (spr_addr[15:11])
                5'b00000: to_wbmux = sys_data;
                5'b00001: to_wbmux = spr_dat_tt;
                5'b00010: to_wbmux = spr_dat_pic;
                5'b00011: to_wbmux = spr_dat_pm;
                5'b00100: to_wbmux = spr_dat_dmmu;
                5'b00101: to_wbmux = spr_dat_immu;
                5'b00110: to_wbmux = spr_dat_mac;
                5'b00111: to_wbmux = spr_dat_du;
                default: to_wbmux = 32'd0;
            endcase
        end else
            to_wbmux = 32'd0;
    end

    // Combinational next SR value
    always @(*) begin
        to_sr = sr;
        if (rfe) begin
            to_sr[15:11] = esr[15:11];
            to_sr[10] = esr[10];
            to_sr[9] = esr[9];
            to_sr[8:0] = esr[8:0];
        end else begin
            if (write_spr & sr_sel) begin
                to_sr[15] = 1'b1;
                to_sr[14:11] = spr_dat_o[14:11];
            end
            if (cy_we)
                to_sr[10] = cyforw;
            else if (write_spr & sr_sel)
                to_sr[10] = spr_dat_o[10];
            if (flag_we)
                to_sr[9] = flagforw;
            else if (write_spr & sr_sel)
                to_sr[9] = spr_dat_o[9];
            if (write_spr & sr_sel)
                to_sr[8:0] = spr_dat_o[8:0];
        end
    end

    // Sequential SR register
    always @(posedge clk or posedge rst) begin
        if (rst)
            sr <= INIT_SR;
        else begin
            if (except_started) begin
                sr[0] <= 1'b1;
                sr[1] <= 1'b0;
                sr[2] <= 1'b0;
                sr[5] <= 1'b0;
                sr[6] <= 1'b0;
            end else if (sr_we) begin
                sr <= to_sr;
            end
        end
    end

    // Output flag and carry
    assign flag = sr[9];
    assign carry = sr[10];

endmodule

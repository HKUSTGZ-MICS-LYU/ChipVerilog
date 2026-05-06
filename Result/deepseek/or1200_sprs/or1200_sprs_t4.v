module or1200_sprs(
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
    output [31:0] to_wbmux,
    output epcr_we,
    output eear_we,
    output esr_we,
    output pc_we,
    output sr_we,
    output [15:0] to_sr,
    output [15:0] sr,
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
    output [31:0] spr_addr,
    output [31:0] spr_dat_o,
    output [31:0] spr_cs,
    output spr_we,
    input [31:0] du_addr,
    input [31:0] du_dat_du,
    input du_read,
    input du_write,
    output [31:0] du_dat_cpu
);

    // Local parameter definitions for ALU operations
    localparam ALUOP_MTSR = 4'b0110;
    localparam ALUOP_MFSR = 4'b0101;
    localparam BRANCH_RFE = 3'b111;

    // Reset value for sr (architecture defined)
    localparam [15:0] SR_RESET = 16'h0001;

    // Internal signals
    wire du_access;
    wire [3:0] sprs_op;
    wire [31:0] spr_addr_int;
    wire [31:0] spr_dat_o_int;
    wire [31:0] du_dat_cpu_int;
    wire read_spr;
    wire write_spr;
    wire spr_we_int;
    wire [31:0] unqualified_cs;
    wire [31:0] spr_cs_int;

    // System group internal selects
    wire cfgr_sel, rf_sel, npc_sel, ppc_sel, sr_sel, epcr_sel, eear_sel, esr_sel;

    // to_sr combinational internal
    reg [15:0] to_sr_comb;

    // sr register
    reg [15:0] sr_reg;

    // Flags
    wire flag_int;
    wire carry_int;

    // sys_data
    wire [31:0] sys_data;

    // Debug Unit access
    assign du_access = du_read | du_write;

    // sprs_op
    assign sprs_op = du_write ? ALUOP_MTSR :
                     du_read  ? ALUOP_MFSR :
                     alu_op;

    // spr_addr
    assign spr_addr_int = du_access ? du_addr :
                          (addrbase | {16'h0000, addrofs});

    // spr_dat_o
    assign spr_dat_o_int = du_write ? du_dat_du : dat_i;

    // du_dat_cpu
    assign du_dat_cpu_int = du_write ? du_dat_du :
                            du_read  ? to_wbmux :
                            dat_i;

    // Operation decode
    assign write_spr = (sprs_op == ALUOP_MTSR);
    assign read_spr  = (sprs_op == ALUOP_MFSR);

    // spr_we
    assign spr_we_int = du_write | write_spr;

    // Unqualified chip select (one-hot of spr_addr[15:11])
    assign unqualified_cs = 32'b1 << spr_addr_int[15:11];

    // Qualified chip select
    assign spr_cs_int = unqualified_cs & {32{read_spr | write_spr}};

    // System group internal register select signals (only when spr_cs[0] is asserted)
    assign cfgr_sel = spr_cs_int[0] && (spr_addr_int[10:8] == 3'b000) && (spr_addr_int[7:0] == 8'h00);
    assign rf_sel   = spr_cs_int[0] && (spr_addr_int[10:8] == 3'b001) && (spr_addr_int[7:0] == 8'h00);
    assign npc_sel  = spr_cs_int[0] && (spr_addr_int[10:0] == 11'h010);
    assign ppc_sel  = spr_cs_int[0] && (spr_addr_int[10:0] == 11'h020);
    assign sr_sel   = spr_cs_int[0] && (spr_addr_int[10:0] == 11'h030);
    assign epcr_sel = spr_cs_int[0] && (spr_addr_int[10:0] == 11'h040);
    assign eear_sel = spr_cs_int[0] && (spr_addr_int[10:0] == 11'h050);
    assign esr_sel  = spr_cs_int[0] && (spr_addr_int[10:0] == 11'h060);

    // Write enables for system registers
    assign pc_we    = (npc_sel | ppc_sel) & write_spr;
    assign epcr_we  = epcr_sel & write_spr;
    assign eear_we  = eear_sel & write_spr;
    assign esr_we   = esr_sel & write_spr;
    assign sr_we    = (sr_sel & write_spr) | (branch_op == BRANCH_RFE) | flag_we | cy_we;

    // Flag and carry outputs
    assign flag_int = sr_reg[9];
    assign carry_int = sr_reg[10];
    assign flag = flag_int;
    assign carry = carry_int;

    // to_sr combinational generation
    always @(*) begin
        // Default: keep old value
        to_sr_comb = sr_reg;

        // Bits 15:11: RFE -> esr[15:11], else MTSR -> {1'b1, spr_dat_o[14:11]}, else keep
        if (branch_op == BRANCH_RFE) begin
            to_sr_comb[15:11] = esr[15:11];
        end else if (write_spr && sr_sel) begin
            to_sr_comb[15] = 1'b1;
            to_sr_comb[14:11] = spr_dat_o_int[14:11];
        end

        // Bit 10 (carry): RFE -> esr[10]; cy_we -> cyforw; MTSR -> spr_dat_o[10]; else keep
        if (branch_op == BRANCH_RFE) begin
            to_sr_comb[10] = esr[10];
        end else if (cy_we) begin
            to_sr_comb[10] = cyforw;
        end else if (write_spr && sr_sel) begin
            to_sr_comb[10] = spr_dat_o_int[10];
        end

        // Bit 9 (flag): RFE -> esr[9]; flag_we -> flagforw; MTSR -> spr_dat_o[9]; else keep
        if (branch_op == BRANCH_RFE) begin
            to_sr_comb[9] = esr[9];
        end else if (flag_we) begin
            to_sr_comb[9] = flagforw;
        end else if (write_spr && sr_sel) begin
            to_sr_comb[9] = spr_dat_o_int[9];
        end

        // Bits 8:0: RFE -> esr[8:0]; MTSR -> spr_dat_o[8:0]; else keep
        if (branch_op == BRANCH_RFE) begin
            to_sr_comb[8:0] = esr[8:0];
        end else if (write_spr && sr_sel) begin
            to_sr_comb[8:0] = spr_dat_o_int[8:0];
        end
    end

    assign to_sr = to_sr_comb;

    // Sequential SR register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sr_reg <= SR_RESET;
        end else if (except_started) begin
            // Exception entry override: set sr[0]=1, clear sr[1],sr[2],sr[5],sr[6]
            sr_reg[0] <= 1'b1;
            sr_reg[1] <= 1'b0;
            sr_reg[2] <= 1'b0;
            sr_reg[5] <= 1'b0;
            sr_reg[6] <= 1'b0;
            // Other bits unchanged
        end else if (sr_we) begin
            sr_reg <= to_sr_comb;
        end
    end

    assign sr = sr_reg;

    // sys_data generation
    wire [31:0] sys_data_masked;
    assign sys_data_masked = ({32{cfgr_sel & read_spr}} & spr_dat_cfgr) |
                             ({32{rf_sel   & read_spr}} & spr_dat_rf) |
                             ({32{npc_sel  & read_spr}} & spr_dat_npc) |
                             ({32{ppc_sel  & read_spr}} & spr_dat_ppc) |
                             ({32{sr_sel   & read_spr}} & {16'h0000, sr_reg}) |
                             ({32{epcr_sel & read_spr}} & epcr) |
                             ({32{eear_sel & read_spr}} & eear) |
                             ({32{esr_sel  & read_spr}} & {16'h0000, esr});
    assign sys_data = sys_data_masked;

    // to_wbmux generation
    reg [31:0] to_wbmux_int;
    always @(*) begin
        if (sprs_op == ALUOP_MTSR) begin
            to_wbmux_int = 32'b0;
        end else if (sprs_op == ALUOP_MFSR) begin
            case (spr_addr_int[15:11])
                5'h00: to_wbmux_int = sys_data;     // System group
                5'h01: to_wbmux_int = spr_dat_tt;   // Tick timer
                5'h02: to_wbmux_int = spr_dat_pic;  // PIC
                5'h03: to_wbmux_int = spr_dat_pm;   // Power management
                5'h04: to_wbmux_int = spr_dat_dmmu; // DMMU
                5'h05: to_wbmux_int = spr_dat_immu; // IMMU
                5'h06: to_wbmux_int = spr_dat_mac;  // MAC
                5'h07: to_wbmux_int = spr_dat_du;   // Debug unit
                default: to_wbmux_int = 32'b0;
            endcase
        end else begin
            to_wbmux_int = 32'b0;
        end
    end
    assign to_wbmux = to_wbmux_int;

    // Output assignments
    assign spr_addr = spr_addr_int;
    assign spr_dat_o = spr_dat_o_int;
    assign spr_cs = spr_cs_int;
    assign spr_we = spr_we_int;
    assign du_dat_cpu = du_dat_cpu_int;

endmodule

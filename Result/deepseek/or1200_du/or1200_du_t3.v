module or1200_du (
    input wire clk,
    input wire rst,
    input wire dcpu_cycstb_i,
    input wire dcpu_we_i,
    input wire [31:0] dcpu_adr_i,
    input wire [31:0] dcpu_dat_lsu,
    input wire [31:0] dcpu_dat_dc,
    input wire icpu_cycstb_i,
    input wire ex_freeze,
    input wire [2:0] branch_op,
    input wire [31:0] ex_insn,
    input wire [31:0] id_pc,
    input wire [31:0] spr_dat_npc,
    input wire [31:0] rf_dataw,
    output reg [13:0] du_dsr,
    output wire du_stall,
    output reg [31:0] du_addr,
    input wire [31:0] du_dat_i,
    output reg [31:0] du_dat_o,
    output wire du_read,
    output wire du_write,
    input wire [12:0] du_except,
    output wire du_hwbkpt,
    input wire spr_cs,
    input wire spr_write,
    input wire [31:0] spr_addr,
    input wire [31:0] spr_dat_i,
    output reg [31:0] spr_dat_o,
    input wire dbg_stall_i,
    input wire dbg_ewt_i,
    output reg [3:0] dbg_lss_o,
    output reg [1:0] dbg_is_o,
    output wire [10:0] dbg_wp_o,
    output reg dbg_bp_o,
    input wire dbg_stb_i,
    input wire dbg_we_i,
    input wire [31:0] dbg_adr_i,
    input wire [31:0] dbg_dat_i,
    output wire [31:0] dbg_dat_o,
    output reg dbg_ack_o
);

//****************************************************************************//
//  Parameters                                                               //
//****************************************************************************//
localparam DMR1_ADDR = 12'h001;
localparam DMR2_ADDR = 12'h002;
localparam DSR_ADDR  = 12'h003;
localparam DRR_ADDR  = 12'h004;
localparam DVR0_ADDR = 12'h010;
localparam DVR1_ADDR = 12'h011;
localparam DVR2_ADDR = 12'h012;
localparam DVR3_ADDR = 12'h013;
localparam DVR4_ADDR = 12'h014;
localparam DVR5_ADDR = 12'h015;
localparam DVR6_ADDR = 12'h016;
localparam DVR7_ADDR = 12'h017;
localparam DCR0_ADDR = 12'h018;
localparam DCR1_ADDR = 12'h019;
localparam DCR2_ADDR = 12'h01A;
localparam DCR3_ADDR = 12'h01B;
localparam DCR4_ADDR = 12'h01C;
localparam DCR5_ADDR = 12'h01D;
localparam DCR6_ADDR = 12'h01E;
localparam DCR7_ADDR = 12'h01F;
localparam DWCR0_ADDR= 12'h020;
localparam DWCR1_ADDR= 12'h021;
localparam TB_BUF_ADDR = 12'h008;
localparam TB_BUF_DATA = 12'h009;

localparam NOP_INSN = 32'h15000000;

//****************************************************************************//
//  Wires and Registers                                                      //
//****************************************************************************//
wire [10:0] spr_addr_low;
assign spr_addr_low = spr_addr[10:0];

// Direct assignments for external debug interface forwarding
assign du_stall = dbg_stall_i;
assign du_addr = dbg_adr_i;
assign du_dat_o = dbg_dat_i;
assign du_read = dbg_stb_i & ~dbg_we_i;
assign du_write = dbg_stb_i & dbg_we_i;
assign dbg_dat_o = du_dat_i;
assign dbg_wp_o = 11'b0;

// Debug acknowledge register
always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_ack_o <= 1'b0;
    else
        dbg_ack_o <= dbg_stb_i;
end

// Debug status outputs
`ifndef OR1200_DU_STATUS_UNIMPLEMENTED
    always @(*) begin
        dbg_lss_o = {dcpu_we_i, dcpu_cycstb_i, 2'b0};
        dbg_is_o = {1'b0, icpu_cycstb_i};
    end
`else
    reg dbg_is_toggle;
    always @(posedge clk) begin
        if (rst)
            dbg_is_toggle <= 1'b0;
        else if (icpu_cycstb_i)
            dbg_is_toggle <= ~dbg_is_toggle;
    end
    always @(*) begin
        dbg_lss_o = 4'b0;
        dbg_is_o = {1'b0, dbg_is_toggle};
    end
`endif

//****************************************************************************//
//  Debug Register Logic (only if DU implemented)                            //
//****************************************************************************//
`ifdef OR1200_DU_IMPLEMENTED

// Register select signals
wire sel_dmr1 = spr_cs && (spr_addr_low == DMR1_ADDR);
wire sel_dmr2 = spr_cs && (spr_addr_low == DMR2_ADDR);
wire sel_dsr  = spr_cs && (spr_addr_low == DSR_ADDR);
wire sel_drr  = spr_cs && (spr_addr_low == DRR_ADDR);
wire [7:0] sel_dvr;
wire [7:0] sel_dcr;
genvar gi;
generate
    for (gi=0; gi<8; gi=gi+1) begin : gen_dvr_dcr_sel
        assign sel_dvr[gi] = spr_cs && (spr_addr_low == (DVR0_ADDR + gi));
        assign sel_dcr[gi] = spr_cs && (spr_addr_low == (DCR0_ADDR + gi));
    end
endgenerate
wire sel_dwcr0 = spr_cs && (spr_addr_low == DWCR0_ADDR);
wire sel_dwcr1 = spr_cs && (spr_addr_low == DWCR1_ADDR);

// Register declarations
`ifdef OR1200_DU_DMR1
    reg [31:0] dmr1;
`else
    wire [31:0] dmr1 = 32'b0;
`endif

`ifdef OR1200_DU_DMR2
    reg [31:0] dmr2;
`else
    wire [31:0] dmr2 = 32'b0;
`endif

`ifdef OR1200_DU_DSR
    reg [31:0] dsr;
`else
    wire [31:0] dsr = 32'b0;
`endif

`ifdef OR1200_DU_DRR
    reg [31:0] drr;
`else
    wire [31:0] drr = 32'b0;
`endif

wire [31:0] dvr [0:7];
wire [31:0] dcr [0:7];
genvar i;
generate
    for (i=0; i<8; i=i+1) begin : gen_dvr
        `ifdef OR1200_DU_DVR0
            reg [31:0] dvr_reg;
            always @(posedge clk or posedge rst) begin
                if (rst) dvr_reg <= 32'b0;
                else if (spr_write && sel_dvr[i]) dvr_reg <= spr_dat_i;
            end
            assign dvr[i] = dvr_reg;
        `else
            assign dvr[i] = 32'b0;
        `endif
    end

    for (i=0; i<8; i=i+1) begin : gen_dcr
        `ifdef OR1200_DU_DCR0
            reg [7:0] dcr_reg;
            always @(posedge clk or posedge rst) begin
                if (rst) dcr_reg <= 8'b0;
                else if (spr_write && sel_dcr[i]) dcr_reg <= spr_dat_i[7:0];
            end
            assign dcr[i] = {24'b0, dcr_reg};
        `else
            assign dcr[i] = 32'b0;
        `endif
    end
endgenerate

// DWCR registers
`ifdef OR1200_DU_DWCR0
    reg [31:0] dwcr0;
`else
    wire [31:0] dwcr0 = 32'b0;
`endif

`ifdef OR1200_DU_DWCR1
    reg [31:0] dwcr1;
`else
    wire [31:0] dwcr1 = 32'b0;
`endif

// DSR and DRR are always 14-bit when implemented
assign du_dsr = dsr[13:0];

// Exception stop decoding
wire [13:0] except_stop = {1'b0, du_except};

// Breakpoint output logic
reg dbg_bp_r;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dbg_bp_r <= 1'b0;
    end else begin
        if (ex_freeze) begin
            dbg_bp_r <= |except_stop;
        end else begin
            dbg_bp_r <= 1'b0;
            if (|except_stop) dbg_bp_r <= 1'b1;
            `ifdef OR1200_DU_SINGLESTEP
                if (dmr1[0] && (ex_insn != NOP_INSN)) dbg_bp_r <= 1'b1;
            `endif
            `ifdef OR1200_DU_BRANCHTRACE
                if (dmr1[1] && (branch_op != 3'b0) && (ex_insn != NOP_INSN)) dbg_bp_r <= 1'b1;
            `endif
        end
    end
end
assign dbg_bp_o = dbg_bp_r;

// SPR read path
`ifdef OR1200_DU_READREGS
    always @(*) begin
        spr_dat_o = 32'b0;
        case (spr_addr_low)
            DMR1_ADDR: spr_dat_o = dmr1;
            DMR2_ADDR: spr_dat_o = dmr2;
            DSR_ADDR:  spr_dat_o = {18'b0, dsr[13:0]};
            DRR_ADDR:  spr_dat_o = {18'b0, drr[13:0]};
            DVR0_ADDR: spr_dat_o = dvr[0];
            DVR1_ADDR: spr_dat_o = dvr[1];
            DVR2_ADDR: spr_dat_o = dvr[2];
            DVR3_ADDR: spr_dat_o = dvr[3];
            DVR4_ADDR: spr_dat_o = dvr[4];
            DVR5_ADDR: spr_dat_o = dvr[5];
            DVR6_ADDR: spr_dat_o = dvr[6];
            DVR7_ADDR: spr_dat_o = dvr[7];
            DCR0_ADDR: spr_dat_o = dcr[0];
            DCR1_ADDR: spr_dat_o = dcr[1];
            DCR2_ADDR: spr_dat_o = dcr[2];
            DCR3_ADDR: spr_dat_o = dcr[3];
            DCR4_ADDR: spr_dat_o = dcr[4];
            DCR5_ADDR: spr_dat_o = dcr[5];
            DCR6_ADDR: spr_dat_o = dcr[6];
            DCR7_ADDR: spr_dat_o = dcr[7];
            DWCR0_ADDR: spr_dat_o = dwcr0;
            DWCR1_ADDR: spr_dat_o = dwcr1;
            `ifdef OR1200_DU_TB_IMPLEMENTED
                TB_BUF_ADDR: spr_dat_o = {24'b0, tb_addr};
                TB_BUF_DATA: spr_dat_o = tb_ram_npc[tb_read_addr];
            `endif
            default: spr_dat_o = 32'b0;
        endcase
    end
`else
    always @(*) spr_dat_o = 32'b0;
`endif

// Hardware watchpoint logic
`ifdef OR1200_DU_HWBKPTS
    // Internal watchpoint wire vector
    wire [10:0] wp_int;

    // Generate individual match signals
    wire [7:0] match;
    genvar j;
    generate
        for (j=0; j<8; j=j+1) begin : gen_watchpoint
            wire [2:0] cmp_type;
            wire [1:0] cmp_mode;
            wire cmp_sign;
            assign cmp_type = dcr[j][7:5];
            assign cmp_mode = dcr[j][4:3];
            assign cmp_sign = dcr[j][2];

            wire cmp_target;
            reg [31:0] compare_a, compare_b;
            reg enable_strobe;
            always @(*) begin
                case (cmp_type)
                    3'b001: begin // instruction fetch address
                        enable_strobe = icpu_cycstb_i;
                        compare_a = id_pc;
                    end
                    3'b010: begin // load address
                        enable_strobe = dcpu_cycstb_i && ~dcpu_we_i;
                        compare_a = dcpu_adr_i;
                    end
                    3'b011: begin // store address
                        enable_strobe = dcpu_cycstb_i && dcpu_we_i;
                        compare_a = dcpu_adr_i;
                    end
                    3'b100: begin // load data
                        enable_strobe = dcpu_cycstb_i && ~dcpu_we_i;
                        compare_a = dcpu_dat_lsu;
                    end
                    3'b101: begin // store data
                        enable_strobe = dcpu_cycstb_i && dcpu_we_i;
                        compare_a = dcpu_dat_lsu;
                    end
                    3'b110: begin // load/store address
                        enable_strobe = dcpu_cycstb_i;
                        compare_a = dcpu_adr_i;
                    end
                    3'b111: begin // load/store data
                        enable_strobe = dcpu_cycstb_i;
                        compare_a = dcpu_dat_lsu;
                    end
                    default: begin
                        enable_strobe = 1'b0;
                        compare_a = 32'b0;
                    end
                endcase
                compare_b = dvr[j];
            end

            wire match_j;
            assign match_j = enable_strobe && (
                (cmp_mode == 2'b00) ? ( (cmp_sign ? ($signed(compare_a) == $signed(compare_b)) : (compare_a == compare_b)) ) :
                (cmp_mode == 2'b01) ? ( (cmp_sign ? ($signed(compare_a) < $signed(compare_b)) : (compare_a < compare_b)) ) :
                (cmp_mode == 2'b10) ? ( (cmp_sign ? ($signed(compare_a) <= $signed(compare_b)) : (compare_a <= compare_b)) ) :
                (cmp_mode == 2'b11) ? ( (cmp_sign ? ($signed(compare_a) >= $signed(compare_b)) : (compare_a >= compare_b)) ) :
                1'b0
            );
            assign match[j] = match_j;
        end
    endgenerate

    // Combine matches into watchpoint bits according to DMR1
    reg [10:0] wp_reg;
    always @(*) begin
        wp_reg = 11'b0;
        // wp0: always direct match if not disabled
        if (dmr1[1:0] != 2'b00)
            wp_reg[0] = match[0];
        else
            wp_reg[0] = 1'b0;

        for (int k=1; k<8; k++) begin
            case (dmr1[2*k+1 : 2*k])
                2'b00: wp_reg[k] = 1'b0;
                2'b01: wp_reg[k] = match[k];
                2'b10: wp_reg[k] = match[k] & wp_reg[k-1];
                2'b11: wp_reg[k] = match[k] | wp_reg[k-1];
                default: wp_reg[k] = 1'b0;
            endcase
        end

        // Watchpoint bits from counters and external trigger
        `ifdef OR1200_DU_DWCR0
            wp_reg[8] = (dwcr0[31:16] == dwcr0[15:0]) ? 1'b1 : 1'b0;
        `else
            wp_reg[8] = 1'b0;
        `endif
        `ifdef OR1200_DU_DWCR1
            wp_reg[9] = (dwcr1[31:16] == dwcr1[15:0]) ? 1'b1 : 1'b0;
        `else
            wp_reg[9] = 1'b0;
        `endif
        wp_reg[10] = dbg_ewt_i;
    end
    assign wp_int = wp_reg;

    // Watchpoint counters increment logic
    `ifdef OR1200_DU_DWCR0
        always @(posedge clk or posedge rst) begin
            if (rst)
                dwcr0 <= 32'b0;
            else if (spr_write && sel_dwcr0)
                dwcr0 <= spr_dat_i;
            else if (dmr2[0] && wp_int[0])
                dwcr0[15:0] <= dwcr0[15:0] + 1;
        end
    `endif
    `ifdef OR1200_DU_DWCR1
        always @(posedge clk or posedge rst) begin
            if (rst)
                dwcr1 <= 32'b0;
            else if (spr_write && sel_dwcr1)
                dwcr1 <= spr_dat_i;
            else if (dmr2[1] && wp_int[1])
                dwcr1[15:0] <= dwcr1[15:0] + 1;
        end
    `endif

    // Hardware breakpoint request from enabled watchpoints
    assign du_hwbkpt = |(wp_int & dmr2[10:0]);

`else // no hardware watchpoints
    assign du_hwbkpt = 1'b0;
`endif

// Register updates for DMR1, DMR2, DSR, DRR
`ifdef OR1200_DU_DMR1
    always @(posedge clk or posedge rst) begin
        if (rst) dmr1 <= 32'b0;
        else if (spr_write && sel_dmr1) dmr1 <= spr_dat_i;
    end
`endif

`ifdef OR1200_DU_DMR2
    always @(posedge clk or posedge rst) begin
        if (rst) dmr2 <= 32'b0;
        else if (spr_write && sel_dmr2) dmr2 <= spr_dat_i;
    end
`endif

`ifdef OR1200_DU_DSR
    always @(posedge clk or posedge rst) begin
        if (rst) dsr <= 32'b0;
        else if (spr_write && sel_dsr) dsr <= spr_dat_i;
    end
`endif

`ifdef OR1200_DU_DRR
    always @(posedge clk or posedge rst) begin
        if (rst) drr <= 32'b0;
        else if (spr_write && sel_drr) drr <= spr_dat_i;
        else drr <= drr | {18'b0, except_stop};
    end
`else
    always @(*) du_dsr = dsr[13:0];
`endif

// Trace buffer
`ifdef OR1200_DU_TB_IMPLEMENTED
    reg [7:0] tb_addr;
    reg [7:0] tb_read_addr;
    reg [31:0] tb_timstmp;
    reg [31:0] tb_ram_npc [0:255];
    reg [31:0] tb_ram_insn [0:255];
    reg [31:0] tb_ram_data [0:255];
    reg [31:0] tb_ram_tim [0:255];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tb_addr <= 8'b0;
            tb_timstmp <= 32'b0;
        end else begin
            if (!ex_freeze) begin
                tb_timstmp <= tb_timstmp + 1;
                if (ex_insn != NOP_INSN) begin
                    tb_ram_npc[tb_addr] <= spr_dat_npc;
                    tb_ram_insn[tb_addr] <= ex_insn;
                    tb_ram_data[tb_addr] <= rf_dataw;
                    tb_ram_tim[tb_addr] <= tb_timstmp;
                    tb_addr <= tb_addr + 1;
                end
            end
        end
    end

    // Allow SPR write to set read address
    always @(posedge clk or posedge rst) begin
        if (rst) tb_read_addr <= 8'b0;
        else if (spr_write && (spr_addr_low == TB_BUF_ADDR)) tb_read_addr <= spr_dat_i[7:0];
    end

`else
    wire [31:0] tb_ram_npc; // dummy to avoid compiler error if referenced in SPR case
    assign tb_ram_npc = 32'b0;
`endif

`else // OR1200_DU_IMPLEMENTED not defined
    assign du_dsr = 14'b0;
    assign dbg_bp_o = 1'b0;
    assign du_hwbkpt = 1'b0;
    always @(*) spr_dat_o = 32'b0;
`endif

endmodule

module or1200_du(
    input clk,
    input rst,
    input dcpu_cycstb_i,
    input dcpu_we_i,
    input [31:0] dcpu_adr_i,
    input [31:0] dcpu_dat_lsu,
    input [31:0] dcpu_dat_dc,
    input icpu_cycstb_i,
    input ex_freeze,
    input [2:0] branch_op,
    input [31:0] ex_insn,
    input [31:0] id_pc,
    input [31:0] spr_dat_npc,
    input [31:0] rf_dataw,
    output [13:0] du_dsr,
    output du_stall,
    output [31:0] du_addr,
    input [31:0] du_dat_i,
    output [31:0] du_dat_o,
    output du_read,
    output du_write,
    input [12:0] du_except,
    output du_hwbkpt,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    input dbg_stall_i,
    input dbg_ewt_i,
    output [3:0] dbg_lss_o,
    output [1:0] dbg_is_o,
    output [10:0] dbg_wp_o,
    output dbg_bp_o,
    input dbg_stb_i,
    input dbg_we_i,
    input [31:0] dbg_adr_i,
    input [31:0] dbg_dat_i,
    output [31:0] dbg_dat_o,
    output dbg_ack_o
);

reg dbg_ack_r;
wire [31:0] du_addr_w;
reg [31:0] du_dat_o_r;
wire du_read_w, du_write_w;

// Direct external debug interface forwarding
assign du_stall = dbg_stall_i;
assign du_addr = dbg_adr_i;
assign du_dat_o = dbg_dat_i;
assign du_read = dbg_stb_i & ~dbg_we_i;
assign du_write = dbg_stb_i & dbg_we_i;
assign dbg_dat_o = du_dat_i;
assign dbg_ack_o = dbg_ack_r;

always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_ack_r <= 1'b0;
    else
        dbg_ack_r <= dbg_stb_i;
end

// Status outputs
`ifdef OR1200_DU_STATUS_UNIMPLEMENTED
    reg dbg_is_toggle;
    always @(posedge clk or posedge rst) begin
        if (rst)
            dbg_is_toggle <= 1'b0;
        else if (icpu_cycstb_i)
            dbg_is_toggle <= ~dbg_is_toggle;
    end
    assign dbg_lss_o = 4'b0;
    assign dbg_is_o = {1'b0, dbg_is_toggle};
`else
    assign dbg_lss_o = {dcpu_cycstb_i, dcpu_we_i, 2'b00};
    assign dbg_is_o = {1'b0, icpu_cycstb_i};
`endif

// Watchpoint output always zero
assign dbg_wp_o = 11'b000_0000_0000;

// Internal signals for implemented features
`ifdef OR1200_DU_IMPLEMENTED

// Register declarations conditionally
`ifdef OR1200_DU_DMR1
    reg [31:0] dmr1;
`endif
`ifdef OR1200_DU_DMR2
    reg [31:0] dmr2;
`endif
`ifdef OR1200_DU_DSR
    reg [13:0] dsr;
`endif
`ifdef OR1200_DU_DRR
    reg [13:0] drr;
`endif
`ifdef OR1200_DU_DVR0
    reg [31:0] dvr0;
`endif
`ifdef OR1200_DU_DVR1
    reg [31:0] dvr1;
`endif
`ifdef OR1200_DU_DVR2
    reg [31:0] dvr2;
`endif
`ifdef OR1200_DU_DVR3
    reg [31:0] dvr3;
`endif
`ifdef OR1200_DU_DVR4
    reg [31:0] dvr4;
`endif
`ifdef OR1200_DU_DVR5
    reg [31:0] dvr5;
`endif
`ifdef OR1200_DU_DVR6
    reg [31:0] dvr6;
`endif
`ifdef OR1200_DU_DVR7
    reg [31:0] dvr7;
`endif
`ifdef OR1200_DU_DCR0
    reg [7:0] dcr0;
`endif
`ifdef OR1200_DU_DCR1
    reg [7:0] dcr1;
`endif
`ifdef OR1200_DU_DCR2
    reg [7:0] dcr2;
`endif
`ifdef OR1200_DU_DCR3
    reg [7:0] dcr3;
`endif
`ifdef OR1200_DU_DCR4
    reg [7:0] dcr4;
`endif
`ifdef OR1200_DU_DCR5
    reg [7:0] dcr5;
`endif
`ifdef OR1200_DU_DCR6
    reg [7:0] dcr6;
`endif
`ifdef OR1200_DU_DCR7
    reg [7:0] dcr7;
`endif
`ifdef OR1200_DU_DWCR0
    reg [31:0] dwcr0;
`endif
`ifdef OR1200_DU_DWCR1
    reg [31:0] dwcr1;
`endif

// Decode except_stop
wire [13:0] except_stop;
assign except_stop = {1'b0, du_except};

// DSR output
`ifdef OR1200_DU_DSR
    assign du_dsr = dsr;
`else
    assign du_dsr = 14'b0;
`endif

// SPR register selection logic
wire reg_select_valid;
wire [10:0] spr_addr_lo;
assign reg_select_valid = spr_cs;
assign spr_addr_lo = spr_addr[10:0];

// Write enables for each register (only when implemented)
wire wr_dmr1, wr_dmr2, wr_dsr, wr_drr;
wire wr_dvr0, wr_dvr1, wr_dvr2, wr_dvr3, wr_dvr4, wr_dvr5, wr_dvr6, wr_dvr7;
wire wr_dcr0, wr_dcr1, wr_dcr2, wr_dcr3, wr_dcr4, wr_dcr5, wr_dcr6, wr_dcr7;
wire wr_dwcr0, wr_dwcr1;

assign wr_dmr1 = reg_select_valid & spr_write & (spr_addr_lo == 12'h000);
assign wr_dmr2 = reg_select_valid & spr_write & (spr_addr_lo == 12'h001);
assign wr_dsr  = reg_select_valid & spr_write & (spr_addr_lo == 12'h005);
assign wr_drr  = reg_select_valid & spr_write & (spr_addr_lo == 12'h006);
assign wr_dvr0 = reg_select_valid & spr_write & (spr_addr_lo == 12'h020);
assign wr_dvr1 = reg_select_valid & spr_write & (spr_addr_lo == 12'h021);
assign wr_dvr2 = reg_select_valid & spr_write & (spr_addr_lo == 12'h022);
assign wr_dvr3 = reg_select_valid & spr_write & (spr_addr_lo == 12'h023);
assign wr_dvr4 = reg_select_valid & spr_write & (spr_addr_lo == 12'h024);
assign wr_dvr5 = reg_select_valid & spr_write & (spr_addr_lo == 12'h025);
assign wr_dvr6 = reg_select_valid & spr_write & (spr_addr_lo == 12'h026);
assign wr_dvr7 = reg_select_valid & spr_write & (spr_addr_lo == 12'h027);
assign wr_dcr0 = reg_select_valid & spr_write & (spr_addr_lo == 12'h028);
assign wr_dcr1 = reg_select_valid & spr_write & (spr_addr_lo == 12'h029);
assign wr_dcr2 = reg_select_valid & spr_write & (spr_addr_lo == 12'h02A);
assign wr_dcr3 = reg_select_valid & spr_write & (spr_addr_lo == 12'h02B);
assign wr_dcr4 = reg_select_valid & spr_write & (spr_addr_lo == 12'h02C);
assign wr_dcr5 = reg_select_valid & spr_write & (spr_addr_lo == 12'h02D);
assign wr_dcr6 = reg_select_valid & spr_write & (spr_addr_lo == 12'h02E);
assign wr_dcr7 = reg_select_valid & spr_write & (spr_addr_lo == 12'h02F);
assign wr_dwcr0= reg_select_valid & spr_write & (spr_addr_lo == 12'h010);
assign wr_dwcr1= reg_select_valid & spr_write & (spr_addr_lo == 12'h011);

// Register updates (asynchronous reset, synchronous write)
always @(posedge clk or posedge rst) begin
    if (rst) begin
`ifdef OR1200_DU_DMR1
        dmr1 <= 32'b0;
`endif
`ifdef OR1200_DU_DMR2
        dmr2 <= 32'b0;
`endif
`ifdef OR1200_DU_DSR
        dsr <= 14'b0;
`endif
`ifdef OR1200_DU_DRR
        drr <= 14'b0;
`endif
`ifdef OR1200_DU_DVR0
        dvr0 <= 32'b0;
`endif
`ifdef OR1200_DU_DVR1
        dvr1 <= 32'b0;
`endif
`ifdef OR1200_DU_DVR2
        dvr2 <= 32'b0;
`endif
`ifdef OR1200_DU_DVR3
        dvr3 <= 32'b0;
`endif
`ifdef OR1200_DU_DVR4
        dvr4 <= 32'b0;
`endif
`ifdef OR1200_DU_DVR5
        dvr5 <= 32'b0;
`endif
`ifdef OR1200_DU_DVR6
        dvr6 <= 32'b0;
`endif
`ifdef OR1200_DU_DVR7
        dvr7 <= 32'b0;
`endif
`ifdef OR1200_DU_DCR0
        dcr0 <= 8'b0;
`endif
`ifdef OR1200_DU_DCR1
        dcr1 <= 8'b0;
`endif
`ifdef OR1200_DU_DCR2
        dcr2 <= 8'b0;
`endif
`ifdef OR1200_DU_DCR3
        dcr3 <= 8'b0;
`endif
`ifdef OR1200_DU_DCR4
        dcr4 <= 8'b0;
`endif
`ifdef OR1200_DU_DCR5
        dcr5 <= 8'b0;
`endif
`ifdef OR1200_DU_DCR6
        dcr6 <= 8'b0;
`endif
`ifdef OR1200_DU_DCR7
        dcr7 <= 8'b0;
`endif
`ifdef OR1200_DU_DWCR0
        dwcr0 <= 32'b0;
`endif
`ifdef OR1200_DU_DWCR1
        dwcr1 <= 32'b0;
`endif
    end else begin
`ifdef OR1200_DU_DMR1
        if (wr_dmr1) dmr1 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DMR2
        if (wr_dmr2) dmr2 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DSR
        if (wr_dsr) dsr <= spr_dat_i[13:0];
`endif
`ifdef OR1200_DU_DRR
        if (wr_drr) drr <= spr_dat_i[13:0];
        else drr <= drr | except_stop;
`endif
`ifdef OR1200_DU_DVR0
        if (wr_dvr0) dvr0 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DVR1
        if (wr_dvr1) dvr1 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DVR2
        if (wr_dvr2) dvr2 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DVR3
        if (wr_dvr3) dvr3 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DVR4
        if (wr_dvr4) dvr4 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DVR5
        if (wr_dvr5) dvr5 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DVR6
        if (wr_dvr6) dvr6 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DVR7
        if (wr_dvr7) dvr7 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DCR0
        if (wr_dcr0) dcr0 <= spr_dat_i[7:0];
`endif
`ifdef OR1200_DU_DCR1
        if (wr_dcr1) dcr1 <= spr_dat_i[7:0];
`endif
`ifdef OR1200_DU_DCR2
        if (wr_dcr2) dcr2 <= spr_dat_i[7:0];
`endif
`ifdef OR1200_DU_DCR3
        if (wr_dcr3) dcr3 <= spr_dat_i[7:0];
`endif
`ifdef OR1200_DU_DCR4
        if (wr_dcr4) dcr4 <= spr_dat_i[7:0];
`endif
`ifdef OR1200_DU_DCR5
        if (wr_dcr5) dcr5 <= spr_dat_i[7:0];
`endif
`ifdef OR1200_DU_DCR6
        if (wr_dcr6) dcr6 <= spr_dat_i[7:0];
`endif
`ifdef OR1200_DU_DCR7
        if (wr_dcr7) dcr7 <= spr_dat_i[7:0];
`endif
`ifdef OR1200_DU_DWCR0
        if (wr_dwcr0) dwcr0 <= spr_dat_i;
`endif
`ifdef OR1200_DU_DWCR1
        if (wr_dwcr1) dwcr1 <= spr_dat_i;
`endif
    end
end

// DRR accumulation (done in the always block above)

// SPR read path
`ifdef OR1200_DU_READREGS
    reg [31:0] spr_dat_o_reg;
    always @* begin
        spr_dat_o_reg = 32'b0;
        if (reg_select_valid) begin
            case (spr_addr_lo)
`ifdef OR1200_DU_DMR1
                12'h000: spr_dat_o_reg = dmr1;
`endif
`ifdef OR1200_DU_DMR2
                12'h001: spr_dat_o_reg = dmr2;
`endif
`ifdef OR1200_DU_DSR
                12'h005: spr_dat_o_reg = {18'b0, dsr};
`endif
`ifdef OR1200_DU_DRR
                12'h006: spr_dat_o_reg = {18'b0, drr};
`endif
`ifdef OR1200_DU_DVR0
                12'h020: spr_dat_o_reg = dvr0;
`endif
`ifdef OR1200_DU_DVR1
                12'h021: spr_dat_o_reg = dvr1;
`endif
`ifdef OR1200_DU_DVR2
                12'h022: spr_dat_o_reg = dvr2;
`endif
`ifdef OR1200_DU_DVR3
                12'h023: spr_dat_o_reg = dvr3;
`endif
`ifdef OR1200_DU_DVR4
                12'h024: spr_dat_o_reg = dvr4;
`endif
`ifdef OR1200_DU_DVR5
                12'h025: spr_dat_o_reg = dvr5;
`endif
`ifdef OR1200_DU_DVR6
                12'h026: spr_dat_o_reg = dvr6;
`endif
`ifdef OR1200_DU_DVR7
                12'h027: spr_dat_o_reg = dvr7;
`endif
`ifdef OR1200_DU_DCR0
                12'h028: spr_dat_o_reg = {24'b0, dcr0};
`endif
`ifdef OR1200_DU_DCR1
                12'h029: spr_dat_o_reg = {24'b0, dcr1};
`endif
`ifdef OR1200_DU_DCR2
                12'h02A: spr_dat_o_reg = {24'b0, dcr2};
`endif
`ifdef OR1200_DU_DCR3
                12'h02B: spr_dat_o_reg = {24'b0, dcr3};
`endif
`ifdef OR1200_DU_DCR4
                12'h02C: spr_dat_o_reg = {24'b0, dcr4};
`endif
`ifdef OR1200_DU_DCR5
                12'h02D: spr_dat_o_reg = {24'b0, dcr5};
`endif
`ifdef OR1200_DU_DCR6
                12'h02E: spr_dat_o_reg = {24'b0, dcr6};
`endif
`ifdef OR1200_DU_DCR7
                12'h02F: spr_dat_o_reg = {24'b0, dcr7};
`endif
`ifdef OR1200_DU_DWCR0
                12'h010: spr_dat_o_reg = dwcr0;
`endif
`ifdef OR1200_DU_DWCR1
                12'h011: spr_dat_o_reg = dwcr1;
`endif
`ifdef OR1200_DU_TB_IMPLEMENTED
                12'h100: spr_dat_o_reg = {24'b0, tb_addr};
                12'h101: spr_dat_o_reg = tb_data_ram[tb_addr];
`endif
                default: spr_dat_o_reg = 32'b0;
            endcase
        end
    end
    assign spr_dat_o = spr_dat_o_reg;
`else
    assign spr_dat_o = 32'b0;
`endif

// Watchpoint logic
`ifdef OR1200_DU_HWBKPTS
    wire [7:0] match_direct;
    wire [7:0] match_strobe;
    wire [10:0] wp;
    integer i;
    reg [31:0] dvr_mux [0:7];
    reg [7:0] dcr_mux [0:7];
    reg [31:0] compare_target;

    // Combine DVR and DCR into arrays for indexing
    always @* begin
        dvr_mux[0] = `ifdef OR1200_DU_DVR0 dvr0 `else 32'b0 `endif;
        dvr_mux[1] = `ifdef OR1200_DU_DVR1 dvr1 `else 32'b0 `endif;
        dvr_mux[2] = `ifdef OR1200_DU_DVR2 dvr2 `else 32'b0 `endif;
        dvr_mux[3] = `ifdef OR1200_DU_DVR3 dvr3 `else 32'b0 `endif;
        dvr_mux[4] = `ifdef OR1200_DU_DVR4 dvr4 `else 32'b0 `endif;
        dvr_mux[5] = `ifdef OR1200_DU_DVR5 dvr5 `else 32'b0 `endif;
        dvr_mux[6] = `ifdef OR1200_DU_DVR6 dvr6 `else 32'b0 `endif;
        dvr_mux[7] = `ifdef OR1200_DU_DVR7 dvr7 `else 32'b0 `endif;
        dcr_mux[0] = `ifdef OR1200_DU_DCR0 dcr0 `else 8'b0 `endif;
        dcr_mux[1] = `ifdef OR1200_DU_DCR1 dcr1 `else 8'b0 `endif;
        dcr_mux[2] = `ifdef OR1200_DU_DCR2 dcr2 `else 8'b0 `endif;
        dcr_mux[3] = `ifdef OR1200_DU_DCR3 dcr3 `else 8'b0 `endif;
        dcr_mux[4] = `ifdef OR1200_DU_DCR4 dcr4 `else 8'b0 `endif;
        dcr_mux[5] = `ifdef OR1200_DU_DCR5 dcr5 `else 8'b0 `endif;
        dcr_mux[6] = `ifdef OR1200_DU_DCR6 dcr6 `else 8'b0 `endif;
        dcr_mux[7] = `ifdef OR1200_DU_DCR7 dcr7 `else 8'b0 `endif;
    end

    // Compute matches
    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : wp_comp
            wire [7:0] dcr = dcr_mux[j];
            wire [31:0] dvr = dvr_mux[j];
            wire [2:0] target_sel = dcr[7:5];
            wire sign = dcr[4];
            wire [2:0] relation = dcr[2:0];
            wire is_inst_fetch = (target_sel == 3'b001);
            wire is_data_related = (target_sel >= 3'b010);
            wire strobe_enable;
            assign strobe_enable = (target_sel == 3'b000) ? 1'b0 :
                                   (is_inst_fetch) ? icpu_cycstb_i :
                                   dcpu_cycstb_i;

            wire [31:0] target_val;
            always @* begin
                case (target_sel)
                    3'b001: target_val = id_pc;
                    3'b010: target_val = (dcpu_we_i == 1'b0) ? dcpu_adr_i : 32'b0; // load address
                    3'b011: target_val = (dcpu_we_i == 1'b1) ? dcpu_adr_i : 32'b0; // store address
                    3'b100: target_val = (dcpu_we_i == 1'b0) ? dcpu_dat_lsu : 32'b0; // load data
                    3'b101: target_val = (dcpu_we_i == 1'b1) ? dcpu_dat_lsu : 32'b0; // store data
                    3'b110: target_val = dcpu_adr_i; // load/store address
                    3'b111: target_val = dcpu_dat_lsu; // load/store data
                    default: target_val = 32'b0;
                endcase
            end

            reg match;
            always @* begin
                if (!strobe_enable) begin
                    match = 1'b0;
                end else begin
                    if (sign) begin
                        // signed comparison
                        case (relation)
                            3'b000: match = ($signed(target_val) == $signed(dvr));
                            3'b001: match = ($signed(target_val) < $signed(dvr));
                            3'b010: match = ($signed(target_val) <= $signed(dvr));
                            3'b011: match = ($signed(target_val) > $signed(dvr));
                            3'b100: match = ($signed(target_val) >= $signed(dvr));
                            3'b101: match = ($signed(target_val) != $signed(dvr));
                            default: match = 1'b0;
                        endcase
                    end else begin
                        case (relation)
                            3'b000: match = (target_val == dvr);
                            3'b001: match = (target_val < dvr);
                            3'b010: match = (target_val <= dvr);
                            3'b011: match = (target_val > dvr);
                            3'b100: match = (target_val >= dvr);
                            3'b101: match = (target_val != dvr);
                            default: match = 1'b0;
                        endcase
                    end
                end
            end
            assign match_direct[j] = match;
        end
    endgenerate

    // Chaining logic
    reg [10:0] wp_r;
    always @* begin
`ifdef OR1200_DU_DMR1
        // Extract DMR1 fields for each watchpoint
        // We assume DMR1[1:0] for wp0, [3:2] for wp1, etc.
        // Also DMR1 bits for wp8,9,10? They are not chained, so just direct.
        // For wp0, only enable (2'b01) else disable
        if (dmr1[1:0] == 2'b01)
            wp_r[0] = match_direct[0];
        else
            wp_r[0] = 1'b0;
        // For wp1..7
        if (dmr1[3:2] == 2'b00)
            wp_r[1] = 1'b0;
        else if (dmr1[3:2] == 2'b01)
            wp_r[1] = match_direct[1];
        else if (dmr1[3:2] == 2'b10)
            wp_r[1] = match_direct[1] & wp_r[0];
        else // 2'b11
            wp_r[1] = match_direct[1] | wp_r[0];

        if (dmr1[5:4] == 2'b00)
            wp_r[2] = 1'b0;
        else if (dmr1[5:4] == 2'b01)
            wp_r[2] = match_direct[2];
        else if (dmr1[5:4] == 2'b10)
            wp_r[2] = match_direct[2] & wp_r[1];
        else
            wp_r[2] = match_direct[2] | wp_r[1];

        if (dmr1[7:6] == 2'b00)
            wp_r[3] = 1'b0;
        else if (dmr1[7:6] == 2'b01)
            wp_r[3] = match_direct[3];
        else if (dmr1[7:6] == 2'b10)
            wp_r[3] = match_direct[3] & wp_r[2];
        else
            wp_r[3] = match_direct[3] | wp_r[2];

        if (dmr1[9:8] == 2'b00)
            wp_r[4] = 1'b0;
        else if (dmr1[9:8] == 2'b01)
            wp_r[4] = match_direct[4];
        else if (dmr1[9:8] == 2'b10)
            wp_r[4] = match_direct[4] & wp_r[3];
        else
            wp_r[4] = match_direct[4] | wp_r[3];

        if (dmr1[11:10] == 2'b00)
            wp_r[5] = 1'b0;
        else if (dmr1[11:10] == 2'b01)
            wp_r[5] = match_direct[5];
        else if (dmr1[11:10] == 2'b10)
            wp_r[5] = match_direct[5] & wp_r[4];
        else
            wp_r[5] = match_direct[5] | wp_r[4];

        if (dmr1[13:12] == 2'b00)
            wp_r[6] = 1'b0;
        else if (dmr1[13:12] == 2'b01)
            wp_r[6] = match_direct[6];
        else if (dmr1[13:12] == 2'b10)
            wp_r[6] = match_direct[6] & wp_r[5];
        else
            wp_r[6] = match_direct[6] | wp_r[5];

        if (dmr1[15:14] == 2'b00)
            wp_r[7] = 1'b0;
        else if (dmr1[15:14] == 2'b01)
            wp_r[7] = match_direct[7];
        else if (dmr1[15:14] == 2'b10)
            wp_r[7] = match_direct[7] & wp_r[6];
        else
            wp_r[7] = match_direct[7] | wp_r[6];
`else
        // If DMR1 not implemented, wire directly
        wp_r[7:0] = match_direct[7:0];
`endif
    end

    // Watchpoint counters
    reg [15:0] cnt0, cnt1;
`ifdef OR1200_DU_DWCR0
    always @(posedge clk or posedge rst) begin
        if (rst)
            cnt0 <= 16'b0;
        else begin
`ifdef OR1200_DU_DMR2
            if (dmr2[0] && wp_r[0]) // increment when enabled and wp0 event
                cnt0 <= cnt0 + 1'b1;
`else
            if (wp_r[0]) cnt0 <= cnt0 + 1'b1;
`endif
        end
    end
    wire match_cnt0 = (cnt0 == dwcr0[31:16]);
`else
    wire match_cnt0 = 1'b0;
`endif

`ifdef OR1200_DU_DWCR1
    always @(posedge clk or posedge rst) begin
        if (rst)
            cnt1 <= 16'b0;
        else begin
`ifdef OR1200_DU_DMR2
            if (dmr2[1] && wp_r[1])
                cnt1 <= cnt1 + 1'b1;
`else
            if (wp_r[1]) cnt1 <= cnt1 + 1'b1;
`endif
        end
    end
    wire match_cnt1 = (cnt1 == dwcr1[31:16]);
`else
    wire match_cnt1 = 1'b0;
`endif

    // Combine watchpoint bits
    assign wp[10] = dbg_ewt_i;
    assign wp[9] = match_cnt1;
    assign wp[8] = match_cnt0;
    assign wp[7:0] = wp_r[7:0];

    // Hardware breakpoint output
`ifdef OR1200_DU_DMR2
    assign du_hwbkpt = |(wp & dmr2[10:0]);
`else
    assign du_hwbkpt = |wp;
`endif

`else
    // Watchpoints not implemented
    assign du_hwbkpt = 1'b0;
`endif

// Breakpoint output
reg dbg_bp_r;
always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_bp_r <= 1'b0;
    else begin
        if (ex_freeze) begin
            // Only exception stop when frozen
            dbg_bp_r <= (except_stop != 14'b0);
        end else begin
            // Exception, single-step, branch-trace
            wire ss_cond, bt_cond;
            // Determine if instruction is NOP (l.nop opcode 0x15)
            wire is_nop = (ex_insn[31:26] == 6'b010101);
`ifdef OR1200_DU_DMR1
            // single-step: non-NOP and DMR1 bit set
            ss_cond = ~is_nop & dmr1[16]; // placeholder bit
            // branch-trace: non-NOP branch and DMR1 bit set
            wire is_branch = (branch_op != 3'b000); // not NOP branch
            bt_cond = is_branch & dmr1[17]; // placeholder bit
`else
            ss_cond = 1'b0;
            bt_cond = 1'b0;
`endif
            dbg_bp_r <= (except_stop != 14'b0) | ss_cond | bt_cond;
        end
    end
end

assign dbg_bp_o = dbg_bp_r;

// Trace buffer
`ifdef OR1200_DU_TB_IMPLEMENTED
    reg [7:0] tb_addr;
    reg [31:0] tb_timstmp;
    reg [31:0] tb_npc_ram [0:255];
    reg [31:0] tb_insn_ram [0:255];
    reg [31:0] tb_data_ram [0:255];
    reg [31:0] tb_timstmp_ram [0:255];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tb_addr <= 8'b0;
            tb_timstmp <= 32'b0;
        end else begin
            if (!ex_freeze && (ex_insn[31:26] != 6'b010101)) begin
                tb_npc_ram[tb_addr] <= spr_dat_npc;
                tb_insn_ram[tb_addr] <= ex_insn;
                tb_data_ram[tb_addr] <= rf_dataw;
                tb_timstmp_ram[tb_addr] <= tb_timstmp;
                tb_addr <= tb_addr + 1'b1;
                tb_timstmp <= tb_timstmp + 1'b1;
            end
        end
    end
`endif

`else
// DU not implemented
assign du_dsr = 14'b0;
assign du_hwbkpt = 1'b0;
assign dbg_bp_o = 1'b0;
assign spr_dat_o = 32'b0;
`endif

endmodule

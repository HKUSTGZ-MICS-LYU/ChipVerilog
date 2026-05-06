module or1200_du (
    // Internal Interface
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
    // External Debug Interface
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

    // Direct external debug interface forwarding
    assign du_stall = dbg_stall_i;
    assign du_addr = dbg_adr_i;
    assign du_dat_o = dbg_dat_i;
    assign du_read = dbg_stb_i & ~dbg_we_i;
    assign du_write = dbg_stb_i & dbg_we_i;
    assign dbg_dat_o = du_dat_i;

    // Registered acknowledge
    reg dbg_ack_r;
    always @(posedge clk or posedge rst) begin
        if (rst) dbg_ack_r <= 1'b0;
        else dbg_ack_r <= dbg_stb_i;
    end
    assign dbg_ack_o = dbg_ack_r;

    // Status outputs
    `ifdef OR1200_DU_STATUS_UNIMPLEMENTED
        reg dbg_is_toggle;
        always @(posedge clk or posedge rst) begin
            if (rst) dbg_is_toggle <= 1'b0;
            else if (icpu_cycstb_i) dbg_is_toggle <= ~dbg_is_toggle;
        end
        assign dbg_lss_o = 4'b0;
        assign dbg_is_o = {1'b0, dbg_is_toggle};
    `else
        assign dbg_lss_o = {2'b0, dcpu_we_i, dcpu_cycstb_i};
        assign dbg_is_o = {1'b0, icpu_cycstb_i};
    `endif

    // wp_o fixed to zero
    assign dbg_wp_o = 11'b0;

    // Internal watchpoint vector (wp[10:0]) used for du_hwbkpt and internal generation
    reg [10:0] wp;

    // --- Debug Registers (only when OR1200_DU_IMPLEMENTED) ---
    `ifdef OR1200_DU_IMPLEMENTED
        // Register definitions based on macros
        // Address decoding for SPR
        localparam DMR1_ADDR = 11'h088;  // 0x1008
        localparam DMR2_ADDR = 11'h089;  // 0x1009
        localparam DSR_ADDR  = 11'h08A;  // 0x100A
        localparam DRR_ADDR  = 11'h08B;  // 0x100B
        localparam DVR0_ADDR = 11'h090;  // 0x1010
        localparam DVR1_ADDR = 11'h091;
        localparam DVR2_ADDR = 11'h092;
        localparam DVR3_ADDR = 11'h093;
        localparam DVR4_ADDR = 11'h094;
        localparam DVR5_ADDR = 11'h095;
        localparam DVR6_ADDR = 11'h096;
        localparam DVR7_ADDR = 11'h097;
        localparam DCR0_ADDR = 11'h098;  // 0x1018
        localparam DCR1_ADDR = 11'h099;
        localparam DCR2_ADDR = 11'h09A;
        localparam DCR3_ADDR = 11'h09B;
        localparam DCR4_ADDR = 11'h09C;
        localparam DCR5_ADDR = 11'h09D;
        localparam DCR6_ADDR = 11'h09E;
        localparam DCR7_ADDR = 11'h09F;
        localparam DWCR0_ADDR = 11'h0A0; // 0x1020
        localparam DWCR1_ADDR = 11'h0A1;
        // Trace buffer addresses (if implemented)
        localparam TB_INSNADDR = 11'h0A2; // example
        localparam TB_INSN_ADDR = 11'h0A3;
        localparam TB_RFDW_ADDR = 11'h0A4;
        localparam TB_TMSTMP_ADDR = 11'h0A5;

        // Register instances
        reg [31:0] dmr1_reg, dmr2_reg;
        reg [13:0] dsr_reg, drr_reg;
        // DVR and DCR arrays
        `ifdef OR1200_DU_DVR0 reg [31:0] dvr0_reg; `endif
        `ifdef OR1200_DU_DVR1 reg [31:0] dvr1_reg; `endif
        `ifdef OR1200_DU_DVR2 reg [31:0] dvr2_reg; `endif
        `ifdef OR1200_DU_DVR3 reg [31:0] dvr3_reg; `endif
        `ifdef OR1200_DU_DVR4 reg [31:0] dvr4_reg; `endif
        `ifdef OR1200_DU_DVR5 reg [31:0] dvr5_reg; `endif
        `ifdef OR1200_DU_DVR6 reg [31:0] dvr6_reg; `endif
        `ifdef OR1200_DU_DVR7 reg [31:0] dvr7_reg; `endif
        `ifdef OR1200_DU_DCR0 reg [7:0] dcr0_reg; `endif
        `ifdef OR1200_DU_DCR1 reg [7:0] dcr1_reg; `endif
        `ifdef OR1200_DU_DCR2 reg [7:0] dcr2_reg; `endif
        `ifdef OR1200_DU_DCR3 reg [7:0] dcr3_reg; `endif
        `ifdef OR1200_DU_DCR4 reg [7:0] dcr4_reg; `endif
        `ifdef OR1200_DU_DCR5 reg [7:0] dcr5_reg; `endif
        `ifdef OR1200_DU_DCR6 reg [7:0] dcr6_reg; `endif
        `ifdef OR1200_DU_DCR7 reg [7:0] dcr7_reg; `endif
        `ifdef OR1200_DU_DWCR0 reg [31:0] dwcr0_reg; `endif
        `ifdef OR1200_DU_DWCR1 reg [31:0] dwcr1_reg; `endif

        // Register selects
        wire dmr1_sel = spr_cs && (spr_addr[10:0] == DMR1_ADDR);
        wire dmr2_sel = spr_cs && (spr_addr[10:0] == DMR2_ADDR);
        wire dsr_sel  = spr_cs && (spr_addr[10:0] == DSR_ADDR);
        wire drr_sel  = spr_cs && (spr_addr[10:0] == DRR_ADDR);
        wire [7:0] dvr_sel, dcr_sel;
        wire dwcr0_sel, dwcr1_sel;
        genvar gi;
        generate
            for (gi = 0; gi < 8; gi = gi + 1) begin
                assign dvr_sel[gi] = spr_cs && (spr_addr[10:0] == (DVR0_ADDR + gi));
                assign dcr_sel[gi] = spr_cs && (spr_addr[10:0] == (DCR0_ADDR + gi));
            end
        endgenerate
        assign dwcr0_sel = spr_cs && (spr_addr[10:0] == DWCR0_ADDR);
        assign dwcr1_sel = spr_cs && (spr_addr[10:0] == DWCR1_ADDR);

        // Write logic
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                dmr1_reg <= 32'b0;
                dmr2_reg <= 32'b0;
                dsr_reg <= 14'b0;
                drr_reg <= 14'b0;
                `ifdef OR1200_DU_DVR0 dvr0_reg <= 32'b0; `endif
                `ifdef OR1200_DU_DVR1 dvr1_reg <= 32'b0; `endif
                `ifdef OR1200_DU_DVR2 dvr2_reg <= 32'b0; `endif
                `ifdef OR1200_DU_DVR3 dvr3_reg <= 32'b0; `endif
                `ifdef OR1200_DU_DVR4 dvr4_reg <= 32'b0; `endif
                `ifdef OR1200_DU_DVR5 dvr5_reg <= 32'b0; `endif
                `ifdef OR1200_DU_DVR6 dvr6_reg <= 32'b0; `endif
                `ifdef OR1200_DU_DVR7 dvr7_reg <= 32'b0; `endif
                `ifdef OR1200_DU_DCR0 dcr0_reg <= 8'b0; `endif
                `ifdef OR1200_DU_DCR1 dcr1_reg <= 8'b0; `endif
                `ifdef OR1200_DU_DCR2 dcr2_reg <= 8'b0; `endif
                `ifdef OR1200_DU_DCR3 dcr3_reg <= 8'b0; `endif
                `ifdef OR1200_DU_DCR4 dcr4_reg <= 8'b0; `endif
                `ifdef OR1200_DU_DCR5 dcr5_reg <= 8'b0; `endif
                `ifdef OR1200_DU_DCR6 dcr6_reg <= 8'b0; `endif
                `ifdef OR1200_DU_DCR7 dcr7_reg <= 8'b0; `endif
                `ifdef OR1200_DU_DWCR0 dwcr0_reg <= 32'b0; `endif
                `ifdef OR1200_DU_DWCR1 dwcr1_reg <= 32'b0; `endif
            end else begin
                if (dmr1_sel && spr_write) dmr1_reg <= spr_dat_i;
                if (dmr2_sel && spr_write) dmr2_reg <= spr_dat_i;
                if (dsr_sel && spr_write) dsr_reg <= spr_dat_i[13:0];
                if (drr_sel && spr_write) drr_reg <= spr_dat_i[13:0];
                else drr_reg <= drr_reg | except_stop; // accumulate exception stops
                `ifdef OR1200_DU_DVR0 if (dvr_sel[0] && spr_write) dvr0_reg <= spr_dat_i; `endif
                `ifdef OR1200_DU_DVR1 if (dvr_sel[1] && spr_write) dvr1_reg <= spr_dat_i; `endif
                `ifdef OR1200_DU_DVR2 if (dvr_sel[2] && spr_write) dvr2_reg <= spr_dat_i; `endif
                `ifdef OR1200_DU_DVR3 if (dvr_sel[3] && spr_write) dvr3_reg <= spr_dat_i; `endif
                `ifdef OR1200_DU_DVR4 if (dvr_sel[4] && spr_write) dvr4_reg <= spr_dat_i; `endif
                `ifdef OR1200_DU_DVR5 if (dvr_sel[5] && spr_write) dvr5_reg <= spr_dat_i; `endif
                `ifdef OR1200_DU_DVR6 if (dvr_sel[6] && spr_write) dvr6_reg <= spr_dat_i; `endif
                `ifdef OR1200_DU_DVR7 if (dvr_sel[7] && spr_write) dvr7_reg <= spr_dat_i; `endif
                `ifdef OR1200_DU_DCR0 if (dcr_sel[0] && spr_write) dcr0_reg <= spr_dat_i[7:0]; `endif
                `ifdef OR1200_DU_DCR1 if (dcr_sel[1] && spr_write) dcr1_reg <= spr_dat_i[7:0]; `endif
                `ifdef OR1200_DU_DCR2 if (dcr_sel[2] && spr_write) dcr2_reg <= spr_dat_i[7:0]; `endif
                `ifdef OR1200_DU_DCR3 if (dcr_sel[3] && spr_write) dcr3_reg <= spr_dat_i[7:0]; `endif
                `ifdef OR1200_DU_DCR4 if (dcr_sel[4] && spr_write) dcr4_reg <= spr_dat_i[7:0]; `endif
                `ifdef OR1200_DU_DCR5 if (dcr_sel[5] && spr_write) dcr5_reg <= spr_dat_i[7:0]; `endif
                `ifdef OR1200_DU_DCR6 if (dcr_sel[6] && spr_write) dcr6_reg <= spr_dat_i[7:0]; `endif
                `ifdef OR1200_DU_DCR7 if (dcr_sel[7] && spr_write) dcr7_reg <= spr_dat_i[7:0]; `endif
                `ifdef OR1200_DU_DWCR0 if (dwcr0_sel && spr_write) dwcr0_reg <= spr_dat_i; `endif
                `ifdef OR1200_DU_DWCR1 if (dwcr1_sel && spr_write) dwcr1_reg <= spr_dat_i; `endif
            end
        end

        // Exception stop decoding (14-bit)
        wire [13:0] except_stop;
        assign except_stop = {1'b0, du_except};

        // Debug Stop Register export
        assign du_dsr = dsr_reg;

        // DRR accumulation: done in the always block above

        // Breakpoint output logic
        reg dbg_bp_r;
        always @(posedge clk or posedge rst) begin
            if (rst) dbg_bp_r <= 1'b0;
            else begin
                if (ex_freeze) begin
                    // only exception stop
                    dbg_bp_r <= (|except_stop);
                end else begin
                    // exception stop always contributes
                    wire bt_cond, ss_cond;
                    `ifdef OR1200_DU_BT
                        bt_cond = dmr1_reg[?] && (branch_op != 3'b0) && (ex_insn != 32'h15000000); // non-NOP branch
                    `else
                        bt_cond = 1'b0;
                    `endif
                    `ifdef OR1200_DU_SS
                        ss_cond = dmr1_reg[?] && (ex_insn != 32'h15000000); // non-NOP
                    `else
                        ss_cond = 1'b0;
                    `endif
                    dbg_bp_r <= (|except_stop) || ss_cond || bt_cond;
                end
            end
        end
        assign dbg_bp_o = dbg_bp_r;

        // Hardware watchpoints
        `ifdef OR1200_DU_HWBKPTS
            // DCR layout: [7:5] compare type (0=none), [4:2] relation, [1] sign, [0] enable? but we use type=0 to disable
            wire [7:0] dcr0 = `ifdef OR1200_DU_DCR0 dcr0_reg `else 8'b0 `endif;
            wire [7:0] dcr1 = `ifdef OR1200_DU_DCR1 dcr1_reg `else 8'b0 `endif;
            wire [7:0] dcr2 = `ifdef OR1200_DU_DCR2 dcr2_reg `else 8'b0 `endif;
            wire [7:0] dcr3 = `ifdef OR1200_DU_DCR3 dcr3_reg `else 8'b0 `endif;
            wire [7:0] dcr4 = `ifdef OR1200_DU_DCR4 dcr4_reg `else 8'b0 `endif;
            wire [7:0] dcr5 = `ifdef OR1200_DU_DCR5 dcr5_reg `else 8'b0 `endif;
            wire [7:0] dcr6 = `ifdef OR1200_DU_DCR6 dcr6_reg `else 8'b0 `endif;
            wire [7:0] dcr7 = `ifdef OR1200_DU_DCR7 dcr7_reg `else 8'b0 `endif;
            wire [31:0] dvr0 = `ifdef OR1200_DU_DVR0 dvr0_reg `else 32'b0 `endif;
            wire [31:0] dvr1 = `ifdef OR1200_DU_DVR1 dvr1_reg `else 32'b0 `endif;
            wire [31:0] dvr2 = `ifdef OR1200_DU_DVR2 dvr2_reg `else 32'b0 `endif;
            wire [31:0] dvr3 = `ifdef OR1200_DU_DVR3 dvr3_reg `else 32'b0 `endif;
            wire [31:0] dvr4 = `ifdef OR1200_DU_DVR4 dvr4_reg `else 32'b0 `endif;
            wire [31:0] dvr5 = `ifdef OR1200_DU_DVR5 dvr5_reg `else 32'b0 `endif;
            wire [31:0] dvr6 = `ifdef OR1200_DU_DVR6 dvr6_reg `else 32'b0 `endif;
            wire [31:0] dvr7 = `ifdef OR1200_DU_DVR7 dvr7_reg `else 32'b0 `endif;

            // Function to perform comparison based on DCR relation and sign
            function match_condition;
                input [31:0] a, b;
                input [2:0] relation;
                input sign;
                reg signed [31:0] sa, sb;
                begin
                    if (sign) begin
                        sa = a; sb = b;
                        case (relation)
                            3'b000: match_condition = (sa == sb);
                            3'b001: match_condition = (sa < sb);
                            3'b010: match_condition = (sa <= sb);
                            3'b011: match_condition = (sa > sb);
                            3'b100: match_condition = (sa >= sb);
                            3'b101: match_condition = (sa != sb);
                            default: match_condition = 1'b0;
                        endcase
                    end else begin
                        case (relation)
                            3'b000: match_condition = (a == b);
                            3'b001: match_condition = (a < b);
                            3'b010: match_condition = (a <= b);
                            3'b011: match_condition = (a > b);
                            3'b100: match_condition = (a >= b);
                            3'b101: match_condition = (a != b);
                            default: match_condition = 1'b0;
                        endcase
                    end
                end
            endfunction

            // Compare target selection
            wire [31:0] cmp_val0, cmp_val1, cmp_val2, cmp_val3, cmp_val4, cmp_val5, cmp_val6, cmp_val7;
            wire cmp_en0, cmp_en1, cmp_en2, cmp_en3, cmp_en4, cmp_en5, cmp_en6, cmp_en7;
            // Compare type encoding:
            // 0: none, 1: id_pc, 2: load addr, 3: store addr, 4: load data, 5: store data, 6: load/store addr, 7: load/store data
            function [31:0] get_cmp_val;
                input [2:0] ctype;
                begin
                    case (ctype)
                        3'b001: get_cmp_val = id_pc;
                        3'b010: get_cmp_val = dcpu_adr_i;
                        3'b011: get_cmp_val = dcpu_adr_i; // store address same as load address
                        3'b100: get_cmp_val = dcpu_dat_lsu; // load data
                        3'b101: get_cmp_val = dcpu_dat_lsu; // store data (but we check we_i)
                        3'b110: get_cmp_val = dcpu_adr_i; // load/store addr
                        3'b111: get_cmp_val = dcpu_dat_lsu; // load/store data
                        default: get_cmp_val = 32'b0;
                    endcase
                end
            endfunction

            function cmp_strobe;
                input [2:0] ctype;
                begin
                    case (ctype)
                        3'b000: cmp_strobe = 1'b0;
                        3'b001: cmp_strobe = icpu_cycstb_i; // instruction fetch address
                        default: cmp_strobe = dcpu_cycstb_i; // data related
                    endcase
                end
            endfunction

            // For store data, we require dcpu_we_i high
            wire [7:0] match_raw;
            genvar g;
            generate
                for (g = 0; g < 8; g = g + 1) begin : hwbp
                    wire [2:0] ctype = (g == 0) ? dcr0[7:5] : (g == 1) ? dcr1[7:5] : (g == 2) ? dcr2[7:5] : (g == 3) ? dcr3[7:5] : (g == 4) ? dcr4[7:5] : (g == 5) ? dcr5[7:5] : (g == 6) ? dcr6[7:5] : dcr7[7:5];
                    wire [2:0] relation = (g == 0) ? dcr0[4:2] : (g == 1) ? dcr1[4:2] : (g == 2) ? dcr2[4:2] : (g == 3) ? dcr3[4:2] : (g == 4) ? dcr4[4:2] : (g == 5) ? dcr5[4:2] : (g == 6) ? dcr6[4:2] : dcr7[4:2];
                    wire sign = (g == 0) ? dcr0[1] : (g == 1) ? dcr1[1] : (g == 2) ? dcr2[1] : (g == 3) ? dcr3[1] : (g == 4) ? dcr4[1] : (g == 5) ? dcr5[1] : (g == 6) ? dcr6[1] : dcr7[1];
                    wire strobe = cmp_strobe(ctype);
                    // For store data types, need to check dcpu_we_i
                    wire store_type = (ctype == 3'b011) || (ctype == 3'b101) || (ctype == 3'b111);
                    wire effective_strobe = strobe && (store_type ? dcpu_we_i : 1'b1);
                    wire [31:0] cmp_val = get_cmp_val(ctype);
                    wire [31:0] dvr_val = (g == 0) ? dvr0 : (g == 1) ? dvr1 : (g == 2) ? dvr2 : (g == 3) ? dvr3 : (g == 4) ? dvr4 : (g == 5) ? dvr5 : (g == 6) ? dvr6 : dvr7;
                    assign match_raw[g] = effective_strobe && match_condition(cmp_val, dvr_val, relation, sign);
                end
            endgenerate

            // DMR1 chaining control for watchpoints 0-7
            // DMR1 bits: [1:0] wp0 enable (1 bit? we'll use bit0), [3:2] wp1 mode, [5:4] wp2, [7:6] wp3, [9:8] wp4, [11:10] wp5, [13:12] wp6, [15:14] wp7
            wire [1:0] wp0_mode = {1'b0, dmr1_reg[0]}; // actually only one bit: 1=direct, 0=disable
            wire [1:0] wp1_mode = dmr1_reg[3:2];
            wire [1:0] wp2_mode = dmr1_reg[5:4];
            wire [1:0] wp3_mode = dmr1_reg[7:6];
            wire [1:0] wp4_mode = dmr1_reg[9:8];
            wire [1:0] wp5_mode = dmr1_reg[11:10];
            wire [1:0] wp6_mode = dmr1_reg[13:12];
            wire [1:0] wp7_mode = dmr1_reg[15:14];

            wire [7:0] match_chain;
            assign match_chain[0] = wp0_mode[0] ? match_raw[0] : 1'b0;
            assign match_chain[1] = (wp1_mode == 2'b01) ? match_raw[1] :
                                    (wp1_mode == 2'b10) ? (match_raw[1] & match_chain[0]) :
                                    (wp1_mode == 2'b11) ? (match_raw[1] | match_chain[0]) : 1'b0;
            assign match_chain[2] = (wp2_mode == 2'b01) ? match_raw[2] :
                                    (wp2_mode == 2'b10) ? (match_raw[2] & match_chain[1]) :
                                    (wp2_mode == 2'b11) ? (match_raw[2] | match_chain[1]) : 1'b0;
            assign match_chain[3] = (wp3_mode == 2'b01) ? match_raw[3] :
                                    (wp3_mode == 2'b10) ? (match_raw[3] & match_chain[2]) :
                                    (wp3_mode == 2'b11) ? (match_raw[3] | match_chain[2]) : 1'b0;
            assign match_chain[4] = (wp4_mode == 2'b01) ? match_raw[4] :
                                    (wp4_mode == 2'b10) ? (match_raw[4] & match_chain[3]) :
                                    (wp4_mode == 2'b11) ? (match_raw[4] | match_chain[3]) : 1'b0;
            assign match_chain[5] = (wp5_mode == 2'b01) ? match_raw[5] :
                                    (wp5_mode == 2'b10) ? (match_raw[5] & match_chain[4]) :
                                    (wp5_mode == 2'b11) ? (match_raw[5] | match_chain[4]) : 1'b0;
            assign match_chain[6] = (wp6_mode == 2'b01) ? match_raw[6] :
                                    (wp6_mode == 2'b10) ? (match_raw[6] & match_chain[5]) :
                                    (wp6_mode == 2'b11) ? (match_raw[6] | match_chain[5]) : 1'b0;
            assign match_chain[7] = (wp7_mode == 2'b01) ? match_raw[7] :
                                    (wp7_mode == 2'b10) ? (match_raw[7] & match_chain[6]) :
                                    (wp7_mode == 2'b11) ? (match_raw[7] | match_chain[6]) : 1'b0;

            // Assign to wp[7:0]
            assign wp[7:0] = match_chain[7:0];

            // Watchpoint counters (DWCR0 and DWCR1)
            `ifdef OR1200_DU_DWCR0
                reg [31:0] dwcr0_count;
                wire dwcr0_match = (dwcr0_reg[31:16] == dwcr0_count[15:0]);
                always @(posedge clk or posedge rst) begin
                    if (rst) dwcr0_count <= 16'b0;
                    else if (dmr2_reg[8] && wp[0]) dwcr0_count <= dwcr0_count + 1'b1; // select wp[0] for example
                end
                assign wp[8] = dwcr0_match;
            `else
                assign wp[8] = 1'b0;
            `endif
            `ifdef OR1200_DU_DWCR1
                reg [31:0] dwcr1_count;
                wire dwcr1_match = (dwcr1_reg[31:16] == dwcr1_count[15:0]);
                always @(posedge clk or posedge rst) begin
                    if (rst) dwcr1_count <= 16'b0;
                    else if (dmr2_reg[9] && wp[1]) dwcr1_count <= dwcr1_count + 1'b1;
                end
                assign wp[9] = dwcr1_match;
            `else
                assign wp[9] = 1'b0;
            `endif
            // external watchpoint trigger
            assign wp[10] = dbg_ewt_i;

            // Hardware breakpoint request
            assign du_hwbkpt = |(wp & dmr2_reg[10:0]);
        `else
            assign wp = 11'b0;
            assign du_hwbkpt = 1'b0;
        `endif

        // SPR read data
        `ifdef OR1200_DU_READREGS
            reg [31:0] spr_dat_o_reg;
            always @(*) begin
                if (!spr_cs) spr_dat_o_reg = 32'b0;
                else begin
                    case (spr_addr[10:0])
                        DMR1_ADDR: spr_dat_o_reg = dmr1_reg;
                        DMR2_ADDR: spr_dat_o_reg = dmr2_reg;
                        DSR_ADDR:  spr_dat_o_reg = {18'b0, dsr_reg};
                        DRR_ADDR:  spr_dat_o_reg = {18'b0, drr_reg};
                        `ifdef OR1200_DU_DVR0 DVR0_ADDR: spr_dat_o_reg = dvr0_reg; `endif
                        `ifdef OR1200_DU_DVR1 DVR1_ADDR: spr_dat_o_reg = dvr1_reg; `endif
                        `ifdef OR1200_DU_DVR2 DVR2_ADDR: spr_dat_o_reg = dvr2_reg; `endif
                        `ifdef OR1200_DU_DVR3 DVR3_ADDR: spr_dat_o_reg = dvr3_reg; `endif
                        `ifdef OR1200_DU_DVR4 DVR4_ADDR: spr_dat_o_reg = dvr4_reg; `endif
                        `ifdef OR1200_DU_DVR5 DVR5_ADDR: spr_dat_o_reg = dvr5_reg; `endif
                        `ifdef OR1200_DU_DVR6 DVR6_ADDR: spr_dat_o_reg = dvr6_reg; `endif
                        `ifdef OR1200_DU_DVR7 DVR7_ADDR: spr_dat_o_reg = dvr7_reg; `endif
                        `ifdef OR1200_DU_DCR0 DCR0_ADDR: spr_dat_o_reg = {24'b0, dcr0_reg}; `endif
                        `ifdef OR1200_DU_DCR1 DCR1_ADDR: spr_dat_o_reg = {24'b0, dcr1_reg}; `endif
                        `ifdef OR1200_DU_DCR2 DCR2_ADDR: spr_dat_o_reg = {24'b0, dcr2_reg}; `endif
                        `ifdef OR1200_DU_DCR3 DCR3_ADDR: spr_dat_o_reg = {24'b0, dcr3_reg}; `endif
                        `ifdef OR1200_DU_DCR4 DCR4_ADDR: spr_dat_o_reg = {24'b0, dcr4_reg}; `endif
                        `ifdef OR1200_DU_DCR5 DCR5_ADDR: spr_dat_o_reg = {24'b0, dcr5_reg}; `endif
                        `ifdef OR1200_DU_DCR6 DCR6_ADDR: spr_dat_o_reg = {24'b0, dcr6_reg}; `endif
                        `ifdef OR1200_DU_DCR7 DCR7_ADDR: spr_dat_o_reg = {24'b0, dcr7_reg}; `endif
                        `ifdef OR1200_DU_DWCR0 DWCR0_ADDR: spr_dat_o_reg = dwcr0_reg; `endif
                        `ifdef OR1200_DU_DWCR1 DWCR1_ADDR: spr_dat_o_reg = dwcr1_reg; `endif
                        `ifdef OR1200_DU_TB_IMPLEMENTED
                            TB_INSNADDR, TB_INSN_ADDR, TB_RFDW_ADDR, TB_TMSTMP_ADDR: spr_dat_o_reg = tb_read_data(spr_addr[10:0]); // assume function
                        `endif
                        default: spr_dat_o_reg = 32'b0;
                    endcase
                end
            end
            assign spr_dat_o = spr_dat_o_reg;
        `else
            assign spr_dat_o = 32'b0;
        `endif

        // Optional trace buffer
        `ifdef OR1200_DU_TB_IMPLEMENTED
            // Trace buffer implementation (simplified)
            reg [7:0] tb_waddr;
            reg [31:0] tb_npc [0:255];
            reg [31:0] tb_insn [0:255];
            reg [31:0] tb_data [0:255];
            reg [31:0] tb_timestamp [0:255];
            reg [31:0] tb_timstmp_cnt;
            wire tb_write = !ex_freeze && (ex_insn != 32'h15000000); // not NOP
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    tb_waddr <= 8'b0;
                    tb_timstmp_cnt <= 32'b0;
                end else begin
                    if (tb_write) begin
                        tb_npc[tb_waddr] <= spr_dat_npc;
                        tb_insn[tb_waddr] <= ex_insn;
                        tb_data[tb_waddr] <= rf_dataw;
                        tb_timestamp[tb_waddr] <= tb_timstmp_cnt;
                        tb_timstmp_cnt <= tb_timstmp_cnt + 1'b1;
                        tb_waddr <= tb_waddr + 1'b1;
                    end
                end
            end
            // SPR read function for trace buffer
            function [31:0] tb_read_data;
                input [10:0] addr;
                reg [7:0] tb_index;
                begin
                    tb_index = spr_addr[7:0];
                    case (addr)
                        TB_INSNADDR: tb_read_data = tb_npc[tb_index];
                        TB_INSN_ADDR: tb_read_data = tb_insn[tb_index];
                        TB_RFDW_ADDR: tb_read_data = tb_data[tb_index];
                        TB_TMSTMP_ADDR: tb_read_data = tb_timestamp[tb_index];
                        default: tb_read_data = 32'b0;
                    endcase
                end
            endfunction
        `endif

    `else // !OR1200_DU_IMPLEMENTED
        // Minimal implementation
        assign dbg_bp_o = 1'b0;
        assign du_dsr = 14'b0;
        assign du_hwbkpt = 1'b0;
        assign spr_dat_o = 32'b0;
        assign wp = 11'b0;
    `endif

endmodule

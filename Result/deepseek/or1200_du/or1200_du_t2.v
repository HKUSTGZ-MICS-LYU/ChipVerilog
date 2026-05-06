// File: or1200_du.v
// Generated from specification - OR1200 Debug Unit

`timescale 1ns / 1ps

module or1200_du(
    // RISC Internal Interface
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

    // ------------------------------------------------------------
    // Compile-time configuration macros (parameterized for synthesis)
    // ------------------------------------------------------------
    // These are typically `defines. We use parameters for simulation/synthesis top-level.
    // In a real design, these would be `defines set by the build system.
    // For this implementation, we assume they are defined as 1 when enabled, else 0.
    // Default values: enable everything for full debug unit.
    parameter OR1200_DU_IMPLEMENTED = 1;
    parameter OR1200_DU_STATUS_UNIMPLEMENTED = 0;
    parameter OR1200_DU_READREGS = 1;
    parameter OR1200_DU_HWBKPTS = 1;
    parameter OR1200_DU_TB_IMPLEMENTED = 1;

    // Register macros for DVR, DCR, DWCR. Assume all 8 pairs implemented.
    parameter OR1200_DU_DVR0_IMPLEMENTED = 1;
    parameter OR1200_DU_DVR1_IMPLEMENTED = 1;
    parameter OR1200_DU_DVR2_IMPLEMENTED = 1;
    parameter OR1200_DU_DVR3_IMPLEMENTED = 1;
    parameter OR1200_DU_DVR4_IMPLEMENTED = 1;
    parameter OR1200_DU_DVR5_IMPLEMENTED = 1;
    parameter OR1200_DU_DVR6_IMPLEMENTED = 1;
    parameter OR1200_DU_DVR7_IMPLEMENTED = 1;
    parameter OR1200_DU_DCR0_IMPLEMENTED = 1;
    parameter OR1200_DU_DCR1_IMPLEMENTED = 1;
    parameter OR1200_DU_DCR2_IMPLEMENTED = 1;
    parameter OR1200_DU_DCR3_IMPLEMENTED = 1;
    parameter OR1200_DU_DCR4_IMPLEMENTED = 1;
    parameter OR1200_DU_DCR5_IMPLEMENTED = 1;
    parameter OR1200_DU_DCR6_IMPLEMENTED = 1;
    parameter OR1200_DU_DCR7_IMPLEMENTED = 1;
    parameter OR1200_DU_DWCR0_IMPLEMENTED = 1;
    parameter OR1200_DU_DWCR1_IMPLEMENTED = 1;

    // ------------------------------------------------------------
    // Signal declarations
    // ------------------------------------------------------------
    wire du_implemented = (OR1200_DU_IMPLEMENTED != 0);
    wire hwbkpts_enabled = (OR1200_DU_HWBKPTS != 0) && du_implemented;
    wire tb_enabled = (OR1200_DU_TB_IMPLEMENTED != 0) && du_implemented;
    wire readregs_enabled = (OR1200_DU_READREGS != 0) && du_implemented;
    wire status_unimpl = (OR1200_DU_STATUS_UNIMPLEMENTED != 0);

    // Debug access bridge signals
    wire [31:0] du_addr_int;
    wire [31:0] du_dat_o_int;
    wire du_read_int;
    wire du_write_int;
    reg dbg_ack_r;

    // SPR decode
    wire spr_sel_dmr1;
    wire spr_sel_dmr2;
    wire spr_sel_dsr;
    wire spr_sel_drr;
    wire [7:0] spr_sel_dvr;
    wire [7:0] spr_sel_dcr;
    wire spr_sel_dwcr0;
    wire spr_sel_dwcr1;
    wire spr_sel_tb_addr;
    wire spr_sel_tb_data;

    // Debug registers
    reg [31:0] dmr1;
    reg [31:0] dmr2;
    reg [13:0] dsr;
    reg [13:0] drr;
    reg [31:0] dvr [0:7];
    reg [7:0] dcr [0:7];
    reg [31:0] dwcr0;
    reg [31:0] dwcr1;

    // Exception stop decoding
    wire [13:0] except_stop;

    // Breakpoint
    reg dbg_bp_r;
    wire single_step_en;
    wire branch_trace_en;
    wire step_cond;
    wire branch_cond;

    // Watchpoint signals
    wire [7:0] match;
    wire [10:0] wp_internal;
    wire [10:0] wp_enables;
    wire du_hwbkpt_int;

    // Trace buffer
    reg [7:0] tb_waddr;
    reg [31:0] tb_timstmp;
    wire tb_write_en;
    wire [7:0] tb_raddr;
    wire [31:0] tb_addr_data, tb_insn_data, tb_rf_data, tb_time_data;
    reg [31:0] tb_addr_mem [0:255];
    reg [31:0] tb_insn_mem [0:255];
    reg [31:0] tb_rf_mem [0:255];
    reg [31:0] tb_time_mem [0:255];

    // ------------------------------------------------------------
    // Basic debug interface bridge (always active)
    // ------------------------------------------------------------
    assign du_addr = dbg_adr_i;
    assign du_dat_o = dbg_dat_i;
    assign du_read = dbg_stb_i && !dbg_we_i;
    assign du_write = dbg_stb_i && dbg_we_i;
    assign dbg_dat_o = du_dat_i;

    always @(posedge clk or posedge rst) begin
        if (rst)
            dbg_ack_r <= 1'b0;
        else
            dbg_ack_r <= dbg_stb_i;
    end
    assign dbg_ack_o = dbg_ack_r;

    assign du_stall = dbg_stall_i;

    // ------------------------------------------------------------
    // Status outputs
    // ------------------------------------------------------------
    generate if (!status_unimpl) begin : gen_status_impl
        assign dbg_lss_o = {dcpu_we_i, dcpu_cycstb_i, dcpu_cycstb_i, dcpu_cycstb_i}; // approximate
        assign dbg_is_o = {icpu_cycstb_i, icpu_cycstb_i};
    end else begin : gen_status_unimpl
        reg dbg_is_toggle;
        always @(posedge clk or posedge rst) begin
            if (rst)
                dbg_is_toggle <= 1'b0;
            else
                dbg_is_toggle <= ~dbg_is_toggle;
        end
        assign dbg_lss_o = 4'b0;
        assign dbg_is_o = {dbg_is_toggle, dbg_is_toggle};
    end endgenerate

    assign dbg_wp_o = 11'b0;

    // ------------------------------------------------------------
    // Implemented debug unit logic
    // ------------------------------------------------------------
    generate if (du_implemented) begin : gen_du_impl

        // SPR address decode (using spr_addr[10:0])
        wire [10:0] addr = spr_addr[10:0];
        assign spr_sel_dmr1  = spr_cs && (addr == 11'h??); // DMR1 at base+0x??
        assign spr_sel_dmr2  = spr_cs && (addr == 11'h??); // DMR2
        assign spr_sel_dsr   = spr_cs && (addr == 11'h??); // DSR
        assign spr_sel_drr   = spr_cs && (addr == 11'h??); // DRR

        // DVR select (example addresses)
        assign spr_sel_dvr[0] = spr_cs && (addr == 11'h??);
        assign spr_sel_dvr[1] = spr_cs && (addr == 11'h??);
        assign spr_sel_dvr[2] = spr_cs && (addr == 11'h??);
        assign spr_sel_dvr[3] = spr_cs && (addr == 11'h??);
        assign spr_sel_dvr[4] = spr_cs && (addr == 11'h??);
        assign spr_sel_dvr[5] = spr_cs && (addr == 11'h??);
        assign spr_sel_dvr[6] = spr_cs && (addr == 11'h??);
        assign spr_sel_dvr[7] = spr_cs && (addr == 11'h??);

        // DCR select
        assign spr_sel_dcr[0] = spr_cs && (addr == 11'h??);
        assign spr_sel_dcr[1] = spr_cs && (addr == 11'h??);
        assign spr_sel_dcr[2] = spr_cs && (addr == 11'h??);
        assign spr_sel_dcr[3] = spr_cs && (addr == 11'h??);
        assign spr_sel_dcr[4] = spr_cs && (addr == 11'h??);
        assign spr_sel_dcr[5] = spr_cs && (addr == 11'h??);
        assign spr_sel_dcr[6] = spr_cs && (addr == 11'h??);
        assign spr_sel_dcr[7] = spr_cs && (addr == 11'h??);

        assign spr_sel_dwcr0 = spr_cs && (addr == 11'h??);
        assign spr_sel_dwcr1 = spr_cs && (addr == 11'h??);
        assign spr_sel_tb_addr = spr_cs && (addr == 11'h??);
        assign spr_sel_tb_data = spr_cs && (addr == 11'h??);

        // Debug register writes
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                dmr1 <= 32'b0;
                dmr2 <= 32'b0;
                dsr <= 14'b0;
                drr <= 14'b0;
            end else begin
                if (spr_write) begin
                    if (spr_sel_dmr1) dmr1 <= spr_dat_i;
                    if (spr_sel_dmr2) dmr2 <= spr_dat_i;
                    if (spr_sel_dsr)  dsr  <= spr_dat_i[13:0];
                    if (spr_sel_drr)  drr  <= spr_dat_i[13:0];
                end else begin
                    // DRR accumulation from except_stop
                    drr <= drr | except_stop;
                end
            end
        end

        // DVR/DCR registers
        genvar i;
        generate for (i=0; i<8; i=i+1) begin : gen_dvr_dcr
            if (OR1200_DU_DVR0_IMPLEMENTED + i > 0) begin : gen_dvr
                always @(posedge clk or posedge rst)
                    if (rst) dvr[i] <= 32'b0;
                    else if (spr_write && spr_sel_dvr[i]) dvr[i] <= spr_dat_i;
            end else begin : gen_dvr_zero
                wire [31:0] dvr[i] = 32'b0;
            end
            if (OR1200_DU_DCR0_IMPLEMENTED + i > 0) begin : gen_dcr
                always @(posedge clk or posedge rst)
                    if (rst) dcr[i] <= 8'b0;
                    else if (spr_write && spr_sel_dcr[i]) dcr[i] <= spr_dat_i[7:0];
            end else begin : gen_dcr_zero
                wire [7:0] dcr[i] = 8'b0;
            end
        end endgenerate

        // DWCR registers
        if (OR1200_DU_DWCR0_IMPLEMENTED) always @(posedge clk or posedge rst)
            if (rst) dwcr0 <= 32'b0;
            else if (spr_write && spr_sel_dwcr0) dwcr0 <= spr_dat_i;
        else assign dwcr0 = 32'b0;

        if (OR1200_DU_DWCR1_IMPLEMENTED) always @(posedge clk or posedge rst)
            if (rst) dwcr1 <= 32'b0;
            else if (spr_write && spr_sel_dwcr1) dwcr1 <= spr_dat_i;
        else assign dwcr1 = 32'b0;

        assign du_dsr = dsr;

        // Exception stop decode
        assign except_stop = {1'b0, du_except}; // simplified mapping

        // Breakpoint logic
        assign single_step_en = dmr1[?];
        assign branch_trace_en = dmr1[?];
        wire ex_not_frozen = !ex_freeze;
        wire is_nop = (ex_insn == 32'b0); // placeholder
        assign step_cond = ex_not_frozen && !is_nop && single_step_en;
        assign branch_cond = ex_not_frozen && !is_nop && (branch_op != 3'b0) && branch_trace_en;

        always @(posedge clk or posedge rst) begin
            if (rst)
                dbg_bp_r <= 1'b0;
            else if (!ex_freeze)
                dbg_bp_r <= (|except_stop) | step_cond | branch_cond;
            else
                dbg_bp_r <= (|except_stop);
        end
        assign dbg_bp_o = dbg_bp_r;

        // Hardware watchpoints
        if (hwbkpts_enabled) begin : gen_hwbkpts
            wire [31:0] cmp_targets [0:7];
            wire [7:0] cmp_strobe;
            integer j;
            always @* begin
                for (j=0; j<8; j=j+1) begin
                    case (dcr[j][7:5])
                        3'b001: cmp_targets[j] = id_pc;
                        3'b010: cmp_targets[j] = dcpu_adr_i; // load addr
                        3'b011: cmp_targets[j] = dcpu_adr_i; // store addr
                        3'b100: cmp_targets[j] = dcpu_dat_lsu; // load data
                        3'b101: cmp_targets[j] = dcpu_dat_dc; // store data
                        3'b110: cmp_targets[j] = dcpu_we_i ? dcpu_adr_i : dcpu_adr_i; // load/store addr
                        3'b111: cmp_targets[j] = dcpu_we_i ? dcpu_dat_dc : dcpu_dat_lsu; // load/store data
                        default: cmp_targets[j] = 32'b0;
                    endcase
                    cmp_strobe[j] = (dcr[j][7:5] == 3'b0) ? 1'b0 :
                                    (dcr[j][7:5] == 3'b001) ? 1'b1 :
                                    dcpu_cycstb_i;
                end
            end

            wire [7:0] match_int;
            for (j=0; j<8; j=j+1) begin : gen_match
                wire [31:0] target = cmp_targets[j];
                wire [31:0] val = dvr[j];
                wire sign = dcr[j][4];
                wire [2:0] cmp_type = dcr[j][2:0];
                wire match_eq, match_lt, match_gt;
                // Simple comparison (unsigned unless sign handled)
                assign match_eq = (target == val);
                assign match_lt = (target < val);
                assign match_gt = (target > val);
                assign match_int[j] = cmp_strobe[j] && (
                    (cmp_type == 3'b001) ? match_eq :
                    (cmp_type == 3'b010) ? match_lt :
                    (cmp_type == 3'b011) ? (match_lt | match_eq) :
                    (cmp_type == 3'b100) ? match_gt :
                    (cmp_type == 3'b101) ? (match_gt | match_eq) :
                    (cmp_type == 3'b110) ? !match_eq : 1'b0
                );
            end

            // wp chain logic
            wire [10:0] wp_chain;
            assign wp_chain[0] = dmr1[0] ? match_int[0] : 1'b0;
            genvar k;
            generate for (k=1; k<8; k=k+1) begin : gen_wp_chain
                wire [1:0] ctrl = dmr1[2*k+1:2*k];
                assign wp_chain[k] = (ctrl == 2'b00) ? 1'b0 :
                                     (ctrl == 2'b01) ? match_int[k] :
                                     (ctrl == 2'b10) ? (match_int[k] & wp_chain[k-1]) :
                                     (ctrl == 2'b11) ? (match_int[k] | wp_chain[k-1]) : 1'b0;
            end endgenerate

            // DWCR counters
            wire dwcr0_match, dwcr1_match;
            reg [15:0] dwcr0_cnt, dwcr1_cnt;
            always @(posedge clk or posedge rst)
                if (rst) dwcr0_cnt <= 16'b0;
                else if (dmr2[?] && wp_chain[?]) dwcr0_cnt <= dwcr0_cnt + 1;
            always @(posedge clk or posedge rst)
                if (rst) dwcr1_cnt <= 16'b0;
                else if (dmr2[?] && wp_chain[?]) dwcr1_cnt <= dwcr1_cnt + 1;
            assign dwcr0_match = (dwcr0[31:16] == dwcr0_cnt);
            assign dwcr1_match = (dwcr1[31:16] == dwcr1_cnt);

            assign wp_internal = {dbg_ewt_i, dwcr1_match, dwcr0_match, wp_chain[7:0]};
            assign wp_enables = dmr2[10:0];
            assign du_hwbkpt_int = |(wp_internal & wp_enables);
        end else begin : gen_no_hwbkpts
            assign du_hwbkpt_int = 1'b0;
            assign wp_internal = 11'b0;
        end

        assign du_hwbkpt = du_hwbkpt_int;

        // Trace buffer
        if (tb_enabled) begin : gen_tb
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    tb_waddr <= 8'b0;
                    tb_timstmp <= 32'b0;
                end else if (!ex_freeze && !(ex_insn == 32'b0)) begin
                    tb_addr_mem[tb_waddr] <= spr_dat_npc;
                    tb_insn_mem[tb_waddr] <= ex_insn;
                    tb_rf_mem[tb_waddr] <= rf_dataw;
                    tb_time_mem[tb_waddr] <= tb_timstmp;
                    tb_waddr <= tb_waddr + 1;
                    tb_timstmp <= tb_timstmp + 1;
                end
            end
            assign tb_raddr = spr_addr[7:0]; // for read
            assign tb_addr_data = tb_addr_mem[tb_raddr];
            assign tb_insn_data = tb_insn_mem[tb_raddr];
            assign tb_rf_data = tb_rf_mem[tb_raddr];
            assign tb_time_data = tb_time_mem[tb_raddr];
        end else begin : gen_no_tb
            assign tb_addr_data = 32'b0;
            assign tb_insn_data = 32'b0;
            assign tb_rf_data = 32'b0;
            assign tb_time_data = 32'b0;
        end

        // SPR read path
        if (readregs_enabled) begin : gen_readregs
            reg [31:0] spr_dat_o_reg;
            always @* begin
                spr_dat_o_reg = 32'b0;
                if (spr_cs) begin
                    if (spr_sel_dmr1) spr_dat_o_reg = {18'b0, dmr1[13:0]};
                    else if (spr_sel_dmr2) spr_dat_o_reg = {18'b0, dmr2[13:0]};
                    else if (spr_sel_dsr) spr_dat_o_reg = {18'b0, dsr};
                    else if (spr_sel_drr) spr_dat_o_reg = {18'b0, drr};
                    else if (spr_sel_dwcr0) spr_dat_o_reg = dwcr0;
                    else if (spr_sel_dwcr1) spr_dat_o_reg = dwcr1;
                    else if (spr_sel_tb_addr) spr_dat_o_reg = tb_addr_data;
                    else if (spr_sel_tb_data) spr_dat_o_reg = tb_time_data;
                    else begin
                        integer n;
                        for (n=0; n<8; n=n+1) begin
                            if (spr_sel_dvr[n]) spr_dat_o_reg = dvr[n];
                            if (spr_sel_dcr[n]) spr_dat_o_reg = {24'b0, dcr[n]};
                        end
                    end
                end
            end
            assign spr_dat_o = spr_dat_o_reg;
        end else begin : gen_no_readregs
            assign spr_dat_o = 32'b0;
        end

    end else begin : gen_du_not_impl
        assign du_dsr = 14'b0;
        assign du_hwbkpt = 1'b0;
        assign dbg_bp_o = 1'b0;
        assign spr_dat_o = 32'b0;
    end endgenerate

endmodule

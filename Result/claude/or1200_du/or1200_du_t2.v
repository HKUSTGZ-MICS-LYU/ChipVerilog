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

    // Debug registers
    reg [24:0] dmr1;
    reg [23:0] dmr2;
    reg [13:0] dsr;
    reg [13:0] drr;
    reg [31:0] dvr0;
    reg [31:0] dvr1;
    reg [31:0] dvr2;
    reg [31:0] dvr3;
    reg [31:0] dvr4;
    reg [31:0] dvr5;
    reg [31:0] dvr6;
    reg [31:0] dvr7;
    reg [7:0] dcr0;
    reg [7:0] dcr1;
    reg [7:0] dcr2;
    reg [7:0] dcr3;
    reg [7:0] dcr4;
    reg [7:0] dcr5;
    reg [7:0] dcr6;
    reg [7:0] dcr7;
    reg [31:0] dwcr0;
    reg [31:0] dwcr1;

    // Control signals for register selection
    wire dmr1_sel;
    wire dmr2_sel;
    wire dsr_sel;
    wire drr_sel;
    wire dvr0_sel;
    wire dvr1_sel;
    wire dvr2_sel;
    wire dvr3_sel;
    wire dvr4_sel;
    wire dvr5_sel;
    wire dvr6_sel;
    wire dvr7_sel;
    wire dcr0_sel;
    wire dcr1_sel;
    wire dcr2_sel;
    wire dcr3_sel;
    wire dcr4_sel;
    wire dcr5_sel;
    wire dcr6_sel;
    wire dcr7_sel;
    wire dwcr0_sel;
    wire dwcr1_sel;

    // Watchpoint and match signals
    reg dbg_bp_r;
    reg [31:0] match_cond0_ct;
    reg [31:0] match_cond1_ct;
    reg [31:0] match_cond2_ct;
    reg [31:0] match_cond3_ct;
    reg [31:0] match_cond4_ct;
    reg [31:0] match_cond5_ct;
    reg [31:0] match_cond6_ct;
    reg [31:0] match_cond7_ct;
    reg match_cond0_stb;
    reg match_cond1_stb;
    reg match_cond2_stb;
    reg match_cond3_stb;
    reg match_cond4_stb;
    reg match_cond5_stb;
    reg match_cond6_stb;
    reg match_cond7_stb;
    reg match0;
    reg match1;
    reg match2;
    reg match3;
    reg match4;
    reg match5;
    reg match6;
    reg match7;
    reg wpcntr0_match;
    reg wpcntr1_match;
    reg incr_wpcntr0;
    reg incr_wpcntr1;
    reg [10:0] wp;

    // SPR data output register
    reg [31:0] spr_dat_o_reg;
    
    // Debug acknowledge output register
    reg dbg_ack_r;
    
    // External debug read data
    reg [31:0] dbg_dat_o_reg;

    // Exception stop flag
    reg [13:0] except_stop;

    // Instruction fetch status
    reg [1:0] dbg_is_r;

    // Register select decoder based on SPR address
    assign dmr1_sel = spr_cs && (spr_addr[15:0] == 16'h0000);
    assign dmr2_sel = spr_cs && (spr_addr[15:0] == 16'h0001);
    assign dsr_sel = spr_cs && (spr_addr[15:0] == 16'h0002);
    assign drr_sel = spr_cs && (spr_addr[15:0] == 16'h0003);
    assign dvr0_sel = spr_cs && (spr_addr[15:0] == 16'h0004);
    assign dvr1_sel = spr_cs && (spr_addr[15:0] == 16'h0005);
    assign dvr2_sel = spr_cs && (spr_addr[15:0] == 16'h0006);
    assign dvr3_sel = spr_cs && (spr_addr[15:0] == 16'h0007);
    assign dvr4_sel = spr_cs && (spr_addr[15:0] == 16'h0008);
    assign dvr5_sel = spr_cs && (spr_addr[15:0] == 16'h0009);
    assign dvr6_sel = spr_cs && (spr_addr[15:0] == 16'h000A);
    assign dvr7_sel = spr_cs && (spr_addr[15:0] == 16'h000B);
    assign dcr0_sel = spr_cs && (spr_addr[15:0] == 16'h000C);
    assign dcr1_sel = spr_cs && (spr_addr[15:0] == 16'h000D);
    assign dcr2_sel = spr_cs && (spr_addr[15:0] == 16'h000E);
    assign dcr3_sel = spr_cs && (spr_addr[15:0] == 16'h000F);
    assign dcr4_sel = spr_cs && (spr_addr[15:0] == 16'h0010);
    assign dcr5_sel = spr_cs && (spr_addr[15:0] == 16'h0011);
    assign dcr6_sel = spr_cs && (spr_addr[15:0] == 16'h0012);
    assign dcr7_sel = spr_cs && (spr_addr[15:0] == 16'h0013);
    assign dwcr0_sel = spr_cs && (spr_addr[15:0] == 16'h0014);
    assign dwcr1_sel = spr_cs && (spr_addr[15:0] == 16'h0015);

    // SPR write logic
    always @(posedge clk) begin
        if (rst) begin
            dmr1 <= 25'h0;
            dmr2 <= 24'h0;
            dsr <= 14'h0;
            drr <= 14'h0;
            dvr0 <= 32'h0;
            dvr1 <= 32'h0;
            dvr2 <= 32'h0;
            dvr3 <= 32'h0;
            dvr4 <= 32'h0;
            dvr5 <= 32'h0;
            dvr6 <= 32'h0;
            dvr7 <= 32'h0;
            dcr0 <= 8'h0;
            dcr1 <= 8'h0;
            dcr2 <= 8'h0;
            dcr3 <= 8'h0;
            dcr4 <= 8'h0;
            dcr5 <= 8'h0;
            dcr6 <= 8'h0;
            dcr7 <= 8'h0;
            dwcr0 <= 32'h0;
            dwcr1 <= 32'h0;
        end else if (spr_write) begin
            if (dmr1_sel)
                dmr1 <= spr_dat_i[24:0];
            if (dmr2_sel)
                dmr2 <= spr_dat_i[23:0];
            if (dsr_sel)
                dsr <= spr_dat_i[13:0];
            if (drr_sel)
                drr <= spr_dat_i[13:0];
            if (dvr0_sel)
                dvr0 <= spr_dat_i;
            if (dvr1_sel)
                dvr1 <= spr_dat_i;
            if (dvr2_sel)
                dvr2 <= spr_dat_i;
            if (dvr3_sel)
                dvr3 <= spr_dat_i;
            if (dvr4_sel)
                dvr4 <= spr_dat_i;
            if (dvr5_sel)
                dvr5 <= spr_dat_i;
            if (dvr6_sel)
                dvr6 <= spr_dat_i;
            if (dvr7_sel)
                dvr7 <= spr_dat_i;
            if (dcr0_sel)
                dcr0 <= spr_dat_i[7:0];
            if (dcr1_sel)
                dcr1 <= spr_dat_i[7:0];
            if (dcr2_sel)
                dcr2 <= spr_dat_i[7:0];
            if (dcr3_sel)
                dcr3 <= spr_dat_i[7:0];
            if (dcr4_sel)
                dcr4 <= spr_dat_i[7:0];
            if (dcr5_sel)
                dcr5 <= spr_dat_i[7:0];
            if (dcr6_sel)
                dcr6 <= spr_dat_i[7:0];
            if (dcr7_sel)
                dcr7 <= spr_dat_i[7:0];
            if (dwcr0_sel)
                dwcr0 <= spr_dat_i;
            if (dwcr1_sel)
                dwcr1 <= spr_dat_i;
        end
    end

    // SPR read multiplexer
    always @(*) begin
        case (1'b1)
            dmr1_sel: spr_dat_o_reg = {7'h0, dmr1};
            dmr2_sel: spr_dat_o_reg = {8'h0, dmr2};
            dsr_sel: spr_dat_o_reg = {18'h0, dsr};
            drr_sel: spr_dat_o_reg = {18'h0, drr};
            dvr0_sel: spr_dat_o_reg = dvr0;
            dvr1_sel: spr_dat_o_reg = dvr1;
            dvr2_sel: spr_dat_o_reg = dvr2;
            dvr3_sel: spr_dat_o_reg = dvr3;
            dvr4_sel: spr_dat_o_reg = dvr4;
            dvr5_sel: spr_dat_o_reg = dvr5;
            dvr6_sel: spr_dat_o_reg = dvr6;
            dvr7_sel: spr_dat_o_reg = dvr7;
            dcr0_sel: spr_dat_o_reg = {24'h0, dcr0};
            dcr1_sel: spr_dat_o_reg = {24'h0, dcr1};
            dcr2_sel: spr_dat_o_reg = {24'h0, dcr2};
            dcr3_sel: spr_dat_o_reg = {24'h0, dcr3};
            dcr4_sel: spr_dat_o_reg = {24'h0, dcr4};
            dcr5_sel: spr_dat_o_reg = {24'h0, dcr5};
            dcr6_sel: spr_dat_o_reg = {24'h0, dcr6};
            dcr7_sel: spr_dat_o_reg = {24'h0, dcr7};
            dwcr0_sel: spr_dat_o_reg = dwcr0;
            dwcr1_sel: spr_dat_o_reg = dwcr1;
            default: spr_dat_o_reg = 32'h0;
        endcase
    end

    // Debug acknowledge delay by one cycle
    always @(posedge clk) begin
        if (rst)
            dbg_ack_r <= 1'b0;
        else
            dbg_ack_r <= dbg_stb_i;
    end

    // Match condition strobes and counter logic
    always @(posedge clk) begin
        if (rst) begin
            match_cond0_stb <= 1'b0;
            match_cond1_stb <= 1'b0;
            match_cond2_stb <= 1'b0;
            match_cond3_stb <= 1'b0;
            match_cond4_stb <= 1'b0;
            match_cond5_stb <= 1'b0;
            match_cond6_stb <= 1'b0;
            match_cond7_stb <= 1'b0;
            match_cond0_ct <= 32'h0;
            match_cond1_ct <= 32'h0;
            match_cond2_ct <= 32'h0;
            match_cond3_ct <= 32'h0;
            match_cond4_ct <= 32'h0;
            match_cond5_ct <= 32'h0;
            match_cond6_ct <= 32'h0;
            match_cond7_ct <= 32'h0;
        end
    end

    // Match comparison logic
    always @(*) begin
        match0 = (ex_insn == dvr0);
        match1 = (dcpu_adr_i == dvr1);
        match2 = (dcpu_dat_lsu == dvr2);
        match3 = (dcpu_dat_dc == dvr3);
        match4 = (id_pc == dvr4);
        match5 = (spr_dat_npc == dvr5);
        match6 = (rf_dataw == dvr6);
        match7 = (ex_insn == dvr7);
    end

    // Watchpoint logic
    always @(posedge clk) begin
        if (rst) begin
            wp <= 11'h0;
            wpcntr0_match <= 1'b0;
            wpcntr1_match <= 1'b0;
            incr_wpcntr0 <= 1'b0;
            incr_wpcntr1 <= 1'b0;
        end else begin
            wp[0] <= match0 & dcr0[0];
            wp[1] <= match1 & dcr1[0];
            wp[2] <= match2 & dcr2[0];
            wp[3] <= match3 & dcr3[0];
            wp[4] <= match4 & dcr4[0];
            wp[5] <= match5 & dcr5[0];
            wp[6] <= match6 & dcr6[0];
            wp[7] <= match7 & dcr7[0];
            wp[10:8] <= 3'h0;
        end
    end

    // Exception stop tracking
    always @(posedge clk) begin
        if (rst)
            except_stop <= 14'h0;
        else
            except_stop <= {1'b0, du_except[12:0]};
    end

    // Debug breakpoint output
    assign du_hwbkpt = (dmr1[0] & (|wp)) | (dmr1[1] & (|except_stop)) | 
                       (dmr1[2] & dbg_ewt_i) | (dmr1[3] & ex_freeze);

    // Instruction fetch status
    always @(posedge clk) begin
        if (rst)
            dbg_is_r <= 2'b0;
        else
            dbg_is_r <= {icpu_cycstb_i, 1'b0};
    end

    // Direct pass-through from external debug interface
    assign du_stall = dbg_stall_i;
    assign du_addr = dbg_adr_i;
    assign du_dat_o = dbg_dat_i;
    assign du_read = dbg_stb_i & ~dbg_we_i;
    assign du_write = dbg_stb_i & dbg_we_i;

    // Output assignments
    assign du_dsr = dsr;
    assign spr_dat_o = spr_dat_o_reg;
    assign dbg_lss_o = {dcpu_cycstb_i, dcpu_we_i, 2'h0};
    assign dbg_is_o = dbg_is_r;
    assign dbg_wp_o = wp;
    assign dbg_bp_o = du_hwbkpt;
    assign dbg_dat_o = du_dat_i;
    assign dbg_ack_o = dbg_ack_r;

endmodule

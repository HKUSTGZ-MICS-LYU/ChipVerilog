module or1200_cpu(
    input clk,
    input rst,
    output ic_en,
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_rty_i,
    input icpu_err_i,
    input [31:0] icpu_adr_i,
    input [3:0] icpu_tag_i,
    output immu_en,
    output [31:0] ex_insn,
    output ex_freeze,
    output [31:0] id_pc,
    output [2:0] branch_op,
    output [31:0] spr_dat_npc,
    output [31:0] rf_dataw,
    input du_stall,
    input [31:0] du_addr,
    input [31:0] du_dat_du,
    input du_read,
    input du_write,
    input [13:0] du_dsr,
    input du_hwbkpt,
    output [12:0] du_except,
    output [31:0] du_dat_cpu,
    output dc_en,
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i,
    input [3:0] dcpu_tag_i,
    output dmmu_en,
    input sig_int,
    input sig_tick,
    output supv,
    output [31:0] spr_addr,
    output [31:0] spr_dat_cpu,
    input [31:0] spr_dat_pic,
    input [31:0] spr_dat_tt,
    input [31:0] spr_dat_pm,
    input [31:0] spr_dat_dmmu,
    input [31:0] spr_dat_immu,
    input [31:0] spr_dat_du,
    output [31:0] spr_cs,
    output spr_we
);

    reg [31:0] if_insn;
    reg [31:0] if_pc;
    reg [31:0] id_insn;
    reg [31:0] ex_insn_reg;
    reg [31:0] wb_insn;
    reg [15:0] sr;
    reg [31:0] pc;
    reg [31:0] epc;
    reg ic_en_reg;
    reg dc_en_reg;
    
    assign ic_en = ic_en_reg;
    assign dc_en = dc_en_reg;
    assign immu_en = sr[3];
    assign dmmu_en = sr[2];
    assign supv = sr[0];
    assign ex_insn = ex_insn_reg;
    assign ex_freeze = 1'b0;
    assign id_pc = if_pc;
    assign branch_op = 3'b0;
    assign spr_dat_npc = pc + 32'd4;
    assign rf_dataw = ex_insn_reg;
    assign du_except = 13'b0;
    assign du_dat_cpu = 32'b0;
    assign icpu_adr_o = pc;
    assign icpu_cycstb_o = 1'b1;
    assign icpu_sel_o = 4'b1111;
    assign icpu_tag_o = 4'b0;
    assign dcpu_adr_o = 32'b0;
    assign dcpu_cycstb_o = 1'b0;
    assign dcpu_we_o = 1'b0;
    assign dcpu_sel_o = 4'b0;
    assign dcpu_tag_o = 4'b0;
    assign dcpu_dat_o = 32'b0;
    assign spr_addr = {16'b0, id_insn[15:0]};
    assign spr_dat_cpu = 32'b0;
    assign spr_cs = 32'b0;
    assign spr_we = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            if_insn <= 32'h15000000;
            if_pc <= 32'b0;
            id_insn <= 32'h15000000;
            ex_insn_reg <= 32'h15000000;
            wb_insn <= 32'h15000000;
            sr <= 16'b0;
            pc <= 32'b0;
            epc <= 32'b0;
            ic_en_reg <= 1'b0;
            dc_en_reg <= 1'b0;
        end else begin
            if_insn <= icpu_dat_i;
            if_pc <= pc;
            id_insn <= if_insn;
            ex_insn_reg <= id_insn;
            wb_insn <= ex_insn_reg;
            
            if (icpu_ack_i) begin
                pc <= pc + 32'd4;
            end
            
            ic_en_reg <= sr[3];
            dc_en_reg <= sr[2];
        end
    end

endmodule

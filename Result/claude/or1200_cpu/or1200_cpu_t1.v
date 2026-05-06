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

reg [31:0] sr;
reg [31:0] pc;
reg [31:0] id_pc_r;
reg [31:0] ex_insn_r;
reg [2:0] branch_op_r;

reg data_pending;
reg data_we_r;
reg [31:0] data_addr_r;
reg [31:0] data_wdat_r;

wire [5:0] opcode;
wire [31:0] simm16;
wire is_load;
wire is_store;
wire [31:0] alu_result;
wire [31:0] lsu_result;
wire [31:0] spr_result;
wire [31:0] link_result;
wire [1:0] rfwb_op;
wire rf_we;
wire [12:0] except_stop;

assign opcode = ex_insn_r[31:26];
assign simm16 = {{16{ex_insn_r[15]}}, ex_insn_r[15:0]};
assign is_load = (opcode == 6'h23);
assign is_store = (opcode == 6'h2b);

assign icpu_adr_o = pc;
assign icpu_cycstb_o = ~rst & ~du_stall;
assign icpu_sel_o = 4'hf;
assign icpu_tag_o = 4'h0;

assign dcpu_adr_o = data_addr_r;
assign dcpu_cycstb_o = data_pending;
assign dcpu_we_o = data_we_r;
assign dcpu_sel_o = 4'hf;
assign dcpu_tag_o = 4'h0;
assign dcpu_dat_o = data_wdat_r;

assign spr_addr = du_addr;
assign spr_dat_cpu = du_dat_du;
assign spr_we = du_write;
assign spr_cs = (du_read | du_write) ? (32'h0000_0001 << du_addr[4:0]) : 32'h0000_0000;
assign spr_dat_npc = pc;

assign dc_en = sr[3];
assign ic_en = sr[4];
assign dmmu_en = sr[5];
assign immu_en = sr[6];
assign supv = sr[0];

assign ex_insn = ex_insn_r;
assign id_pc = id_pc_r;
assign branch_op = branch_op_r;
assign ex_freeze = du_stall | (data_pending & ~(dcpu_ack_i | dcpu_rty_i | dcpu_err_i));

assign alu_result = ex_insn_r + id_pc_r;
assign lsu_result = dcpu_dat_i;
assign spr_result = du_dat_cpu;
assign link_result = id_pc_r + 32'd8;
assign rfwb_op = ex_insn_r[1:0];
assign rf_we = rfwb_op[0];

assign rf_dataw = (rfwb_op == 2'b00) ? alu_result :
                  (rfwb_op == 2'b01) ? lsu_result :
                  (rfwb_op == 2'b10) ? spr_result :
                                       link_result;

assign du_dat_cpu = (du_addr[15:12] == 4'h0) ? sr :
                    (du_addr[15:12] == 4'h1) ? spr_dat_pic :
                    (du_addr[15:12] == 4'h2) ? spr_dat_tt :
                    (du_addr[15:12] == 4'h3) ? spr_dat_pm :
                    (du_addr[15:12] == 4'h4) ? spr_dat_dmmu :
                    (du_addr[15:12] == 4'h5) ? spr_dat_immu :
                    (du_addr[15:12] == 4'h6) ? spr_dat_du :
                                               32'h0000_0000;

assign except_stop[0] = sig_int;
assign except_stop[1] = sig_tick;
assign except_stop[2] = icpu_err_i;
assign except_stop[3] = dcpu_err_i;
assign except_stop[4] = du_hwbkpt;
assign except_stop[5] = (opcode == 6'h3f);
assign except_stop[6] = (data_pending & (data_addr_r[1:0] != 2'b00));
assign except_stop[7] = icpu_rty_i;
assign except_stop[8] = dcpu_rty_i;
assign except_stop[9] = du_dsr[0];
assign except_stop[10] = du_dsr[1];
assign except_stop[11] = du_dsr[2];
assign except_stop[12] = du_dsr[3];
assign du_except = except_stop;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sr <= 32'h0000_0001;
        pc <= 32'h0000_0100;
        id_pc_r <= 32'h0000_0000;
        ex_insn_r <= 32'h1500_0000;
        branch_op_r <= 3'b000;
        data_pending <= 1'b0;
        data_we_r <= 1'b0;
        data_addr_r <= 32'h0000_0000;
        data_wdat_r <= 32'h0000_0000;
    end else begin
        if (du_write && (du_addr[7:0] == 8'h11)) begin
            sr <= du_dat_du;
        end
        if (sig_int | sig_tick) begin
            sr[0] <= 1'b1;
        end

        if (!du_stall && icpu_ack_i) begin
            id_pc_r <= pc;
            ex_insn_r <= icpu_dat_i;
            pc <= pc + 32'd4;
            case (icpu_dat_i[31:26])
                6'h04: branch_op_r <= 3'b001;
                6'h05: branch_op_r <= 3'b001;
                6'h02: branch_op_r <= 3'b010;
                6'h03: branch_op_r <= 3'b010;
                default: branch_op_r <= 3'b000;
            endcase
        end

        if (data_pending) begin
            if (dcpu_ack_i | dcpu_rty_i | dcpu_err_i) begin
                data_pending <= 1'b0;
            end
        end else if (!du_stall && (is_load | is_store) && rf_we) begin
            data_pending <= 1'b1;
            data_we_r <= is_store;
            data_addr_r <= id_pc_r + simm16;
            data_wdat_r <= rf_dataw;
        end
    end
end

endmodule

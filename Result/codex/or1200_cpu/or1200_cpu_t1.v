module or1200_cpu(
    input clk,
    input rst,
    output ic_en,
    output reg [31:0] icpu_adr_o,
    output reg icpu_cycstb_o,
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
    output reg [31:0] dcpu_adr_o,
    output reg dcpu_cycstb_o,
    output reg dcpu_we_o,
    output reg [3:0] dcpu_sel_o,
    output reg [3:0] dcpu_tag_o,
    output reg [31:0] dcpu_dat_o,
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

reg [31:0] sr_r;
reg [31:0] pc_r;
reg [31:0] epcr_r;
reg [31:0] eear_r;
reg [31:0] esr_r;
reg [31:0] ex_insn_r;
reg [31:0] id_pc_r;
reg [31:0] rf_dataw_r;
reg [12:0] except_stop_r;
reg [31:0] gpr[0:31];
reg load_pending_r;
reg [4:0] pending_rd_r;
integer i;

wire except_prefix_w;
wire [2:0] op_class_w;
wire [4:0] rd_w;
wire [4:0] ra_w;
wire [4:0] rb_w;
wire [2:0] alu_op_w;
wire [31:0] ra_val_w;
wire [31:0] rb_val_w;
wire [31:0] imm_w;
wire [31:0] mem_addr_w;
wire exec_spr_access_w;
wire exec_spr_write_w;
wire [31:0] spr_addr_w;
wire [31:0] spr_dat_cpu_w;
wire [31:0] spr_cs_w;
wire spr_we_w;
wire [31:0] spr_rdata_w;
wire [31:0] du_rdata_w;
wire [31:0] vector_base_w;
wire [31:0] link_addr_w;
wire [31:0] mac_result_w;
wire load_op_w;
wire store_op_w;
wire branch_req_w;
wire branch_taken_w;
wire link_req_w;
wire syscall_w;
wire trap_w;
wire illegal_w;
wire align_w;
wire if_fault_w;
wire data_fault_w;
wire if_retry_w;
wire data_retry_w;
wire [31:0] branch_target_w;
wire ex_freeze_w;

reg [31:0] alu_result_r;
reg [2:0] branch_op_r;
reg exception_taken_r;
reg [31:0] exception_pc_r;
reg [12:0] exception_stop_next_r;

function [31:0] spr_lookup;
    input [31:0] addr;
    begin
        case (addr[7:5])
            3'b000: begin
                case (addr[4:0])
                    5'd0: spr_lookup = pc_r;
                    5'd1: spr_lookup = id_pc_r;
                    5'd2: spr_lookup = ex_insn_r;
                    5'd3: spr_lookup = sr_r;
                    5'd4: spr_lookup = epcr_r;
                    5'd5: spr_lookup = eear_r;
                    5'd6: spr_lookup = esr_r;
                    5'd7: spr_lookup = rf_dataw_r;
                    5'd8: spr_lookup = {19'd0, except_stop_r};
                    default: spr_lookup = gpr[addr[4:0]];
                endcase
            end
            3'b001: spr_lookup = spr_dat_pic;
            3'b010: spr_lookup = spr_dat_tt;
            3'b011: spr_lookup = spr_dat_pm;
            3'b100: spr_lookup = spr_dat_dmmu;
            3'b101: spr_lookup = spr_dat_immu;
            3'b110: spr_lookup = spr_dat_du;
            default: spr_lookup = 32'd0;
        endcase
    end
endfunction

assign except_prefix_w = sr_r[14];
assign ic_en = sr_r[4];
assign dc_en = sr_r[3];
assign immu_en = sr_r[6];
assign dmmu_en = sr_r[5];
assign supv = sr_r[0];
assign ex_insn = ex_insn_r;
assign id_pc = id_pc_r;
assign branch_op = branch_op_r;
assign spr_dat_npc = pc_r + 32'd4;
assign rf_dataw = rf_dataw_r;
assign du_except = except_stop_r;
assign du_dat_cpu = du_rdata_w;
assign spr_addr = spr_addr_w;
assign spr_dat_cpu = spr_dat_cpu_w;
assign spr_cs = spr_cs_w;
assign spr_we = spr_we_w;
assign icpu_sel_o = 4'b1111;
assign icpu_tag_o = {1'b0, icpu_err_i, icpu_ack_i, icpu_cycstb_o};
assign ex_freeze = ex_freeze_w;

assign op_class_w = ex_insn_r[31:29];
assign rd_w = ex_insn_r[28:24];
assign ra_w = ex_insn_r[23:19];
assign rb_w = ex_insn_r[18:14];
assign alu_op_w = ex_insn_r[13:11];
assign imm_w = {{16{ex_insn_r[15]}}, ex_insn_r[15:0]};
assign ra_val_w = gpr[ra_w];
assign rb_val_w = gpr[rb_w];
assign mem_addr_w = ra_val_w + imm_w;
assign link_addr_w = id_pc_r + 32'd4;
assign mac_result_w = (ra_val_w * rb_val_w) + (ex_insn_r[10] ? rf_dataw_r : 32'd0);
assign load_op_w = (op_class_w == 3'b010);
assign store_op_w = (op_class_w == 3'b011);
assign branch_req_w = (op_class_w == 3'b001);
assign branch_taken_w = ex_insn_r[13] | (ra_val_w == rb_val_w);
assign link_req_w = (op_class_w == 3'b101);
assign syscall_w = (op_class_w == 3'b110) & ~ex_insn_r[16];
assign trap_w = (op_class_w == 3'b110) & ex_insn_r[16];
assign illegal_w = (ex_insn_r == 32'hffff_ffff);
assign align_w = (load_op_w | store_op_w) & (mem_addr_w[1:0] != 2'b00);
assign if_fault_w = icpu_cycstb_o & icpu_err_i;
assign data_fault_w = dcpu_cycstb_o & dcpu_err_i;
assign if_retry_w = icpu_cycstb_o & icpu_rty_i;
assign data_retry_w = dcpu_cycstb_o & dcpu_rty_i;
assign branch_target_w = id_pc_r + {imm_w[29:0], 2'b00};
assign vector_base_w = except_prefix_w ? 32'hf000_0000 : 32'h0000_0000;
assign ex_freeze_w = du_stall | dcpu_cycstb_o | load_pending_r;

assign exec_spr_access_w = (op_class_w == 3'b100) & ~du_stall & ~dcpu_cycstb_o;
assign exec_spr_write_w = exec_spr_access_w & ex_insn_r[16];
assign spr_addr_w = (du_read | du_write) ? du_addr : (exec_spr_access_w ? {16'd0, ex_insn_r[15:0]} : 32'd0);
assign spr_dat_cpu_w = du_write ? du_dat_du : ra_val_w;
assign spr_cs_w = (du_read | du_write | exec_spr_access_w) ? (32'h0000_0001 << spr_addr_w[4:0]) : 32'd0;
assign spr_we_w = du_write | exec_spr_write_w;
assign spr_rdata_w = spr_lookup(spr_addr_w);
assign du_rdata_w = spr_lookup(du_addr);

always @* begin
    case (alu_op_w)
        3'b000: alu_result_r = ra_val_w + rb_val_w;
        3'b001: alu_result_r = ra_val_w - rb_val_w;
        3'b010: alu_result_r = ra_val_w & rb_val_w;
        3'b011: alu_result_r = ra_val_w | rb_val_w;
        3'b100: alu_result_r = ra_val_w ^ rb_val_w;
        3'b101: alu_result_r = ra_val_w << rb_val_w[4:0];
        3'b110: alu_result_r = ra_val_w >> rb_val_w[4:0];
        default: alu_result_r = $signed(ra_val_w) >>> rb_val_w[4:0];
    endcase
end

always @* begin
    branch_op_r = 3'd0;
    if (branch_req_w) begin
        branch_op_r = {ex_insn_r[13], ex_insn_r[12], 1'b1};
    end else if (link_req_w) begin
        branch_op_r = 3'b111;
    end
end

always @* begin
    exception_taken_r = 1'b0;
    exception_pc_r = vector_base_w;
    exception_stop_next_r = 13'd0;

    if (du_hwbkpt) begin
        exception_taken_r = 1'b1;
        exception_pc_r = vector_base_w + 32'h0000_0900;
        exception_stop_next_r[8] = 1'b1;
    end else if (if_fault_w) begin
        exception_taken_r = 1'b1;
        exception_pc_r = vector_base_w + 32'h0000_0200;
        exception_stop_next_r[2] = 1'b1;
    end else if (data_fault_w) begin
        exception_taken_r = 1'b1;
        exception_pc_r = vector_base_w + 32'h0000_0300;
        exception_stop_next_r[3] = 1'b1;
    end else if (align_w) begin
        exception_taken_r = 1'b1;
        exception_pc_r = vector_base_w + 32'h0000_0400;
        exception_stop_next_r[5] = 1'b1;
    end else if (illegal_w) begin
        exception_taken_r = 1'b1;
        exception_pc_r = vector_base_w + 32'h0000_0500;
        exception_stop_next_r[4] = 1'b1;
    end else if (syscall_w) begin
        exception_taken_r = 1'b1;
        exception_pc_r = vector_base_w + 32'h0000_0600;
        exception_stop_next_r[6] = 1'b1;
    end else if (trap_w) begin
        exception_taken_r = 1'b1;
        exception_pc_r = vector_base_w + 32'h0000_0700;
        exception_stop_next_r[7] = 1'b1;
    end else if (sig_tick) begin
        exception_taken_r = 1'b1;
        exception_pc_r = vector_base_w + 32'h0000_0800;
        exception_stop_next_r[1] = 1'b1;
    end else if (sig_int) begin
        exception_taken_r = 1'b1;
        exception_pc_r = vector_base_w + 32'h0000_0100;
        exception_stop_next_r[0] = 1'b1;
    end else if (if_retry_w) begin
        exception_stop_next_r[9] = 1'b1;
    end else if (data_retry_w) begin
        exception_stop_next_r[10] = 1'b1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sr_r <= 32'h0000_0001;
        pc_r <= 32'd0;
        epcr_r <= 32'd0;
        eear_r <= 32'd0;
        esr_r <= 32'd0;
        ex_insn_r <= 32'd0;
        id_pc_r <= 32'd0;
        rf_dataw_r <= 32'd0;
        except_stop_r <= 13'd0;
        icpu_adr_o <= 32'd0;
        icpu_cycstb_o <= 1'b0;
        dcpu_adr_o <= 32'd0;
        dcpu_cycstb_o <= 1'b0;
        dcpu_we_o <= 1'b0;
        dcpu_sel_o <= 4'b0000;
        dcpu_tag_o <= 4'b0000;
        dcpu_dat_o <= 32'd0;
        load_pending_r <= 1'b0;
        pending_rd_r <= 5'd0;
        for (i = 0; i < 32; i = i + 1) begin
            gpr[i] <= 32'd0;
        end
    end else begin
        except_stop_r <= exception_stop_next_r;

        if (du_write) begin
            if (du_addr[7:5] == 3'b000) begin
                case (du_addr[4:0])
                    5'd0: pc_r <= du_dat_du;
                    5'd3: sr_r <= du_dat_du;
                    5'd4: epcr_r <= du_dat_du;
                    5'd5: eear_r <= du_dat_du;
                    5'd6: esr_r <= du_dat_du;
                    default: if (du_addr[4:0] != 5'd0) gpr[du_addr[4:0]] <= du_dat_du;
                endcase
            end
        end

        if (dcpu_cycstb_o && dcpu_ack_i) begin
            dcpu_cycstb_o <= 1'b0;
            dcpu_we_o <= 1'b0;
            dcpu_sel_o <= 4'b0000;
            dcpu_tag_o <= 4'b0000;
            if (load_pending_r) begin
                rf_dataw_r <= dcpu_dat_i;
                if (pending_rd_r != 5'd0) begin
                    gpr[pending_rd_r] <= dcpu_dat_i;
                end
            end
            load_pending_r <= 1'b0;
            pending_rd_r <= 5'd0;
        end

        if (exception_taken_r) begin
            epcr_r <= id_pc_r;
            eear_r <= (align_w | data_fault_w) ? mem_addr_w : pc_r;
            esr_r <= sr_r;
            pc_r <= exception_pc_r;
            ex_insn_r <= 32'd0;
            id_pc_r <= exception_pc_r;
            rf_dataw_r <= 32'd0;
            icpu_adr_o <= exception_pc_r;
            icpu_cycstb_o <= ~du_stall;
            dcpu_cycstb_o <= 1'b0;
            dcpu_we_o <= 1'b0;
            dcpu_sel_o <= 4'b0000;
            dcpu_tag_o <= 4'b0000;
            load_pending_r <= 1'b0;
            pending_rd_r <= 5'd0;
        end else if (!du_stall) begin
            if (!dcpu_cycstb_o) begin
                case (op_class_w)
                    3'b000: begin
                        rf_dataw_r <= alu_result_r;
                        if (rd_w != 5'd0) begin
                            gpr[rd_w] <= alu_result_r;
                        end
                    end
                    3'b001: begin
                        if (branch_taken_w) begin
                            pc_r <= branch_target_w;
                            icpu_adr_o <= branch_target_w;
                            icpu_cycstb_o <= 1'b1;
                            ex_insn_r <= 32'd0;
                        end
                    end
                    3'b010: begin
                        if (!align_w) begin
                            dcpu_adr_o <= mem_addr_w;
                            dcpu_cycstb_o <= 1'b1;
                            dcpu_we_o <= 1'b0;
                            dcpu_sel_o <= 4'b1111;
                            dcpu_tag_o <= 4'b0010;
                            dcpu_dat_o <= 32'd0;
                            load_pending_r <= 1'b1;
                            pending_rd_r <= rd_w;
                        end
                    end
                    3'b011: begin
                        if (!align_w) begin
                            dcpu_adr_o <= mem_addr_w;
                            dcpu_cycstb_o <= 1'b1;
                            dcpu_we_o <= 1'b1;
                            dcpu_sel_o <= 4'b1111;
                            dcpu_tag_o <= 4'b0011;
                            dcpu_dat_o <= rb_val_w;
                            load_pending_r <= 1'b0;
                            pending_rd_r <= 5'd0;
                        end
                    end
                    3'b100: begin
                        if (exec_spr_write_w) begin
                            if (spr_addr_w[7:5] == 3'b000) begin
                                case (spr_addr_w[4:0])
                                    5'd0: pc_r <= spr_dat_cpu_w;
                                    5'd3: sr_r <= spr_dat_cpu_w;
                                    5'd4: epcr_r <= spr_dat_cpu_w;
                                    5'd5: eear_r <= spr_dat_cpu_w;
                                    5'd6: esr_r <= spr_dat_cpu_w;
                                    default: if (spr_addr_w[4:0] != 5'd0) gpr[spr_addr_w[4:0]] <= spr_dat_cpu_w;
                                endcase
                            end
                        end else begin
                            rf_dataw_r <= spr_rdata_w;
                            if (rd_w != 5'd0) begin
                                gpr[rd_w] <= spr_rdata_w;
                            end
                        end
                    end
                    3'b101: begin
                        rf_dataw_r <= link_addr_w;
                        if (rd_w != 5'd0) begin
                            gpr[rd_w] <= link_addr_w;
                        end
                        pc_r <= branch_target_w;
                        icpu_adr_o <= branch_target_w;
                        icpu_cycstb_o <= 1'b1;
                        ex_insn_r <= 32'd0;
                    end
                    3'b111: begin
                        rf_dataw_r <= mac_result_w;
                        if (rd_w != 5'd0) begin
                            gpr[rd_w] <= mac_result_w;
                        end
                    end
                    default: begin
                    end
                endcase
            end

            if (icpu_cycstb_o && icpu_ack_i && !branch_req_w && !link_req_w) begin
                ex_insn_r <= icpu_dat_i;
                id_pc_r <= icpu_adr_o;
                rf_dataw_r <= rf_dataw_r;
                pc_r <= icpu_adr_o + 32'd4;
                icpu_cycstb_o <= 1'b0;
            end

            if (!icpu_cycstb_o && !dcpu_cycstb_o) begin
                icpu_adr_o <= pc_r;
                icpu_cycstb_o <= 1'b1;
            end
        end

        gpr[0] <= 32'd0;
    end
end

endmodule

module or1200_ctrl(
    input clk,
    input rst,
    input id_freeze,
    input ex_freeze,
    input wb_freeze,
    input flushpipe,
    input [31:0] if_insn,
    output reg [31:0] ex_insn,
    output reg [2:0] branch_op,
    input branch_taken,
    output [4:0] rf_addra,
    output [4:0] rf_addrb,
    output rf_rda,
    output rf_rdb,
    output reg [3:0] alu_op,
    output reg [1:0] mac_op,
    output reg [1:0] shrot_op,
    output reg [3:0] comp_op,
    output reg [4:0] rf_addrw,
    output reg [2:0] rfwb_op,
    output [31:0] wb_insn,
    output [31:0] simm,
    output reg [31:2] branch_addrofs,
    output [31:0] lsu_addrofs,
    output reg [1:0] sel_a,
    output reg [1:0] sel_b,
    output reg [3:0] lsu_op,
    output reg [3:0] comp_op_ctl,
    output [4:0] cust5_op,
    output [5:0] cust5_limm,
    output reg [1:0] multicycle,
    output reg [15:0] spr_addrimm,
    input wbforw_valid,
    input du_hwbkpt,
    output reg sig_syscall,
    output reg sig_trap,
    output force_dslot_fetch,
    output no_more_dslot,
    output ex_void,
    output reg id_macrc_op,
    output reg ex_macrc_op,
    output rfe,
    output except_illegal
);

    reg [31:0] id_insn;
    reg [31:0] ex_insn_buf;
    reg [31:0] wb_insn_buf;
    reg [4:0] wb_rfaddrw;
    
    assign rf_addra = if_insn[20:16];
    assign rf_addrb = if_insn[15:11];
    assign rf_rda = 1'b1;
    assign rf_rdb = 1'b1;
    assign simm = {{16{id_insn[15]}}, id_insn[15:0]};
    assign lsu_addrofs = {{16{id_insn[15]}}, id_insn[15:0]};
    assign cust5_op = ex_insn[4:0];
    assign cust5_limm = ex_insn[10:5];
    assign wb_insn = wb_insn_buf;
    assign ex_void = (ex_insn_buf == 32'h15000000);
    assign force_dslot_fetch = 1'b0;
    assign no_more_dslot = 1'b0;
    assign rfe = 1'b0;
    assign except_illegal = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            id_insn <= 32'h15000000;
            ex_insn <= 32'h15000000;
            ex_insn_buf <= 32'h15000000;
            wb_insn_buf <= 32'h15000000;
            alu_op <= 4'b0;
            mac_op <= 2'b0;
            shrot_op <= 2'b0;
            comp_op <= 4'b0;
            lsu_op <= 4'b0;
            comp_op_ctl <= 4'b0;
            branch_op <= 3'b0;
            rfwb_op <= 3'b0;
            rf_addrw <= 5'b0;
            wb_rfaddrw <= 5'b0;
            sel_a <= 2'b0;
            sel_b <= 2'b0;
            multicycle <= 2'b0;
            spr_addrimm <= 16'b0;
            sig_syscall <= 1'b0;
            sig_trap <= 1'b0;
            id_macrc_op <= 1'b0;
            ex_macrc_op <= 1'b0;
            branch_addrofs <= 30'b0;
        end else begin
            if (flushpipe) begin
                id_insn <= 32'h15000000;
                ex_insn <= 32'h15000000;
                ex_insn_buf <= 32'h15000000;
                wb_insn_buf <= 32'h15000000;
            end else if (!id_freeze) begin
                id_insn <= if_insn;
                id_macrc_op <= (if_insn[31:26] == 6'b011000) & (if_insn[16] == 1'b1);
            end
            
            if (!ex_freeze & !id_freeze) begin
                ex_insn <= id_insn;
                ex_insn_buf <= id_insn;
                ex_macrc_op <= id_macrc_op;
            end
            
            if (!wb_freeze) begin
                wb_insn_buf <= ex_insn_buf;
                wb_rfaddrw <= rf_addrw;
            end
            
            case (id_insn[31:26])
                6'b000000: begin
                    alu_op <= id_insn[3:0];
                    branch_op <= 3'b0;
                    rfwb_op <= 3'b001;
                end
                6'b001000: begin
                    alu_op <= 4'b0000;
                    branch_op <= 3'b0;
                    rfwb_op <= 3'b001;
                end
                6'b100100: begin
                    lsu_op <= 4'b0001;
                    rfwb_op <= 3'b010;
                end
                6'b100101: begin
                    lsu_op <= 4'b0010;
                    rfwb_op <= 3'b010;
                end
                default: begin
                    alu_op <= 4'b0;
                    lsu_op <= 4'b0;
                    rfwb_op <= 3'b0;
                end
            endcase
            
            rf_addrw <= id_insn[25:21];
            spr_addrimm <= id_insn[15:0];
        end
    end

endmodule

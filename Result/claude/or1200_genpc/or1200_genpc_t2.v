module or1200_genpc(
    input clk,
    input rst,
    
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input icpu_rty_i,
    input [31:0] icpu_adr_i,
    
    input [2:0] branch_op,
    input [3:0] except_type,
    input except_prefix,
    input [31:2] branch_addrofs,
    input [31:0] lr_restor,
    input flag,
    output taken,
    input except_start,
    input [31:2] binsn_addr,
    input [31:0] epcr,
    input [31:0] spr_dat_i,
    input spr_pc_we,
    input genpc_refetch,
    input genpc_freeze,
    input genpc_stop_prefetch,
    input no_more_dslot
);

reg [31:2] pcreg;
reg [31:0] pc;
reg taken;
reg genpc_refetch_r;

localparam BRANCH_NOP = 3'b000;
localparam BRANCH_J   = 3'b001;
localparam BRANCH_JR  = 3'b010;
localparam BRANCH_BAL = 3'b011;
localparam BRANCH_BF  = 3'b100;
localparam BRANCH_BNF = 3'b101;
localparam BRANCH_RFE = 3'b110;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        genpc_refetch_r <= 1'b0;
    end else begin
        genpc_refetch_r <= genpc_refetch;
    end
end

always @(*) begin
    if (spr_pc_we) begin
        pc = spr_dat_i;
    end else if (except_start) begin
        pc = {except_prefix, except_type, 28'b0};
        pc[31:2] = {except_prefix, except_type, 26'b0};
    end else begin
        case (branch_op)
            BRANCH_NOP: begin
                pc = {pcreg + 1, 2'b00};
                taken = 1'b0;
            end
            BRANCH_J: begin
                pc = {branch_addrofs, 2'b00};
                taken = 1'b1;
            end
            BRANCH_JR: begin
                pc = lr_restor;
                taken = 1'b1;
            end
            BRANCH_BAL: begin
                pc = {binsn_addr + branch_addrofs, 2'b00};
                taken = 1'b1;
            end
            BRANCH_BF: begin
                if (flag) begin
                    pc = {branch_addrofs, 2'b00};
                    taken = 1'b1;
                end else begin
                    pc = {pcreg + 1, 2'b00};
                    taken = 1'b0;
                end
            end
            BRANCH_BNF: begin
                if (!flag) begin
                    pc = {branch_addrofs, 2'b00};
                    taken = 1'b1;
                end else begin
                    pc = {pcreg + 1, 2'b00};
                    taken = 1'b0;
                end
            end
            BRANCH_RFE: begin
                pc = epcr;
                taken = 1'b1;
            end
            default: begin
                pc = {pcreg + 1, 2'b00};
                taken = 1'b0;
            end
        endcase
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pcreg <= 30'h0;
    end else if (spr_pc_we) begin
        pcreg <= spr_dat_i[31:2];
    end else if (no_more_dslot || except_start) begin
        pcreg <= pc[31:2];
    end else if (!genpc_freeze && !icpu_rty_i && !genpc_refetch) begin
        pcreg <= pc[31:2];
    end
end

assign icpu_adr_o = (no_more_dslot || except_start || spr_pc_we || icpu_rty_i || genpc_refetch) ? 
                     icpu_adr_i : pc;

assign icpu_cycstb_o = !genpc_freeze;
assign icpu_sel_o = 4'b1111;
assign icpu_tag_o = 4'b0;

endmodule

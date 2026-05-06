module or1200_genpc(
    input clk,
    input rst,
    output reg [31:0] icpu_adr_o,
    output reg icpu_cycstb_o,
    output reg [3:0] icpu_sel_o,
    output reg [3:0] icpu_tag_o,
    input icpu_rty_i,
    input [31:0] icpu_adr_i,
    input [2:0] branch_op,
    input [3:0] except_type,
    input except_prefix,
    input [31:2] branch_addrofs,
    input [31:0] lr_restor,
    input flag,
    output reg taken,
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

    // Branch operation codes
    localparam [2:0] OR1200_BRANCHOP_NOP = 3'b000;
    localparam [2:0] OR1200_BRANCHOP_J   = 3'b001;
    localparam [2:0] OR1200_BRANCHOP_JR  = 3'b010;
    localparam [2:0] OR1200_BRANCHOP_BAL = 3'b011;
    localparam [2:0] OR1200_BRANCHOP_BF  = 3'b100;
    localparam [2:0] OR1200_BRANCHOP_BNF = 3'b101;
    localparam [2:0] OR1200_BRANCHOP_RFE = 3'b110;

    // Exception prefix bases (example values)
    localparam [31:0] EPH0_BASE = 32'h00000100;
    localparam [31:0] EPH1_BASE = 32'hFFFFF100;

    // Reset exception vector address
    localparam [31:0] RST_VEC = 32'h00000100;

    // Instruction tag constant
    localparam [3:0] OR1200_ITAG_NI = 4'b0000;

    // Internal registers
    reg [31:2] pcreg;
    reg genpc_refetch_r;

    // Combunational PC and taken logic
    reg [31:0] pc;
    always @(*) begin
        if (spr_pc_we) begin
            pc = spr_dat_i;
            taken = 1'b0;
        end else if (except_start) begin
            pc = (except_prefix ? EPH1_BASE : EPH0_BASE) + {except_type, 8'b0};
            taken = 1'b1;
        end else begin
            case (branch_op)
                OR1200_BRANCHOP_NOP: begin
                    pc = {pcreg + 1'b1, 2'b00};
                    taken = 1'b0;
                end
                OR1200_BRANCHOP_J: begin
                    pc = {branch_addrofs, 2'b00};
                    taken = 1'b1;
                end
                OR1200_BRANCHOP_JR: begin
                    pc = lr_restor;
                    taken = 1'b1;
                end
                OR1200_BRANCHOP_BAL: begin
                    pc = {binsn_addr + branch_addrofs, 2'b00};
                    taken = 1'b1;
                end
                OR1200_BRANCHOP_BF: begin
                    if (flag) begin
                        pc = {binsn_addr + branch_addrofs, 2'b00};
                        taken = 1'b1;
                    end else begin
                        pc = {pcreg + 1'b1, 2'b00};
                        taken = 1'b0;
                    end
                end
                OR1200_BRANCHOP_BNF: begin
                    if (!flag) begin
                        pc = {binsn_addr + branch_addrofs, 2'b00};
                        taken = 1'b1;
                    end else begin
                        pc = {pcreg + 1'b1, 2'b00};
                        taken = 1'b0;
                    end
                end
                OR1200_BRANCHOP_RFE: begin
                    pc = epcr;
                    taken = 1'b1;
                end
                default: begin
                    pc = {pcreg + 1'b1, 2'b00};
                    taken = 1'b0;
                end
            endcase
        end
    end

    // icpu_adr_o selection
    always @(*) begin
        if ( (~no_more_dslot) & (~except_start) & (~spr_pc_we) & (icpu_rty_i | genpc_refetch) )
            icpu_adr_o = icpu_adr_i;
        else
            icpu_adr_o = pc;
    end

    // icpu_cycstb_o (active high request, asserted when not frozen)
    always @(*) begin
        icpu_cycstb_o = ~genpc_freeze;
    end

    // Fixed byte select and tag
    always @(*) begin
        icpu_sel_o = 4'b1111;
        icpu_tag_o = OR1200_ITAG_NI;
    end

    // Sequential logic for pcreg and genpc_refetch_r
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pcreg <= (RST_VEC - 32'd4) >> 2;
            genpc_refetch_r <= 1'b0;
        end else begin
            // genpc_refetch_r (not used in active logic)
            genpc_refetch_r <= genpc_refetch;

            // pcreg update
            if (spr_pc_we) begin
                pcreg <= spr_dat_i[31:2];
            end else if (no_more_dslot | except_start | (~genpc_freeze & ~icpu_rty_i & ~genpc_refetch)) begin
                pcreg <= pc[31:2];
            end
        end
    end

endmodule

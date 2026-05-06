`timescale 1ns / 1ps

module or1200_genpc(
    input  wire         clk,
    input  wire         rst,
    output reg  [31:0]  icpu_adr_o,
    output wire         icpu_cycstb_o,
    output wire [3:0]   icpu_sel_o,
    output wire [3:0]   icpu_tag_o,
    input  wire         icpu_rty_i,
    input  wire [31:0]  icpu_adr_i,
    input  wire [2:0]   branch_op,
    input  wire [3:0]   except_type,
    input  wire         except_prefix,
    input  wire [31:2]  branch_addrofs,
    input  wire [31:0]  lr_restor,
    input  wire         flag,
    output reg          taken,
    input  wire         except_start,
    input  wire [31:2]  binsn_addr,
    input  wire [31:0]  epcr,
    input  wire [31:0]  spr_dat_i,
    input  wire         spr_pc_we,
    input  wire         genpc_refetch,
    input  wire         genpc_freeze,
    input  wire         genpc_stop_prefetch,
    input  wire         no_more_dslot
);

    // Internal signals
    reg [31:2] pcreg;
    reg genpc_refetch_r;
    wire [31:0] pc;
    reg [31:0] exception_addr;

    // Constants
    localparam [31:0] RESET_VECTOR = 32'h00000100;
    localparam [3:0] ITAG_NI = 4'b0001; // Normal instruction fetch tag

    // Exception address generation
    always @* begin
        // Assume exception vector = prefix_base + (except_type << 2)
        // prefix_base: 0x0000_0100 if except_prefix=0, 0x3000_0100 if except_prefix=1
        if (except_prefix)
            exception_addr = 32'h3000_0100 + {except_type, 2'b00};
        else
            exception_addr = 32'h0000_0100 + {except_type, 2'b00};
    end

    // Combinational PC selection
    always @* begin
        // Highest priority: SPR PC write
        if (spr_pc_we)
            pc = spr_dat_i;
        else if (except_start)
            pc = exception_addr;
        else begin
            case (branch_op)
                3'b000: // NOP
                    pc = {pcreg[31:2], 2'b00} + 32'd4;
                3'b001: // J
                    pc = {branch_addrofs[29:0], 2'b00};
                3'b010: // JR
                    pc = lr_restor;
                3'b011: // BAL
                    pc = ({binsn_addr[29:0], 2'b00} + {branch_addrofs[29:0], 2'b00});
                3'b100: // BF
                    pc = flag ? ({binsn_addr[29:0], 2'b00} + {branch_addrofs[29:0], 2'b00})
                             : ({pcreg[31:2], 2'b00} + 32'd4);
                3'b101: // BNF
                    pc = flag ? ({pcreg[31:2], 2'b00} + 32'd4)
                             : ({binsn_addr[29:0], 2'b00} + {branch_addrofs[29:0], 2'b00});
                3'b110: // RFE
                    pc = epcr;
                default:
                    pc = {pcreg[31:2], 2'b00} + 32'd4;
            endcase
        end
    end

    // Combinational taken signal
    always @* begin
        if (spr_pc_we)
            taken = 1'b0;
        else if (except_start)
            taken = 1'b1;
        else begin
            case (branch_op)
                3'b000: taken = 1'b0; // NOP
                3'b001: taken = 1'b1; // J
                3'b010: taken = 1'b1; // JR
                3'b011: taken = 1'b1; // BAL
                3'b100: taken = flag; // BF
                3'b101: taken = ~flag; // BNF
                3'b110: taken = 1'b1; // RFE
                default: taken = 1'b0;
            endcase
        end
    end

    // icpu_adr_o output
    always @* begin
        if (!no_more_dslot && !except_start && !spr_pc_we && (icpu_rty_i || genpc_refetch))
            icpu_adr_o = icpu_adr_i;
        else
            icpu_adr_o = pc;
    end

    // icpu_cycstb_o
    assign icpu_cycstb_o = ~genpc_freeze;

    // icpu_sel_o fixed to 4'b1111
    assign icpu_sel_o = 4'b1111;

    // icpu_tag_o fixed to ITAG_NI
    assign icpu_tag_o = ITAG_NI;

    // pcreg sequential update
    always @(posedge clk or posedge rst) begin
        if (rst)
            pcreg <= (RESET_VECTOR - 32'd4) >> 2;
        else if (spr_pc_we)
            pcreg <= spr_dat_i[31:2];
        else if (no_more_dslot)
            pcreg <= pc[31:2];
        else if (except_start)
            pcreg <= pc[31:2];
        else if (~genpc_freeze && ~icpu_rty_i && ~genpc_refetch)
            pcreg <= pc[31:2];
    end

    // genpc_refetch_r sequential update
    always @(posedge clk or posedge rst) begin
        if (rst)
            genpc_refetch_r <= 1'b0;
        else
            genpc_refetch_r <= genpc_refetch;
    end

endmodule

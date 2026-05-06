module or1200_lsu(
    // Internal i/f
    input [31:0] addrbase,
    input [31:0] addrofs,
    input [3:0] lsu_op,
    input [31:0] lsu_datain,
    output [31:0] lsu_dataout,
    output lsu_stall,
    output lsu_unstall,
    input du_stall,
    output except_align,
    output except_dtlbmiss,
    output except_dmmufault,
    output except_dbuserr,

    // External i/f to DC
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output reg [3:0] dcpu_sel_o, // declared as reg for always block assignment
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i,
    input [3:0] dcpu_tag_i
);

    // Local parameters for data-side tags (typical OR1200 values)
    localparam OR1200_DTAG_ND  = 4'd2; // Normal data access
    localparam OR1200_DTAG_IDLE= 4'd0; // Idle
    localparam OR1200_DTAG_TE  = 4'd1; // TLB miss
    localparam OR1200_DTAG_PE  = 4'd3; // MMU protection
    localparam OR1200_DTAG_BE  = 4'd4; // Bus error

    // Internal wires
    wire [31:0] adr;
    wire [1:0] mem2reg_addr;
    wire except_align_w; // intermediate for alignment check

    // Effective address
    assign adr = addrbase + addrofs;
    assign dcpu_adr_o = adr;
    assign mem2reg_addr = adr[1:0];

    // Write enable
    assign dcpu_we_o = lsu_op[3];

    // Byte select and alignment exception generation
    always @(*) begin
        // Default values
        dcpu_sel_o = 4'b0000;
        except_align_w = 1'b0;

        case (lsu_op)
            // Byte accesses: SB, LBZ, LBS (assuming opcodes with size bits 00)
            // The exact opcode values are not specified; we assume bits [2:1] encode size:
            // 00 = byte, 01 = halfword, 10 = word.
            // Here we check only the lower two bits of lsu_op for simplicity; adjust if needed.
            // Instead, we can detect byte accesses by checking that the operation is not halfword or word.
            // We will use the same pattern as in dcpu_sel_o generation.
            4'b0000? : // Placeholder; actual will be coded differently
        endcase
    end

    // Alternative: Use separate always block for byte/halfword/word detection based on known OR1200 encoding.
    // Since specific opcodes are not provided, we design a generic decoder using lsu_op[2:1] as size.
    // This is consistent with common OR1200 design.
    always @(*) begin
        // Defaults
        dcpu_sel_o = 4'b0000;
        except_align_w = 1'b0;

        // Size classification: 00=byte, 01=halfword, 10=word, 11=reserved
        case (lsu_op[2:1])
            2'b00: begin // Byte operations
                case (mem2reg_addr)
                    2'b00: dcpu_sel_o = 4'b1000;
                    2'b01: dcpu_sel_o = 4'b0100;
                    2'b10: dcpu_sel_o = 4'b0010;
                    2'b11: dcpu_sel_o = 4'b0001;
                endcase
                // No alignment check for bytes
            end
            2'b01: begin // Halfword operations
                case (mem2reg_addr)
                    2'b00: dcpu_sel_o = 4'b1100;
                    2'b10: dcpu_sel_o = 4'b0011;
                    default: begin
                        dcpu_sel_o = 4'b0000;
                        except_align_w = 1'b1; // misaligned halfword
                    end
                endcase
            end
            2'b10: begin // Word operations
                if (mem2reg_addr == 2'b00)
                    dcpu_sel_o = 4'b1111;
                else begin
                    dcpu_sel_o = 4'b0000;
                    except_align_w = 1'b1; // misaligned word
                end
            end
            default: begin
                // Reserved or unknown opcode; no request will be issued
                dcpu_sel_o = 4'b0000;
            end
        endcase
    end

    assign except_align = except_align_w;

    // Request generation
    assign lsu_unstall = dcpu_ack_i;
    assign dcpu_cycstb_o = (|lsu_op) & (~du_stall) & (~lsu_unstall) & (~except_align);

    // Tag output
    assign dcpu_tag_o = dcpu_cycstb_o ? OR1200_DTAG_ND : OR1200_DTAG_IDLE;

    // Stall output
    assign lsu_stall = dcpu_rty_i & dcpu_cycstb_o;

    // Exception classification from downstream
    reg except_dtlbmiss_r, except_dmmufault_r, except_dbuserr_r;
    always @(*) begin
        except_dtlbmiss_r = 1'b0;
        except_dmmufault_r = 1'b0;
        except_dbuserr_r  = 1'b0;
        if (dcpu_err_i) begin
            case (dcpu_tag_i)
                OR1200_DTAG_TE: except_dtlbmiss_r = 1'b1;
                OR1200_DTAG_PE: except_dmmufault_r = 1'b1;
                OR1200_DTAG_BE: except_dbuserr_r  = 1'b1;
                default: ;
            endcase
        end
    end
    assign except_dtlbmiss = except_dtlbmiss_r;
    assign except_dmmufault = except_dmmufault_r;
    assign except_dbuserr  = except_dbuserr_r;

    // Instantiate alignment submodules
    or1200_mem2reg u_mem2reg(
        .addr_low (mem2reg_addr),
        .lsu_op   (lsu_op),
        .dcpu_dat_i(dcpu_dat_i),
        .lsu_dataout(lsu_dataout)
    );

    or1200_reg2mem u_reg2mem(
        .addr_low (mem2reg_addr),
        .lsu_op   (lsu_op),
        .lsu_datain(lsu_datain),
        .dcpu_dat_o(dcpu_dat_o)
    );

endmodule

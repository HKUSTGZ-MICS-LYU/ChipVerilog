module or1200_except (
    input clk,
    input rst,
    input sig_ibuserr,
    input sig_dbuserr,
    input sig_illegal,
    input sig_align,
    input sig_range,
    input sig_dtlbmiss,
    input sig_dmmufault,
    input sig_int,
    input sig_syscall,
    input sig_trap,
    input sig_itlbmiss,
    input sig_immufault,
    input sig_tick,
    input branch_taken,
    input genpc_freeze,
    input id_freeze,
    input ex_freeze,
    input wb_freeze,
    input if_stall,
    input [31:0] if_pc,
    output [31:0] id_pc,
    output [31:2] lr_sav,
    output flushpipe,
    output extend_flush,
    output [3:0] except_type,
    output except_start,
    output except_started,
    output [12:0] except_stop,
    input ex_void,
    output [31:0] spr_dat_ppc,
    output [31:0] spr_dat_npc,
    input [31:0] datain,
    input [13:0] du_dsr,
    input epcr_we,
    input eear_we,
    input esr_we,
    input pc_we,
    output [31:0] epcr,
    output [31:0] eear,
    output [15:0] esr,
    input sr_we,
    input [15:0] to_sr,
    input [15:0] sr,
    input [31:0] lsu_addr,
    output abort_ex,
    input icpu_ack_i,
    input icpu_err_i,
    input dcpu_ack_i,
    input dcpu_err_i
);

    localparam IDLE = 3'b000;
    localparam FLU1 = 3'b001;
    localparam FLU2 = 3'b010;
    localparam FLU3 = 3'b011;
    localparam FLU4 = 3'b100;
    localparam FLU5 = 3'b101;

    localparam OR1200_EXCEPT_NONE = 4'd0;
    localparam EXCEPT_TICK       = 4'd1;
    localparam EXCEPT_INT        = 4'd2;
    localparam EXCEPT_ITLBMISS   = 4'd3;
    localparam EXCEPT_IMMUFAULT  = 4'd4;
    localparam EXCEPT_IBUSERR    = 4'd5;
    localparam EXCEPT_ILLEGAL    = 4'd6;
    localparam EXCEPT_ALIGN      = 4'd7;
    localparam EXCEPT_DTLBMISS   = 4'd8;
    localparam EXCEPT_DMMUFAULT  = 4'd9;
    localparam EXCEPT_DBUSERR    = 4'd10;
    localparam EXCEPT_RANGE      = 4'd11;
    localparam EXCEPT_TRAP       = 4'd12;
    localparam EXCEPT_SYSCALL    = 4'd13;

    // registers
    reg [2:0] state;
    reg [31:0] id_pc_reg, ex_pc, wb_pc;
    reg [2:0] id_exceptflags, ex_exceptflags;
    reg [31:0] epcr_reg, eear_reg;
    reg [15:0] esr_reg;
    reg extend_flush_reg;
    reg extend_flush_last;
    reg [3:0] except_type_reg;
    reg ex_dslot, delayed1_ex_dslot, delayed2_ex_dslot;
    reg id_dslot;
    reg pre_ex_dslot;
    reg [2:0] delayed_iee, delayed_tee;

    // combinational wires
    wire [12:0] except_trig;
    wire except_flushpipe;
    wire int_pending;
    wire tick_pending;
    wire [3:0] except_type_sel;
    wire [31:0] epcr_sel, eear_sel;
    wire [2:0] next_state;

    // except_trig: priority order from bit12 (tick) to bit0 (syscall)
    assign except_trig[12] = sig_tick & ~du_dsr[12];
    assign except_trig[11] = sig_int & ~du_dsr[11];
    assign except_trig[10] = sig_itlbmiss & ~du_dsr[10];
    assign except_trig[9] = sig_immufault & ~du_dsr[9];
    assign except_trig[8] = sig_ibuserr & ~du_dsr[8];
    assign except_trig[7] = sig_illegal & ~du_dsr[7];
    assign except_trig[6] = sig_align & ~du_dsr[6];
    assign except_trig[5] = sig_dtlbmiss & ~du_dsr[5];
    assign except_trig[4] = sig_dmmufault & ~du_dsr[4];
    assign except_trig[3] = sig_dbuserr & ~du_dsr[3];
    assign except_trig[2] = sig_range & ~du_dsr[2];
    assign except_trig[1] = sig_trap & ~du_dsr[1] & ~ex_freeze;
    assign except_trig[0] = sig_syscall & ~du_dsr[0] & ~ex_freeze;

    // except_stop same ordering but gated by du_dsr
    assign except_stop[12] = sig_tick & du_dsr[12];
    assign except_stop[11] = sig_int & du_dsr[11];
    assign except_stop[10] = sig_itlbmiss & du_dsr[10];
    assign except_stop[9] = sig_immufault & du_dsr[9];
    assign except_stop[8] = sig_ibuserr & du_dsr[8];
    assign except_stop[7] = sig_illegal & du_dsr[7];
    assign except_stop[6] = sig_align & du_dsr[6];
    assign except_stop[5] = sig_dtlbmiss & du_dsr[5];
    assign except_stop[4] = sig_dmmufault & du_dsr[4];
    assign except_stop[3] = sig_dbuserr & du_dsr[3];
    assign except_stop[2] = sig_range & du_dsr[2];
    assign except_stop[1] = sig_trap & du_dsr[1];
    assign except_stop[0] = sig_syscall & du_dsr[0];

    // int_pending
    assign int_pending = sig_int & sr[2] & delayed_iee[2] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

    // tick_pending
    assign tick_pending = sig_tick & sr[1] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

    // except_flushpipe
    assign except_flushpipe = (|except_trig) & (state == IDLE);

    // flushpipe
    assign flushpipe = except_flushpipe | pc_we | extend_flush_reg;

    // abort_ex
    assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;

    // lr_sav
    assign lr_sav = ex_pc[31:2];

    // spr_dat_ppc
    assign spr_dat_ppc = wb_pc;

    // spr_dat_npc
    assign spr_dat_npc = ex_void ? id_pc_reg : ex_pc;

    // except_start and except_started
    assign except_start = (except_type_reg != OR1200_EXCEPT_NONE) & extend_flush_reg;
    assign except_started = extend_flush_reg & except_start;

    // output connections
    assign id_pc = id_pc_reg;
    assign epcr = epcr_reg;
    assign eear = eear_reg;
    assign esr = esr_reg;
    assign extend_flush = extend_flush_reg;
    assign except_type = except_type_reg;

    // Pipeline PC and exception flags
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_pc_reg <= 32'b0;
            id_exceptflags <= 3'b0;
            ex_pc <= 32'b0;
            ex_exceptflags <= 3'b0;
            wb_pc <= 32'b0;
            id_dslot <= 1'b0;
            pre_ex_dslot <= 1'b0;
            ex_dslot <= 1'b0;
            delayed1_ex_dslot <= 1'b0;
            delayed2_ex_dslot <= 1'b0;
        end else begin
            // ID stage update
            if (!id_freeze) begin
                id_pc_reg <= flushpipe ? 32'b0 : if_pc;
                id_exceptflags <= flushpipe ? 3'b0 : {sig_ibuserr, sig_itlbmiss, sig_immufault};
                id_dslot <= flushpipe ? 1'b0 : (branch_taken & ~ex_freeze);
            end else if (flushpipe) begin
                id_pc_reg <= 32'b0;
                id_exceptflags <= 3'b0;
                id_dslot <= 1'b0;
            end

            // pre_ex_dslot for pipeline to ex_dslot
            if (!ex_freeze) begin
                pre_ex_dslot <= flushpipe ? 1'b0 : id_dslot;
            end else if (flushpipe) begin
                pre_ex_dslot <= 1'b0;
            end

            // EX stage update
            if (!ex_freeze) begin
                ex_pc <= flushpipe ? 32'b0 : id_pc_reg;
                ex_exceptflags <= flushpipe ? 3'b0 : id_exceptflags;
                ex_dslot <= flushpipe ? 1'b0 : pre_ex_dslot;
                delayed1_ex_dslot <= flushpipe ? 1'b0 : ex_dslot;
                delayed2_ex_dslot <= flushpipe ? 1'b0 : delayed1_ex_dslot;
            end else if (flushpipe) begin
                ex_pc <= 32'b0;
                ex_exceptflags <= 3'b0;
                ex_dslot <= 1'b0;
                delayed1_ex_dslot <= 1'b0;
                delayed2_ex_dslot <= 1'b0;
            end

            // WB stage update
            if (!wb_freeze) begin
                wb_pc <= ex_pc;
            end
        end
    end

    // delayed_iee and delayed_tee shift registers
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            delayed_iee <= 3'b0;
            delayed_tee <= 3'b0;
        end else begin
            delayed_iee <= {delayed_iee[1:0], sr[2]};
            delayed_tee <= {delayed_tee[1:0], sr[1]};
        end
    end

    // Exception type, EPCR, EEAR selection combinational
    always @(*) begin
        casex (except_trig)
            13'b1_xxxxxxxxxxxx: begin
                except_type_sel = EXCEPT_TICK;
                epcr_sel = ex_dslot ? wb_pc : id_pc_reg;
                eear_sel = 32'b0;
            end
            13'b01_xxxxxxxxxxx: begin
                except_type_sel = EXCEPT_INT;
                epcr_sel = ex_dslot ? wb_pc : id_pc_reg;
                eear_sel = 32'b0;
            end
            13'b001_xxxxxxxxxx: begin
                except_type_sel = EXCEPT_ITLBMISS;
                epcr_sel = ex_dslot ? wb_pc : ex_pc;
                eear_sel = ex_pc;
            end
            13'b0001_xxxxxxxxx: begin
                except_type_sel = EXCEPT_IMMUFAULT;
                epcr_sel = ex_dslot ? wb_pc : id_pc_reg;
                eear_sel = ex_dslot ? ex_pc : id_pc_reg;
            end
            13'b00001_xxxxxxxx: begin
                except_type_sel = EXCEPT_IBUSERR;
                epcr_sel = ex_dslot ? wb_pc : ex_pc;
                eear_sel = ex_dslot ? wb_pc : ex_pc;
            end
            13'b000001_xxxxxxx: begin
                except_type_sel = EXCEPT_ILLEGAL;
                epcr_sel = ex_dslot ? wb_pc : ex_pc;
                eear_sel = ex_pc;
            end
            13'b0000001_xxxxxx: begin
                except_type_sel = EXCEPT_ALIGN;
                epcr_sel = ex_dslot ? wb_pc : ex_pc;
                eear_sel = lsu_addr;
            end
            13'b00000001_xxxxx: begin
                except_type_sel = EXCEPT_DTLBMISS;
                epcr_sel = ex_dslot ? wb_pc : ex_pc;
                eear_sel = lsu_addr;
            end
            13'b000000001_xxxx: begin
                except_type_sel = EXCEPT_DMMUFAULT;
                epcr_sel = ex_dslot ? wb_pc : ex_pc;
                eear_sel = lsu_addr;
            end
            13'b0000000001_xxx: begin
                except_type_sel = EXCEPT_DBUSERR;
                epcr_sel = ex_dslot ? wb_pc : ex_pc;
                eear_sel = lsu_addr;
            end
            13'b00000000001_xx: begin
                except_type_sel = EXCEPT_RANGE;
                epcr_sel = ex_dslot ? wb_pc : id_pc_reg;
                eear_sel = 32'b0;
            end
            13'b000000000001_x: begin
                except_type_sel = EXCEPT_TRAP;
                epcr_sel = ex_dslot ? wb_pc : ex_pc;
                eear_sel = 32'b0;
            end
            13'b0000000000001: begin
                except_type_sel = EXCEPT_SYSCALL;
                epcr_sel = ex_dslot ? wb_pc : id_pc_reg;
                eear_sel = 32'b0;
            end
            default: begin
                except_type_sel = OR1200_EXCEPT_NONE;
                epcr_sel = 32'b0;
                eear_sel = 32'b0;
            end
        endcase
    end

    // FSM next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (except_flushpipe) begin
                    next_state = FLU1;
                end else if (pc_we) begin
                    next_state = FLU1;
                end else begin
                    next_state = IDLE;
                end
            end
            FLU1: begin
                if (icpu_ack_i | icpu_err_i | genpc_freeze) begin
                    next_state = FLU2;
                end else begin
                    next_state = FLU1;
                end
            end
            FLU2: begin
                // For trap exception, return to IDLE directly
                if (except_type_reg == EXCEPT_TRAP) begin
                    next_state = IDLE;
                end else begin
                    next_state = FLU3;
                end
            end
            FLU3: begin
                next_state = FLU4;
            end
            FLU4: begin
                next_state = FLU5;
            end
            FLU5: begin
                if (!if_stall && !id_freeze) begin
                    next_state = IDLE;
                end else begin
                    next_state = FLU5;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic for FSM and registers
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            except_type_reg <= OR1200_EXCEPT_NONE;
            extend_flush_reg <= 1'b0;
            extend_flush_last <= 1'b0;
            epcr_reg <= 32'b0;
            eear_reg <= 32'b0;
            esr_reg <= {1'b1, {14{1'b0}}, 1'b1}; // 16'h8001
        end else begin
            state <= next_state;

            // Default: keep values
            extend_flush_reg <= extend_flush_reg;
            except_type_reg <= except_type_reg;
            epcr_reg <= epcr_reg;
            eear_reg <= eear_reg;
            esr_reg <= esr_reg;

            case (state)
                IDLE: begin
                    if (except_flushpipe) begin
                        // Take exception
                        if (sr_we) begin
                            esr_reg <= to_sr;
                        end else begin
                            esr_reg <= sr;
                        end
                        except_type_reg <= except_type_sel;
                        epcr_reg <= epcr_sel;
                        eear_reg <= eear_sel;
                        extend_flush_reg <= 1'b1;
                    end else if (pc_we) begin
                        // Flush without exception
                        extend_flush_reg <= 1'b1;
                        // except_type, epcr, eear unchanged
                    end else begin
                        // SPR writes if idle
                        if (epcr_we) epcr_reg <= datain;
                        if (eear_we) eear_reg <= datain;
                        if (esr_we) esr_reg <= {1'b1, datain[14:0]};
                    end
                end
                FLU1: begin
                    // extend_flush already set; remain set
                end
                FLU2: begin
                    if (except_type_reg == EXCEPT_TRAP) begin
                        // Return to IDLE
                        extend_flush_reg <= 1'b0;
                        extend_flush_last <= 1'b0;
                        except_type_reg <= OR1200_EXCEPT_NONE;
                    end
                end
                FLU3: begin
                    // no change
                end
                FLU4: begin
                    // Deassert extend_flush
                    extend_flush_reg <= 1'b0;
                end
                FLU5: begin
                    if (!if_stall && !id_freeze) begin
                        except_type_reg <= OR1200_EXCEPT_NONE;
                    end
                end
            endcase
        end
    end

    // extend_flush_last is declared but not used, assign 0
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            extend_flush_last <= 1'b0;
        end else begin
            extend_flush_last <= 1'b0;
        end
    end

endmodule

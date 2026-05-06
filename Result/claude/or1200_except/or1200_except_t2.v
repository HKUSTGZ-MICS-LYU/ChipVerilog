module or1200_except(
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
    output reg [31:0] id_pc,
    output [31:2] lr_sav,
    output reg flushpipe,
    output reg extend_flush,
    output reg [3:0] except_type,
    output reg except_start,
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
    output reg [31:0] epcr,
    output reg [31:0] eear,
    output reg [15:0] esr,
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

    localparam STATE_IDLE = 3'b000;
    localparam STATE_FLU1 = 3'b001;
    localparam STATE_FLU2 = 3'b010;
    localparam STATE_FLU3 = 3'b011;
    localparam STATE_FLU4 = 3'b100;
    localparam STATE_FLU5 = 3'b101;

    localparam EXCEPT_NONE  = 4'b0000;
    localparam EXCEPT_TICK  = 4'b0001;
    localparam EXCEPT_INT   = 4'b0010;
    localparam EXCEPT_ITLB  = 4'b0011;
    localparam EXCEPT_IMMU  = 4'b0100;
    localparam EXCEPT_IBUSERR = 4'b0101;
    localparam EXCEPT_ILLEGAL  = 4'b0110;
    localparam EXCEPT_ALIGN = 4'b0111;
    localparam EXCEPT_DTLB  = 4'b1000;
    localparam EXCEPT_DMMU  = 4'b1001;
    localparam EXCEPT_DBUSERR = 4'b1010;
    localparam EXCEPT_RANGE = 4'b1011;
    localparam EXCEPT_TRAP  = 4'b1100;
    localparam EXCEPT_SYSCALL = 4'b1101;

    reg [31:0] ex_pc;
    reg [31:0] wb_pc;
    reg [2:0] id_exceptflags;
    reg [2:0] ex_exceptflags;
    reg [2:0] state;
    reg ex_dslot;
    reg delayed1_ex_dslot;
    reg delayed2_ex_dslot;
    reg [2:0] delayed_iee;
    reg [2:0] delayed_tee;

    wire [12:0] except_trig;
    wire except_flushpipe;
    wire int_pending;
    wire tick_pending;

    assign lr_sav = ex_pc[31:2];
    assign spr_dat_ppc = wb_pc;
    assign spr_dat_npc = (ex_pc == 32'h0) ? id_pc : ex_pc;
    assign except_started = extend_flush & except_start;
    assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;

    assign int_pending = (sr[16] & delayed_iee[0]) & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;
    assign tick_pending = (sr[17] & delayed_tee[0]) & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

    assign except_trig[0] = (tick_pending & du_dsr[12]) ? sig_tick : 1'b0;
    assign except_trig[1] = (int_pending & du_dsr[11]) ? sig_int : 1'b0;
    assign except_trig[2] = (du_dsr[10]) ? sig_immufault : 1'b0;
    assign except_trig[3] = (du_dsr[9]) ? sig_itlbmiss : 1'b0;
    assign except_trig[4] = (du_dsr[8]) ? sig_ibuserr : 1'b0;
    assign except_trig[5] = (du_dsr[7]) ? sig_illegal : 1'b0;
    assign except_trig[6] = (du_dsr[6]) ? sig_align : 1'b0;
    assign except_trig[7] = (du_dsr[5]) ? sig_dtlbmiss : 1'b0;
    assign except_trig[8] = (du_dsr[4]) ? sig_dmmufault : 1'b0;
    assign except_trig[9] = (du_dsr[3]) ? sig_dbuserr : 1'b0;
    assign except_trig[10] = (du_dsr[2]) ? sig_range : 1'b0;
    assign except_trig[11] = (du_dsr[1]) ? sig_trap : 1'b0;
    assign except_trig[12] = (du_dsr[0]) ? sig_syscall : 1'b0;

    assign except_flushpipe = (except_trig != 13'b0) & (state == STATE_IDLE);

    assign except_stop[0] = (du_dsr[12] & sig_tick);
    assign except_stop[1] = (du_dsr[11] & sig_int);
    assign except_stop[2] = (du_dsr[10] & sig_immufault);
    assign except_stop[3] = (du_dsr[9] & sig_itlbmiss);
    assign except_stop[4] = (du_dsr[8] & sig_ibuserr);
    assign except_stop[5] = (du_dsr[7] & sig_illegal);
    assign except_stop[6] = (du_dsr[6] & sig_align);
    assign except_stop[7] = (du_dsr[5] & sig_dtlbmiss);
    assign except_stop[8] = (du_dsr[4] & sig_dmmufault);
    assign except_stop[9] = (du_dsr[3] & sig_dbuserr);
    assign except_stop[10] = (du_dsr[2] & sig_range);
    assign except_stop[11] = (du_dsr[1] & sig_trap);
    assign except_stop[12] = (du_dsr[0] & sig_syscall);

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            except_type <= EXCEPT_NONE;
            extend_flush <= 1'b0;
            epcr <= 32'b0;
            eear <= 32'b0;
            esr <= 16'h0001;
            id_pc <= 32'b0;
            ex_pc <= 32'b0;
            wb_pc <= 32'b0;
            ex_dslot <= 1'b0;
            delayed1_ex_dslot <= 1'b0;
            delayed2_ex_dslot <= 1'b0;
            id_exceptflags <= 3'b0;
            ex_exceptflags <= 3'b0;
            state <= STATE_IDLE;
            flushpipe <= 1'b0;
            except_start <= 1'b0;
            delayed_iee <= 3'b0;
            delayed_tee <= 3'b0;
        end else begin
            delayed_iee <= {delayed_iee[1:0], sr[16]};
            delayed_tee <= {delayed_tee[1:0], sr[17]};

            except_start <= 1'b0;
            flushpipe <= 1'b0;

            id_pc <= if_pc;
            if (~id_freeze) begin
                ex_pc <= id_pc;
                ex_exceptflags <= id_exceptflags;
            end
            if (~wb_freeze) begin
                wb_pc <= ex_pc;
            end

            if (~ex_freeze) begin
                ex_dslot <= branch_taken;
            end
            delayed1_ex_dslot <= ex_dslot;
            delayed2_ex_dslot <= delayed1_ex_dslot;

            id_exceptflags[0] <= sig_ibuserr;
            id_exceptflags[1] <= sig_itlbmiss;
            id_exceptflags[2] <= sig_immufault;

            case (state)
                STATE_IDLE: begin
                    if (epcr_we) epcr <= datain;
                    if (eear_we) eear <= datain;
                    if (esr_we) esr <= {1'b1, datain[14:0]};

                    if (except_flushpipe) begin
                        flushpipe <= 1'b1;
                        extend_flush <= 1'b1;
                        esr <= sr_we ? to_sr : sr;

                        if (tick_pending & du_dsr[12]) begin
                            except_type <= EXCEPT_TICK;
                            epcr <= delayed2_ex_dslot ? wb_pc : ex_pc;
                        end else if (int_pending & du_dsr[11]) begin
                            except_type <= EXCEPT_INT;
                            epcr <= delayed2_ex_dslot ? wb_pc : ex_pc;
                        end else if (sig_immufault & du_dsr[10]) begin
                            except_type <= EXCEPT_IMMU;
                            epcr <= if_pc;
                            eear <= if_pc;
                        end else if (sig_itlbmiss & du_dsr[9]) begin
                            except_type <= EXCEPT_ITLB;
                            epcr <= if_pc;
                            eear <= if_pc;
                        end else if (sig_ibuserr & du_dsr[8]) begin
                            except_type <= EXCEPT_IBUSERR;
                            epcr <= if_pc;
                        end else if (sig_illegal & du_dsr[7]) begin
                            except_type <= EXCEPT_ILLEGAL;
                            epcr <= ex_pc;
                        end else if (sig_align & du_dsr[6]) begin
                            except_type <= EXCEPT_ALIGN;
                            epcr <= ex_pc;
                            eear <= lsu_addr;
                        end else if (sig_dtlbmiss & du_dsr[5]) begin
                            except_type <= EXCEPT_DTLB;
                            epcr <= delayed2_ex_dslot ? wb_pc : ex_pc;
                            eear <= lsu_addr;
                        end else if (sig_dmmufault & du_dsr[4]) begin
                            except_type <= EXCEPT_DMMU;
                            epcr <= delayed2_ex_dslot ? wb_pc : ex_pc;
                            eear <= lsu_addr;
                        end else if (sig_dbuserr & du_dsr[3]) begin
                            except_type <= EXCEPT_DBUSERR;
                            epcr <= delayed2_ex_dslot ? wb_pc : ex_pc;
                            eear <= lsu_addr;
                        end else if (sig_range & du_dsr[2]) begin
                            except_type <= EXCEPT_RANGE;
                            epcr <= ex_pc;
                        end else if (sig_trap & du_dsr[1]) begin
                            except_type <= EXCEPT_TRAP;
                            epcr <= ex_pc;
                        end else if (sig_syscall & du_dsr[0]) begin
                            except_type <= EXCEPT_SYSCALL;
                            epcr <= ex_pc;
                        end else begin
                            except_type <= EXCEPT_NONE;
                        end

                        state <= STATE_FLU1;
                    end else if (pc_we) begin
                        flushpipe <= 1'b1;
                    end
                end

                STATE_FLU1: begin
                    extend_flush <= 1'b1;
                    state <= STATE_FLU2;
                end

                STATE_FLU2: begin
                    extend_flush <= 1'b1;
                    state <= STATE_FLU3;
                end

                STATE_FLU3: begin
                    extend_flush <= 1'b1;
                    state <= STATE_FLU4;
                end

                STATE_FLU4: begin
                    extend_flush <= 1'b1;
                    state <= STATE_FLU5;
                end

                STATE_FLU5: begin
                    extend_flush <= 1'b1;
                    except_start <= (except_type != EXCEPT_NONE);
                    if (~if_stall & ~id_freeze) begin
                        extend_flush <= 1'b0;
                        except_type <= EXCEPT_NONE;
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule

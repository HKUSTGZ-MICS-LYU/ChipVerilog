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
    localparam STATE_IDLE = 3'd0;
    localparam STATE_FLU1 = 3'd1;
    localparam STATE_FLU2 = 3'd2;
    localparam STATE_FLU3 = 3'd3;
    localparam STATE_FLU4 = 3'd4;
    localparam STATE_FLU5 = 3'd5;

    localparam EXCEPT_NONE   = 4'd0;
    localparam EXCEPT_TICK   = 4'd1;
    localparam EXCEPT_INT    = 4'd2;
    localparam EXCEPT_ITLBM  = 4'd3;
    localparam EXCEPT_IMMUF  = 4'd4;
    localparam EXCEPT_IBUS   = 4'd5;
    localparam EXCEPT_ILLEG  = 4'd6;
    localparam EXCEPT_ALIGN  = 4'd7;
    localparam EXCEPT_DTLBM  = 4'd8;
    localparam EXCEPT_DMMUF  = 4'd9;
    localparam EXCEPT_DBUS   = 4'd10;
    localparam EXCEPT_RANGE  = 4'd11;
    localparam EXCEPT_TRAP   = 4'd12;
    localparam EXCEPT_SYSCALL= 4'd13;

    reg [31:0] id_pc_reg, ex_pc_reg, wb_pc_reg;
    reg [2:0] id_exceptflags, ex_exceptflags;
    reg [2:0] state;
    reg extend_flush_reg;
    reg extend_flush_last;
    reg [3:0] except_type_reg;
    reg [31:0] epcr_reg, eear_reg;
    reg [15:0] esr_reg;
    reg ex_dslot, delayed1_ex_dslot, delayed2_ex_dslot;
    reg [2:0] delayed_iee, delayed_tee;

    wire [12:0] except_trig;
    wire except_flushpipe;
    wire int_pending, tick_pending;

    // Pipeline outputs
    assign id_pc = id_pc_reg;
    assign lr_sav = ex_pc_reg[31:2];
    assign flushpipe = except_flushpipe | pc_we | extend_flush_reg;
    assign extend_flush = extend_flush_reg;
    assign except_type = except_type_reg;
    assign except_start = (except_type_reg != EXCEPT_NONE) & extend_flush_reg;
    assign except_started = extend_flush_reg & except_start;
    assign spr_dat_ppc = wb_pc_reg;
    assign spr_dat_npc = ex_void ? id_pc_reg : ex_pc_reg;
    assign epcr = epcr_reg;
    assign eear = eear_reg;
    assign esr = esr_reg;
    assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;

    // Int and tick pending
    assign int_pending = sig_int & sr[2] & delayed_iee[2] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;
    assign tick_pending = sig_tick & sr[1] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

    // Exception trigger vector (priority order: bit12 highest to bit0 lowest)
    assign except_trig[12] = tick_pending & ~du_dsr[12];
    assign except_trig[11] = int_pending & ~du_dsr[11];
    assign except_trig[10] = sig_itlbmiss & ~du_dsr[10];
    assign except_trig[9]  = sig_immufault & ~du_dsr[9];
    assign except_trig[8]  = sig_ibuserr & ~du_dsr[8];
    assign except_trig[7]  = sig_illegal & ~du_dsr[7];
    assign except_trig[6]  = sig_align & ~du_dsr[6];
    assign except_trig[5]  = sig_dtlbmiss & ~du_dsr[5];
    assign except_trig[4]  = sig_dmmufault & ~du_dsr[4];
    assign except_trig[3]  = sig_dbuserr & ~du_dsr[3];
    assign except_trig[2]  = sig_range & ~du_dsr[2];
    assign except_trig[1]  = (sig_trap & ~ex_freeze) & ~du_dsr[1];
    assign except_trig[0]  = (sig_syscall & ~ex_freeze) & ~du_dsr[0];

    assign except_flushpipe = |except_trig & (state == STATE_IDLE);

    // Debug stop vector
    assign except_stop[12] = tick_pending & du_dsr[12];
    assign except_stop[11] = int_pending & du_dsr[11];
    assign except_stop[10] = sig_itlbmiss & du_dsr[10];
    assign except_stop[9]  = sig_immufault & du_dsr[9];
    assign except_stop[8]  = sig_ibuserr & du_dsr[8];
    assign except_stop[7]  = sig_illegal & du_dsr[7];
    assign except_stop[6]  = sig_align & du_dsr[6];
    assign except_stop[5]  = sig_dtlbmiss & du_dsr[5];
    assign except_stop[4]  = sig_dmmufault & du_dsr[4];
    assign except_stop[3]  = sig_dbuserr & du_dsr[3];
    assign except_stop[2]  = sig_range & du_dsr[2];
    assign except_stop[1]  = (sig_trap & ~ex_freeze) & du_dsr[1];
    assign except_stop[0]  = (sig_syscall & ~ex_freeze) & du_dsr[0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_pc_reg <= 32'd0;
            ex_pc_reg <= 32'd0;
            wb_pc_reg <= 32'd0;
            id_exceptflags <= 3'd0;
            ex_exceptflags <= 3'd0;
            ex_dslot <= 1'b0;
            delayed1_ex_dslot <= 1'b0;
            delayed2_ex_dslot <= 1'b0;
            delayed_iee <= 3'd0;
            delayed_tee <= 3'd0;
            extend_flush_reg <= 1'b0;
            extend_flush_last <= 1'b0;
            state <= STATE_IDLE;
            except_type_reg <= EXCEPT_NONE;
            epcr_reg <= 32'd0;
            eear_reg <= 32'd0;
            esr_reg <= {1'b1, 14'd0, 1'b1};
        end else begin
            // Pipeline stage 1: IF to ID
            if (flushpipe) begin
                id_pc_reg <= 32'd0;
                id_exceptflags <= 3'd0;
            end else if (!id_freeze) begin
                id_pc_reg <= if_pc;
                id_exceptflags <= {sig_ibuserr, sig_itlbmiss, sig_immufault};
            end

            // Pipeline stage 2: ID to EX
            if (flushpipe) begin
                ex_pc_reg <= 32'd0;
                ex_exceptflags <= 3'd0;
            end else if (!ex_freeze) begin
                ex_pc_reg <= id_pc_reg;
                ex_exceptflags <= id_exceptflags;
            end

            // Pipeline stage 3: EX to WB
            if (!wb_freeze) begin
                wb_pc_reg <= ex_pc_reg;
            end

            // Delay slot tracking
            if (!ex_freeze) begin
                ex_dslot <= branch_taken;
            end
            delayed1_ex_dslot <= ex_dslot;
            delayed2_ex_dslot <= delayed1_ex_dslot;

            // Delayed interrupt and tick enable bits
            delayed_iee <= {delayed_iee[1:0], sr[2]};
            delayed_tee <= {delayed_tee[1:0], sr[1]};

            // Exception FSM and state saving
            case (state)
                STATE_IDLE: begin
                    if (except_flushpipe) begin
                        // Latch ESR
                        if (sr_we) esr_reg <= to_sr;
                        else esr_reg <= sr;
                        // Resolve exception priority and save state
                        casex (except_trig)
                            13'b1xxxxxxxxxxxx: begin // tick
                                except_type_reg <= EXCEPT_TICK;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= id_pc_reg;
                                // EEAR not set
                            end
                            13'b01xxxxxxxxxxx: begin // int
                                except_type_reg <= EXCEPT_INT;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= id_pc_reg;
                            end
                            13'b001xxxxxxxxxx: begin // itlbmiss
                                except_type_reg <= EXCEPT_ITLBM;
                                eear_reg <= ex_pc_reg;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= ex_pc_reg;
                            end
                            13'b0001xxxxxxxxx: begin // immufault
                                except_type_reg <= EXCEPT_IMMUF;
                                if (ex_dslot) eear_reg <= ex_pc_reg;
                                else eear_reg <= id_pc_reg;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= id_pc_reg;
                            end
                            13'b00001xxxxxxxx: begin // ibuserr
                                except_type_reg <= EXCEPT_IBUS;
                                if (ex_dslot) begin
                                    epcr_reg <= wb_pc_reg;
                                    eear_reg <= wb_pc_reg;
                                end else begin
                                    epcr_reg <= ex_pc_reg;
                                    eear_reg <= ex_pc_reg;
                                end
                            end
                            13'b000001xxxxxxx: begin // illegal
                                except_type_reg <= EXCEPT_ILLEG;
                                eear_reg <= ex_pc_reg;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= ex_pc_reg;
                            end
                            13'b0000001xxxxxx: begin // align
                                except_type_reg <= EXCEPT_ALIGN;
                                eear_reg <= lsu_addr;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= ex_pc_reg;
                            end
                            13'b00000001xxxxx: begin // dtlbmiss
                                except_type_reg <= EXCEPT_DTLBM;
                                eear_reg <= lsu_addr;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= ex_pc_reg;
                            end
                            13'b000000001xxxx: begin // dmmufault
                                except_type_reg <= EXCEPT_DMMUF;
                                eear_reg <= lsu_addr;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= ex_pc_reg;
                            end
                            13'b0000000001xxx: begin // dbuserr
                                except_type_reg <= EXCEPT_DBUS;
                                eear_reg <= lsu_addr;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= ex_pc_reg;
                            end
                            13'b00000000001xx: begin // range
                                except_type_reg <= EXCEPT_RANGE;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= id_pc_reg;
                            end
                            13'b000000000001x: begin // trap
                                except_type_reg <= EXCEPT_TRAP;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= ex_pc_reg;
                            end
                            13'b0000000000001: begin // syscall
                                except_type_reg <= EXCEPT_SYSCALL;
                                if (ex_dslot) epcr_reg <= wb_pc_reg;
                                else epcr_reg <= id_pc_reg;
                            end
                            default: ;
                        endcase
                        state <= STATE_FLU1;
                        extend_flush_reg <= 1'b1;
                    end else if (pc_we) begin
                        state <= STATE_FLU1;
                        extend_flush_reg <= 1'b1;
                    end else begin
                        // SPR writes when idle
                        if (epcr_we) epcr_reg <= datain;
                        if (eear_we) eear_reg <= datain;
                        if (esr_we) esr_reg <= {1'b1, datain[14:0]};
                    end
                end

                STATE_FLU1: begin
                    if (icpu_ack_i | icpu_err_i | genpc_freeze) begin
                        state <= STATE_FLU2;
                    end
                end

                STATE_FLU2: begin
                    if (except_type_reg == EXCEPT_TRAP) begin
                        state <= STATE_IDLE;
                        extend_flush_reg <= 1'b0;
                        extend_flush_last <= 1'b0;
                        except_type_reg <= EXCEPT_NONE;
                    end else begin
                        state <= STATE_FLU3;
                    end
                end

                STATE_FLU3: begin
                    state <= STATE_FLU4;
                end

                STATE_FLU4: begin
                    state <= STATE_FLU5;
                    extend_flush_reg <= 1'b0;
                end

                STATE_FLU5: begin
                    if (!if_stall && !id_freeze) begin
                        state <= STATE_IDLE;
                        except_type_reg <= EXCEPT_NONE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule

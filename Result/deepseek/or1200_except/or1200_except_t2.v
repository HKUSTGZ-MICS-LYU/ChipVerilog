// or1200_except: Exception recognition and sequencing
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
    output flushpipe,
    output extend_flush,
    output reg [3:0] except_type,
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
    output reg [31:0] epcr,
    output reg [31:0] eear,
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

    // Exception type encodings
    localparam OR1200_EXCEPT_NONE      = 4'h0;
    localparam OR1200_EXCEPT_TICK      = 4'h1;
    localparam OR1200_EXCEPT_INT       = 4'h2;
    localparam OR1200_EXCEPT_ITLBMISS  = 4'h3;
    localparam OR1200_EXCEPT_IMMUFAULT = 4'h4;
    localparam OR1200_EXCEPT_IBUSERR   = 4'h5;
    localparam OR1200_EXCEPT_ILLEGAL   = 4'h6;
    localparam OR1200_EXCEPT_ALIGN     = 4'h7;
    localparam OR1200_EXCEPT_DTLBMISS  = 4'h8;
    localparam OR1200_EXCEPT_DMMUFAULT = 4'h9;
    localparam OR1200_EXCEPT_DBUSERR   = 4'hA;
    localparam OR1200_EXCEPT_RANGE     = 4'hB;
    localparam OR1200_EXCEPT_TRAP      = 4'hC;
    localparam OR1200_EXCEPT_SYSCALL   = 4'hD;

    // FSM states
    localparam IDLE = 3'd0;
    localparam FLU1 = 3'd1;
    localparam FLU2 = 3'd2;
    localparam FLU3 = 3'd3;
    localparam FLU4 = 3'd4;
    localparam FLU5 = 3'd5;

    // Exceptions priority order in except_trig
    localparam TRIG_TICK      = 12;
    localparam TRIG_INT       = 11;
    localparam TRIG_ITLBMISS  = 10;
    localparam TRIG_IMMUFAULT = 9;
    localparam TRIG_IBUSERR   = 8;
    localparam TRIG_ILLEGAL   = 7;
    localparam TRIG_ALIGN     = 6;
    localparam TRIG_DTLBMISS  = 5;
    localparam TRIG_DMMUFAULT = 4;
    localparam TRIG_DBUSERR   = 3;
    localparam TRIG_RANGE     = 2;
    localparam TRIG_TRAP      = 1;
    localparam TRIG_SYSCALL   = 0;

    // Pipeline registers
    reg [31:0] ex_pc;
    reg [31:0] wb_pc;
    reg [2:0] id_exceptflags;
    reg [2:0] ex_exceptflags;
    reg ex_dslot;
    reg delayed1_ex_dslot;
    reg delayed2_ex_dslot;

    // Exception FSM state
    reg [2:0] state;
    reg extend_flush_reg;
    reg extend_flush_last;

    // Exception status register
    reg [15:0] esr_reg;

    // Delayed enables
    reg [2:0] delayed_iee;
    reg [2:0] delayed_tee;

    // Internal signals
    wire int_pending;
    wire tick_pending;
    wire [12:0] except_trig;
    wire except_flushpipe;
    wire except_started_comb;

    // Pipeline PC tracking
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_pc <= 32'd0;
        end else if (flushpipe) begin
            id_pc <= 32'd0;
        end else if (!id_freeze) begin
            id_pc <= if_pc;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_pc <= 32'd0;
        end else if (flushpipe) begin
            ex_pc <= 32'd0;
        end else if (!ex_freeze) begin
            ex_pc <= id_pc;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_pc <= 32'd0;
        end else if (!wb_freeze) begin
            wb_pc <= ex_pc;
        end
    end

    // Pipeline exception flags
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_exceptflags <= 3'd0;
        end else if (flushpipe) begin
            id_exceptflags <= 3'd0;
        end else if (!id_freeze) begin
            id_exceptflags <= {sig_ibuserr, sig_itlbmiss, sig_immufault};
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_exceptflags <= 3'd0;
        end else if (flushpipe) begin
            ex_exceptflags <= 3'd0;
        end else if (!ex_freeze) begin
            ex_exceptflags <= id_exceptflags;
        end
    end

    // Delay slot tracking
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_dslot <= 1'b0;
            delayed1_ex_dslot <= 1'b0;
            delayed2_ex_dslot <= 1'b0;
        end else if (!ex_freeze) begin
            delayed2_ex_dslot <= delayed1_ex_dslot;
            delayed1_ex_dslot <= ex_dslot;
            ex_dslot <= branch_taken;
        end
    end

    // Delayed interrupt/tick enables
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            delayed_iee <= 3'd0;
            delayed_tee <= 3'd0;
        end else if (!ex_freeze) begin
            delayed_iee <= {delayed_iee[1:0], sr[2]};
            delayed_tee <= {delayed_tee[1:0], sr[1]};
        end
    end

    // Interrupt and tick pending
    assign int_pending  = sig_int  && sr[2] && delayed_iee[2] && !ex_freeze && !branch_taken && !ex_dslot && !sr_we;
    assign tick_pending = sig_tick && sr[1] && !ex_freeze && !branch_taken && !ex_dslot && !sr_we;

    // Exception trigger vector (priority ordered)
    assign except_trig[TRIG_TICK]      = tick_pending  && !du_dsr[TRIG_TICK];
    assign except_trig[TRIG_INT]       = int_pending   && !du_dsr[TRIG_INT];
    assign except_trig[TRIG_ITLBMISS]  = (ex_exceptflags[1] && !ex_freeze) && !du_dsr[TRIG_ITLBMISS];
    assign except_trig[TRIG_IMMUFAULT] = (ex_exceptflags[0] && !ex_freeze) && !du_dsr[TRIG_IMMUFAULT];
    assign except_trig[TRIG_IBUSERR]   = (ex_exceptflags[2] && !ex_freeze) && !du_dsr[TRIG_IBUSERR];
    assign except_trig[TRIG_ILLEGAL]   = (sig_illegal && !ex_freeze) && !du_dsr[TRIG_ILLEGAL];
    assign except_trig[TRIG_ALIGN]     = (sig_align && !ex_freeze) && !du_dsr[TRIG_ALIGN];
    assign except_trig[TRIG_DTLBMISS]  = (sig_dtlbmiss && !ex_freeze) && !du_dsr[TRIG_DTLBMISS];
    assign except_trig[TRIG_DMMUFAULT] = (sig_dmmufault && !ex_freeze) && !du_dsr[TRIG_DMMUFAULT];
    assign except_trig[TRIG_DBUSERR]   = (sig_dbuserr && !ex_freeze) && !du_dsr[TRIG_DBUSERR];
    assign except_trig[TRIG_RANGE]     = (sig_range && !ex_freeze) && !du_dsr[TRIG_RANGE];
    assign except_trig[TRIG_TRAP]      = (sig_trap && !ex_freeze) && !du_dsr[TRIG_TRAP];
    assign except_trig[TRIG_SYSCALL]   = (sig_syscall && !ex_freeze) && !du_dsr[TRIG_SYSCALL];

    // Debug stop vector
    assign except_stop[TRIG_TICK]      = tick_pending  && du_dsr[TRIG_TICK];
    assign except_stop[TRIG_INT]       = int_pending   && du_dsr[TRIG_INT];
    assign except_stop[TRIG_ITLBMISS]  = (ex_exceptflags[1] && !ex_freeze) && du_dsr[TRIG_ITLBMISS];
    assign except_stop[TRIG_IMMUFAULT] = (ex_exceptflags[0] && !ex_freeze) && du_dsr[TRIG_IMMUFAULT];
    assign except_stop[TRIG_IBUSERR]   = (ex_exceptflags[2] && !ex_freeze) && du_dsr[TRIG_IBUSERR];
    assign except_stop[TRIG_ILLEGAL]   = (sig_illegal && !ex_freeze) && du_dsr[TRIG_ILLEGAL];
    assign except_stop[TRIG_ALIGN]     = (sig_align && !ex_freeze) && du_dsr[TRIG_ALIGN];
    assign except_stop[TRIG_DTLBMISS]  = (sig_dtlbmiss && !ex_freeze) && du_dsr[TRIG_DTLBMISS];
    assign except_stop[TRIG_DMMUFAULT] = (sig_dmmufault && !ex_freeze) && du_dsr[TRIG_DMMUFAULT];
    assign except_stop[TRIG_DBUSERR]   = (sig_dbuserr && !ex_freeze) && du_dsr[TRIG_DBUSERR];
    assign except_stop[TRIG_RANGE]     = (sig_range && !ex_freeze) && du_dsr[TRIG_RANGE];
    assign except_stop[TRIG_TRAP]      = (sig_trap && !ex_freeze) && du_dsr[TRIG_TRAP];
    assign except_stop[TRIG_SYSCALL]   = (sig_syscall && !ex_freeze) && du_dsr[TRIG_SYSCALL];

    // Exception flush request
    assign except_flushpipe = |except_trig && (state == IDLE);

    // Combined flush signal
    assign flushpipe = except_flushpipe || pc_we || extend_flush_reg;

    // Abort execute stage
    assign abort_ex = sig_dbuserr || sig_dmmufault || sig_dtlbmiss || sig_align || sig_illegal;

    // Link register save value
    assign lr_sav = ex_pc[31:2];

    // SPR read data
    assign spr_dat_ppc = wb_pc;
    assign spr_dat_npc = ex_void ? id_pc : ex_pc;

    // Exception start signals
    assign except_start = (except_type != OR1200_EXCEPT_NONE) && extend_flush_reg;
    assign except_started_comb = extend_flush_reg && except_start;
    assign except_started = except_started_comb;

    // ESR output
    assign esr = esr_reg;

    // Extend flush output
    assign extend_flush = extend_flush_reg;

    // Exception FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            except_type <= OR1200_EXCEPT_NONE;
            extend_flush_reg <= 1'b0;
            extend_flush_last <= 1'b0;
            epcr <= 32'd0;
            eear <= 32'd0;
            esr_reg <= {1'b1, {14{1'b0}}, 1'b1};
        end else begin
            case (state)
                IDLE: begin
                    if (except_flushpipe) begin
                        state <= FLU1;
                        extend_flush_reg <= 1'b1;
                        // Latch ESR
                        if (sr_we)
                            esr_reg <= to_sr;
                        else
                            esr_reg <= sr;
                        // Priority resolution
                        casex (except_trig)
                            13'b1xxxxxxxxxxxx: begin // Tick
                                except_type <= OR1200_EXCEPT_TICK;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else if (delayed1_ex_dslot)
                                    epcr <= id_pc;
                                else if (delayed2_ex_dslot)
                                    epcr <= ex_pc;
                                else
                                    epcr <= id_pc;
                            end
                            13'b01xxxxxxxxxxx: begin // Int
                                except_type <= OR1200_EXCEPT_INT;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else if (delayed1_ex_dslot)
                                    epcr <= id_pc;
                                else if (delayed2_ex_dslot)
                                    epcr <= ex_pc;
                                else
                                    epcr <= id_pc;
                            end
                            13'b001xxxxxxxxxx: begin // ITLB miss
                                except_type <= OR1200_EXCEPT_ITLBMISS;
                                eear <= ex_pc;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else
                                    epcr <= ex_pc;
                            end
                            13'b0001xxxxxxxxx: begin // IMMU fault
                                except_type <= OR1200_EXCEPT_IMMUFAULT;
                                if (ex_dslot)
                                    eear <= ex_pc;
                                else if (delayed1_ex_dslot)
                                    eear <= id_pc;
                                else if (delayed2_ex_dslot)
                                    eear <= ex_pc;
                                else
                                    eear <= id_pc;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else if (delayed1_ex_dslot)
                                    epcr <= id_pc;
                                else if (delayed2_ex_dslot)
                                    epcr <= ex_pc;
                                else
                                    epcr <= id_pc;
                            end
                            13'b00001xxxxxxxx: begin // IBUS error
                                except_type <= OR1200_EXCEPT_IBUSERR;
                                if (ex_dslot) begin
                                    eear <= wb_pc;
                                    epcr <= wb_pc;
                                end else begin
                                    eear <= ex_pc;
                                    epcr <= ex_pc;
                                end
                            end
                            13'b000001xxxxxxx: begin // Illegal
                                except_type <= OR1200_EXCEPT_ILLEGAL;
                                eear <= ex_pc;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else
                                    epcr <= ex_pc;
                            end
                            13'b0000001xxxxxx: begin // Align
                                except_type <= OR1200_EXCEPT_ALIGN;
                                eear <= lsu_addr;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else
                                    epcr <= ex_pc;
                            end
                            13'b00000001xxxxx: begin // DTLB miss
                                except_type <= OR1200_EXCEPT_DTLBMISS;
                                eear <= lsu_addr;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else
                                    epcr <= ex_pc;
                            end
                            13'b000000001xxxx: begin // DMMU fault
                                except_type <= OR1200_EXCEPT_DMMUFAULT;
                                eear <= lsu_addr;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else
                                    epcr <= ex_pc;
                            end
                            13'b0000000001xxx: begin // DBUS error
                                except_type <= OR1200_EXCEPT_DBUSERR;
                                eear <= lsu_addr;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else
                                    epcr <= ex_pc;
                            end
                            13'b00000000001xx: begin // Range
                                except_type <= OR1200_EXCEPT_RANGE;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else if (delayed1_ex_dslot)
                                    epcr <= id_pc;
                                else if (delayed2_ex_dslot)
                                    epcr <= ex_pc;
                                else
                                    epcr <= id_pc;
                            end
                            13'b000000000001x: begin // Trap
                                except_type <= OR1200_EXCEPT_TRAP;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else
                                    epcr <= ex_pc;
                            end
                            13'b0000000000001: begin // Syscall
                                except_type <= OR1200_EXCEPT_SYSCALL;
                                if (ex_dslot)
                                    epcr <= wb_pc;
                                else if (delayed1_ex_dslot)
                                    epcr <= id_pc;
                                else if (delayed2_ex_dslot)
                                    epcr <= ex_pc;
                                else
                                    epcr <= id_pc;
                            end
                            default: begin
                                except_type <= OR1200_EXCEPT_NONE;
                            end
                        endcase
                    end else if (pc_we) begin
                        state <= FLU1;
                        extend_flush_reg <= 1'b1;
                    end else begin
                        // SPR writes when idle
                        if (epcr_we)
                            epcr <= datain;
                        if (eear_we)
                            eear <= datain;
                        if (esr_we)
                            esr_reg <= {1'b1, datain[14:0]};
                    end
                end

                FLU1: begin
                    if (icpu_ack_i || icpu_err_i || genpc_freeze) begin
                        state <= FLU2;
                    end
                end

                FLU2: begin
                    if (except_type == OR1200_EXCEPT_TRAP) begin
                        state <= IDLE;
                        extend_flush_reg <= 1'b0;
                        extend_flush_last <= 1'b0;
                        except_type <= OR1200_EXCEPT_NONE;
                    end else begin
                        state <= FLU3;
                    end
                end

                FLU3: begin
                    state <= FLU4;
                end

                FLU4: begin
                    state <= FLU5;
                    extend_flush_reg <= 1'b0;
                end

                FLU5: begin
                    if (!if_stall && !id_freeze) begin
                        state <= IDLE;
                        except_type <= OR1200_EXCEPT_NONE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

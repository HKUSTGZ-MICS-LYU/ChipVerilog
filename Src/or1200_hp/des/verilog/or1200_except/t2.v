`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_except (
    input         clk,
    input         rst,

    input         sig_ibuserr,
    input         sig_dbuserr,
    input         sig_illegal,
    input         sig_align,
    input         sig_range,
    input         sig_dtlbmiss,
    input         sig_dmmufault,
    input         sig_int,
    input         sig_syscall,
    input         sig_trap,
    input         sig_itlbmiss,
    input         sig_immufault,
    input         sig_tick,
    input         branch_taken,
    input         genpc_freeze,
    input         id_freeze,
    input         ex_freeze,
    input         wb_freeze,
    input         if_stall,
    input  [31:0] if_pc,
    output [31:0] id_pc,
    output [31:2] lr_sav,
    output        flushpipe,
    output        extend_flush,
    output [3:0]  except_type,
    output        except_start,
    output        except_started,
    output [12:0] except_stop,
    input         ex_void,
    output [31:0] spr_dat_ppc,
    output [31:0] spr_dat_npc,
    input  [31:0] datain,
    input  [13:0] du_dsr,
    input         epcr_we,
    input         eear_we,
    input         esr_we,
    input         pc_we,
    output [31:0] epcr,
    output [31:0] eear,
    output [15:0] esr,
    input         sr_we,
    input  [15:0] to_sr,
    input  [15:0] sr,
    input  [31:0] lsu_addr,
    output        abort_ex,
    input         icpu_ack_i,
    input         icpu_err_i,
    input         dcpu_ack_i,
    input         dcpu_err_i
);

    //--------------------------------------------------------------------------
    // FSM states
    //--------------------------------------------------------------------------
    localparam [2:0]
        IDLE = 3'd0,
        FLU1 = 3'd1,
        FLU2 = 3'd2,
        FLU3 = 3'd3,
        FLU4 = 3'd4,
        FLU5 = 3'd5;

    //--------------------------------------------------------------------------
    // Internal registers
    //--------------------------------------------------------------------------
    reg [3:0]  except_type_r;
    reg [31:0] id_pc_r;
    reg [31:0] ex_pc;
    reg [31:0] wb_pc;
    reg [31:0] epcr_r;
    reg [31:0] eear_r;
    reg [15:0] esr_r;
    reg [2:0]  id_exceptflags;
    reg [2:0]  ex_exceptflags;
    reg [2:0]  state;
    reg        extend_flush_r;
    reg        extend_flush_last;
    reg        ex_dslot;
    reg        delayed1_ex_dslot;
    reg        delayed2_ex_dslot;
    reg [2:0]  delayed_iee;
    reg [2:0]  delayed_tee;

    //--------------------------------------------------------------------------
    // Output assignments
    //--------------------------------------------------------------------------
    assign id_pc         = id_pc_r;
    assign except_type   = except_type_r;
    assign epcr          = epcr_r;
    assign eear          = eear_r;
    assign esr           = esr_r;
    assign extend_flush  = extend_flush_r;
    assign lr_sav        = ex_pc[31:2];
    assign spr_dat_ppc   = wb_pc;
    assign spr_dat_npc   = ex_void ? id_pc_r : ex_pc;
    assign abort_ex      = sig_dbuserr | sig_dmmufault | sig_dtlbmiss |
                           sig_align   | sig_illegal;

    //--------------------------------------------------------------------------
    // except_start / except_started
    //--------------------------------------------------------------------------
    assign except_start   = (except_type_r != `OR1200_EXCEPT_NONE) & extend_flush_r;
    assign except_started = extend_flush_r & except_start;

    //--------------------------------------------------------------------------
    // flushpipe
    //--------------------------------------------------------------------------
    wire except_flushpipe;
    assign flushpipe = except_flushpipe | pc_we | extend_flush_r;

    //--------------------------------------------------------------------------
    // Interrupt and tick pending
    //--------------------------------------------------------------------------
    wire int_pending  = sig_int  & sr[2] & delayed_iee[2] & ~ex_freeze &
                        ~branch_taken & ~ex_dslot & ~sr_we;
    wire tick_pending = sig_tick & sr[1] & ~ex_freeze &
                        ~branch_taken & ~ex_dslot & ~sr_we;

    //--------------------------------------------------------------------------
    // Exception trigger and stop vectors (priority: tick,int,itlbmiss,immufault,
    // ibuserr,illegal,align,dtlbmiss,dmmufault,dbuserr,range,trap,syscall)
    //--------------------------------------------------------------------------
    wire [12:0] except_trig = {
        tick_pending              & ~du_dsr[13],
        int_pending               & ~du_dsr[12],
        sig_itlbmiss              & ~du_dsr[11],
        sig_immufault             & ~du_dsr[10],
        sig_ibuserr               & ~du_dsr[9],
        sig_illegal               & ~du_dsr[8],
        sig_align                 & ~du_dsr[7],
        sig_dtlbmiss              & ~du_dsr[6],
        sig_dmmufault             & ~du_dsr[5],
        sig_dbuserr               & ~du_dsr[4],
        sig_range                 & ~du_dsr[3],
        (sig_trap & ~ex_freeze)   & ~du_dsr[2],
        (sig_syscall & ~ex_freeze)& ~du_dsr[1]
    };

    assign except_stop = {
        tick_pending              & du_dsr[13],
        int_pending               & du_dsr[12],
        sig_itlbmiss              & du_dsr[11],
        sig_immufault             & du_dsr[10],
        sig_ibuserr               & du_dsr[9],
        sig_illegal               & du_dsr[8],
        sig_align                 & du_dsr[7],
        sig_dtlbmiss              & du_dsr[6],
        sig_dmmufault             & du_dsr[5],
        sig_dbuserr               & du_dsr[4],
        sig_range                 & du_dsr[3],
        (sig_trap & ~ex_freeze)   & du_dsr[2],
        (sig_syscall & ~ex_freeze)& du_dsr[1]
    };

    assign except_flushpipe = |except_trig & (state == IDLE);

    //--------------------------------------------------------------------------
    // PC pipeline
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_pc_r        <= 32'h0;
            ex_pc          <= 32'h0;
            wb_pc          <= 32'h0;
            id_exceptflags <= 3'h0;
            ex_exceptflags <= 3'h0;
        end else begin
            if (flushpipe) begin
                id_pc_r        <= 32'h0;
                id_exceptflags <= 3'h0;
                ex_pc          <= 32'h0;
                ex_exceptflags <= 3'h0;
            end else begin
                if (!id_freeze) begin
                    id_pc_r        <= if_pc;
                    id_exceptflags <= {sig_ibuserr, sig_itlbmiss, sig_immufault};
                end
                if (!ex_freeze) begin
                    ex_pc          <= id_pc_r;
                    ex_exceptflags <= id_exceptflags;
                end
            end
            if (!wb_freeze)
                wb_pc <= ex_pc;
        end
    end

    //--------------------------------------------------------------------------
    // Delay slot tracking
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_dslot          <= 1'b0;
            delayed1_ex_dslot <= 1'b0;
            delayed2_ex_dslot <= 1'b0;
        end else if (!ex_freeze) begin
            ex_dslot          <= branch_taken;
            delayed1_ex_dslot <= ex_dslot;
            delayed2_ex_dslot <= delayed1_ex_dslot;
        end
    end

    //--------------------------------------------------------------------------
    // Delayed IEE / TEE
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            delayed_iee <= 3'h0;
            delayed_tee <= 3'h0;
        end else begin
            delayed_iee <= {delayed_iee[1:0], sr[2]};
            delayed_tee <= {delayed_tee[1:0], sr[1]};
        end
    end

    //--------------------------------------------------------------------------
    // Exception FSM + EPCR/EEAR/ESR
    //--------------------------------------------------------------------------
    // Helper: EPCR selection based on delay slot state
    // For int/tick/range/syscall: wb_pc if ex_dslot, else id_pc (via delayed)
    // For most others:             wb_pc if ex_dslot, else ex_pc

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state              <= IDLE;
            except_type_r      <= `OR1200_EXCEPT_NONE;
            extend_flush_r     <= 1'b0;
            extend_flush_last  <= 1'b0;
            epcr_r             <= 32'h0;
            eear_r             <= 32'h0;
            esr_r              <= {1'b1, {(`OR1200_SR_WIDTH-2){1'b0}}, 1'b1};
        end else begin
            case (state)
                //--------------------------------------------------------------
                IDLE: begin
                    extend_flush_last <= 1'b0;
                    if (except_flushpipe) begin
                        // Latch ESR
                        esr_r <= sr_we ? to_sr : sr;
                        // Select highest-priority exception via casex
                        casex (except_trig)
                            13'b1xxxxxxxxxxxx: begin  // tick
                                except_type_r <= `OR1200_EXCEPT_TICK;
                                epcr_r        <= ex_dslot ? wb_pc :
                                                 delayed1_ex_dslot ? ex_pc : id_pc_r;
                            end
                            13'b01xxxxxxxxxxx: begin  // int
                                except_type_r <= `OR1200_EXCEPT_INT;
                                epcr_r        <= ex_dslot ? wb_pc :
                                                 delayed1_ex_dslot ? ex_pc : id_pc_r;
                            end
                            13'b001xxxxxxxxxx: begin  // itlbmiss
                                except_type_r <= `OR1200_EXCEPT_ITLBMISS;
                                eear_r        <= ex_pc;
                                epcr_r        <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0001xxxxxxxxx: begin  // immufault
                                except_type_r <= `OR1200_EXCEPT_IPF;
                                eear_r        <= ex_dslot ? ex_pc : id_pc_r;
                                epcr_r        <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b00001xxxxxxxx: begin  // ibuserr
                                except_type_r <= `OR1200_EXCEPT_BUSERR;
                                eear_r        <= ex_dslot ? wb_pc : ex_pc;
                                epcr_r        <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b000001xxxxxxx: begin  // illegal
                                except_type_r <= `OR1200_EXCEPT_ILLEGAL;
                                eear_r        <= ex_pc;
                                epcr_r        <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0000001xxxxxx: begin  // align
                                except_type_r <= `OR1200_EXCEPT_ALIGN;
                                eear_r        <= lsu_addr;
                                epcr_r        <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b00000001xxxxx: begin  // dtlbmiss
                                except_type_r <= `OR1200_EXCEPT_DTLBMISS;
                                eear_r        <= lsu_addr;
                                epcr_r        <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b000000001xxxx: begin  // dmmufault
                                except_type_r <= `OR1200_EXCEPT_DPF;
                                eear_r        <= lsu_addr;
                                epcr_r        <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0000000001xxx: begin  // dbuserr
                                except_type_r <= `OR1200_EXCEPT_BUSERR;
                                eear_r        <= lsu_addr;
                                epcr_r        <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b00000000001xx: begin  // range
                                except_type_r <= `OR1200_EXCEPT_RANGE;
                                epcr_r        <= ex_dslot ? wb_pc :
                                                 delayed1_ex_dslot ? ex_pc : id_pc_r;
                            end
                            13'b000000000001x: begin  // trap
                                except_type_r <= `OR1200_EXCEPT_TRAP;
                                epcr_r        <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0000000000001: begin  // syscall
                                except_type_r <= `OR1200_EXCEPT_SYSCALL;
                                epcr_r        <= ex_dslot ? wb_pc :
                                                 delayed1_ex_dslot ? ex_pc : id_pc_r;
                            end
                            default: except_type_r <= `OR1200_EXCEPT_NONE;
                        endcase
                        extend_flush_r <= 1'b1;
                        state          <= FLU1;
                    end else if (pc_we) begin
                        extend_flush_r <= 1'b1;
                        state          <= FLU1;
                    end else begin
                        // SPR writes when idle
                        if (epcr_we)  epcr_r <= datain;
                        if (eear_we)  eear_r <= datain;
                        if (esr_we)   esr_r  <= {1'b1, datain[14:0]};
                    end
                end

                //--------------------------------------------------------------
                FLU1: begin
                    if (icpu_ack_i | icpu_err_i | genpc_freeze)
                        state <= FLU2;
                end

                //--------------------------------------------------------------
                FLU2: begin
`ifdef OR1200_EXCEPT_TRAP
                    if (except_type_r == `OR1200_EXCEPT_TRAP) begin
                        state              <= IDLE;
                        extend_flush_r     <= 1'b0;
                        extend_flush_last  <= 1'b0;
                        except_type_r      <= `OR1200_EXCEPT_NONE;
                    end else
`endif
                        state <= FLU3;
                end

                //--------------------------------------------------------------
                FLU3: state <= FLU4;

                //--------------------------------------------------------------
                FLU4: begin
                    state          <= FLU5;
                    extend_flush_r <= 1'b0;
                end

                //--------------------------------------------------------------
                FLU5: begin
                    if (!if_stall && !id_freeze) begin
                        state         <= IDLE;
                        except_type_r <= `OR1200_EXCEPT_NONE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
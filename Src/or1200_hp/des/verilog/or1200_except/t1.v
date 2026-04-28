`include "timescale.v"
`include "or1200_defines.v"

module or1200_except(
    clk, rst,
    sig_ibuserr, sig_dbuserr, sig_illegal, sig_align, sig_range,
    sig_dtlbmiss, sig_dmmufault, sig_int, sig_syscall, sig_trap,
    sig_itlbmiss, sig_immufault, sig_tick,
    branch_taken, genpc_freeze, id_freeze, ex_freeze, wb_freeze,
    if_stall, if_pc, id_pc, lr_sav,
    flushpipe, extend_flush, except_type, except_start, except_started,
    except_stop, ex_void,
    spr_dat_ppc, spr_dat_npc,
    datain, du_dsr,
    epcr_we, eear_we, esr_we, pc_we,
    epcr, eear, esr,
    sr_we, to_sr, sr,
    lsu_addr, abort_ex,
    icpu_ack_i, icpu_err_i, dcpu_ack_i, dcpu_err_i
);

input         clk, rst;
input         sig_ibuserr, sig_dbuserr, sig_illegal, sig_align, sig_range;
input         sig_dtlbmiss, sig_dmmufault, sig_int, sig_syscall, sig_trap;
input         sig_itlbmiss, sig_immufault, sig_tick;
input         branch_taken;
input         genpc_freeze, id_freeze, ex_freeze, wb_freeze;
input         if_stall;
input  [31:0] if_pc;
output [31:0] id_pc;
output [31:2] lr_sav;
output        flushpipe;
output        extend_flush;
output [3:0]  except_type;
output        except_start;
output        except_started;
output [12:0] except_stop;
input         ex_void;
output [31:0] spr_dat_ppc;
output [31:0] spr_dat_npc;
input  [31:0] datain;
input  [13:0] du_dsr;
input         epcr_we, eear_we, esr_we, pc_we;
output [31:0] epcr;
output [31:0] eear;
output [15:0] esr;
input         sr_we;
input  [15:0] to_sr, sr;
input  [31:0] lsu_addr;
output        abort_ex;
input         icpu_ack_i, icpu_err_i;
input         dcpu_ack_i, dcpu_err_i;

// FSM states
`define OR1200_EXCEPT_IDLE  3'd0
`define OR1200_EXCEPT_FLU1  3'd1
`define OR1200_EXCEPT_FLU2  3'd2
`define OR1200_EXCEPT_FLU3  3'd3
`define OR1200_EXCEPT_FLU4  3'd4
`define OR1200_EXCEPT_FLU5  3'd5

// Internal registers
reg [3:0]  except_type;
reg [31:0] id_pc;
reg [31:0] ex_pc;
reg [31:0] wb_pc;
reg [31:0] epcr;
reg [31:0] eear;
reg [15:0] esr;
reg [2:0]  id_exceptflags;
reg [2:0]  ex_exceptflags;
reg [2:0]  state;
reg        extend_flush;
reg        extend_flush_last;
reg        ex_dslot;
reg        delayed1_ex_dslot;
reg        delayed2_ex_dslot;
reg [2:0]  delayed_iee;
reg [2:0]  delayed_tee;

// Combinational
wire int_pending  = sig_int & sr[2] & delayed_iee[2] & !ex_freeze &
                    !branch_taken & !ex_dslot & !sr_we;
wire tick_pending = sig_tick & sr[1] & !ex_freeze &
                    !branch_taken & !ex_dslot & !sr_we;

// Exception trigger vector (ordered by priority, gated by du_dsr)
wire [12:0] except_trig;
assign except_trig[0]  = tick_pending       & !du_dsr[0];
assign except_trig[1]  = int_pending        & !du_dsr[1];
assign except_trig[2]  = sig_itlbmiss       & !du_dsr[2];
assign except_trig[3]  = sig_immufault      & !du_dsr[3];
assign except_trig[4]  = sig_ibuserr        & !du_dsr[4];
assign except_trig[5]  = sig_illegal        & !du_dsr[5];
assign except_trig[6]  = sig_align          & !du_dsr[6];
assign except_trig[7]  = sig_dtlbmiss       & !du_dsr[7];
assign except_trig[8]  = sig_dmmufault      & !du_dsr[8];
assign except_trig[9]  = sig_dbuserr        & !du_dsr[9];
assign except_trig[10] = sig_range          & !du_dsr[10];
assign except_trig[11] = sig_trap & !ex_freeze & !du_dsr[11];
assign except_trig[12] = sig_syscall & !ex_freeze & !du_dsr[12];

// Debug stop vector
assign except_stop[0]  = tick_pending       & du_dsr[0];
assign except_stop[1]  = int_pending        & du_dsr[1];
assign except_stop[2]  = sig_itlbmiss       & du_dsr[2];
assign except_stop[3]  = sig_immufault      & du_dsr[3];
assign except_stop[4]  = sig_ibuserr        & du_dsr[4];
assign except_stop[5]  = sig_illegal        & du_dsr[5];
assign except_stop[6]  = sig_align          & du_dsr[6];
assign except_stop[7]  = sig_dtlbmiss       & du_dsr[7];
assign except_stop[8]  = sig_dmmufault      & du_dsr[8];
assign except_stop[9]  = sig_dbuserr        & du_dsr[9];
assign except_stop[10] = sig_range          & du_dsr[10];
assign except_stop[11] = sig_trap & !ex_freeze & du_dsr[11];
assign except_stop[12] = sig_syscall & !ex_freeze & du_dsr[12];

wire except_flushpipe = |except_trig & (state == `OR1200_EXCEPT_IDLE);
assign flushpipe   = except_flushpipe | pc_we | extend_flush;
assign except_start   = (except_type != `OR1200_EXCEPT_NONE) & extend_flush;
assign except_started = extend_flush & except_start;

assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;
assign lr_sav      = ex_pc[31:2];
assign spr_dat_ppc = wb_pc;
assign spr_dat_npc = ex_void ? id_pc : ex_pc;

// Pipeline PC and exception flag tracking
always @(posedge clk or posedge rst) begin
    if (rst) begin
        id_pc          <= 32'h0;
        ex_pc          <= 32'h0;
        wb_pc          <= 32'h0;
        id_exceptflags <= 3'b0;
        ex_exceptflags <= 3'b0;
        ex_dslot       <= 1'b0;
        delayed1_ex_dslot <= 1'b0;
        delayed2_ex_dslot <= 1'b0;
    end else begin
        if (flushpipe) begin
            id_pc          <= 32'h0;
            ex_pc          <= 32'h0;
            id_exceptflags <= 3'b0;
            ex_exceptflags <= 3'b0;
        end else begin
            if (!id_freeze) begin
                id_pc          <= if_pc;
                id_exceptflags <= {sig_ibuserr, sig_itlbmiss, sig_immufault};
            end
            if (!ex_freeze) begin
                ex_pc          <= id_pc;
                ex_exceptflags <= id_exceptflags;
            end
        end
        if (!wb_freeze)
            wb_pc <= ex_pc;
        if (!ex_freeze) begin
            ex_dslot          <= branch_taken;
            delayed1_ex_dslot <= ex_dslot;
            delayed2_ex_dslot <= delayed1_ex_dslot;
        end
    end
end

// Delayed IEE/TEE
always @(posedge clk or posedge rst) begin
    if (rst) begin
        delayed_iee <= 3'b0;
        delayed_tee <= 3'b0;
    end else begin
        delayed_iee <= {delayed_iee[1:0], sr[2]};
        delayed_tee <= {delayed_tee[1:0], sr[1]};
    end
end

// Exception FSM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state              <= `OR1200_EXCEPT_IDLE;
        except_type        <= `OR1200_EXCEPT_NONE;
        extend_flush       <= 1'b0;
        extend_flush_last  <= 1'b0;
        epcr               <= 32'h0;
        eear               <= 32'h0;
        esr                <= {1'b1, {`OR1200_SR_WIDTH-2{1'b0}}, 1'b1};
    end else begin
        case (state)

        `OR1200_EXCEPT_IDLE: begin
            if (except_flushpipe) begin
                state        <= `OR1200_EXCEPT_FLU1;
                extend_flush <= 1'b1;
                // Latch ESR
                esr <= sr_we ? {1'b1, to_sr[14:0]} : {1'b1, sr[14:0]};
                // Exception selection
                casex (except_trig)
                    13'bx_xxxx_xxxx_xxx1: begin // tick
                        except_type <= `OR1200_EXCEPT_TICK;
                        epcr        <= ex_dslot ? wb_pc :
                                       delayed1_ex_dslot ? wb_pc : id_pc;
                    end
                    13'bx_xxxx_xxxx_xx10: begin // int
                        except_type <= `OR1200_EXCEPT_INT;
                        epcr        <= ex_dslot ? wb_pc :
                                       delayed1_ex_dslot ? wb_pc : id_pc;
                    end
                    13'bx_xxxx_xxxx_x100: begin // itlbmiss
                        except_type <= `OR1200_EXCEPT_ITLBMISS;
                        eear        <= ex_pc;
                        epcr        <= ex_dslot ? wb_pc : ex_pc;
                    end
                    13'bx_xxxx_xxxx_1000: begin // immufault
                        except_type <= `OR1200_EXCEPT_IPF;
                        eear        <= ex_dslot ? ex_pc : id_pc;
                        epcr        <= ex_dslot ? wb_pc : id_pc;
                    end
                    13'bx_xxxx_xxx1_0000: begin // ibuserr
                        except_type <= `OR1200_EXCEPT_IBE;
                        eear        <= ex_dslot ? wb_pc : ex_pc;
                        epcr        <= ex_dslot ? wb_pc : ex_pc;
                    end
                    13'bx_xxxx_xx10_0000: begin // illegal
                        except_type <= `OR1200_EXCEPT_ILLEGAL;
                        eear        <= ex_pc;
                        epcr        <= ex_dslot ? wb_pc : ex_pc;
                    end
                    13'bx_xxxx_x100_0000: begin // align
                        except_type <= `OR1200_EXCEPT_ALIGN;
                        eear        <= lsu_addr;
                        epcr        <= ex_dslot ? wb_pc : ex_pc;
                    end
                    13'bx_xxxx_1000_0000: begin // dtlbmiss
                        except_type <= `OR1200_EXCEPT_DTLBMISS;
                        eear        <= lsu_addr;
                        epcr        <= ex_dslot ? wb_pc : ex_pc;
                    end
                    13'bx_xxx1_0000_0000: begin // dmmufault
                        except_type <= `OR1200_EXCEPT_DPF;
                        eear        <= lsu_addr;
                        epcr        <= ex_dslot ? wb_pc : ex_pc;
                    end
                    13'bx_xx10_0000_0000: begin // dbuserr
                        except_type <= `OR1200_EXCEPT_DBE;
                        eear        <= lsu_addr;
                        epcr        <= ex_dslot ? wb_pc : ex_pc;
                    end
                    13'bx_x100_0000_0000: begin // range
                        except_type <= `OR1200_EXCEPT_RANGE;
                        epcr        <= ex_dslot ? wb_pc :
                                       delayed1_ex_dslot ? wb_pc : id_pc;
                    end
                    13'bx_1000_0000_0000: begin // trap
                        except_type <= `OR1200_EXCEPT_TRAP;
                        epcr        <= ex_dslot ? wb_pc : ex_pc;
                    end
                    13'b1_0000_0000_0000: begin // syscall
                        except_type <= `OR1200_EXCEPT_SYSCALL;
                        epcr        <= ex_dslot ? wb_pc :
                                       delayed1_ex_dslot ? wb_pc : id_pc;
                    end
                    default: begin
                        except_type <= `OR1200_EXCEPT_NONE;
                    end
                endcase
            end else if (pc_we) begin
                state        <= `OR1200_EXCEPT_FLU1;
                extend_flush <= 1'b1;
            end else begin
                // SPR writes when idle
                if (epcr_we) epcr <= datain;
                if (eear_we) eear <= datain;
                if (esr_we)  esr  <= {1'b1, datain[14:0]};
            end
        end

        `OR1200_EXCEPT_FLU1: begin
            if (icpu_ack_i | icpu_err_i | genpc_freeze)
                state <= `OR1200_EXCEPT_FLU2;
        end

        `OR1200_EXCEPT_FLU2: begin
`ifdef OR1200_EXCEPT_TRAP
            if (except_type == `OR1200_EXCEPT_TRAP) begin
                state              <= `OR1200_EXCEPT_IDLE;
                extend_flush       <= 1'b0;
                extend_flush_last  <= 1'b0;
                except_type        <= `OR1200_EXCEPT_NONE;
            end else
`endif
                state <= `OR1200_EXCEPT_FLU3;
        end

        `OR1200_EXCEPT_FLU3:
            state <= `OR1200_EXCEPT_FLU4;

        `OR1200_EXCEPT_FLU4: begin
            state        <= `OR1200_EXCEPT_FLU5;
            extend_flush <= 1'b0;
        end

        `OR1200_EXCEPT_FLU5: begin
            if (!if_stall & !id_freeze) begin
                state       <= `OR1200_EXCEPT_IDLE;
                except_type <= `OR1200_EXCEPT_NONE;
            end
        end

        default:
            state <= `OR1200_EXCEPT_IDLE;

        endcase
    end
end

endmodule
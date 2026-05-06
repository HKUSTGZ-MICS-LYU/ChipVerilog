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

localparam integer OR1200_SR_WIDTH = 16;

localparam [3:0]
    OR1200_EXCEPT_NONE     = 4'd0,
    OR1200_EXCEPT_TICK     = 4'd1,
    OR1200_EXCEPT_INT      = 4'd2,
    OR1200_EXCEPT_ITLBMISS = 4'd3,
    OR1200_EXCEPT_IPF      = 4'd4,
    OR1200_EXCEPT_IBUSERR  = 4'd5,
    OR1200_EXCEPT_ILLEGAL  = 4'd6,
    OR1200_EXCEPT_ALIGN    = 4'd7,
    OR1200_EXCEPT_DTLBMISS = 4'd8,
    OR1200_EXCEPT_DPF      = 4'd9,
    OR1200_EXCEPT_DBUSERR  = 4'd10,
    OR1200_EXCEPT_RANGE    = 4'd11,
    OR1200_EXCEPT_TRAP     = 4'd12,
    OR1200_EXCEPT_SYSCALL  = 4'd13;

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_FLU1 = 3'd1,
    STATE_FLU2 = 3'd2,
    STATE_FLU3 = 3'd3,
    STATE_FLU4 = 3'd4,
    STATE_FLU5 = 3'd5;

reg [31:0] id_pc;
reg [31:0] ex_pc;
reg [31:0] wb_pc;
reg [31:0] epcr;
reg [31:0] eear;
reg [15:0] esr;
reg [2:0] id_exceptflags;
reg [2:0] ex_exceptflags;
reg [2:0] state;
reg extend_flush;
reg extend_flush_last;
reg ex_dslot;
reg delayed1_ex_dslot;
reg delayed2_ex_dslot;
reg [2:0] delayed_iee;
reg [2:0] delayed_tee;
reg [3:0] except_type;

wire trap_or_syscall_ok;
wire int_pending;
wire tick_pending;
wire [12:0] except_trig;
wire except_flushpipe;
wire [31:0] id_related_pc;
wire unused_dcpu;

assign trap_or_syscall_ok = ~ex_freeze;
assign id_related_pc = delayed1_ex_dslot ? id_pc :
                       delayed2_ex_dslot ? id_pc :
                       id_pc;
assign int_pending = sig_int & sr[2] & delayed_iee[2] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;
assign tick_pending = sig_tick & sr[1] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

assign except_trig = {
    tick_pending & ~du_dsr[12],
    int_pending & ~du_dsr[11],
    ex_exceptflags[1] & ~du_dsr[10],
    ex_exceptflags[0] & ~du_dsr[9],
    ex_exceptflags[2] & ~du_dsr[8],
    sig_illegal & ~du_dsr[7],
    sig_align & ~du_dsr[6],
    sig_dtlbmiss & ~du_dsr[5],
    sig_dmmufault & ~du_dsr[4],
    sig_dbuserr & ~du_dsr[3],
    sig_range & ~du_dsr[2],
    (sig_trap & trap_or_syscall_ok) & ~du_dsr[1],
    (sig_syscall & trap_or_syscall_ok) & ~du_dsr[0]
};

assign except_stop = {
    tick_pending & du_dsr[12],
    int_pending & du_dsr[11],
    ex_exceptflags[1] & du_dsr[10],
    ex_exceptflags[0] & du_dsr[9],
    ex_exceptflags[2] & du_dsr[8],
    sig_illegal & du_dsr[7],
    sig_align & du_dsr[6],
    sig_dtlbmiss & du_dsr[5],
    sig_dmmufault & du_dsr[4],
    sig_dbuserr & du_dsr[3],
    sig_range & du_dsr[2],
    (sig_trap & trap_or_syscall_ok) & du_dsr[1],
    (sig_syscall & trap_or_syscall_ok) & du_dsr[0]
};

assign except_flushpipe = (state == STATE_IDLE) & (|except_trig);
assign flushpipe = except_flushpipe | pc_we | extend_flush;
assign lr_sav = ex_pc[31:2];
assign spr_dat_ppc = wb_pc;
assign spr_dat_npc = ex_void ? id_pc : ex_pc;
assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;
assign except_start = (except_type != OR1200_EXCEPT_NONE) & extend_flush;
assign except_started = extend_flush & except_start;
assign unused_dcpu = dcpu_ack_i ^ dcpu_err_i ^ delayed_tee[0];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        id_pc <= 32'h00000000;
        ex_pc <= 32'h00000000;
        wb_pc <= 32'h00000000;
        id_exceptflags <= 3'b000;
        ex_exceptflags <= 3'b000;
        ex_dslot <= 1'b0;
        delayed1_ex_dslot <= 1'b0;
        delayed2_ex_dslot <= 1'b0;
    end else begin
        if (flushpipe) begin
            id_pc <= 32'h00000000;
            ex_pc <= 32'h00000000;
            id_exceptflags <= 3'b000;
            ex_exceptflags <= 3'b000;
            ex_dslot <= 1'b0;
            delayed1_ex_dslot <= 1'b0;
            delayed2_ex_dslot <= 1'b0;
        end else begin
            if (!id_freeze) begin
                id_pc <= if_pc;
                id_exceptflags <= {sig_ibuserr, sig_itlbmiss, sig_immufault};
            end
            if (!ex_freeze) begin
                ex_pc <= id_pc;
                ex_exceptflags <= id_exceptflags;
                ex_dslot <= branch_taken;
                delayed1_ex_dslot <= ex_dslot;
                delayed2_ex_dslot <= delayed1_ex_dslot;
            end
        end

        if (!wb_freeze)
            wb_pc <= ex_pc;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        delayed_iee <= 3'b000;
        delayed_tee <= 3'b000;
    end else begin
        delayed_iee <= {delayed_iee[1:0], (sr_we ? to_sr[2] : sr[2])};
        delayed_tee <= {delayed_tee[1:0], (sr_we ? to_sr[1] : sr[1])};
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= STATE_IDLE;
        except_type <= OR1200_EXCEPT_NONE;
        extend_flush <= 1'b0;
        extend_flush_last <= 1'b0;
        epcr <= 32'h00000000;
        eear <= 32'h00000000;
        esr <= {1'b1, {OR1200_SR_WIDTH-2{1'b0}}, 1'b1};
    end else begin
        case (state)
            STATE_IDLE: begin
                extend_flush <= 1'b0;
                extend_flush_last <= 1'b0;

                if (except_flushpipe) begin
                    state <= STATE_FLU1;
                    extend_flush <= 1'b1;
                    esr <= sr_we ? to_sr : sr;

                    casez (except_trig)
                        13'b1????????????: begin
                            except_type <= OR1200_EXCEPT_TICK;
                            epcr <= ex_dslot ? wb_pc : id_related_pc;
                        end
                        13'b01???????????: begin
                            except_type <= OR1200_EXCEPT_INT;
                            epcr <= ex_dslot ? wb_pc : id_related_pc;
                        end
                        13'b001??????????: begin
                            except_type <= OR1200_EXCEPT_ITLBMISS;
                            epcr <= ex_dslot ? wb_pc : ex_pc;
                            eear <= ex_pc;
                        end
                        13'b0001?????????: begin
                            except_type <= OR1200_EXCEPT_IPF;
                            epcr <= ex_dslot ? wb_pc : id_related_pc;
                            eear <= ex_dslot ? ex_pc : id_related_pc;
                        end
                        13'b00001????????: begin
                            except_type <= OR1200_EXCEPT_IBUSERR;
                            epcr <= ex_dslot ? wb_pc : ex_pc;
                            eear <= ex_dslot ? wb_pc : ex_pc;
                        end
                        13'b000001???????: begin
                            except_type <= OR1200_EXCEPT_ILLEGAL;
                            epcr <= ex_dslot ? wb_pc : ex_pc;
                            eear <= ex_pc;
                        end
                        13'b0000001??????: begin
                            except_type <= OR1200_EXCEPT_ALIGN;
                            epcr <= ex_dslot ? wb_pc : ex_pc;
                            eear <= lsu_addr;
                        end
                        13'b00000001?????: begin
                            except_type <= OR1200_EXCEPT_DTLBMISS;
                            epcr <= ex_dslot ? wb_pc : ex_pc;
                            eear <= lsu_addr;
                        end
                        13'b000000001????: begin
                            except_type <= OR1200_EXCEPT_DPF;
                            epcr <= ex_dslot ? wb_pc : ex_pc;
                            eear <= lsu_addr;
                        end
                        13'b0000000001???: begin
                            except_type <= OR1200_EXCEPT_DBUSERR;
                            epcr <= ex_dslot ? wb_pc : ex_pc;
                            eear <= lsu_addr;
                        end
                        13'b00000000001??: begin
                            except_type <= OR1200_EXCEPT_RANGE;
                            epcr <= ex_dslot ? wb_pc : id_related_pc;
                        end
                        13'b000000000001?: begin
                            except_type <= OR1200_EXCEPT_TRAP;
                            epcr <= ex_dslot ? wb_pc : ex_pc;
                        end
                        default: begin
                            except_type <= OR1200_EXCEPT_SYSCALL;
                            epcr <= ex_dslot ? wb_pc : id_related_pc;
                        end
                    endcase
                end else if (pc_we) begin
                    state <= STATE_FLU1;
                    extend_flush <= 1'b1;
                    except_type <= OR1200_EXCEPT_NONE;
                end else begin
                    if (epcr_we)
                        epcr <= datain;
                    if (eear_we)
                        eear <= datain;
                    if (esr_we)
                        esr <= {1'b1, datain[14:0]};
                end
            end

            STATE_FLU1: begin
                if (icpu_ack_i | icpu_err_i | genpc_freeze)
                    state <= STATE_FLU2;
            end

            STATE_FLU2: begin
                if (except_type == OR1200_EXCEPT_TRAP) begin
                    state <= STATE_IDLE;
                    extend_flush <= 1'b0;
                    extend_flush_last <= 1'b0;
                    except_type <= OR1200_EXCEPT_NONE;
                end else begin
                    state <= STATE_FLU3;
                end
            end

            STATE_FLU3: begin
                state <= STATE_FLU4;
            end

            STATE_FLU4: begin
                state <= STATE_FLU5;
                extend_flush <= 1'b0;
            end

            STATE_FLU5: begin
                if (!if_stall && !id_freeze) begin
                    state <= STATE_IDLE;
                    except_type <= OR1200_EXCEPT_NONE;
                    extend_flush_last <= 1'b0;
                end
            end

            default: begin
                state <= STATE_IDLE;
                except_type <= OR1200_EXCEPT_NONE;
                extend_flush <= 1'b0;
                extend_flush_last <= 1'b0;
            end
        endcase
    end
end

endmodule

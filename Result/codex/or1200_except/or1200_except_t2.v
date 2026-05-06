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
    output reg extend_flush,
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

localparam integer OR1200_SR_WIDTH = 16;

localparam [2:0] STATE_IDLE = 3'd0;
localparam [2:0] STATE_FLU1 = 3'd1;
localparam [2:0] STATE_FLU2 = 3'd2;
localparam [2:0] STATE_FLU3 = 3'd3;
localparam [2:0] STATE_FLU4 = 3'd4;
localparam [2:0] STATE_FLU5 = 3'd5;

localparam [3:0] EXCEPT_NONE     = 4'd0;
localparam [3:0] EXCEPT_TICK     = 4'd1;
localparam [3:0] EXCEPT_INT      = 4'd2;
localparam [3:0] EXCEPT_ITLBMISS = 4'd3;
localparam [3:0] EXCEPT_IPF      = 4'd4;
localparam [3:0] EXCEPT_IBE      = 4'd5;
localparam [3:0] EXCEPT_ILLEGAL  = 4'd6;
localparam [3:0] EXCEPT_ALIGN    = 4'd7;
localparam [3:0] EXCEPT_DTLBMISS = 4'd8;
localparam [3:0] EXCEPT_DPF      = 4'd9;
localparam [3:0] EXCEPT_DBE      = 4'd10;
localparam [3:0] EXCEPT_RANGE    = 4'd11;
localparam [3:0] EXCEPT_TRAP     = 4'd12;
localparam [3:0] EXCEPT_SYSCALL  = 4'd13;

reg [31:0] ex_pc;
reg [31:0] wb_pc;
reg [2:0] id_exceptflags;
reg [2:0] ex_exceptflags;
reg [2:0] state;
reg extend_flush_last;
reg ex_dslot;
reg delayed1_ex_dslot;
reg delayed2_ex_dslot;
reg [2:0] delayed_iee;
reg [2:0] delayed_tee;

wire int_pending;
wire tick_pending;
wire [12:0] except_trig;
wire except_flushpipe;
wire delayed_dslot_any;
wire [31:0] delayed_dslot_pc;

assign delayed_dslot_any = delayed1_ex_dslot | delayed2_ex_dslot;
assign delayed_dslot_pc = delayed_dslot_any ? id_pc : id_pc;

assign int_pending = sig_int & sr[2] & delayed_iee[2] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;
assign tick_pending = sig_tick & sr[1] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

assign except_trig[12] = tick_pending & ~du_dsr[12];
assign except_trig[11] = int_pending & ~du_dsr[11];
assign except_trig[10] = ex_exceptflags[1] & ~du_dsr[10];
assign except_trig[9]  = ex_exceptflags[0] & ~du_dsr[9];
assign except_trig[8]  = ex_exceptflags[2] & ~du_dsr[8];
assign except_trig[7]  = sig_illegal & ~du_dsr[7];
assign except_trig[6]  = sig_align & ~du_dsr[6];
assign except_trig[5]  = sig_dtlbmiss & ~du_dsr[5];
assign except_trig[4]  = sig_dmmufault & ~du_dsr[4];
assign except_trig[3]  = sig_dbuserr & ~du_dsr[3];
assign except_trig[2]  = sig_range & ~du_dsr[2];
assign except_trig[1]  = sig_trap & ~ex_freeze & ~du_dsr[1];
assign except_trig[0]  = sig_syscall & ~ex_freeze & ~du_dsr[0];

assign except_stop[12] = tick_pending & du_dsr[12];
assign except_stop[11] = int_pending & du_dsr[11];
assign except_stop[10] = ex_exceptflags[1] & du_dsr[10];
assign except_stop[9]  = ex_exceptflags[0] & du_dsr[9];
assign except_stop[8]  = ex_exceptflags[2] & du_dsr[8];
assign except_stop[7]  = sig_illegal & du_dsr[7];
assign except_stop[6]  = sig_align & du_dsr[6];
assign except_stop[5]  = sig_dtlbmiss & du_dsr[5];
assign except_stop[4]  = sig_dmmufault & du_dsr[4];
assign except_stop[3]  = sig_dbuserr & du_dsr[3];
assign except_stop[2]  = sig_range & du_dsr[2];
assign except_stop[1]  = sig_trap & ~ex_freeze & du_dsr[1];
assign except_stop[0]  = sig_syscall & ~ex_freeze & du_dsr[0];

assign except_flushpipe = (|except_trig) & (state == STATE_IDLE);
assign flushpipe = except_flushpipe | pc_we | extend_flush;

assign lr_sav = ex_pc[31:2];
assign spr_dat_ppc = wb_pc;
assign spr_dat_npc = ex_void ? id_pc : ex_pc;

assign except_start = (except_type != EXCEPT_NONE) & extend_flush;
assign except_started = extend_flush & except_start;

assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        except_type <= EXCEPT_NONE;
        id_pc <= 32'd0;
        ex_pc <= 32'd0;
        wb_pc <= 32'd0;
        epcr <= 32'd0;
        eear <= 32'd0;
        esr <= {1'b1, {(OR1200_SR_WIDTH-2){1'b0}}, 1'b1};
        id_exceptflags <= 3'd0;
        ex_exceptflags <= 3'd0;
        state <= STATE_IDLE;
        extend_flush <= 1'b0;
        extend_flush_last <= 1'b0;
        ex_dslot <= 1'b0;
        delayed1_ex_dslot <= 1'b0;
        delayed2_ex_dslot <= 1'b0;
        delayed_iee <= 3'd0;
        delayed_tee <= 3'd0;
    end else begin
        delayed_iee <= {delayed_iee[1:0], (sr_we ? to_sr[2] : sr[2])};
        delayed_tee <= {delayed_tee[1:0], (sr_we ? to_sr[1] : sr[1])};

        if (flushpipe) begin
            id_pc <= 32'd0;
            ex_pc <= 32'd0;
            id_exceptflags <= 3'd0;
            ex_exceptflags <= 3'd0;
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

        if (!wb_freeze) begin
            wb_pc <= ex_pc;
        end

        case (state)
            STATE_IDLE: begin
                extend_flush_last <= 1'b0;
                if (except_flushpipe) begin
                    state <= STATE_FLU1;
                    extend_flush <= 1'b1;
                    esr <= sr_we ? to_sr : sr;

                    if (except_trig[12]) begin
                        except_type <= EXCEPT_TICK;
                        epcr <= ex_dslot ? wb_pc : delayed_dslot_pc;
                    end else if (except_trig[11]) begin
                        except_type <= EXCEPT_INT;
                        epcr <= ex_dslot ? wb_pc : delayed_dslot_pc;
                    end else if (except_trig[10]) begin
                        except_type <= EXCEPT_ITLBMISS;
                        eear <= ex_pc;
                        epcr <= ex_dslot ? wb_pc : ex_pc;
                    end else if (except_trig[9]) begin
                        except_type <= EXCEPT_IPF;
                        eear <= ex_dslot ? ex_pc : delayed_dslot_pc;
                        epcr <= ex_dslot ? wb_pc : delayed_dslot_pc;
                    end else if (except_trig[8]) begin
                        except_type <= EXCEPT_IBE;
                        eear <= ex_dslot ? wb_pc : ex_pc;
                        epcr <= ex_dslot ? wb_pc : ex_pc;
                    end else if (except_trig[7]) begin
                        except_type <= EXCEPT_ILLEGAL;
                        eear <= ex_pc;
                        epcr <= ex_dslot ? wb_pc : ex_pc;
                    end else if (except_trig[6]) begin
                        except_type <= EXCEPT_ALIGN;
                        eear <= lsu_addr;
                        epcr <= ex_dslot ? wb_pc : ex_pc;
                    end else if (except_trig[5]) begin
                        except_type <= EXCEPT_DTLBMISS;
                        eear <= lsu_addr;
                        epcr <= ex_dslot ? wb_pc : ex_pc;
                    end else if (except_trig[4]) begin
                        except_type <= EXCEPT_DPF;
                        eear <= lsu_addr;
                        epcr <= ex_dslot ? wb_pc : ex_pc;
                    end else if (except_trig[3]) begin
                        except_type <= EXCEPT_DBE;
                        eear <= lsu_addr;
                        epcr <= ex_dslot ? wb_pc : ex_pc;
                    end else if (except_trig[2]) begin
                        except_type <= EXCEPT_RANGE;
                        epcr <= ex_dslot ? wb_pc : delayed_dslot_pc;
                    end else if (except_trig[1]) begin
                        except_type <= EXCEPT_TRAP;
                        epcr <= ex_dslot ? wb_pc : ex_pc;
                    end else if (except_trig[0]) begin
                        except_type <= EXCEPT_SYSCALL;
                        epcr <= ex_dslot ? wb_pc : delayed_dslot_pc;
                    end
                end else if (pc_we) begin
                    state <= STATE_FLU1;
                    extend_flush <= 1'b1;
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
                if (except_type == EXCEPT_TRAP) begin
                    state <= STATE_IDLE;
                    extend_flush <= 1'b0;
                    extend_flush_last <= 1'b0;
                    except_type <= EXCEPT_NONE;
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
                    except_type <= EXCEPT_NONE;
                    extend_flush_last <= 1'b0;
                end
            end

            default: begin
                state <= STATE_IDLE;
                except_type <= EXCEPT_NONE;
                extend_flush <= 1'b0;
                extend_flush_last <= 1'b0;
            end
        endcase
    end
end

endmodule

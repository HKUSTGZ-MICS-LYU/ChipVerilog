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

    localparam OR1200_SR_WIDTH = 16;
    localparam OR1200_EXCEPT_NONE = 4'h0;

    localparam IDLE = 3'h0;
    localparam FLU1 = 3'h1;
    localparam FLU2 = 3'h2;
    localparam FLU3 = 3'h3;
    localparam FLU4 = 3'h4;
    localparam FLU5 = 3'h5;

    reg [31:0] ex_pc;
    reg [31:0] wb_pc;
    reg [2:0] id_exceptflags;
    reg [2:0] ex_exceptflags;
    reg [2:0] state;
    reg extend_flush_last;
    reg ex_dslot;
    reg delayed1_ex_dslot;
    reg delayed2_ex_dslot;
    reg [3:0] except_type_reg;
    reg [15:0] esr_reg;

    reg [2:0] delayed_iee;
    reg [2:0] delayed_tee;

    wire int_pending;
    wire tick_pending;

    wire [12:0] except_trig;
    wire except_flushpipe;

    assign except_type = except_type_reg;
    assign esr = esr_reg;

    assign spr_dat_ppc = wb_pc;
    assign spr_dat_npc = ex_void ? id_pc : ex_pc;

    assign lr_sav = ex_pc[31:2];

    assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;

    assign int_pending = sig_int & sr[2] & delayed_iee[2] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;
    assign tick_pending = sig_tick & sr[1] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

    assign except_trig[12] = (tick_pending & ~du_dsr[12]);
    assign except_trig[11] = (int_pending & ~du_dsr[11]);
    assign except_trig[10] = (sig_itlbmiss & ~du_dsr[10]);
    assign except_trig[9]  = (sig_immufault & ~du_dsr[9]);
    assign except_trig[8]  = (sig_ibuserr & ~du_dsr[8]);
    assign except_trig[7]  = (sig_illegal & ~du_dsr[7]);
    assign except_trig[6]  = (sig_align & ~du_dsr[6]);
    assign except_trig[5]  = (sig_dtlbmiss & ~du_dsr[5]);
    assign except_trig[4]  = (sig_dmmufault & ~du_dsr[4]);
    assign except_trig[3]  = (sig_dbuserr & ~du_dsr[3]);
    assign except_trig[2]  = (sig_range & ~du_dsr[2]);
    assign except_trig[1]  = (sig_trap & ~du_dsr[1] & ~ex_freeze);
    assign except_trig[0]  = (sig_syscall & ~du_dsr[0] & ~ex_freeze);

    assign except_stop[12] = (tick_pending & du_dsr[12]);
    assign except_stop[11] = (int_pending & du_dsr[11]);
    assign except_stop[10] = (sig_itlbmiss & du_dsr[10]);
    assign except_stop[9]  = (sig_immufault & du_dsr[9]);
    assign except_stop[8]  = (sig_ibuserr & du_dsr[8]);
    assign except_stop[7]  = (sig_illegal & du_dsr[7]);
    assign except_stop[6]  = (sig_align & du_dsr[6]);
    assign except_stop[5]  = (sig_dtlbmiss & du_dsr[5]);
    assign except_stop[4]  = (sig_dmmufault & du_dsr[4]);
    assign except_stop[3]  = (sig_dbuserr & du_dsr[3]);
    assign except_stop[2]  = (sig_range & du_dsr[2]);
    assign except_stop[1]  = (sig_trap & du_dsr[1] & ~ex_freeze);
    assign except_stop[0]  = (sig_syscall & du_dsr[0] & ~ex_freeze);

    assign except_flushpipe = |except_trig & (state == IDLE);
    assign flushpipe = except_flushpipe | pc_we | extend_flush;

    assign except_start = (except_type_reg != OR1200_EXCEPT_NONE) & extend_flush;
    assign except_started = extend_flush & except_start;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_pc <= 32'h0;
            ex_pc <= 32'h0;
            wb_pc <= 32'h0;
            id_exceptflags <= 3'b0;
            ex_exceptflags <= 3'b0;
            ex_dslot <= 1'b0;
            delayed1_ex_dslot <= 1'b0;
            delayed2_ex_dslot <= 1'b0;
            delayed_iee <= 3'b0;
            delayed_tee <= 3'b0;
            state <= IDLE;
            except_type_reg <= OR1200_EXCEPT_NONE;
            extend_flush <= 1'b0;
            extend_flush_last <= 1'b0;
            epcr <= 32'h0;
            eear <= 32'h0;
            esr_reg <= {1'b1, {(OR1200_SR_WIDTH-2){1'b0}}, 1'b1};
        end
        else begin
            if (~id_freeze) begin
                id_pc <= if_pc;
                id_exceptflags <= {sig_ibuserr, sig_itlbmiss, sig_immufault};
            end
            if (flushpipe) begin
                id_pc <= 32'h0;
                id_exceptflags <= 3'b0;
                ex_pc <= 32'h0;
                ex_exceptflags <= 3'b0;
            end
            else begin
                if (~ex_freeze) begin
                    ex_pc <= id_pc;
                    ex_exceptflags <= id_exceptflags;
                    ex_dslot <= branch_taken;
                end
                delayed1_ex_dslot <= ex_dslot;
                delayed2_ex_dslot <= delayed1_ex_dslot;
            end
            if (~wb_freeze & ~flushpipe)
                wb_pc <= ex_pc;

            delayed_iee <= sr[5:3];
            delayed_tee <= sr[8:6];

            case (state)
                IDLE: begin
                    if (except_flushpipe) begin
                        state <= FLU1;
                        extend_flush <= 1'b1;
                        extend_flush_last <= 1'b0;
                        if (sr_we)
                            esr_reg <= to_sr;
                        else
                            esr_reg <= sr;

                        casex (except_trig)
                            13'b1_xxxx_xxxx_xxxx: begin
                                except_type_reg <= 4'd12;
                                epcr <= ex_dslot ? wb_pc :
                                        delayed1_ex_dslot ? ex_pc :
                                        delayed2_ex_dslot ? id_pc : id_pc;
                            end
                            13'b0_1_xxxx_xxxx_xxxx: begin
                                except_type_reg <= 4'd11;
                                epcr <= ex_dslot ? wb_pc :
                                        delayed1_ex_dslot ? ex_pc :
                                        delayed2_ex_dslot ? id_pc : id_pc;
                            end
                            13'b0_0_1_xxxx_xxxx_xxxx: begin
                                except_type_reg <= 4'd10;
                                eear <= ex_pc;
                                epcr <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0_0_0_1_xxxx_xxxx_xxxx: begin
                                except_type_reg <= 4'd9;
                                eear <= ex_dslot ? ex_pc :
                                        delayed1_ex_dslot ? ex_pc :
                                        delayed2_ex_dslot ? id_pc : id_pc;
                                epcr <= ex_dslot ? wb_pc :
                                        delayed1_ex_dslot ? wb_pc :
                                        delayed2_ex_dslot ? id_pc : id_pc;
                            end
                            13'b0_0_0_0_1_xxxx_xxxx: begin
                                except_type_reg <= 4'd8;
                                eear <= ex_dslot ? wb_pc : ex_pc;
                                epcr <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0_0_0_0_0_1_xxxx_xxxx: begin
                                except_type_reg <= 4'd7;
                                eear <= ex_pc;
                                epcr <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0_0_0_0_0_0_1_xxxx_xxxx: begin
                                except_type_reg <= 4'd6;
                                eear <= lsu_addr;
                                epcr <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0_0_0_0_0_0_0_1_xxxx_xxxx: begin
                                except_type_reg <= 4'd5;
                                eear <= lsu_addr;
                                epcr <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0_0_0_0_0_0_0_0_1_xxxx_xxxx: begin
                                except_type_reg <= 4'd4;
                                eear <= lsu_addr;
                                epcr <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0_0_0_0_0_0_0_0_0_1_xxxx_xxxx: begin
                                except_type_reg <= 4'd3;
                                eear <= lsu_addr;
                                epcr <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0_0_0_0_0_0_0_0_0_0_1_xxxx_xxxx: begin
                                except_type_reg <= 4'd2;
                                epcr <= ex_dslot ? wb_pc :
                                        delayed1_ex_dslot ? ex_pc :
                                        delayed2_ex_dslot ? id_pc : id_pc;
                            end
                            13'b0_0_0_0_0_0_0_0_0_0_0_1_xxxx_xxxx: begin
                                except_type_reg <= 4'd1;
                                epcr <= ex_dslot ? wb_pc : ex_pc;
                            end
                            13'b0_0_0_0_0_0_0_0_0_0_0_0_1: begin
                                except_type_reg <= 4'd0;
                                epcr <= ex_dslot ? wb_pc :
                                        delayed1_ex_dslot ? ex_pc :
                                        delayed2_ex_dslot ? id_pc : id_pc;
                            end
                            default: begin
                                except_type_reg <= OR1200_EXCEPT_NONE;
                            end
                        endcase
                    end
                    else if (pc_we) begin
                        state <= FLU1;
                        extend_flush <= 1'b1;
                        extend_flush_last <= 1'b0;
                        except_type_reg <= OR1200_EXCEPT_NONE;
                    end
                    else begin
                        if (epcr_we)
                            epcr <= datain;
                        if (eear_we)
                            eear <= datain;
                        if (esr_we)
                            esr_reg <= {1'b1, datain[14:0]};
                    end
                end

                FLU1: begin
                    if (icpu_ack_i | icpu_err_i | genpc_freeze)
                        state <= FLU2;
                end

                FLU2: begin
                    if ((except_type_reg == 4'd1) & (du_dsr[1] == 1'b0)) begin
                        state <= IDLE;
                        extend_flush <= 1'b0;
                        extend_flush_last <= 1'b0;
                        except_type_reg <= OR1200_EXCEPT_NONE;
                    end
                    else
                        state <= FLU3;
                end

                FLU3: state <= FLU4;

                FLU4: begin
                    state <= FLU5;
                    extend_flush <= 1'b0;
                end

                FLU5: begin
                    if (~if_stall & ~id_freeze) begin
                        state <= IDLE;
                        except_type_reg <= OR1200_EXCEPT_NONE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

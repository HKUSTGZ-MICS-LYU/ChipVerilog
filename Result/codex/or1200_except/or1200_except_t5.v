module or1200_except(
    clk,
    rst,
    sig_ibuserr,
    sig_dbuserr,
    sig_illegal,
    sig_align,
    sig_range,
    sig_dtlbmiss,
    sig_dmmufault,
    sig_int,
    sig_syscall,
    sig_trap,
    sig_itlbmiss,
    sig_immufault,
    sig_tick,
    branch_taken,
    genpc_freeze,
    id_freeze,
    ex_freeze,
    wb_freeze,
    if_stall,
    if_pc,
    id_pc,
    lr_sav,
    flushpipe,
    extend_flush,
    except_type,
    except_start,
    except_started,
    except_stop,
    ex_void,
    spr_dat_ppc,
    spr_dat_npc,
    datain,
    du_dsr,
    epcr_we,
    eear_we,
    esr_we,
    pc_we,
    epcr,
    eear,
    esr,
    sr_we,
    to_sr,
    sr,
    lsu_addr,
    abort_ex,
    icpu_ack_i,
    icpu_err_i,
    dcpu_ack_i,
    dcpu_err_i
);

input clk;
input rst;
input sig_ibuserr;
input sig_dbuserr;
input sig_illegal;
input sig_align;
input sig_range;
input sig_dtlbmiss;
input sig_dmmufault;
input sig_int;
input sig_syscall;
input sig_trap;
input sig_itlbmiss;
input sig_immufault;
input sig_tick;
input branch_taken;
input genpc_freeze;
input id_freeze;
input ex_freeze;
input wb_freeze;
input if_stall;
input [31:0] if_pc;
output [31:0] id_pc;
output [31:2] lr_sav;
output flushpipe;
output extend_flush;
output [3:0] except_type;
output except_start;
output except_started;
output [12:0] except_stop;
input ex_void;
output [31:0] spr_dat_ppc;
output [31:0] spr_dat_npc;
input [31:0] datain;
input [13:0] du_dsr;
input epcr_we;
input eear_we;
input esr_we;
input pc_we;
output [31:0] epcr;
output [31:0] eear;
output [15:0] esr;
input sr_we;
input [15:0] to_sr;
input [15:0] sr;
input [31:0] lsu_addr;
output abort_ex;
input icpu_ack_i;
input icpu_err_i;
input dcpu_ack_i;
input dcpu_err_i;

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

wire [2:0] if_exceptflags;
wire int_pending;
wire tick_pending;
wire [12:0] except_trig;
wire except_flushpipe;
wire sr_iee_in;
wire sr_tee_in;
wire [31:0] epcr_ex_path;
wire [31:0] epcr_id_path;
wire [31:0] immu_pc_path;

localparam OR1200_SR_WIDTH = 16;
localparam [3:0] OR1200_EXCEPT_NONE     = 4'h0;
localparam [3:0] OR1200_EXCEPT_TICK     = 4'h1;
localparam [3:0] OR1200_EXCEPT_INT      = 4'h2;
localparam [3:0] OR1200_EXCEPT_ITLBMISS = 4'h3;
localparam [3:0] OR1200_EXCEPT_IPF      = 4'h4;
localparam [3:0] OR1200_EXCEPT_BUSERR   = 4'h5;
localparam [3:0] OR1200_EXCEPT_ILLEGAL  = 4'h6;
localparam [3:0] OR1200_EXCEPT_ALIGN    = 4'h7;
localparam [3:0] OR1200_EXCEPT_DTLBMISS = 4'h8;
localparam [3:0] OR1200_EXCEPT_DPF      = 4'h9;
localparam [3:0] OR1200_EXCEPT_RANGE    = 4'hA;
localparam [3:0] OR1200_EXCEPT_TRAP     = 4'hB;
localparam [3:0] OR1200_EXCEPT_SYSCALL  = 4'hC;

localparam [2:0] STATE_IDLE = 3'd0;
localparam [2:0] STATE_FLU1 = 3'd1;
localparam [2:0] STATE_FLU2 = 3'd2;
localparam [2:0] STATE_FLU3 = 3'd3;
localparam [2:0] STATE_FLU4 = 3'd4;
localparam [2:0] STATE_FLU5 = 3'd5;

assign if_exceptflags = {sig_ibuserr, sig_itlbmiss, sig_immufault};
assign sr_iee_in = sr_we ? to_sr[2] : sr[2];
assign sr_tee_in = sr_we ? to_sr[1] : sr[1];

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

assign except_flushpipe = (state == STATE_IDLE) & (|except_trig);
assign flushpipe = except_flushpipe | pc_we | extend_flush;

assign lr_sav = ex_pc[31:2];
assign spr_dat_ppc = wb_pc;
assign spr_dat_npc = ex_void ? id_pc : ex_pc;
assign except_start = (except_type != OR1200_EXCEPT_NONE) & extend_flush;
assign except_started = extend_flush & except_start;
assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;

assign epcr_ex_path = ex_dslot ? wb_pc : ex_pc;
assign epcr_id_path = ex_dslot ? wb_pc :
                      delayed1_ex_dslot ? id_pc :
                      delayed2_ex_dslot ? id_pc :
                      id_pc;
assign immu_pc_path = ex_dslot ? ex_pc :
                      delayed1_ex_dslot ? id_pc :
                      delayed2_ex_dslot ? id_pc :
                      id_pc;

always @(posedge clk or posedge rst)
begin
    if (rst) begin
        id_pc <= 32'b0;
        ex_pc <= 32'b0;
        wb_pc <= 32'b0;
        epcr <= 32'b0;
        eear <= 32'b0;
        esr <= {1'b1, {(OR1200_SR_WIDTH-2){1'b0}}, 1'b1};
        id_exceptflags <= 3'b000;
        ex_exceptflags <= 3'b000;
        state <= STATE_IDLE;
        extend_flush <= 1'b0;
        extend_flush_last <= 1'b0;
        ex_dslot <= 1'b0;
        delayed1_ex_dslot <= 1'b0;
        delayed2_ex_dslot <= 1'b0;
        delayed_iee <= 3'b000;
        delayed_tee <= 3'b000;
        except_type <= OR1200_EXCEPT_NONE;
    end else begin
        delayed_iee <= {delayed_iee[1:0], sr_iee_in};
        delayed_tee <= {delayed_tee[1:0], sr_tee_in};

        if (flushpipe) begin
            id_pc <= 32'b0;
            ex_pc <= 32'b0;
            id_exceptflags <= 3'b000;
            ex_exceptflags <= 3'b000;
            ex_dslot <= 1'b0;
            delayed1_ex_dslot <= 1'b0;
            delayed2_ex_dslot <= 1'b0;
        end else begin
            if (!id_freeze) begin
                id_pc <= if_pc;
                id_exceptflags <= if_exceptflags;
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

        case (state)
            STATE_IDLE: begin
                if (except_flushpipe) begin
                    state <= STATE_FLU1;
                    extend_flush <= 1'b1;
                    extend_flush_last <= 1'b0;
                    esr <= sr_we ? to_sr : sr;
                    casex (except_trig)
                        13'b1xxxxxxxxxxxx: begin
                            except_type <= OR1200_EXCEPT_TICK;
                            epcr <= epcr_id_path;
                        end
                        13'b01xxxxxxxxxxx: begin
                            except_type <= OR1200_EXCEPT_INT;
                            epcr <= epcr_id_path;
                        end
                        13'b001xxxxxxxxxx: begin
                            except_type <= OR1200_EXCEPT_ITLBMISS;
                            epcr <= epcr_ex_path;
                            eear <= ex_pc;
                        end
                        13'b0001xxxxxxxxx: begin
                            except_type <= OR1200_EXCEPT_IPF;
                            epcr <= epcr_id_path;
                            eear <= immu_pc_path;
                        end
                        13'b00001xxxxxxxx: begin
                            except_type <= OR1200_EXCEPT_BUSERR;
                            epcr <= epcr_ex_path;
                            eear <= epcr_ex_path;
                        end
                        13'b000001xxxxxxx: begin
                            except_type <= OR1200_EXCEPT_ILLEGAL;
                            epcr <= epcr_ex_path;
                            eear <= ex_pc;
                        end
                        13'b0000001xxxxxx: begin
                            except_type <= OR1200_EXCEPT_ALIGN;
                            epcr <= epcr_ex_path;
                            eear <= lsu_addr;
                        end
                        13'b00000001xxxxx: begin
                            except_type <= OR1200_EXCEPT_DTLBMISS;
                            epcr <= epcr_ex_path;
                            eear <= lsu_addr;
                        end
                        13'b000000001xxxx: begin
                            except_type <= OR1200_EXCEPT_DPF;
                            epcr <= epcr_ex_path;
                            eear <= lsu_addr;
                        end
                        13'b0000000001xxx: begin
                            except_type <= OR1200_EXCEPT_BUSERR;
                            epcr <= epcr_ex_path;
                            eear <= lsu_addr;
                        end
                        13'b00000000001xx: begin
                            except_type <= OR1200_EXCEPT_RANGE;
                            epcr <= epcr_id_path;
                        end
                        13'b000000000001x: begin
                            except_type <= OR1200_EXCEPT_TRAP;
                            epcr <= epcr_ex_path;
                        end
                        13'b0000000000001: begin
                            except_type <= OR1200_EXCEPT_SYSCALL;
                            epcr <= epcr_id_path;
                        end
                        default: begin
                            except_type <= OR1200_EXCEPT_NONE;
                        end
                    endcase
                end else if (pc_we) begin
                    state <= STATE_FLU1;
                    extend_flush <= 1'b1;
                    extend_flush_last <= 1'b0;
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
                extend_flush_last <= 1'b0;
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
                extend_flush <= 1'b0;
                extend_flush_last <= 1'b0;
                except_type <= OR1200_EXCEPT_NONE;
            end
        endcase
    end
end

endmodule

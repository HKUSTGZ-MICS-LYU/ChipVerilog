module or1200_except (
    input wire clk,
    input wire rst,
    input wire sig_ibuserr,
    input wire sig_dbuserr,
    input wire sig_illegal,
    input wire sig_align,
    input wire sig_range,
    input wire sig_dtlbmiss,
    input wire sig_dmmufault,
    input wire sig_int,
    input wire sig_syscall,
    input wire sig_trap,
    input wire sig_itlbmiss,
    input wire sig_immufault,
    input wire sig_tick,
    input wire branch_taken,
    input wire genpc_freeze,
    input wire id_freeze,
    input wire ex_freeze,
    input wire wb_freeze,
    input wire if_stall,
    input wire [31:0] if_pc,
    output wire [31:0] id_pc,
    output wire [31:2] lr_sav,
    output wire flushpipe,
    output wire extend_flush,
    output reg [3:0] except_type,
    output wire except_start,
    output wire except_started,
    output wire [12:0] except_stop,
    input wire ex_void,
    output wire [31:0] spr_dat_ppc,
    output wire [31:0] spr_dat_npc,
    input wire [31:0] datain,
    input wire [13:0] du_dsr,
    input wire epcr_we,
    input wire eear_we,
    input wire esr_we,
    input wire pc_we,
    output reg [31:0] epcr,
    output reg [31:0] eear,
    output reg [15:0] esr,
    input wire sr_we,
    input wire [15:0] to_sr,
    input wire [15:0] sr,
    input wire [31:0] lsu_addr,
    output wire abort_ex,
    input wire icpu_ack_i,
    input wire icpu_err_i,
    input wire dcpu_ack_i,
    input wire dcpu_err_i
);

// Parameters
localparam OR1200_EXCEPT_NONE = 4'd0;
localparam OR1200_EXCEPT_TICK = 4'd1;
localparam OR1200_EXCEPT_INT = 4'd2;
localparam OR1200_EXCEPT_ITLBMISS = 4'd3;
localparam OR1200_EXCEPT_IMMUFAULT = 4'd4;
localparam OR1200_EXCEPT_IBUSERR = 4'd5;
localparam OR1200_EXCEPT_ILLEGAL = 4'd6;
localparam OR1200_EXCEPT_ALIGN = 4'd7;
localparam OR1200_EXCEPT_DTLBMISS = 4'd8;
localparam OR1200_EXCEPT_DMMUFAULT = 4'd9;
localparam OR1200_EXCEPT_DBUSERR = 4'd10;
localparam OR1200_EXCEPT_RANGE = 4'd11;
localparam OR1200_EXCEPT_TRAP = 4'd12;
localparam OR1200_EXCEPT_SYSCALL = 4'd13;

localparam IDLE = 3'd0;
localparam FLU1 = 3'd1;
localparam FLU2 = 3'd2;
localparam FLU3 = 3'd3;
localparam FLU4 = 3'd4;
localparam FLU5 = 3'd5;

// Internal registers
reg [31:0] id_pc_reg;
reg [31:0] ex_pc_reg;
reg [31:0] wb_pc_reg;
reg [2:0] id_exceptflags;
reg [2:0] ex_exceptflags;
reg [2:0] state;
reg extend_flush_reg;
reg extend_flush_last;
reg ex_dslot;
reg delayed1_ex_dslot;
reg delayed2_ex_dslot;
reg [2:0] delayed_iee;
reg [2:0] delayed_tee;
reg id_branch_taken; // pipeline branch_taken

// Combinational wires
wire [2:0] if_exceptflags;
wire int_pending;
wire tick_pending;
wire [12:0] except_trig;
wire except_flushpipe;

// Assign outputs
assign id_pc = id_pc_reg;
assign lr_sav = ex_pc_reg[31:2];
assign flushpipe = except_flushpipe | pc_we | extend_flush_reg;
assign extend_flush = extend_flush_reg;
assign except_start = (except_type != OR1200_EXCEPT_NONE) & extend_flush_reg;
assign except_started = extend_flush_reg & except_start;
assign spr_dat_ppc = wb_pc_reg;
assign spr_dat_npc = ex_void ? id_pc_reg : ex_pc_reg;

// abort_ex
assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;

// if_exceptflags
assign if_exceptflags = {sig_ibuserr, sig_itlbmiss, sig_immufault};

// int_pending and tick_pending
assign int_pending = sig_int & sr[2] & delayed_iee[2] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;
assign tick_pending = sig_tick & sr[1] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

// except_trig (13-bit, priority)
assign except_trig[12] = tick_pending & ~du_dsr[12];
assign except_trig[11] = int_pending & ~du_dsr[11];
assign except_trig[10] = sig_itlbmiss & ~du_dsr[10];
assign except_trig[9] = sig_immufault & ~du_dsr[9];
assign except_trig[8] = sig_ibuserr & ~du_dsr[8];
assign except_trig[7] = sig_illegal & ~du_dsr[7];
assign except_trig[6] = sig_align & ~du_dsr[6];
assign except_trig[5] = sig_dtlbmiss & ~du_dsr[5];
assign except_trig[4] = sig_dmmufault & ~du_dsr[4];
assign except_trig[3] = sig_dbuserr & ~du_dsr[3];
assign except_trig[2] = sig_range & ~du_dsr[2];
assign except_trig[1] = (sig_trap & ~ex_freeze) & ~du_dsr[1];
assign except_trig[0] = (sig_syscall & ~ex_freeze) & ~du_dsr[0];

// except_stop (13-bit)
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
assign except_stop[1] = (sig_trap & ~ex_freeze) & du_dsr[1];
assign except_stop[0] = (sig_syscall & ~ex_freeze) & du_dsr[0];

// except_flushpipe
assign except_flushpipe = (|except_trig) && (state == IDLE);

// Sequential logic
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
        id_branch_taken <= 1'b0;
        state <= IDLE;
        except_type <= OR1200_EXCEPT_NONE;
        extend_flush_reg <= 1'b0;
        extend_flush_last <= 1'b0;
        epcr <= 32'd0;
        eear <= 32'd0;
        esr <= {1'b1, {14{1'b0}}, 1'b1}; // 16'h8001
    end else begin
        // Pipeline PC and exception flags
        if (flushpipe) begin
            id_pc_reg <= 32'd0;
            ex_pc_reg <= 32'd0;
            id_exceptflags <= 3'd0;
            ex_exceptflags <= 3'd0;
        end else begin
            if (!id_freeze) begin
                id_pc_reg <= if_pc;
                id_exceptflags <= if_exceptflags;
            end
            if (!ex_freeze) begin
                ex_pc_reg <= id_pc_reg;
                ex_exceptflags <= id_exceptflags;
            end
        end
        if (!wb_freeze) begin
            wb_pc_reg <= ex_pc_reg;
        end

        // Pipeline branch_taken for delay slot detection
        if (!id_freeze) begin
            id_branch_taken <= branch_taken;
        end
        if (!ex_freeze) begin
            ex_dslot <= id_branch_taken;
        end

        // Delay slot pipeline
        delayed1_ex_dslot <= ex_dslot;
        delayed2_ex_dslot <= delayed1_ex_dslot;

        // Delayed iee and tee (shift from sr bits)
        delayed_iee <= {delayed_iee[1:0], sr[2]};
        delayed_tee <= {delayed_tee[1:0], sr[1]};

        // FSM
        case (state)
            IDLE: begin
                if (except_flushpipe) begin
                    // Save ESR
                    if (sr_we)
                        esr <= to_sr;
                    else
                        esr <= sr;
                    // Exception priority resolution
                    casex (except_trig)
                        13'b1_xxxx_xxxx_xxxx: begin // tick
                            except_type <= OR1200_EXCEPT_TICK;
                            eear <= 32'd0;
                            epcr <= ex_dslot ? wb_pc_reg : id_pc_reg;
                        end
                        13'b01_xxxx_xxxx_xxx: begin // int
                            except_type <= OR1200_EXCEPT_INT;
                            eear <= 32'd0;
                            epcr <= ex_dslot ? wb_pc_reg : id_pc_reg;
                        end
                        13'b001_xxxx_xxxx_xx: begin // itlbmiss
                            except_type <= OR1200_EXCEPT_ITLBMISS;
                            eear <= ex_pc_reg;
                            epcr <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                        end
                        13'b0001_xxxx_xxxx_x: begin // immufault
                            except_type <= OR1200_EXCEPT_IMMUFAULT;
                            eear <= ex_dslot ? ex_pc_reg : id_pc_reg;
                            epcr <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                        end
                        13'b00001_xxxx_xxxx: begin // ibuserr
                            except_type <= OR1200_EXCEPT_IBUSERR;
                            eear <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                            epcr <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                        end
                        13'b000001_xxxx_xxx: begin // illegal
                            except_type <= OR1200_EXCEPT_ILLEGAL;
                            eear <= ex_pc_reg;
                            epcr <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                        end
                        13'b0000001_xxxx_xx: begin // align
                            except_type <= OR1200_EXCEPT_ALIGN;
                            eear <= lsu_addr;
                            epcr <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                        end
                        13'b00000001_xxxx_x: begin // dtlbmiss
                            except_type <= OR1200_EXCEPT_DTLBMISS;
                            eear <= lsu_addr;
                            epcr <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                        end
                        13'b000000001_xxxx: begin // dmmufault
                            except_type <= OR1200_EXCEPT_DMMUFAULT;
                            eear <= lsu_addr;
                            epcr <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                        end
                        13'b0000000001_xxx: begin // dbuserr
                            except_type <= OR1200_EXCEPT_DBUSERR;
                            eear <= lsu_addr;
                            epcr <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                        end
                        13'b00000000001_xx: begin // range
                            except_type <= OR1200_EXCEPT_RANGE;
                            eear <= 32'd0;
                            epcr <= ex_dslot ? wb_pc_reg : id_pc_reg;
                        end
                        13'b000000000001_x: begin // trap
                            except_type <= OR1200_EXCEPT_TRAP;
                            eear <= 32'd0;
                            epcr <= ex_dslot ? wb_pc_reg : ex_pc_reg;
                        end
                        13'b0000000000001: begin // syscall
                            except_type <= OR1200_EXCEPT_SYSCALL;
                            eear <= 32'd0;
                            epcr <= ex_dslot ? wb_pc_reg : id_pc_reg;
                        end
                        default: begin
                            // Should not occur
                        end
                    endcase
                    state <= FLU1;
                    extend_flush_reg <= 1'b1;
                end else if (pc_we) begin
                    state <= FLU1;
                    extend_flush_reg <= 1'b1;
                end

                // SPR writes when idle and not an exception or pc_we
                if (!except_flushpipe && !pc_we) begin
                    if (epcr_we)
                        epcr <= datain;
                    if (eear_we)
                        eear <= datain;
                    if (esr_we)
                        esr <= {1'b1, datain[14:0]};
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

            default: state <= IDLE;
        endcase
    end
end

endmodule

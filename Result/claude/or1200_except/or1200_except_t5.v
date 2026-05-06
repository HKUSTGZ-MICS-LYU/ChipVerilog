// Generated from: Description/or1200_except_description.txt
module or1200_except(
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

`include "or1200_defines.v"

  // Pipeline PCs and IF exception flags
  reg [31:0] id_pc_r, ex_pc_r, wb_pc_r;
  reg [2:0]  id_exceptflags, ex_exceptflags;

  assign id_pc = id_pc_r;

  // Decode IF exception flags into ID stage (ordered as described)
  wire if_sig_itlbmiss  = sig_itlbmiss;
  wire if_sig_immufault = sig_immufault;
  wire if_sig_ibuserr   = sig_ibuserr;

  // Delay slot tracking (simplified)
  reg ex_dslot, delayed1_ex_dslot, delayed2_ex_dslot;

  // Exception registers
  reg [31:0] epcr_r, eear_r;
  reg [15:0] esr_r;
  assign epcr = epcr_r;
  assign eear = eear_r;
  assign esr  = esr_r;

  // SPR read data
  assign spr_dat_ppc = wb_pc_r;
  assign spr_dat_npc = ex_void ? id_pc_r : ex_pc_r;

  // Link save
  assign lr_sav = ex_pc_r[31:2];

  // Abort execute for selected exceptions
  assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;

  // Delayed interrupt enable tracking (3 bits in SR)
  reg [2:0] delayed_iee;
  reg [2:0] delayed_tee;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      delayed_iee <= 3'b000;
      delayed_tee <= 3'b000;
    end else begin
      delayed_iee <= {delayed_iee[1:0], sr[2]};
      delayed_tee <= {delayed_tee[1:0], sr[1]};
    end
  end

  wire int_pending =
      sig_int & sr[2] & delayed_iee[2] &
      ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

  wire tick_pending =
      sig_tick & sr[1] &
      ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;

  // Exception trigger vectors, gated by DSR bits into stop vs trig
  wire [12:0] raw_vec = {
      tick_pending,
      int_pending,
      ex_exceptflags[1], // itlbmiss
      ex_exceptflags[0], // immufault
      ex_exceptflags[2], // ibuserr
      sig_illegal,
      sig_align,
      sig_dtlbmiss,
      sig_dmmufault,
      sig_dbuserr,
      sig_range,
      sig_trap & ~ex_freeze,
      sig_syscall & ~ex_freeze
  };

  wire [12:0] except_trig = raw_vec & ~du_dsr[12:0];
  assign except_stop = raw_vec & du_dsr[12:0];

  // FSM
  localparam [2:0] IDLE=3'd0, FLU1=3'd1, FLU2=3'd2, FLU3=3'd3, FLU4=3'd4, FLU5=3'd5;
  reg [2:0] state;
  reg extend_flush_r;
  reg [3:0] except_type_r;
  assign extend_flush = extend_flush_r;
  assign except_type  = except_type_r;

  wire except_flushpipe = (except_trig != 13'd0) & (state == IDLE);
  assign flushpipe = except_flushpipe | pc_we | extend_flush_r;

  assign except_start = (except_type_r != `OR1200_EXCEPT_NONE) & extend_flush_r;
  assign except_started = extend_flush_r & except_start;

  // Exception priority resolution
  function automatic [3:0] pick_except_type(input [12:0] v);
    begin
      casex (v)
        13'b1xxxxxxxxxxxx: pick_except_type = `OR1200_EXCEPT_TICK;
        13'b01xxxxxxxxxxx: pick_except_type = `OR1200_EXCEPT_INT;
        13'b001xxxxxxxxxx: pick_except_type = `OR1200_EXCEPT_ITLBMISS;
        13'b0001xxxxxxxxx: pick_except_type = `OR1200_EXCEPT_IPF;
        13'b00001xxxxxxxx: pick_except_type = `OR1200_EXCEPT_BUSERR;
        13'b000001xxxxxxx: pick_except_type = `OR1200_EXCEPT_ILLEGAL;
        13'b0000001xxxxxx: pick_except_type = `OR1200_EXCEPT_ALIGN;
        13'b00000001xxxxx: pick_except_type = `OR1200_EXCEPT_DTLBMISS;
        13'b000000001xxxx: pick_except_type = `OR1200_EXCEPT_DPF;
        13'b0000000001xxx: pick_except_type = `OR1200_EXCEPT_BUSERR;
        13'b00000000001xx: pick_except_type = `OR1200_EXCEPT_RANGE;
        13'b000000000001x: pick_except_type = `OR1200_EXCEPT_TRAP;
        13'b0000000000001: pick_except_type = `OR1200_EXCEPT_SYSCALL;
        default:           pick_except_type = `OR1200_EXCEPT_NONE;
      endcase
    end
  endfunction

  // Basic PC selection for EPCR/EEAR (description-level behavior)
  wire [31:0] pc_for_epcr = ex_dslot ? wb_pc_r : ex_pc_r;

  // sequential
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      id_pc_r <= 32'd0;
      ex_pc_r <= 32'd0;
      wb_pc_r <= 32'd0;
      id_exceptflags <= 3'b000;
      ex_exceptflags <= 3'b000;
      ex_dslot <= 1'b0;
      delayed1_ex_dslot <= 1'b0;
      delayed2_ex_dslot <= 1'b0;
      epcr_r <= 32'd0;
      eear_r <= 32'd0;
      esr_r  <= {1'b1, {`OR1200_SR_WIDTH-2{1'b0}}, 1'b1};
      state <= IDLE;
      extend_flush_r <= 1'b0;
      except_type_r <= `OR1200_EXCEPT_NONE;
    end else begin
      // PC/flag pipeline
      if (flushpipe) begin
        if (!id_freeze) begin
          id_pc_r <= 32'd0;
          id_exceptflags <= 3'b000;
        end
        if (!ex_freeze) begin
          ex_pc_r <= 32'd0;
          ex_exceptflags <= 3'b000;
        end
      end else begin
        if (!id_freeze) begin
          id_pc_r <= if_pc;
          id_exceptflags <= {if_sig_ibuserr, if_sig_itlbmiss, if_sig_immufault};
        end
        if (!ex_freeze) begin
          ex_pc_r <= id_pc_r;
          ex_exceptflags <= id_exceptflags;
        end
      end

      if (!wb_freeze) wb_pc_r <= ex_pc_r;

      // delay slot tracking (approximate)
      if (!ex_freeze) begin
        ex_dslot <= branch_taken;
        delayed1_ex_dslot <= ex_dslot;
        delayed2_ex_dslot <= delayed1_ex_dslot;
      end

      // SPR writes when idle and not taking exception
      if (state == IDLE && !except_flushpipe) begin
        if (epcr_we) epcr_r <= datain;
        if (eear_we) eear_r <= datain;
        if (esr_we)  esr_r  <= {1'b1, datain[14:0]};
      end

      // FSM transitions
      case (state)
        IDLE: begin
          if (except_flushpipe) begin
            extend_flush_r <= 1'b1;
            except_type_r <= pick_except_type(except_trig);
            esr_r <= sr_we ? to_sr : sr;

            // Save EPCR/EEAR per exception class (coarse mapping)
            epcr_r <= pc_for_epcr;
            if (except_trig[2] | except_trig[3] | except_trig[4] | except_trig[5]) begin
              // instruction-side-ish: use ex_pc as EEAR for itlb/immu/ibus/illegal
              eear_r <= ex_pc_r;
            end else if (except_trig[7] | except_trig[8] | except_trig[9]) begin
              // data-side faults
              eear_r <= lsu_addr;
            end else begin
              eear_r <= eear_r;
            end
            state <= FLU1;
          end else if (pc_we) begin
            extend_flush_r <= 1'b1;
            except_type_r <= `OR1200_EXCEPT_NONE;
            state <= FLU1;
          end
        end

        FLU1: begin
          if (icpu_ack_i | icpu_err_i | genpc_freeze) state <= FLU2;
        end

        FLU2: begin
`ifdef OR1200_TRAP
          if (except_type_r == `OR1200_EXCEPT_TRAP) begin
            state <= IDLE;
            extend_flush_r <= 1'b0;
            except_type_r <= `OR1200_EXCEPT_NONE;
          end else begin
            state <= FLU3;
          end
`else
          state <= FLU3;
`endif
        end

        FLU3: state <= FLU4;
        FLU4: begin
          state <= FLU5;
          extend_flush_r <= 1'b0;
        end
        FLU5: begin
          if (!if_stall && !id_freeze) begin
            state <= IDLE;
            except_type_r <= `OR1200_EXCEPT_NONE;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

  // Unused inputs in this implementation (as per description notes)
  wire _unused = dcpu_ack_i ^ dcpu_err_i ^ delayed2_ex_dslot;

endmodule


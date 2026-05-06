`include "timescale.v"
`include "or1200_defines.v"

module or1200_if(
    clk, rst,
    icpu_dat_i, icpu_ack_i, icpu_err_i, icpu_adr_i, icpu_tag_i,
    if_freeze, if_insn, if_pc, flushpipe,
    if_stall, no_more_dslot, genpc_refetch, rfe,
    except_itlbmiss, except_immufault, except_ibuserr
);

input         clk, rst;
input  [31:0] icpu_dat_i;
input         icpu_ack_i;
input         icpu_err_i;
input  [31:0] icpu_adr_i;
input  [3:0]  icpu_tag_i;
input         if_freeze;
output [31:0] if_insn;
output [31:0] if_pc;
input         flushpipe;
output        if_stall;
input         no_more_dslot;
output        genpc_refetch;
input         rfe;
output        except_itlbmiss;
output        except_immufault;
output        except_ibuserr;

reg [31:0] insn_saved;
reg [31:0] addr_saved;
reg        saved;

// if_insn: priority mux
// 1. Error/control NOP (err, no_more_dslot, rfe)
// 2. Saved instruction
// 3. New acknowledge
// 4. Default NOP
assign if_insn = (icpu_err_i | no_more_dslot | rfe) ?
                     {`OR1200_OR32_NOP, 26'h041_0000} :
                 saved ?
                     insn_saved :
                 icpu_ack_i ?
                     icpu_dat_i :
                     {`OR1200_OR32_NOP, 26'h061_0000};

// if_pc
assign if_pc = saved ? addr_saved : icpu_adr_i;

// if_stall: no error, no ack, no saved
assign if_stall = !icpu_err_i & !icpu_ack_i & !saved;

// genpc_refetch: saved instruction exists and new ack arrives
assign genpc_refetch = saved & icpu_ack_i;

// Exception decode (suppressed by no_more_dslot)
assign except_itlbmiss = icpu_err_i & (icpu_tag_i == `OR1200_ITAG_TE) & !no_more_dslot;
assign except_immufault = icpu_err_i & (icpu_tag_i == `OR1200_ITAG_PE) & !no_more_dslot;
assign except_ibuserr   = icpu_err_i & (icpu_tag_i == `OR1200_ITAG_BE) & !no_more_dslot;

// Sequential: saved, insn_saved, addr_saved
always @(posedge clk or posedge rst) begin
    if (rst) begin
        saved      <= 1'b0;
        insn_saved <= {`OR1200_OR32_NOP, 26'h041_0000};
        addr_saved <= 32'h00000000;
    end
    else if (flushpipe) begin
        saved      <= 1'b0;
        insn_saved <= {`OR1200_OR32_NOP, 26'h041_0000};
        addr_saved <= 32'h00000000;
    end
    else begin
        // saved flag
        if (icpu_ack_i & if_freeze & !saved)
            saved <= 1'b1;
        else if (!if_freeze)
            saved <= 1'b0;

        // insn_saved
        if (icpu_ack_i & if_freeze & !saved)
            insn_saved <= icpu_dat_i;
        else if (!if_freeze)
            insn_saved <= {`OR1200_OR32_NOP, 26'h041_0000};

        // addr_saved
        if (icpu_ack_i & if_freeze & !saved)
            addr_saved <= icpu_adr_i;
        else if (!if_freeze)
            addr_saved <= icpu_adr_i;
    end
end

endmodule
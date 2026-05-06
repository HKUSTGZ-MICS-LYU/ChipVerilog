// Generated from or1200_lsu/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_lsu(
    // Internal i/f
    input [31:0] addrbase,
    input [31:0] addrofs,
    input [3:0] lsu_op,
    input [31:0] lsu_datain,
    output [31:0] lsu_dataout,
    output lsu_stall,
    output lsu_unstall,
    input du_stall,
    output except_align,
    output except_dtlbmiss,
    output except_dmmufault,
    output except_dbuserr,

    // External i/f to DC
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i,
    input [3:0] dcpu_tag_i
);

reg [31:0] lsu_dataout_r;
reg lsu_stall_r;
reg lsu_unstall_r;
reg except_align_r;
reg except_dtlbmiss_r;
reg except_dmmufault_r;
reg except_dbuserr_r;
reg [31:0] dcpu_adr_o_r;
reg dcpu_cycstb_o_r;
reg dcpu_we_o_r;
reg [3:0] dcpu_sel_o_r;
reg [3:0] dcpu_tag_o_r;
reg [31:0] dcpu_dat_o_r;
assign lsu_dataout = lsu_dataout_r;
assign lsu_stall = lsu_stall_r;
assign lsu_unstall = lsu_unstall_r;
assign except_align = except_align_r;
assign except_dtlbmiss = except_dtlbmiss_r;
assign except_dmmufault = except_dmmufault_r;
assign except_dbuserr = except_dbuserr_r;
assign dcpu_adr_o = dcpu_adr_o_r;
assign dcpu_cycstb_o = dcpu_cycstb_o_r;
assign dcpu_we_o = dcpu_we_o_r;
assign dcpu_sel_o = dcpu_sel_o_r;
assign dcpu_tag_o = dcpu_tag_o_r;
assign dcpu_dat_o = dcpu_dat_o_r;

always @* begin
    reg [31:0] addr_sum;
    addr_sum = addrbase + addrofs;
    dcpu_adr_o_r = addr_sum;
    dcpu_cycstb_o_r = lsu_op != 0;
    dcpu_we_o_r = lsu_op[3];
    dcpu_sel_o_r = (lsu_op[1:0] == 2'b00) ? 4'hf :
                   (addr_sum[1] ? 4'b0011 : 4'b1100);
    dcpu_tag_o_r = 4'd0;
    dcpu_dat_o_r = lsu_datain;
    lsu_stall_r = dcpu_cycstb_o_r && !dcpu_ack_i && !dcpu_err_i;
    except_align_r = (lsu_op[1:0] == 2'b10) && addr_sum[0];
    except_dtlbmiss_r = 1'b0;
    except_dmmufault_r = 1'b0;
    except_dbuserr_r = dcpu_err_i;
    lsu_unstall_r = dcpu_ack_i | dcpu_err_i | dcpu_rty_i;
    lsu_dataout_r = dcpu_dat_i;
end

endmodule

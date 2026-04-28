`include "timescale.v"
`include "or1200_defines.v"

module or1200_du(
    clk, rst,
    dcpu_cycstb_i, dcpu_we_i, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc,
    icpu_cycstb_i,
    ex_freeze, branch_op, ex_insn, id_pc, spr_dat_npc, rf_dataw,
    du_dsr, du_stall, du_addr, du_dat_i, du_dat_o, du_read, du_write,
    du_except, du_hwbkpt,
    spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o,
    dbg_stall_i, dbg_ewt_i,
    dbg_lss_o, dbg_is_o, dbg_wp_o, dbg_bp_o,
    dbg_stb_i, dbg_we_i, dbg_adr_i, dbg_dat_i, dbg_dat_o, dbg_ack_o
);

input         clk, rst;
input         dcpu_cycstb_i, dcpu_we_i;
input  [31:0] dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc;
input  [0:0]  icpu_cycstb_i;
input         ex_freeze;
input  [2:0]  branch_op;
input  [31:0] ex_insn, id_pc, spr_dat_npc, rf_dataw;
output [13:0] du_dsr;
output        du_stall;
output [31:0] du_addr;
input  [31:0] du_dat_i;
output [31:0] du_dat_o;
output        du_read, du_write;
input  [12:0] du_except;
output        du_hwbkpt;
input         spr_cs, spr_write;
input  [31:0] spr_addr, spr_dat_i;
output [31:0] spr_dat_o;
input         dbg_stall_i, dbg_ewt_i;
output [3:0]  dbg_lss_o;
output [1:0]  dbg_is_o;
output [10:0] dbg_wp_o;
output        dbg_bp_o;
input         dbg_stb_i, dbg_we_i;
input  [31:0] dbg_adr_i, dbg_dat_i;
output [31:0] dbg_dat_o;
output        dbg_ack_o;

// External debug interface forwarding
assign du_stall  = dbg_stall_i;
assign du_addr   = dbg_adr_i;
assign du_dat_o  = dbg_dat_i;
assign du_read   = dbg_stb_i & !dbg_we_i;
assign du_write  = dbg_stb_i &  dbg_we_i;
assign dbg_dat_o = du_dat_i;
assign dbg_wp_o  = 11'b000_0000_0000;

// dbg_ack_o: one-cycle delayed dbg_stb_i
reg dbg_ack_r;
always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_ack_r <= 1'b0;
    else
        dbg_ack_r <= dbg_stb_i;
end
assign dbg_ack_o = dbg_ack_r;

`ifdef OR1200_DU_IMPLEMENTED

// Debug registers
`ifdef OR1200_DU_DMR1
reg [`OR1200_DU_DMR1_WIDTH-1:0] dmr1;
wire dmr1_sel = spr_cs & (spr_addr[10:0] == `OR1200_DU_DMR1);
always @(posedge clk or posedge rst)
    if (rst) dmr1 <= 0;
    else if (dmr1_sel & spr_write) dmr1 <= spr_dat_i[`OR1200_DU_DMR1_WIDTH-1:0];
`else
wire [`OR1200_DU_DMR1_WIDTH-1:0] dmr1 = 0;
`endif

`ifdef OR1200_DU_DMR2
reg [`OR1200_DU_DMR2_WIDTH-1:0] dmr2;
wire dmr2_sel = spr_cs & (spr_addr[10:0] == `OR1200_DU_DMR2);
always @(posedge clk or posedge rst)
    if (rst) dmr2 <= 0;
    else if (dmr2_sel & spr_write) dmr2 <= spr_dat_i[`OR1200_DU_DMR2_WIDTH-1:0];
`else
wire [`OR1200_DU_DMR2_WIDTH-1:0] dmr2 = 0;
`endif

`ifdef OR1200_DU_DSR
reg [`OR1200_DU_DSR_WIDTH-1:0] dsr;
wire dsr_sel = spr_cs & (spr_addr[10:0] == `OR1200_DU_DSR);
always @(posedge clk or posedge rst)
    if (rst) dsr <= 0;
    else if (dsr_sel & spr_write) dsr <= spr_dat_i[`OR1200_DU_DSR_WIDTH-1:0];
`else
wire [`OR1200_DU_DSR_WIDTH-1:0] dsr = 0;
`endif
assign du_dsr = dsr;

`ifdef OR1200_DU_DRR
reg [`OR1200_DU_DRR_WIDTH-1:0] drr;
wire drr_sel = spr_cs & (spr_addr[10:0] == `OR1200_DU_DRR);
`endif

// except_stop decode
wire [13:0] except_stop;
assign except_stop[ 0] = du_except[0];
assign except_stop[ 1] = du_except[1];
assign except_stop[ 2] = du_except[2];
assign except_stop[ 3] = du_except[3];
assign except_stop[ 4] = du_except[4];
assign except_stop[ 5] = du_except[5];
assign except_stop[ 6] = du_except[6];
assign except_stop[ 7] = du_except[7];
assign except_stop[ 8] = du_except[8];
assign except_stop[ 9] = du_except[9];
assign except_stop[10] = du_except[10];
assign except_stop[11] = du_except[11];
assign except_stop[12] = du_except[12];
assign except_stop[13] = 1'b0;

`ifdef OR1200_DU_DRR
always @(posedge clk or posedge rst)
    if (rst) drr <= 0;
    else if (drr_sel & spr_write) drr <= spr_dat_i[`OR1200_DU_DRR_WIDTH-1:0];
    else drr <= drr | except_stop[`OR1200_DU_DRR_WIDTH-1:0];
`endif

// DVR/DCR pairs
`ifdef OR1200_DU_DVRDCR_WIDTH
`define OR1200_DU_N_HW_BKPTS 8
reg [31:0] dvr [0:`OR1200_DU_N_HW_BKPTS-1];
reg [7:0]  dcr [0:`OR1200_DU_N_HW_BKPTS-1];
integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i=0; i<`OR1200_DU_N_HW_BKPTS; i=i+1) begin
            dvr[i] <= 0;
            dcr[i] <= 0;
        end
    end else begin
        if (spr_cs & spr_write) begin
            case (spr_addr[10:0])
                `OR1200_DU_DVR0: dvr[0] <= spr_dat_i;
                `OR1200_DU_DVR1: dvr[1] <= spr_dat_i;
                `OR1200_DU_DVR2: dvr[2] <= spr_dat_i;
                `OR1200_DU_DVR3: dvr[3] <= spr_dat_i;
                `OR1200_DU_DVR4: dvr[4] <= spr_dat_i;
                `OR1200_DU_DVR5: dvr[5] <= spr_dat_i;
                `OR1200_DU_DVR6: dvr[6] <= spr_dat_i;
                `OR1200_DU_DVR7: dvr[7] <= spr_dat_i;
                `OR1200_DU_DCR0: dcr[0] <= spr_dat_i[7:0];
                `OR1200_DU_DCR1: dcr[1] <= spr_dat_i[7:0];
                `OR1200_DU_DCR2: dcr[2] <= spr_dat_i[7:0];
                `OR1200_DU_DCR3: dcr[3] <= spr_dat_i[7:0];
                `OR1200_DU_DCR4: dcr[4] <= spr_dat_i[7:0];
                `OR1200_DU_DCR5: dcr[5] <= spr_dat_i[7:0];
                `OR1200_DU_DCR6: dcr[6] <= spr_dat_i[7:0];
                `OR1200_DU_DCR7: dcr[7] <= spr_dat_i[7:0];
            endcase
        end
    end
end
`endif

// DWCR
`ifdef OR1200_DU_DWCR0
reg [31:0] dwcr0;
wire dwcr0_sel = spr_cs & (spr_addr[10:0] == `OR1200_DU_DWCR0);
always @(posedge clk or posedge rst)
    if (rst) dwcr0 <= 0;
    else if (dwcr0_sel & spr_write) dwcr0 <= spr_dat_i;
`else
wire [31:0] dwcr0 = 0;
`endif

`ifdef OR1200_DU_DWCR1
reg [31:0] dwcr1;
wire dwcr1_sel = spr_cs & (spr_addr[10:0] == `OR1200_DU_DWCR1);
always @(posedge clk or posedge rst)
    if (rst) dwcr1 <= 0;
    else if (dwcr1_sel & spr_write) dwcr1 <= spr_dat_i;
`else
wire [31:0] dwcr1 = 0;
`endif

// Hardware watchpoints
`ifdef OR1200_DU_HWBKPTS
reg [10:0] wp;
always @(*) begin
    reg [31:0] comp_target [0:7];
    reg        comp_en     [0:7];
    reg [31:0] comp_a      [0:7];
    reg        match       [0:7];
    integer j;
    for (j=0; j<8; j=j+1) begin
        case (dcr[j][7:5])
            3'b000: begin comp_target[j] = id_pc;       comp_en[j] = 1'b0; end
            3'b001: begin comp_target[j] = id_pc;       comp_en[j] = 1'b1; end
            3'b010: begin comp_target[j] = dcpu_adr_i;  comp_en[j] = dcpu_cycstb_i & !dcpu_we_i; end
            3'b011: begin comp_target[j] = dcpu_adr_i;  comp_en[j] = dcpu_cycstb_i &  dcpu_we_i; end
            3'b100: begin comp_target[j] = dcpu_dat_dc; comp_en[j] = dcpu_cycstb_i & !dcpu_we_i; end
            3'b101: begin comp_target[j] = dcpu_dat_lsu;comp_en[j] = dcpu_cycstb_i &  dcpu_we_i; end
            3'b110: begin comp_target[j] = dcpu_adr_i;  comp_en[j] = dcpu_cycstb_i; end
            3'b111: begin comp_target[j] = dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc;
                         comp_en[j] = dcpu_cycstb_i; end
        endcase
        comp_a[j] = {comp_target[j][31] ^ dcr[j][0], comp_target[j][30:0]};
        if (!comp_en[j])
            match[j] = 1'b0;
        else begin
            case (dcr[j][4:2])
                3'b000: match[j] = 1'b0;
                3'b001: match[j] = (comp_a[j] == {dvr[j][31] ^ dcr[j][0], dvr[j][30:0]});
                3'b010: match[j] = (comp_a[j] <  {dvr[j][31] ^ dcr[j][0], dvr[j][30:0]});
                3'b011: match[j] = (comp_a[j] <= {dvr[j][31] ^ dcr[j][0], dvr[j][30:0]});
                3'b100: match[j] = (comp_a[j] >  {dvr[j][31] ^ dcr[j][0], dvr[j][30:0]});
                3'b101: match[j] = (comp_a[j] >= {dvr[j][31] ^ dcr[j][0], dvr[j][30:0]});
                3'b110: match[j] = (comp_a[j] != {dvr[j][31] ^ dcr[j][0], dvr[j][30:0]});
                default: match[j] = 1'b0;
            endcase
        end
    end
    // wp[0]
    wp[0] = match[0];
    // wp[1..7] chained by DMR1
    wp[1] = (dmr1[`OR1200_DU_DMR1_CW1] == 2'b00) ? 1'b0 :
            (dmr1[`OR1200_DU_DMR1_CW1] == 2'b01) ? match[1] :
            (dmr1[`OR1200_DU_DMR1_CW1] == 2'b10) ? match[1] & wp[0] :
                                                     match[1] | wp[0];
    wp[2] = (dmr1[`OR1200_DU_DMR1_CW2] == 2'b00) ? 1'b0 :
            (dmr1[`OR1200_DU_DMR1_CW2] == 2'b01) ? match[2] :
            (dmr1[`OR1200_DU_DMR1_CW2] == 2'b10) ? match[2] & wp[1] :
                                                     match[2] | wp[1];
    wp[3] = (dmr1[`OR1200_DU_DMR1_CW3] == 2'b00) ? 1'b0 :
            (dmr1[`OR1200_DU_DMR1_CW3] == 2'b01) ? match[3] :
            (dmr1[`OR1200_DU_DMR1_CW3] == 2'b10) ? match[3] & wp[2] :
                                                     match[3] | wp[2];
    wp[4] = (dmr1[`OR1200_DU_DMR1_CW4] == 2'b00) ? 1'b0 :
            (dmr1[`OR1200_DU_DMR1_CW4] == 2'b01) ? match[4] :
            (dmr1[`OR1200_DU_DMR1_CW4] == 2'b10) ? match[4] & wp[3] :
                                                     match[4] | wp[3];
    wp[5] = (dmr1[`OR1200_DU_DMR1_CW5] == 2'b00) ? 1'b0 :
            (dmr1[`OR1200_DU_DMR1_CW5] == 2'b01) ? match[5] :
            (dmr1[`OR1200_DU_DMR1_CW5] == 2'b10) ? match[5] & wp[4] :
                                                     match[5] | wp[4];
    wp[6] = (dmr1[`OR1200_DU_DMR1_CW6] == 2'b00) ? 1'b0 :
            (dmr1[`OR1200_DU_DMR1_CW6] == 2'b01) ? match[6] :
            (dmr1[`OR1200_DU_DMR1_CW6] == 2'b10) ? match[6] & wp[5] :
                                                     match[6] | wp[5];
    wp[7] = (dmr1[`OR1200_DU_DMR1_CW7] == 2'b00) ? 1'b0 :
            (dmr1[`OR1200_DU_DMR1_CW7] == 2'b01) ? match[7] :
            (dmr1[`OR1200_DU_DMR1_CW7] == 2'b10) ? match[7] & wp[6] :
                                                     match[7] | wp[6];
    // wp[8]: dwcr0 match
    wp[8]  = (dwcr0[31:16] == dwcr0[15:0]);
    // wp[9]: dwcr1 match
    wp[9]  = (dwcr1[31:16] == dwcr1[15:0]);
    // wp[10]: external watchpoint trigger
    wp[10] = dbg_ewt_i;
end

assign du_hwbkpt = |(wp[10:0] & dmr2[10:0]);
`else
assign du_hwbkpt = 1'b0;
`endif

// Breakpoint output
reg dbg_bp_r;
always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_bp_r <= 1'b0;
    else if (!ex_freeze) begin
        dbg_bp_r <= |except_stop
`ifdef OR1200_DU_DMR1_ST
                  | (dmr1[`OR1200_DU_DMR1_ST] & !ex_insn[16])
`endif
`ifdef OR1200_DU_DMR1_BT
                  | (dmr1[`OR1200_DU_DMR1_BT] & |branch_op & !ex_insn[16])
`endif
                  ;
    end else
        dbg_bp_r <= |except_stop;
end
assign dbg_bp_o = dbg_bp_r;

// Status outputs
`ifdef OR1200_DU_STATUS_UNIMPLEMENTED
reg dbg_is_toggle;
always @(posedge clk or posedge rst)
    if (rst) dbg_is_toggle <= 1'b0;
    else if (icpu_cycstb_i) dbg_is_toggle <= ~dbg_is_toggle;
assign dbg_lss_o = 4'b0000;
assign dbg_is_o  = {1'b0, dbg_is_toggle};
`else
assign dbg_lss_o = {dcpu_cycstb_i, dcpu_we_i, 2'b00};
assign dbg_is_o  = {icpu_cycstb_i, 1'b0};
`endif

// SPR read path
`ifdef OR1200_DU_READREGS
reg [31:0] spr_dat_o;
always @(*) begin
    spr_dat_o = 32'h00000000;
    if (spr_cs) begin
        case (spr_addr[10:0])
`ifdef OR1200_DU_DVRDCR_WIDTH
            `OR1200_DU_DVR0: spr_dat_o = dvr[0];
            `OR1200_DU_DVR1: spr_dat_o = dvr[1];
            `OR1200_DU_DVR2: spr_dat_o = dvr[2];
            `OR1200_DU_DVR3: spr_dat_o = dvr[3];
            `OR1200_DU_DVR4: spr_dat_o = dvr[4];
            `OR1200_DU_DVR5: spr_dat_o = dvr[5];
            `OR1200_DU_DVR6: spr_dat_o = dvr[6];
            `OR1200_DU_DVR7: spr_dat_o = dvr[7];
            `OR1200_DU_DCR0: spr_dat_o = {24'h0, dcr[0]};
            `OR1200_DU_DCR1: spr_dat_o = {24'h0, dcr[1]};
            `OR1200_DU_DCR2: spr_dat_o = {24'h0, dcr[2]};
            `OR1200_DU_DCR3: spr_dat_o = {24'h0, dcr[3]};
            `OR1200_DU_DCR4: spr_dat_o = {24'h0, dcr[4]};
            `OR1200_DU_DCR5: spr_dat_o = {24'h0, dcr[5]};
            `OR1200_DU_DCR6: spr_dat_o = {24'h0, dcr[6]};
            `OR1200_DU_DCR7: spr_dat_o = {24'h0, dcr[7]};
`endif
`ifdef OR1200_DU_DMR1
            `OR1200_DU_DMR1: spr_dat_o = {{32-`OR1200_DU_DMR1_WIDTH{1'b0}}, dmr1};
`endif
`ifdef OR1200_DU_DMR2
            `OR1200_DU_DMR2: spr_dat_o = {{32-`OR1200_DU_DMR2_WIDTH{1'b0}}, dmr2};
`endif
`ifdef OR1200_DU_DWCR0
            `OR1200_DU_DWCR0: spr_dat_o = dwcr0;
`endif
`ifdef OR1200_DU_DWCR1
            `OR1200_DU_DWCR1: spr_dat_o = dwcr1;
`endif
`ifdef OR1200_DU_DSR
            `OR1200_DU_DSR: spr_dat_o = {{32-`OR1200_DU_DSR_WIDTH{1'b0}}, dsr};
`endif
`ifdef OR1200_DU_DRR
            `OR1200_DU_DRR: spr_dat_o = {{32-`OR1200_DU_DRR_WIDTH{1'b0}}, drr};
`endif
            default: spr_dat_o = 32'h00000000;
        endcase
    end
end
`else
assign spr_dat_o = 32'h00000000;
`endif

`else // !OR1200_DU_IMPLEMENTED

assign du_dsr    = 14'h0000;
assign du_hwbkpt = 1'b0;
assign dbg_bp_o  = 1'b0;
assign dbg_lss_o = 4'b0000;
assign dbg_is_o  = 2'b00;
`ifdef OR1200_DU_READREGS
assign spr_dat_o = 32'h00000000;
`else
assign spr_dat_o = 32'h00000000;
`endif

`endif // OR1200_DU_IMPLEMENTED

endmodule
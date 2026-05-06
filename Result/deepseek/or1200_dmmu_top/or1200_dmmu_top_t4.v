module or1200_dmmu_top(
    input clk,
    input rst,
    input dc_en,
    input dmmu_en,
    input supv,
    input [31:0] dcpu_adr_i,
    input dcpu_cycstb_i,
    input dcpu_we_i,
    output reg [3:0] dcpu_tag_o,
    output reg dcpu_err_o,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output reg [31:0] spr_dat_o,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input qmemdmmu_err_i,
    input [3:0] qmemdmmu_tag_i,
    output reg [31:0] qmemdmmu_adr_o,
    output reg qmemdmmu_cycstb_o,
    output reg qmemdmmu_ci_o
);

    localparam [3:0] OR1200_DTAG_TE = 4'b0111;
    localparam [3:0] OR1200_DTAG_PE = 4'b1000;

`ifdef OR1200_NO_DMMU
    // Bypass mode
    always @* begin
        qmemdmmu_adr_o = dcpu_adr_i;
        qmemdmmu_cycstb_o = dcpu_cycstb_i;
        dcpu_tag_o = qmemdmmu_tag_i;
        dcpu_err_o = qmemdmmu_err_i;
        spr_dat_o = 32'b0;
        qmemdmmu_ci_o = dcpu_adr_i[31];
    end

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else
    // Normal DMMU implementation
    wire dtlb_hit;
    wire [31:13] dtlb_ppn;
    wire dtlb_uwe, dtlb_ure, dtlb_swe, dtlb_sre;
    wire dtlb_ci;
    wire [31:0] dtlb_dat_o;

    reg dtlb_done;
    reg [31:13] dcpu_vpn_r;

    wire dtlb_en = dmmu_en & dcpu_cycstb_i;
    wire miss = dtlb_done & ~dtlb_hit;
    wire fault;

    // Permission check
    always @* begin
        if (dtlb_done) begin
            if (~supv) begin
                if (dcpu_we_i)
                    fault = ~dtlb_uwe;
                else
                    fault = ~dtlb_ure;
            end else begin
                if (dcpu_we_i)
                    fault = ~dtlb_swe;
                else
                    fault = ~dtlb_sre;
            end
        end else begin
            fault = 1'b0;
        end
    end

    // dtlb_done sequential
    always @(posedge clk or posedge rst) begin
        if (rst)
            dtlb_done <= 1'b0;
        else if (dtlb_en)
            dtlb_done <= dcpu_cycstb_i;
        else
            dtlb_done <= 1'b0;
    end

    // dcpu_vpn_r is updated but not used in output
    always @(posedge clk) begin
        dcpu_vpn_r <= dcpu_adr_i[31:13];
    end

    // CPU error and tag
    always @* begin
        dcpu_err_o = miss | fault | qmemdmmu_err_i;
        if (miss)
            dcpu_tag_o = OR1200_DTAG_TE;
        else if (fault)
            dcpu_tag_o = OR1200_DTAG_PE;
        else
            dcpu_tag_o = qmemdmmu_tag_i;
    end

    // Downstream address
    always @* begin
        if (dmmu_en)
            qmemdmmu_adr_o = {dtlb_ppn, dcpu_adr_i[12:0]};
        else
            qmemdmmu_adr_o = dcpu_adr_i;
    end

    // Downstream request gating
    wire forward_wait;
    assign forward_wait = (dc_en | ~dmmu_en) ? 1'b1 : dtlb_done;
    always @* begin
        qmemdmmu_cycstb_o = dcpu_cycstb_i & forward_wait & ~miss & ~fault;
    end

    // Cache inhibit
    always @* begin
        if (dmmu_en)
            qmemdmmu_ci_o = dtlb_done ? dtlb_ci : 1'b0;
        else
            qmemdmmu_ci_o = dcpu_adr_i[31];
    end

    // SPR read data
    always @* begin
        if (spr_cs)
            spr_dat_o = dtlb_dat_o;
        else
            spr_dat_o = 32'b0;
    end

    // DTLB submodule instantiation
`ifdef OR1200_BIST
    or1200_dmmu_tlb #(
        .MBIST_CTRL_WIDTH(`OR1200_MBIST_CTRL_WIDTH)
    ) dtlb_inst (
        .clk(clk),
        .rst(rst),
        .addr(dcpu_adr_i),
        .en(dtlb_en),
        .spr_cs(spr_cs),
        .spr_write(spr_write),
        .spr_addr(spr_addr),
        .spr_dat_i(spr_dat_i),
        .hit(dtlb_hit),
        .ppn(dtlb_ppn),
        .uwe(dtlb_uwe),
        .ure(dtlb_ure),
        .swe(dtlb_swe),
        .sre(dtlb_sre),
        .ci(dtlb_ci),
        .dat_o(dtlb_dat_o),
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    );
`else
    or1200_dmmu_tlb dtlb_inst (
        .clk(clk),
        .rst(rst),
        .addr(dcpu_adr_i),
        .en(dtlb_en),
        .spr_cs(spr_cs),
        .spr_write(spr_write),
        .spr_addr(spr_addr),
        .spr_dat_i(spr_dat_i),
        .hit(dtlb_hit),
        .ppn(dtlb_ppn),
        .uwe(dtlb_uwe),
        .ure(dtlb_ure),
        .swe(dtlb_swe),
        .sre(dtlb_sre),
        .ci(dtlb_ci),
        .dat_o(dtlb_dat_o)
    );
`endif

`endif // OR1200_NO_DMMU

endmodule

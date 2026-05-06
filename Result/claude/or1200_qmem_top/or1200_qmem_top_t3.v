module or1200_qmem_top(
    input clk,
    input rst,
    input [31:0] dcqmem_adr_i,
    input dcqmem_cycstb_i,
    input dcqmem_we_i,
    input [3:0] dcqmem_sel_i,
    input [31:0] dcqmem_dat_i,
    output [31:0] dcqmem_dat_o,
    output dcqmem_ack_o,
    output dcqmem_rty_o,
    output dcqmem_err_o
);

    reg [31:0] qmem [0:1023];
    reg ack_reg;

    assign dcqmem_dat_o = qmem[dcqmem_adr_i[11:2]];
    assign dcqmem_ack_o = ack_reg;
    assign dcqmem_rty_o = !ack_reg & dcqmem_cycstb_i;
    assign dcqmem_err_o = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            ack_reg <= 1'b0;
        end
        else begin
            if (dcqmem_cycstb_i) begin
                if (dcqmem_we_i) begin
                    if (dcqmem_sel_i[0]) qmem[dcqmem_adr_i[11:2]][7:0] <= dcqmem_dat_i[7:0];
                    if (dcqmem_sel_i[1]) qmem[dcqmem_adr_i[11:2]][15:8] <= dcqmem_dat_i[15:8];
                    if (dcqmem_sel_i[2]) qmem[dcqmem_adr_i[11:2]][23:16] <= dcqmem_dat_i[23:16];
                    if (dcqmem_sel_i[3]) qmem[dcqmem_adr_i[11:2]][31:24] <= dcqmem_dat_i[31:24];
                end
                ack_reg <= 1'b1;
            end
            else begin
                ack_reg <= 1'b0;
            end
        end
    end

endmodule

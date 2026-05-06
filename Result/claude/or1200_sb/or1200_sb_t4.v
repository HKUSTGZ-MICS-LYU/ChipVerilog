module or1200_sb(
    input clk,
    input rst,
    input [31:0] dcsb_dat_i,
    input dcsb_ack_i,
    input dcsb_err_i,
    input [31:0] dcpu_dat_i,
    input dcpu_cycstb_i,
    input dcpu_we_i,
    output [31:0] dcpu_dat_o,
    output dcpu_ack_o,
    output dcpu_rty_o,
    output dcpu_err_o,
    output [31:0] dcsb_dat_o,
    output dcsb_cycstb_o,
    output dcsb_we_o
);

    reg [31:0] store_buffer;
    reg sb_valid;
    reg sb_we;

    assign dcpu_dat_o = dcsb_dat_i;
    assign dcpu_ack_o = dcsb_ack_i;
    assign dcpu_rty_o = dcsb_err_i;
    assign dcpu_err_o = dcsb_err_i;
    
    assign dcsb_dat_o = store_buffer;
    assign dcsb_cycstb_o = sb_valid;
    assign dcsb_we_o = sb_we;

    always @(posedge clk) begin
        if (rst) begin
            store_buffer <= 32'b0;
            sb_valid <= 1'b0;
            sb_we <= 1'b0;
        end
        else begin
            if (dcpu_cycstb_i & dcpu_we_i) begin
                store_buffer <= dcpu_dat_i;
                sb_valid <= 1'b1;
                sb_we <= 1'b1;
            end
            else if (dcsb_ack_i) begin
                sb_valid <= 1'b0;
                sb_we <= 1'b0;
            end
        end
    end

endmodule

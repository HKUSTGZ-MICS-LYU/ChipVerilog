module or1200_cfgr(
    input [31:0] spr_addr,
    output reg [31:0] spr_dat_o
);

    always @(*) begin
        case(spr_addr[7:0])
            8'h00: spr_dat_o = 32'h12000001;
            
            8'h01: spr_dat_o = 32'h0000000f;
            
            8'h02: spr_dat_o = 32'h00000000;
            
            8'h03: spr_dat_o = 32'h00000000;
            
            8'h04: spr_dat_o = 32'h00000000;
            
            8'h05: spr_dat_o = 32'h00000000;
            
            8'h06: spr_dat_o = 32'h00000000;
            
            8'h07: spr_dat_o = 32'h00000000;
            
            default: spr_dat_o = 32'h00000000;
        endcase
    end

endmodule

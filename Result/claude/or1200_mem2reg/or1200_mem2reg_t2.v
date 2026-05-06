module or1200_mem2reg(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] memdata,
    output [31:0] regdata
);

    wire [31:0] aligned;
    wire [7:0] sign_bit;
    
    // Align data based on address offset
    // When offset is 00, data unchanged
    // When offset is 01, shift left by 8 bits: {memdata[23:0], 8'b0}
    // When offset is 10, shift left by 16 bits: {memdata[15:0], 16'b0}
    // When offset is 11, shift left by 24 bits: {memdata[7:0], 24'b0}
    assign aligned = (addr[1:0] == 2'b00) ? memdata :
                     (addr[1:0] == 2'b01) ? {memdata[23:0], 8'b0} :
                     (addr[1:0] == 2'b10) ? {memdata[15:0], 16'b0} :
                     {memdata[7:0], 24'b0};
    
    // Extract sign bit from aligned data
    assign sign_bit = aligned[31];
    
    // Select output based on lsu_op
    // Encoding assumed:
    // 0000: LBZ (load byte zero-extend)
    // 0001: LBS (load byte sign-extend)
    // 0010: LHZ (load halfword zero-extend)
    // 0011: LHS (load halfword sign-extend)
    // Others: LWZ/LWS (load word)
    assign regdata = (lsu_op[2:1] == 2'b00 && lsu_op[0] == 1'b0) ? {24'b0, aligned[31:24]} :
                     (lsu_op[2:1] == 2'b00 && lsu_op[0] == 1'b1) ? {{24{aligned[31]}}, aligned[31:24]} :
                     (lsu_op[2:1] == 2'b01 && lsu_op[0] == 1'b0) ? {16'b0, aligned[31:16]} :
                     (lsu_op[2:1] == 2'b01 && lsu_op[0] == 1'b1) ? {{16{aligned[31]}}, aligned[31:16]} :
                     aligned;

endmodule

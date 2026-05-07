`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

// 32x32 multiplier, no input/output registers
// Registers inside Wallace trees every 8 full adder levels,
// with first pipeline after level 4

`ifdef OR1200_GENERIC_MULTP2_32X32

`define OR1200_W 32
`define OR1200_WW 64

module or1200_gmultp2_32x32 ( X, Y, CLK, RST, P );

input   [`OR1200_W-1:0]  X;
input   [`OR1200_W-1:0]  Y;
input           CLK;
input           RST;
output  [`OR1200_WW-1:0]  P;

reg     [`OR1200_WW-1:0]  p0;
reg     [`OR1200_WW-1:0]  p1;
integer 		  xi;
integer 		  yi;

//
// Conversion unsigned to signed
//
always @(X)
	xi <= X;

//
// Conversion unsigned to signed
//
always @(Y)
	yi <= Y;

//
// First multiply stage
//

always @(posedge CLK) 
               p0 <= #1 xi * yi;


//
// Second multiply stage
//
always @(posedge CLK or posedge RST)
        if (RST)
                p1 <= `OR1200_WW'b0;
        else
                p1 <= #1 p0;

assign P = p1;

endmodule

`endif

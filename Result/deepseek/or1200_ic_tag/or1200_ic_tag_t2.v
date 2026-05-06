// Default case: no cache size defined, drive zero outputs
assign tag = 19'h0;
assign tag_v = 1'b0;
`endif
`endif
`endif
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
`endif
`endif
endmodule

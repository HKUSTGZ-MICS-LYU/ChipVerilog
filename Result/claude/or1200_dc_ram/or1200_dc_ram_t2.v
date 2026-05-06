module or1200_dc_ram(
    input clk,
    input rst,

`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);

`ifdef OR1200_NO_DC
    assign dataout = 32'b0;
    
    `ifdef OR1200_BIST
        assign mbist_so_o = mbist_si_i;
    `endif

`else

    wire en_wire;
    wire [3:0] we_wire;
    wire [10:0] addr_wire;
    wire [31:0] datain_wire;

    assign en_wire = en;
    assign we_wire = we;
    assign addr_wire = addr;
    assign datain_wire = datain;

    reg [31:0] ram_mem [0:2047];
    reg [31:0] read_data;

    assign dataout = read_data;

    always @(posedge clk) begin
        if (en_wire) begin
            if (we_wire[0]) ram_mem[addr_wire][7:0] <= datain_wire[7:0];
            if (we_wire[1]) ram_mem[addr_wire][15:8] <= datain_wire[15:8];
            if (we_wire[2]) ram_mem[addr_wire][23:16] <= datain_wire[23:16];
            if (we_wire[3]) ram_mem[addr_wire][31:24] <= datain_wire[31:24];

            read_data <= ram_mem[addr_wire];
        end
    end

    `ifdef OR1200_BIST
        assign mbist_so_o = mbist_si_i;
    `endif

`endif

endmodule

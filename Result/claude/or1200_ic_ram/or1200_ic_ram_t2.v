module or1200_ic_ram(
    // Clock and reset
    input clk,
    input rst,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // Internal i/f
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);

`ifdef OR1200_NO_IC

    assign dataout = 32'h00000000;

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else

    // Internal signals
    wire en_wire;
    wire [0 : 0] we_wire;
    wire [10 : 0] addr_wire;
    wire [31 : 0] datain_wire;

    assign en_wire = en;
    assign we_wire = we[0];
    assign addr_wire = addr;
    assign datain_wire = datain;

    // Memory array: 2048 words x 32 bits (11 bits address = 2^11 = 2048 locations)
    reg [31:0] mem [2047:0];

    // Synchronous read/write
    reg [31:0] read_data;

    assign dataout = read_data;

    always @(posedge clk) begin
        if (rst) begin
            read_data <= 32'h00000000;
        end else if (en_wire) begin
            if (|we_wire) begin
                // Write operation
                if (we_wire[0]) begin
                    mem[addr_wire] <= datain_wire;
                end
            end
            // Always perform read
            read_data <= mem[addr_wire];
        end
    end

    // Initialize memory to zero
    initial begin
        integer i;
        for (i = 0; i < 2048; i = i + 1) begin
            mem[i] = 32'h00000000;
        end
    end

`ifdef OR1200_BIST
    // BIST scan chain pass-through
    assign mbist_so_o = mbist_si_i;
`endif

`endif

endmodule

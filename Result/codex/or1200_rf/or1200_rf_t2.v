// Generated from or1200_rf/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_rf(
    // Clock and reset
    input clk,
    input rst,

    // Write i/f
    input supv,
    input wb_freeze,
    input [4:0] addrw,
    input [31:0] dataw,
    input we,
    input flushpipe,

    // Read i/f
    input id_freeze,
    input [4:0] addra,
    input [4:0] addrb,
    output [31:0] dataa,
    output [31:0] datab,
    input rda,
    input rdb,

    // Debug
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

reg [31:0] dataa_r;
reg [31:0] datab_r;
reg [31:0] spr_dat_o_r;
assign dataa = dataa_r;
assign datab = datab_r;
assign spr_dat_o = spr_dat_o_r;

reg [31:0] rf_mem [0:31];
wire [4:0] rf_addrw = (spr_cs && spr_write) ? spr_addr[4:0] : addrw;
wire [31:0] rf_dataw = (spr_cs && spr_write) ? spr_dat_i : dataw;
wire rf_we = (spr_cs && spr_write) || (we && !wb_freeze);

always @(posedge clk or posedge rst) begin
    if (rst) begin
    end else if (rf_we && (supv || (|rf_addrw))) begin
        rf_mem[rf_addrw] <= rf_dataw;
    end
end

always @* begin
    dataa_r = rf_mem[addra];
    datab_r = rf_mem[addrb];
    spr_dat_o_r = rf_mem[spr_addr[4:0]];
end

endmodule

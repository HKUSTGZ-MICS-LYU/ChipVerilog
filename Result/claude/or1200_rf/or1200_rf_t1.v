module or1200_rf(
    input clk,
    input rst,
    
    input supv,
    input wb_freeze,
    input [4:0] addrw,
    input [31:0] dataw,
    input we,
    input flushpipe,
    
    input id_freeze,
    input [4:0] addra,
    input [4:0] addrb,
    output [31:0] dataa,
    output [31:0] datab,
    input rda,
    input rdb,
    
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

    wire [31:0] from_rfa;
    wire [31:0] from_rfb;
    reg [32:0] dataa_saved;
    reg [32:0] datab_saved;
    
    wire [4:0] rf_addra;
    wire [4:0] rf_addrb;
    wire [4:0] rf_addrw;
    wire [31:0] rf_dataw;
    wire rf_we;
    wire spr_valid;
    wire rf_ena;
    wire rf_enb;
    reg rf_we_allow;
    
    wire [31:0] from_rfa_int;
    wire [31:0] from_rfb_int;
    
    reg [31:0] rf_mem [0:31];
    
    integer i;
    
    assign spr_valid = spr_cs & (spr_addr[31:5] == 27'h0);
    
    assign rf_addra = (spr_valid & ~spr_write) ? spr_addr[4:0] : addra;
    assign rf_addrb = addrb;
    assign rf_addrw = spr_valid ? spr_addr[4:0] : addrw;
    assign rf_dataw = spr_valid ? spr_dat_i : dataw;
    
    assign rf_ena = rda | spr_valid;
    assign rf_enb = rdb & ~id_freeze;
    
    assign from_rfa_int = rf_mem[rf_addra];
    assign from_rfb_int = rf_mem[rf_addrb];
    
    assign from_rfa = (rf_addra == 5'h00) ? 32'h0 : from_rfa_int;
    assign from_rfb = (rf_addrb == 5'h00) ? 32'h0 : from_rfb_int;
    
    assign rf_we = (spr_valid & spr_write) | 
                   (we & ~wb_freeze & rf_we_allow) | 
                   ~(supv | (|rf_addrw));
    
    assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
    assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;
    
    assign spr_dat_o = from_rfa;
    
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            rf_we_allow <= 1'b1;
        end
        else if (~wb_freeze) begin
            rf_we_allow <= ~flushpipe;
        end
    end
    
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            dataa_saved <= 33'h0;
            datab_saved <= 33'h0;
        end
        else begin
            if (id_freeze) begin
                if (~dataa_saved[32]) begin
                    dataa_saved <= {1'b1, from_rfa};
                end
                if (~datab_saved[32]) begin
                    datab_saved <= {1'b1, from_rfb};
                end
            end
            else begin
                dataa_saved <= 33'h0;
                datab_saved <= 33'h0;
            end
        end
    end
    
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf_mem[i] <= 32'h0;
            end
        end
        else if (rf_we) begin
            rf_mem[rf_addrw] <= rf_dataw;
        end
    end

endmodule

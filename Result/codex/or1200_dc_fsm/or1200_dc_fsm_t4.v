`timescale 1ns/1ps
`include "or1200_defines.v"
module or1200_dc_fsm(
    input clk,
    input rst,
    input dc_en,
    input dcqmem_cycstb_i,
    input dcqmem_ci_i,
    input dcqmem_we_i,
    input [3:0] dcqmem_sel_i,
    input tagcomp_miss,
    input biudata_valid,
    input biudata_error,
    input [31:0] start_addr,
    output [31:0] saved_addr,
    output reg [3:0] dcram_we,
    output reg biu_read,
    output reg biu_write,
    output reg first_hit_ack,
    output reg first_miss_ack,
    output reg first_miss_err,
    output reg burst,
    output reg tag_we,
    output [31:0] dc_addr
);
    localparam IDLE=3'd0, CLOAD=3'd1, LREFILL3=3'd2, CSTORE=3'd3, SREFILL4=3'd4;
    reg [2:0] state;
    reg [31:0] saved_addr_r;
    reg [2:0] cnt;
    reg load, store, cache_inhibit;
    assign saved_addr = saved_addr_r;
    assign dc_addr = (state == IDLE || state == CLOAD || state == CSTORE) ? start_addr : saved_addr_r;
    wire cache_bypass = dcqmem_ci_i | !dc_en;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE; saved_addr_r <= 0; cnt <= 0; load <= 0; store <= 0; cache_inhibit <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (dc_en && dcqmem_cycstb_i) begin
                        saved_addr_r <= start_addr; cache_inhibit <= cache_bypass; store <= dcqmem_we_i; load <= !dcqmem_we_i;
                        state <= dcqmem_we_i ? CSTORE : CLOAD;
                    end
                end
                CLOAD: begin
                    if (!dcqmem_cycstb_i || biudata_error) state <= IDLE;
                    else if (cache_inhibit) begin if (biudata_valid) state <= IDLE; end
                    else if (!tagcomp_miss) state <= IDLE;
                    else if (biudata_valid) begin state <= LREFILL3; cnt <= `OR1200_DCLS - 2; saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1; end
                end
                LREFILL3: begin
                    if (biudata_error) state <= IDLE;
                    else if (biudata_valid) begin
                        if (cnt == 0) state <= IDLE;
                        else begin cnt <= cnt - 1'b1; saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1; end
                    end
                end
                CSTORE: begin
                    if (!dcqmem_cycstb_i || biudata_error) state <= IDLE;
                    else if (biudata_valid) begin
`ifdef OR1200_DC_STORE_REFILL
                        if (!cache_inhibit && tagcomp_miss) begin state <= SREFILL4; cnt <= `OR1200_DCLS - 1; saved_addr_r[3:2] <= 2'd0; end
                        else state <= IDLE;
`else
                        state <= IDLE;
`endif
                    end
                end
                SREFILL4: begin
                    if (biudata_error) state <= IDLE;
                    else if (biudata_valid) begin
                        if (cnt == 0) state <= IDLE;
                        else begin cnt <= cnt - 1'b1; saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1; end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
    always @(*) begin
        dcram_we = 4'b0000; biu_read = 0; biu_write = 0; first_hit_ack = 0; first_miss_ack = 0; first_miss_err = 0; burst = 0; tag_we = 0;
        case (state)
            CLOAD: begin
                biu_read = cache_inhibit || tagcomp_miss;
                first_hit_ack = dcqmem_cycstb_i && !cache_inhibit && !tagcomp_miss;
                first_miss_ack = biudata_valid;
                first_miss_err = biudata_error;
                dcram_we = (biudata_valid && tagcomp_miss && !cache_inhibit) ? 4'b1111 : 4'b0000;
                burst = tagcomp_miss && !cache_inhibit;
                tag_we = biudata_valid && tagcomp_miss && !cache_inhibit;
            end
            LREFILL3: begin
                biu_read = 1; burst = 1; first_miss_err = biudata_error;
                dcram_we = biudata_valid ? 4'b1111 : 4'b0000;
                tag_we = biudata_valid;
            end
            CSTORE: begin
                biu_write = 1; first_miss_ack = biudata_valid; first_miss_err = biudata_error;
                first_hit_ack = biudata_valid && !cache_inhibit && !tagcomp_miss;
                dcram_we = (biudata_valid && !cache_inhibit && !tagcomp_miss) ? dcqmem_sel_i : 4'b0000;
            end
            SREFILL4: begin
                biu_read = 1; burst = 1; first_miss_err = biudata_error;
                dcram_we = biudata_valid ? 4'b1111 : 4'b0000;
                tag_we = biudata_valid;
            end
        endcase
    end
endmodule

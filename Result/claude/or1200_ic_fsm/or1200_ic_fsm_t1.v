`include "timescale.v"
`include "or1200_defines.v"

`define OR1200_ICFSM_IDLE     2'd0
`define OR1200_ICFSM_CFETCH   2'd1
`define OR1200_ICFSM_LREFILL3 2'd2
`define OR1200_ICFSM_IFETCH   2'd3

module or1200_ic_fsm(
    clk, rst,
    ic_en, icqmem_cycstb_i, icqmem_ci_i,
    tagcomp_miss, biudata_valid, biudata_error, start_addr,
    saved_addr, icram_we, biu_read,
    first_hit_ack, first_miss_ack, first_miss_err,
    burst, tag_we
);

input         clk, rst;
input         ic_en;
input         icqmem_cycstb_i;
input         icqmem_ci_i;
input         tagcomp_miss;
input         biudata_valid;
input         biudata_error;
input  [31:0] start_addr;
output [31:0] saved_addr;
output [3:0]  icram_we;
output        biu_read;
output        first_hit_ack;
output        first_miss_ack;
output        first_miss_err;
output        burst;
output        tag_we;

reg [31:0] saved_addr_r;
reg [1:0]  state;
reg [2:0]  cnt;
reg        hitmiss_eval;
reg        load;
reg        cache_inhibit;

assign saved_addr = saved_addr_r;

assign biu_read  = (hitmiss_eval & tagcomp_miss) | (!hitmiss_eval & load);

assign icram_we  = {4{biu_read & biudata_valid & !cache_inhibit}};
assign tag_we    = biu_read & biudata_valid & !cache_inhibit;

assign first_hit_ack  = (state == `OR1200_ICFSM_CFETCH) &
                         hitmiss_eval & !tagcomp_miss & !cache_inhibit & !icqmem_ci_i;
assign first_miss_ack = (state == `OR1200_ICFSM_CFETCH) & biudata_valid;
assign first_miss_err = (state == `OR1200_ICFSM_CFETCH) & biudata_error;

assign burst = ((state == `OR1200_ICFSM_CFETCH) & tagcomp_miss & !cache_inhibit) |
               (state == `OR1200_ICFSM_LREFILL3);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state         <= `OR1200_ICFSM_IDLE;
        saved_addr_r  <= 32'b0;
        cnt           <= 3'b000;
        hitmiss_eval  <= 1'b0;
        load          <= 1'b0;
        cache_inhibit <= 1'b0;
    end
    else case (state)

        `OR1200_ICFSM_IDLE: begin
            if (ic_en & icqmem_cycstb_i) begin
                state         <= `OR1200_ICFSM_CFETCH;
                saved_addr_r  <= start_addr;
                hitmiss_eval  <= 1'b1;
                load          <= 1'b1;
                cache_inhibit <= 1'b0;
            end else begin
                hitmiss_eval  <= 1'b0;
                load          <= 1'b0;
                cache_inhibit <= 1'b0;
            end
        end

        `OR1200_ICFSM_CFETCH: begin
            // Latch cache-inhibit
            if (icqmem_cycstb_i & icqmem_ci_i)
                cache_inhibit <= 1'b1;

            // Refresh upper address bits during evaluation
            if (hitmiss_eval)
                saved_addr_r[31:13] <= start_addr[31:13];

            // High-priority return-to-IDLE conditions
            if (!ic_en |
                (hitmiss_eval & !icqmem_cycstb_i) |
                biudata_error |
                (cache_inhibit & biudata_valid)) begin
                state         <= `OR1200_ICFSM_IDLE;
                hitmiss_eval  <= 1'b0;
                load          <= 1'b0;
                cache_inhibit <= 1'b0;
            end
            // Miss: first word returned
            else if (tagcomp_miss & biudata_valid) begin
                state                 <= `OR1200_ICFSM_LREFILL3;
                saved_addr_r[3:2]     <= saved_addr_r[3:2] + 1'd1;
                hitmiss_eval          <= 1'b0;
                cnt                   <= `OR1200_ICLS - 2;
                cache_inhibit         <= 1'b0;
            end
            // Cache hit
            else if (!tagcomp_miss & !icqmem_ci_i) begin
                saved_addr_r  <= start_addr;
                cache_inhibit <= 1'b0;
            end
            // Request withdrawn
            else if (!icqmem_cycstb_i) begin
                state         <= `OR1200_ICFSM_IDLE;
                hitmiss_eval  <= 1'b0;
                load          <= 1'b0;
                cache_inhibit <= 1'b0;
            end
            else begin
                hitmiss_eval <= 1'b0;
            end
        end

        `OR1200_ICFSM_LREFILL3: begin
            if (biudata_valid & (|cnt)) begin
                cnt              <= cnt - 3'd1;
                saved_addr_r[3:2]<= saved_addr_r[3:2] + 1'd1;
            end
            else if (biudata_valid) begin
                state        <= `OR1200_ICFSM_IDLE;
                saved_addr_r <= start_addr;
                hitmiss_eval <= 1'b0;
                load         <= 1'b0;
            end
        end

        default:
            state <= `OR1200_ICFSM_IDLE;

    endcase
end

endmodule
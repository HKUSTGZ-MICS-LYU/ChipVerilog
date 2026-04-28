`include "timescale.v"
`include "or1200_defines.v"

`define OR1200_DCFSM_IDLE    3'd0
`define OR1200_DCFSM_CLOAD   3'd1
`define OR1200_DCFSM_LREFILL3 3'd2
`define OR1200_DCFSM_CSTORE  3'd3
`define OR1200_DCFSM_SREFILL4 3'd4

module or1200_dc_fsm(
    clk, rst,
    dc_en, dcqmem_cycstb_i, dcqmem_ci_i, dcqmem_we_i, dcqmem_sel_i,
    tagcomp_miss, biudata_valid, biudata_error, start_addr,
    saved_addr, dcram_we, biu_read, biu_write,
    first_hit_ack, first_miss_ack, first_miss_err,
    burst, tag_we, dc_addr
);

input         clk, rst;
input         dc_en;
input         dcqmem_cycstb_i;
input         dcqmem_ci_i;
input         dcqmem_we_i;
input  [3:0]  dcqmem_sel_i;
input         tagcomp_miss;
input         biudata_valid;
input         biudata_error;
input  [31:0] start_addr;
output [31:0] saved_addr;
output [3:0]  dcram_we;
output        biu_read;
output        biu_write;
output        first_hit_ack;
output        first_miss_ack;
output        first_miss_err;
output        burst;
output        tag_we;
output [31:0] dc_addr;

reg [2:0]  state;
reg [31:0] saved_addr_r;
reg [2:0]  cnt;
reg        hitmiss_eval;
reg        store;
reg        load;
reg        cache_inhibit;

assign saved_addr = saved_addr_r;

// biu_read: during miss eval with tagcomp_miss, or post-eval refill load
assign biu_read  = (hitmiss_eval & tagcomp_miss & !cache_inhibit & load) |
                   (!hitmiss_eval & load);

// biu_write: while store flag active
assign biu_write = store;

// dc_addr: start_addr during hit/miss eval, saved_addr during post-eval transfers
assign dc_addr = (hitmiss_eval | (!hitmiss_eval & !biu_read & !biu_write)) ?
                 start_addr : saved_addr_r;

// DCRAM write enable
wire first_store_hit_ack = (state == `OR1200_DCFSM_CSTORE) &
                            biudata_valid & !tagcomp_miss & !cache_inhibit;

assign dcram_we = ({4{load & biudata_valid & !cache_inhibit}}) |
                  (first_store_hit_ack ? dcqmem_sel_i : 4'b0000);

// Tag write enable
assign tag_we = biu_read & biudata_valid & !cache_inhibit;

// first_hit_ack: load hit in CLOAD or store hit ack
assign first_hit_ack = ((state == `OR1200_DCFSM_CLOAD) &
                         hitmiss_eval & !tagcomp_miss & !cache_inhibit) |
                        first_store_hit_ack;

// first_miss_ack / err
assign first_miss_ack = ((state == `OR1200_DCFSM_CLOAD) |
                          (state == `OR1200_DCFSM_CSTORE)) & biudata_valid;
assign first_miss_err  = ((state == `OR1200_DCFSM_CLOAD) |
                          (state == `OR1200_DCFSM_CSTORE)) & biudata_error;

// burst
assign burst = ((state == `OR1200_DCFSM_CLOAD) & tagcomp_miss & !cache_inhibit) |
               (state == `OR1200_DCFSM_LREFILL3)
`ifdef OR1200_DC_STORE_REFILL
               | (state == `OR1200_DCFSM_SREFILL4)
`endif
               ;

// FSM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state          <= `OR1200_DCFSM_IDLE;
        saved_addr_r   <= 32'b0;
        cnt            <= 3'b000;
        hitmiss_eval   <= 1'b0;
        store          <= 1'b0;
        load           <= 1'b0;
        cache_inhibit  <= 1'b0;
    end
    else case (state)

        `OR1200_DCFSM_IDLE: begin
            if (dc_en & dcqmem_cycstb_i) begin
                saved_addr_r  <= start_addr;
                hitmiss_eval  <= 1'b1;
                cache_inhibit <= 1'b0;
                if (dcqmem_we_i) begin
                    state <= `OR1200_DCFSM_CSTORE;
                    store <= 1'b1;
                    load  <= 1'b0;
                end else begin
                    state <= `OR1200_DCFSM_CLOAD;
                    load  <= 1'b1;
                    store <= 1'b0;
                end
            end else begin
                hitmiss_eval  <= 1'b0;
                store         <= 1'b0;
                load          <= 1'b0;
                cache_inhibit <= 1'b0;
            end
        end

        `OR1200_DCFSM_CLOAD: begin
            // Detect cache-inhibit
            if (dcqmem_cycstb_i & dcqmem_ci_i)
                cache_inhibit <= 1'b1;

            // Update upper address bits during eval
            if (hitmiss_eval)
                saved_addr_r[31:13] <= start_addr[31:13];

            if (!dc_en |
                (hitmiss_eval & !dcqmem_cycstb_i) |
                biudata_error |
                (cache_inhibit & biudata_valid)) begin
                // Abort or done
                state        <= `OR1200_DCFSM_IDLE;
                hitmiss_eval <= 1'b0;
                load         <= 1'b0;
                cache_inhibit<= 1'b0;
            end
            else if (tagcomp_miss & biudata_valid) begin
                // Miss: first word received, start refill
                state        <= `OR1200_DCFSM_LREFILL3;
                saved_addr_r[3:2] <= saved_addr_r[3:2] + 1'd1;
                hitmiss_eval <= 1'b0;
                cnt          <= `OR1200_DCLS - 2;
                cache_inhibit<= 1'b0;
            end
            else if (!tagcomp_miss & !dcqmem_ci_i) begin
                // Hit: done
                saved_addr_r <= start_addr;
                cache_inhibit<= 1'b0;
                state        <= `OR1200_DCFSM_IDLE;
                hitmiss_eval <= 1'b0;
                load         <= 1'b0;
            end
            else if (!dcqmem_cycstb_i) begin
                state        <= `OR1200_DCFSM_IDLE;
                hitmiss_eval <= 1'b0;
                load         <= 1'b0;
                cache_inhibit<= 1'b0;
            end
            else begin
                hitmiss_eval <= 1'b0;
            end
        end

        `OR1200_DCFSM_LREFILL3: begin
            if (biudata_valid & (|cnt)) begin
                cnt              <= cnt - 3'd1;
                saved_addr_r[3:2]<= saved_addr_r[3:2] + 1'd1;
            end
            else if (biudata_valid) begin
                state        <= `OR1200_DCFSM_IDLE;
                saved_addr_r <= start_addr;
                hitmiss_eval <= 1'b0;
                load         <= 1'b0;
            end
        end

        `OR1200_DCFSM_CSTORE: begin
            // Detect cache-inhibit
            if (dcqmem_cycstb_i & dcqmem_ci_i)
                cache_inhibit <= 1'b1;

            if (hitmiss_eval)
                saved_addr_r[31:13] <= start_addr[31:13];

            if (!dc_en |
                (hitmiss_eval & !dcqmem_cycstb_i) |
                biudata_error |
                (cache_inhibit & biudata_valid)) begin
                state        <= `OR1200_DCFSM_IDLE;
                hitmiss_eval <= 1'b0;
                store        <= 1'b0;
                cache_inhibit<= 1'b0;
            end
            else if (biudata_valid) begin
`ifdef OR1200_DC_STORE_REFILL
                if (tagcomp_miss) begin
                    // Store miss: enter refill
                    state        <= `OR1200_DCFSM_SREFILL4;
                    store        <= 1'b0;
                    load         <= 1'b1;
                    cnt          <= `OR1200_DCLS - 1;
                    hitmiss_eval <= 1'b0;
                    cache_inhibit<= 1'b0;
                end else begin
`endif
                    state        <= `OR1200_DCFSM_IDLE;
                    hitmiss_eval <= 1'b0;
                    store        <= 1'b0;
                    cache_inhibit<= 1'b0;
`ifdef OR1200_DC_STORE_REFILL
                end
`endif
            end
            else begin
                hitmiss_eval <= 1'b0;
            end
        end

`ifdef OR1200_DC_STORE_REFILL
        `OR1200_DCFSM_SREFILL4: begin
            if (biudata_valid & (|cnt)) begin
                cnt              <= cnt - 3'd1;
                saved_addr_r[3:2]<= saved_addr_r[3:2] + 1'd1;
            end
            else if (biudata_valid) begin
                state <= `OR1200_DCFSM_IDLE;
                load  <= 1'b0;
            end
        end
`endif

        default:
            state <= `OR1200_DCFSM_IDLE;

    endcase
end

endmodule
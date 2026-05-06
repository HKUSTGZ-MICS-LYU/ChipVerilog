`ifndef OR1200_DCLS
`define OR1200_DCLS 4
`endif

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
    output [3:0] dcram_we,
    output biu_read,
    output biu_write,
    output first_hit_ack,
    output first_miss_ack,
    output first_miss_err,
    output burst,
    output tag_we,
    output [31:0] dc_addr
);

localparam [2:0] IDLE     = 3'd0;
localparam [2:0] CLOAD    = 3'd1;
localparam [2:0] LREFILL3 = 3'd2;
localparam [2:0] CSTORE   = 3'd3;
localparam [2:0] SREFILL4 = 3'd4;

localparam integer DCLS = `OR1200_DCLS;
localparam integer DCLS_MINUS_1 = (DCLS > 0) ? (DCLS - 1) : 0;
localparam integer DCLS_MINUS_2 = (DCLS > 1) ? (DCLS - 2) : 0;

reg [2:0] state;
reg [31:0] saved_addr_r;
reg [7:0] cnt;
reg hitmiss_eval;
reg store;
reg load;
reg cache_inhibit;

wire ci_access;
wire first_store_hit_ack;

assign ci_access = cache_inhibit | (((state == CLOAD) || (state == CSTORE)) && dcqmem_cycstb_i && dcqmem_ci_i);
assign first_store_hit_ack = (state == CSTORE) && biudata_valid && !ci_access && !tagcomp_miss;

assign saved_addr = saved_addr_r;
assign biu_write = store;
assign biu_read = ((state == CLOAD) && (ci_access || tagcomp_miss)) ||
                  (state == LREFILL3)
`ifdef OR1200_DC_STORE_REFILL
                  || (state == SREFILL4)
`endif
                  ;
assign first_hit_ack = ((state == CLOAD) && hitmiss_eval && !ci_access && !tagcomp_miss) || first_store_hit_ack;
assign first_miss_ack = ((state == CLOAD) || (state == CSTORE)) && biudata_valid;
assign first_miss_err = ((state == CLOAD) || (state == CSTORE)) && biudata_error;
assign burst = ((state == CLOAD) && !ci_access && tagcomp_miss) ||
               (state == LREFILL3)
`ifdef OR1200_DC_STORE_REFILL
               || (state == SREFILL4)
`endif
               ;
assign dcram_we = (load && biudata_valid && !ci_access) ? 4'b1111 :
                  (first_store_hit_ack ? dcqmem_sel_i : 4'b0000);
assign tag_we = biu_read && biudata_valid && !ci_access;
assign dc_addr = (!hitmiss_eval && (biu_read || biu_write)) ? saved_addr_r : start_addr;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        saved_addr_r <= 32'b0;
        cnt <= 8'b0;
        hitmiss_eval <= 1'b0;
        store <= 1'b0;
        load <= 1'b0;
        cache_inhibit <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                cnt <= 8'b0;
                hitmiss_eval <= 1'b0;
                store <= 1'b0;
                load <= 1'b0;
                cache_inhibit <= 1'b0;
                if (dc_en && dcqmem_cycstb_i) begin
                    state <= dcqmem_we_i ? CSTORE : CLOAD;
                    saved_addr_r <= start_addr;
                    hitmiss_eval <= 1'b1;
                    store <= dcqmem_we_i;
                    load <= !dcqmem_we_i;
                end
            end

            CLOAD: begin
                if (dcqmem_cycstb_i && dcqmem_ci_i)
                    cache_inhibit <= 1'b1;

                if (hitmiss_eval && !dcqmem_cycstb_i) begin
                    state <= IDLE;
                    cnt <= 8'b0;
                    hitmiss_eval <= 1'b0;
                    store <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else if (biudata_error) begin
                    state <= IDLE;
                    cnt <= 8'b0;
                    hitmiss_eval <= 1'b0;
                    store <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else if (ci_access) begin
                    hitmiss_eval <= 1'b0;
                    if (biudata_valid) begin
                        state <= IDLE;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                end else if (!tagcomp_miss) begin
                    state <= IDLE;
                    hitmiss_eval <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else begin
                    hitmiss_eval <= 1'b0;
                    if (biudata_valid) begin
                        if (DCLS > 1) begin
                            state <= LREFILL3;
                            cnt <= DCLS_MINUS_2;
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                        end else begin
                            state <= IDLE;
                            load <= 1'b0;
                        end
                    end
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 0) begin
                        cnt <= cnt - 8'd1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end else begin
                        state <= IDLE;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                end
            end

            CSTORE: begin
                if (dcqmem_cycstb_i && dcqmem_ci_i)
                    cache_inhibit <= 1'b1;

                if (hitmiss_eval && !dcqmem_cycstb_i) begin
                    state <= IDLE;
                    cnt <= 8'b0;
                    hitmiss_eval <= 1'b0;
                    store <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else if (biudata_error) begin
                    state <= IDLE;
                    cnt <= 8'b0;
                    hitmiss_eval <= 1'b0;
                    store <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else begin
                    hitmiss_eval <= 1'b0;
                    if (biudata_valid) begin
`ifdef OR1200_DC_STORE_REFILL
                        if (!ci_access && tagcomp_miss) begin
                            state <= SREFILL4;
                            store <= 1'b0;
                            load <= 1'b1;
                            cnt <= DCLS_MINUS_1;
                            cache_inhibit <= 1'b0;
                        end else begin
                            state <= IDLE;
                            store <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end
`else
                        state <= IDLE;
                        store <= 1'b0;
                        cache_inhibit <= 1'b0;
`endif
                    end
                end
            end

`ifdef OR1200_DC_STORE_REFILL
            SREFILL4: begin
                if (biudata_valid) begin
                    if (cnt != 0) begin
                        cnt <= cnt - 8'd1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end else begin
                        state <= IDLE;
                        load <= 1'b0;
                    end
                end
            end
`endif

            default: begin
                state <= IDLE;
                saved_addr_r <= 32'b0;
                cnt <= 8'b0;
                hitmiss_eval <= 1'b0;
                store <= 1'b0;
                load <= 1'b0;
                cache_inhibit <= 1'b0;
            end
        endcase
    end
end

endmodule

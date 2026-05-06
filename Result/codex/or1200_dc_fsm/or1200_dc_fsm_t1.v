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
localparam [1:0] DCLS_M2  = 2'd2;
localparam [1:0] DCLS_M1  = 2'd3;

reg [2:0] state;
reg [31:0] saved_addr_r;
reg [1:0] cnt;
reg hitmiss_eval;
reg store;
reg load;
reg cache_inhibit;

wire cache_inhibit_active;
wire first_load_hit_ack;
wire first_store_hit_ack;

assign saved_addr = saved_addr_r;
assign cache_inhibit_active = cache_inhibit |
                              (((state == CLOAD) || (state == CSTORE)) &
                               dcqmem_cycstb_i & dcqmem_ci_i);

assign biu_read = (hitmiss_eval & tagcomp_miss) | (~hitmiss_eval & load);
assign biu_write = store;

assign first_load_hit_ack = (state == CLOAD) & hitmiss_eval & dcqmem_cycstb_i &
                            ~tagcomp_miss & ~cache_inhibit_active;
assign first_store_hit_ack = (state == CSTORE) & biudata_valid & ~tagcomp_miss &
                             ~cache_inhibit_active;
assign first_hit_ack = first_load_hit_ack | first_store_hit_ack;
assign first_miss_ack = ((state == CLOAD) | (state == CSTORE)) & biudata_valid;
assign first_miss_err = ((state == CLOAD) | (state == CSTORE)) & biudata_error;

assign dcram_we = (load & biudata_valid & ~cache_inhibit_active) ? 4'b1111 :
                  (first_store_hit_ack ? dcqmem_sel_i : 4'b0000);
assign tag_we = biu_read & biudata_valid & ~cache_inhibit_active;
assign dc_addr = ((!hitmiss_eval) & (biu_read | biu_write)) ? saved_addr_r : start_addr;

assign burst = ((state == CLOAD) & hitmiss_eval & tagcomp_miss & ~cache_inhibit_active) |
               (state == LREFILL3)
`ifdef OR1200_DC_STORE_REFILL
               | (state == SREFILL4)
`endif
               ;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        saved_addr_r <= 32'b0;
        cnt <= 2'b0;
        hitmiss_eval <= 1'b0;
        store <= 1'b0;
        load <= 1'b0;
        cache_inhibit <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                hitmiss_eval <= 1'b0;
                store <= 1'b0;
                load <= 1'b0;
                cache_inhibit <= 1'b0;
                cnt <= 2'b0;
                if (dc_en & dcqmem_cycstb_i) begin
                    saved_addr_r <= start_addr;
                    hitmiss_eval <= 1'b1;
                    if (dcqmem_we_i) begin
                        state <= CSTORE;
                        store <= 1'b1;
                    end else begin
                        state <= CLOAD;
                        load <= 1'b1;
                    end
                end
            end

            CLOAD: begin
                if (hitmiss_eval & ~dcqmem_cycstb_i) begin
                    state <= IDLE;
                    hitmiss_eval <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                    cnt <= 2'b0;
                end else if (biudata_error) begin
                    state <= IDLE;
                    hitmiss_eval <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                    cnt <= 2'b0;
                end else if (hitmiss_eval) begin
                    if (dcqmem_cycstb_i & dcqmem_ci_i) begin
                        if (biudata_valid) begin
                            state <= IDLE;
                            hitmiss_eval <= 1'b0;
                            load <= 1'b0;
                            cache_inhibit <= 1'b0;
                            cnt <= 2'b0;
                        end else begin
                            hitmiss_eval <= 1'b0;
                            cache_inhibit <= 1'b1;
                        end
                    end else if (~tagcomp_miss) begin
                        state <= IDLE;
                        hitmiss_eval <= 1'b0;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                        cnt <= 2'b0;
                    end else if (biudata_valid) begin
                        state <= LREFILL3;
                        hitmiss_eval <= 1'b0;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                        cnt <= DCLS_M2;
                    end else begin
                        hitmiss_eval <= 1'b0;
                    end
                end else if (biudata_valid) begin
                    if (cache_inhibit) begin
                        state <= IDLE;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                        cnt <= 2'b0;
                    end else begin
                        state <= LREFILL3;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                        cnt <= DCLS_M2;
                    end
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 2'b0) begin
                        cnt <= cnt - 2'd1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end else begin
                        state <= IDLE;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                        cnt <= 2'b0;
                    end
                end
            end

            CSTORE: begin
                if (hitmiss_eval & ~dcqmem_cycstb_i) begin
                    state <= IDLE;
                    hitmiss_eval <= 1'b0;
                    store <= 1'b0;
                    cache_inhibit <= 1'b0;
                    cnt <= 2'b0;
                end else if (biudata_error) begin
                    state <= IDLE;
                    hitmiss_eval <= 1'b0;
                    store <= 1'b0;
                    cache_inhibit <= 1'b0;
                    cnt <= 2'b0;
                end else if (biudata_valid) begin
                    if (cache_inhibit_active) begin
                        state <= IDLE;
                        hitmiss_eval <= 1'b0;
                        store <= 1'b0;
                        cache_inhibit <= 1'b0;
                        cnt <= 2'b0;
                    end else if (tagcomp_miss) begin
`ifdef OR1200_DC_STORE_REFILL
                        state <= SREFILL4;
                        hitmiss_eval <= 1'b0;
                        store <= 1'b0;
                        load <= 1'b1;
                        cnt <= DCLS_M1;
`else
                        state <= IDLE;
                        hitmiss_eval <= 1'b0;
                        store <= 1'b0;
                        cache_inhibit <= 1'b0;
                        cnt <= 2'b0;
`endif
                    end else begin
                        state <= IDLE;
                        hitmiss_eval <= 1'b0;
                        store <= 1'b0;
                        cache_inhibit <= 1'b0;
                        cnt <= 2'b0;
                    end
                end else if (hitmiss_eval) begin
                    hitmiss_eval <= 1'b0;
                    if (dcqmem_cycstb_i & dcqmem_ci_i) begin
                        cache_inhibit <= 1'b1;
                    end
                end
            end

            SREFILL4: begin
                if (biudata_valid) begin
                    if (cnt != 2'b0) begin
                        cnt <= cnt - 2'd1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end else begin
                        state <= IDLE;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                        cnt <= 2'b0;
                    end
                end
            end

            default: begin
                state <= IDLE;
                saved_addr_r <= 32'b0;
                cnt <= 2'b0;
                hitmiss_eval <= 1'b0;
                store <= 1'b0;
                load <= 1'b0;
                cache_inhibit <= 1'b0;
            end
        endcase
    end
end

endmodule

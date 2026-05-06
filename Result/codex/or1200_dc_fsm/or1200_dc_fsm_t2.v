`ifndef OR1200_DCLS
`define OR1200_DCLS 4
`endif

module or1200_dc_fsm(
    input         clk,
    input         rst,
    input         dc_en,
    input         dcqmem_cycstb_i,
    input         dcqmem_ci_i,
    input         dcqmem_we_i,
    input  [3:0]  dcqmem_sel_i,
    input         tagcomp_miss,
    input         biudata_valid,
    input         biudata_error,
    input  [31:0] start_addr,
    output [31:0] saved_addr,
    output [3:0]  dcram_we,
    output        biu_read,
    output        biu_write,
    output        first_hit_ack,
    output        first_miss_ack,
    output        first_miss_err,
    output        burst,
    output        tag_we,
    output [31:0] dc_addr
);

localparam [2:0] IDLE     = 3'd0;
localparam [2:0] CLOAD    = 3'd1;
localparam [2:0] LREFILL3 = 3'd2;
localparam [2:0] CSTORE   = 3'd3;
localparam [2:0] SREFILL4 = 3'd4;

reg [2:0]  state;
reg [31:0] saved_addr_r;
reg [31:0] cnt;
reg        hitmiss_eval;
reg        store;
reg        load;
reg        cache_inhibit;

wire ci_request;
wire ci_active;
wire load_hit_ack;
wire first_store_hit_ack;
wire post_eval_biu;
wire cstate_first_phase;
wire burst_cload_miss;

assign ci_request  = dcqmem_cycstb_i & dcqmem_ci_i;
assign ci_active   = cache_inhibit | (hitmiss_eval & ci_request);
assign saved_addr  = saved_addr_r;

assign biu_write   = store;
assign biu_read    = load & ((hitmiss_eval & tagcomp_miss) | (~hitmiss_eval));

assign cstate_first_phase = (state == CLOAD) | (state == CSTORE);
assign first_miss_ack     = cstate_first_phase & biudata_valid;
assign first_miss_err     = cstate_first_phase & biudata_error;

assign load_hit_ack        = (state == CLOAD) & hitmiss_eval & dcqmem_cycstb_i &
                             (~tagcomp_miss) & (~ci_request) & (~cache_inhibit);
assign first_store_hit_ack = (state == CSTORE) & biudata_valid & (~tagcomp_miss) & (~ci_active);
assign first_hit_ack       = load_hit_ack | first_store_hit_ack;

assign dcram_we = (load & biudata_valid & (~cache_inhibit)) ? 4'b1111 :
                  (first_store_hit_ack ? dcqmem_sel_i : 4'b0000);

assign tag_we = biu_read & biudata_valid & (~cache_inhibit);

assign burst_cload_miss = (state == CLOAD) & load & (~ci_active) &
                          (tagcomp_miss | (~hitmiss_eval));
assign burst =
    burst_cload_miss |
    (state == LREFILL3)
`ifdef OR1200_DC_STORE_REFILL
    | (state == SREFILL4)
`endif
    ;

assign post_eval_biu = (~hitmiss_eval) & (biu_read | biu_write);
assign dc_addr = (hitmiss_eval | (~post_eval_biu)) ? start_addr : saved_addr_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state          <= IDLE;
        saved_addr_r   <= 32'd0;
        cnt            <= 32'd0;
        hitmiss_eval   <= 1'b0;
        store          <= 1'b0;
        load           <= 1'b0;
        cache_inhibit  <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                state         <= IDLE;
                cnt           <= 32'd0;
                hitmiss_eval  <= 1'b0;
                store         <= 1'b0;
                load          <= 1'b0;
                cache_inhibit <= 1'b0;
                if (dc_en & dcqmem_cycstb_i) begin
                    saved_addr_r  <= start_addr;
                    hitmiss_eval  <= 1'b1;
                    cache_inhibit <= 1'b0;
                    if (dcqmem_we_i) begin
                        state <= CSTORE;
                        store <= 1'b1;
                    end else begin
                        state <= CLOAD;
                        load  <= 1'b1;
                    end
                end
            end

            CLOAD: begin
                if (ci_request)
                    cache_inhibit <= 1'b1;

                if ((hitmiss_eval & (~dcqmem_cycstb_i)) | biudata_error | (ci_active & biudata_valid)) begin
                    state         <= IDLE;
                    cnt           <= 32'd0;
                    hitmiss_eval  <= 1'b0;
                    store         <= 1'b0;
                    load          <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else if (hitmiss_eval) begin
                    if (dcqmem_cycstb_i) begin
                        hitmiss_eval <= 1'b0;
                        if ((~tagcomp_miss) & (~ci_request) & (~cache_inhibit)) begin
                            state         <= IDLE;
                            load          <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end
                    end
                end else if (biudata_valid & (~cache_inhibit)) begin
                    state             <= LREFILL3;
                    saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'b01;
                    cnt               <= (`OR1200_DCLS - 2);
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 32'd0) begin
                        cnt             <= cnt - 32'd1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'b01;
                    end else begin
                        state         <= IDLE;
                        load          <= 1'b0;
                        hitmiss_eval  <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                end
            end

            CSTORE: begin
                if (ci_request)
                    cache_inhibit <= 1'b1;

                if ((hitmiss_eval & (~dcqmem_cycstb_i)) | biudata_error | (ci_active & biudata_valid)) begin
                    state         <= IDLE;
                    cnt           <= 32'd0;
                    hitmiss_eval  <= 1'b0;
                    store         <= 1'b0;
                    load          <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else begin
                    if (hitmiss_eval & dcqmem_cycstb_i)
                        hitmiss_eval <= 1'b0;

                    if (biudata_valid) begin
`ifdef OR1200_DC_STORE_REFILL
                        if ((~ci_active) & tagcomp_miss) begin
                            state        <= SREFILL4;
                            store        <= 1'b0;
                            load         <= 1'b1;
                            hitmiss_eval <= 1'b0;
                            cnt          <= (`OR1200_DCLS - 1);
                        end else begin
                            state         <= IDLE;
                            cnt           <= 32'd0;
                            hitmiss_eval  <= 1'b0;
                            store         <= 1'b0;
                            load          <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end
`else
                        state         <= IDLE;
                        cnt           <= 32'd0;
                        hitmiss_eval  <= 1'b0;
                        store         <= 1'b0;
                        load          <= 1'b0;
                        cache_inhibit <= 1'b0;
`endif
                    end
                end
            end

`ifdef OR1200_DC_STORE_REFILL
            SREFILL4: begin
                if (biudata_valid) begin
                    if (cnt != 32'd0) begin
                        cnt               <= cnt - 32'd1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'b01;
                    end else begin
                        state         <= IDLE;
                        load          <= 1'b0;
                        hitmiss_eval  <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                end
            end
`endif

            default: begin
                state         <= IDLE;
                saved_addr_r  <= 32'd0;
                cnt           <= 32'd0;
                hitmiss_eval  <= 1'b0;
                store         <= 1'b0;
                load          <= 1'b0;
                cache_inhibit <= 1'b0;
            end
        endcase
    end
end

endmodule

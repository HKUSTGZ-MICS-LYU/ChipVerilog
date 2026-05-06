module or1200_dc_fsm #(
    parameter OR1200_DCLS            = 4,
    parameter OR1200_DC_STORE_REFILL = 0,
    parameter CNT_WIDTH              = 4
)(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f to top level DC
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

    // ------------------------------------------------------------
    // FSM state encoding
    // ------------------------------------------------------------
    localparam IDLE     = 3'd0;
    localparam CLOAD    = 3'd1;
    localparam LREFILL3 = 3'd2;
    localparam CSTORE   = 3'd3;
    localparam SREFILL4 = 3'd4;

    reg [2:0] state;

    reg [31:0] saved_addr_r;
    reg [CNT_WIDTH-1:0] cnt;

    reg hitmiss_eval;
    reg store;
    reg load;
    reg cache_inhibit;

    wire current_cache_inhibit;
    wire first_store_hit_ack;
    wire load_hit_ack;

    // Cache inhibit may be seen either from the latched flag or
    // directly during the CLOAD/CSTORE evaluation cycle.
    assign current_cache_inhibit =
        cache_inhibit | (dcqmem_cycstb_i & dcqmem_ci_i);

    assign saved_addr = saved_addr_r;

    // ------------------------------------------------------------
    // Acknowledge / error generation
    // ------------------------------------------------------------

    assign load_hit_ack =
        (state == CLOAD)        &&
        load                    &&
        hitmiss_eval            &&
        dcqmem_cycstb_i         &&
        !dcqmem_ci_i            &&
        !tagcomp_miss;

    assign first_store_hit_ack =
        (state == CSTORE)       &&
        store                   &&
        biudata_valid           &&
        !tagcomp_miss           &&
        !current_cache_inhibit;

    assign first_hit_ack =
        load_hit_ack | first_store_hit_ack;

    assign first_miss_ack =
        ((state == CLOAD) || (state == CSTORE)) &&
        biudata_valid;

    assign first_miss_err =
        ((state == CLOAD) || (state == CSTORE)) &&
        biudata_error;

    // ------------------------------------------------------------
    // BIU request generation
    // ------------------------------------------------------------

    assign biu_read =
        (
            hitmiss_eval &&
            load         &&
            tagcomp_miss &&
            !current_cache_inhibit
        ) ||
        (
            !hitmiss_eval &&
            load
        );

    assign biu_write = store;

    // ------------------------------------------------------------
    // Burst indication
    // ------------------------------------------------------------

    assign burst =
        (
            (state == CLOAD)    &&
            load                &&
            hitmiss_eval        &&
            tagcomp_miss        &&
            !current_cache_inhibit
        ) ||
        (state == LREFILL3) ||
        (
            OR1200_DC_STORE_REFILL &&
            (state == SREFILL4)
        );

    // ------------------------------------------------------------
    // DCRAM and tag RAM write enable generation
    // ------------------------------------------------------------

    assign dcram_we =
        (load && biudata_valid && !current_cache_inhibit) ?
            4'b1111 :
        (first_store_hit_ack) ?
            dcqmem_sel_i :
            4'b0000;

    assign tag_we =
        biu_read &&
        biudata_valid &&
        !current_cache_inhibit;

    // ------------------------------------------------------------
    // Address mux
    // ------------------------------------------------------------
    // During hit/miss evaluation, use start_addr.
    // After evaluation, when an active BIU transfer is in progress,
    // use saved_addr_r.
    assign dc_addr =
        (!hitmiss_eval && (biu_read || biu_write)) ?
            saved_addr_r :
            start_addr;

    // ------------------------------------------------------------
    // Sequential FSM
    // ------------------------------------------------------------

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= IDLE;
            saved_addr_r  <= 32'd0;
            cnt           <= {CNT_WIDTH{1'b0}};
            hitmiss_eval  <= 1'b0;
            store         <= 1'b0;
            load          <= 1'b0;
            cache_inhibit <= 1'b0;
        end else begin
            case (state)

                // ------------------------------------------------
                // IDLE: accept a new CPU-side request
                // ------------------------------------------------
                IDLE: begin
                    cnt           <= {CNT_WIDTH{1'b0}};
                    hitmiss_eval  <= 1'b0;
                    store         <= 1'b0;
                    load          <= 1'b0;
                    cache_inhibit <= 1'b0;

                    if (dc_en && dcqmem_cycstb_i) begin
                        saved_addr_r <= start_addr;
                        hitmiss_eval <= 1'b1;

                        if (dcqmem_we_i) begin
                            state <= CSTORE;
                            store <= 1'b1;
                            load  <= 1'b0;
                        end else begin
                            state <= CLOAD;
                            store <= 1'b0;
                            load  <= 1'b1;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end

                // ------------------------------------------------
                // CLOAD: load hit, load miss, or cache-inhibited load
                // ------------------------------------------------
                CLOAD: begin
                    if (biudata_error) begin
                        state         <= IDLE;
                        hitmiss_eval  <= 1'b0;
                        load          <= 1'b0;
                        store         <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end else if (hitmiss_eval) begin
                        if (!dcqmem_cycstb_i) begin
                            // Request aborted before evaluation completes.
                            state         <= IDLE;
                            hitmiss_eval  <= 1'b0;
                            load          <= 1'b0;
                            store         <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end else if (dcqmem_ci_i) begin
                            // Cache-inhibited load bypasses cache refill.
                            cache_inhibit <= 1'b1;
                            hitmiss_eval  <= 1'b0;
                            state         <= CLOAD;
                        end else if (!tagcomp_miss) begin
                            // Normal load hit.
                            state         <= IDLE;
                            hitmiss_eval  <= 1'b0;
                            load          <= 1'b0;
                            store         <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end else if (biudata_valid) begin
                            // First word of a load miss refill returned.
                            state                  <= LREFILL3;
                            hitmiss_eval           <= 1'b0;
                            saved_addr_r[3:2]      <= saved_addr_r[3:2] + 2'd1;
                            cnt                    <= OR1200_DCLS - 2;
                        end else begin
                            // Load miss waiting for first BIU word.
                            state <= CLOAD;
                        end
                    end else begin
                        // Post-evaluation load phase.
                        // This is used for cache-inhibited load completion.
                        if (biudata_valid) begin
                            state         <= IDLE;
                            load          <= 1'b0;
                            store         <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end else begin
                            state <= CLOAD;
                        end
                    end
                end

                // ------------------------------------------------
                // LREFILL3: continue normal load-miss cache line refill
                // ------------------------------------------------
                LREFILL3: begin
                    if (biudata_error) begin
                        state         <= IDLE;
                        load          <= 1'b0;
                        store         <= 1'b0;
                        hitmiss_eval  <= 1'b0;
                        cache_inhibit <= 1'b0;
                        cnt           <= {CNT_WIDTH{1'b0}};
                    end else if (biudata_valid) begin
                        if (cnt != {CNT_WIDTH{1'b0}}) begin
                            cnt               <= cnt - {{(CNT_WIDTH-1){1'b0}}, 1'b1};
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                            state             <= LREFILL3;
                        end else begin
                            state         <= IDLE;
                            load          <= 1'b0;
                            store         <= 1'b0;
                            hitmiss_eval  <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end
                    end else begin
                        state <= LREFILL3;
                    end
                end

                // ------------------------------------------------
                // CSTORE: write-through store hit, miss, or CI store
                // ------------------------------------------------
                CSTORE: begin
                    if (biudata_error) begin
                        state         <= IDLE;
                        hitmiss_eval  <= 1'b0;
                        store         <= 1'b0;
                        load          <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end else if (hitmiss_eval) begin
                        if (!dcqmem_cycstb_i) begin
                            // Request aborted before evaluation completes.
                            state         <= IDLE;
                            hitmiss_eval  <= 1'b0;
                            store         <= 1'b0;
                            load          <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end else if (dcqmem_ci_i) begin
                            // Cache-inhibited store bypasses cache update/refill.
                            cache_inhibit <= 1'b1;
                            hitmiss_eval  <= 1'b0;
                            state         <= CSTORE;
                        end else if (biudata_valid) begin
                            if (tagcomp_miss && OR1200_DC_STORE_REFILL) begin
                                // Optional store-miss refill path.
                                state         <= SREFILL4;
                                hitmiss_eval  <= 1'b0;
                                store         <= 1'b0;
                                load          <= 1'b1;
                                cache_inhibit <= 1'b0;
                                cnt           <= OR1200_DCLS - 1;
                            end else begin
                                // Store hit, or store miss without refill.
                                state         <= IDLE;
                                hitmiss_eval  <= 1'b0;
                                store         <= 1'b0;
                                load          <= 1'b0;
                                cache_inhibit <= 1'b0;
                            end
                        end else begin
                            state <= CSTORE;
                        end
                    end else begin
                        // Post-evaluation store phase.
                        // Mainly used for cache-inhibited store completion.
                        if (biudata_valid) begin
                            state         <= IDLE;
                            store         <= 1'b0;
                            load          <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end else begin
                            state <= CSTORE;
                        end
                    end
                end

                // ------------------------------------------------
                // SREFILL4: optional store-miss cache line refill
                // ------------------------------------------------
                SREFILL4: begin
                    if (biudata_error) begin
                        state         <= IDLE;
                        load          <= 1'b0;
                        store         <= 1'b0;
                        hitmiss_eval  <= 1'b0;
                        cache_inhibit <= 1'b0;
                        cnt           <= {CNT_WIDTH{1'b0}};
                    end else if (biudata_valid) begin
                        if (cnt != {CNT_WIDTH{1'b0}}) begin
                            cnt               <= cnt - {{(CNT_WIDTH-1){1'b0}}, 1'b1};
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                            state             <= SREFILL4;
                        end else begin
                            state         <= IDLE;
                            load          <= 1'b0;
                            store         <= 1'b0;
                            hitmiss_eval  <= 1'b0;
                            cache_inhibit <= 1'b0;
                        end
                    end else begin
                        state <= SREFILL4;
                    end
                end

                default: begin
                    state         <= IDLE;
                    saved_addr_r  <= 32'd0;
                    cnt           <= {CNT_WIDTH{1'b0}};
                    hitmiss_eval  <= 1'b0;
                    store         <= 1'b0;
                    load          <= 1'b0;
                    cache_inhibit <= 1'b0;
                end

            endcase
        end
    end

endmodule
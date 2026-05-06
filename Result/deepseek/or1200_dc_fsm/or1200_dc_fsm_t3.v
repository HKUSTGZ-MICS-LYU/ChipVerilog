module or1200_dc_fsm (
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
    output reg [31:0] saved_addr,
    output reg [3:0] dcram_we,
    output biu_read,
    output biu_write,
    output first_hit_ack,
    output first_miss_ack,
    output first_miss_err,
    output burst,
    output tag_we,
    output [31:0] dc_addr
);

parameter STORE_REFILL_ENABLE = 1'b1;
localparam DCLS = 4; // Words per cache line (16 bytes)

// State encoding
localparam [2:0] IDLE     = 3'b000,
                 CLOAD    = 3'b001,
                 CSTORE   = 3'b010,
                 LREFILL3 = 3'b011,
                 SREFILL4 = 3'b100;

reg [2:0] state, next_state;
reg [1:0] cnt; // counter for refill words remaining
reg store, load;
reg hitmiss_eval;
reg cache_inhibit;

// Sequential state update
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        saved_addr <= 32'd0;
        cnt <= 2'd0;
        hitmiss_eval <= 1'b0;
        store <= 1'b0;
        load <= 1'b0;
        cache_inhibit <= 1'b0;
    end else begin
        state <= next_state;
        // Other registers updated in combinational next_state logic (or explicit assign below)
        // We'll handle saved_addr, cnt, hitmiss_eval, store, load, cache_inhibit in always_comb for next state logic
    end
end

// Combinational next state and register updates
reg [1:0] cnt_next;
reg [31:0] saved_addr_next;
reg hitmiss_eval_next, store_next, load_next, cache_inhibit_next;
always @(*) begin
    // Default: hold values
    next_state = state;
    saved_addr_next = saved_addr;
    cnt_next = cnt;
    hitmiss_eval_next = hitmiss_eval;
    store_next = store;
    load_next = load;
    cache_inhibit_next = cache_inhibit;

    case (state)
        IDLE: begin
            // Clear flags while idle
            hitmiss_eval_next = 1'b0;
            store_next = 1'b0;
            load_next = 1'b0;
            cache_inhibit_next = 1'b0;
            if (dc_en && dcqmem_cycstb_i) begin
                saved_addr_next = start_addr;
                hitmiss_eval_next = 1'b1;
                cache_inhibit_next = 1'b0; // clear on entry, set later if needed
                if (dcqmem_we_i) begin
                    store_next = 1'b1;
                    load_next = 1'b0;
                    next_state = CSTORE;
                end else begin
                    load_next = 1'b1;
                    store_next = 1'b0;
                    next_state = CLOAD;
                end
                // Note: cache_inhibit will be set in CLOAD/CSTORE if dcqmem_ci_i is asserted
            end
        end

        CLOAD: begin
            // If cache-inhibited, wait for BIU response
            if (cache_inhibit) begin
                if (biudata_valid) begin
                    next_state = IDLE;
                    load_next = 1'b0;
                    hitmiss_eval_next = 1'b0;
                end else if (biudata_error) begin
                    next_state = IDLE;
                    load_next = 1'b0;
                    hitmiss_eval_next = 1'b0;
                end
                // else stay
            end else begin
                // Not cache-inhibited: evaluate hit/miss
                if (tagcomp_miss) begin
                    // Miss: assert biu_read (combinational)
                    // Wait for biudata_valid
                    if (biudata_valid) begin
                        // First word returned
                        // Go to LREFILL3, increment address, set cnt
                        saved_addr_next[3:2] = saved_addr[3:2] + 1'b1;
                        cnt_next = DCLS - 2'd2;
                        next_state = LREFILL3;
                        load_next = 1'b1;
                        hitmiss_eval_next = 1'b0;
                    end else if (biudata_error) begin
                        next_state = IDLE;
                        load_next = 1'b0;
                        hitmiss_eval_next = 1'b0;
                    end
                    // else stay
                end else begin
                    // Hit: immediate acknowledge, go IDLE
                    next_state = IDLE;
                    load_next = 1'b0;
                    hitmiss_eval_next = 1'b0;
                end
            end
            // Detect cache_inhibit if dcqmem_cycstb_i & dcqmem_ci_i (should be stable during request)
            // We set cache_inhibit when entering CLOAD if dcqmem_ci_i is high
            // But we need to capture it at request time; we set in IDLE acceptance? Actually spec says detect later.
            // For simplicity, capture at edge when entering CLOAD from IDLE: cache_inhibit_next = dcqmem_ci_i & dcqmem_cycstb_i;
            // But dcqmem_cycstb_i may have changed. Safer: set on transition from IDLE when dcqmem_ci_i is high.
            // We'll do: if (state==IDLE && next_state==CLOAD) then cache_inhibit_next = dcqmem_ci_i;
            // But we are in case state; we need to check transition. We'll handle in IDLE case when we set next_state.
        end

        CSTORE: begin
            // Similar to CLOAD but for stores
            if (cache_inhibit) begin
                if (biudata_valid || biudata_error) begin
                    next_state = IDLE;
                    store_next = 1'b0;
                    hitmiss_eval_next = 1'b0;
                end
            end else begin
                // Not cache-inhibited
                if (tagcomp_miss) begin
                    // Miss
                    if (biudata_valid) begin
                        if (STORE_REFILL_ENABLE) begin
                            // Go to SREFILL4, set load, clear store, cnt = DCLS-1
                            cnt_next = DCLS - 1'd1;
                            next_state = SREFILL4;
                            store_next = 1'b0;
                            load_next = 1'b1;
                            hitmiss_eval_next = 1'b0;
                        end else begin
                            next_state = IDLE;
                            store_next = 1'b0;
                            hitmiss_eval_next = 1'b0;
                        end
                    end else if (biudata_error) begin
                        next_state = IDLE;
                        store_next = 1'b0;
                        hitmiss_eval_next = 1'b0;
                    end
                end else begin
                    // Hit: wait for write-through response
                    if (biudata_valid) begin
                        next_state = IDLE;
                        store_next = 1'b0;
                        hitmiss_eval_next = 1'b0;
                    end else if (biudata_error) begin
                        next_state = IDLE;
                        store_next = 1'b0;
                        hitmiss_eval_next = 1'b0;
                    end
                end
            end
            // Cache-inhibit capture: when entering CSTORE from IDLE
        end

        LREFILL3: begin
            if (biudata_valid) begin
                if (cnt == 2'd0) begin
                    // Last word already? Actually cnt initial is DCLS-2 (2). So first valid: cnt>0.
                    // This condition will trigger after second valid when cnt becomes 0 before decrement?
                    // We'll implement: if cnt == 1 before decrement, this is last word.
                    // But easier: decrement and then if cnt_next == 0, go IDLE.
                    // We'll compute cnt_next = cnt - 1; if (cnt == 0) but that won't happen because we only decrement when cnt>0.
                    // So test if cnt == 1 before decrement.
                    // Let's implement:
                    if (cnt == 2'd1) begin
                        // Last word
                        next_state = IDLE;
                        load_next = 1'b0;
                        hitmiss_eval_next = 1'b0;
                    end else begin
                        saved_addr_next[3:2] = saved_addr[3:2] + 1'b1;
                        cnt_next = cnt - 1'b1;
                    end
                end else begin
                    // cnt > 0 initially (2 or 1)
                    saved_addr_next[3:2] = saved_addr[3:2] + 1'b1;
                    cnt_next = cnt - 1'b1;
                    if (cnt_next == 0) begin
                        // After decrement becomes 0, last word
                        next_state = IDLE;
                        load_next = 1'b0;
                        hitmiss_eval_next = 1'b0;
                    end
                end
            end
            // No error handling specified, but could have biudata_error; spec says if error occurs, FSM returns to IDLE? Not mentioned for LREFILL3. Assume stay.
        end

        SREFILL4: begin
            if (biudata_valid) begin
                if (cnt == 2'd1) begin
                    // Last word
                    next_state = IDLE;
                    load_next = 1'b0;
                    hitmiss_eval_next = 1'b0;
                end else begin
                    saved_addr_next[3:2] = saved_addr[3:2] + 1'b1;
                    cnt_next = cnt - 1'b1;
                    if (cnt_next == 0) begin
                        next_state = IDLE;
                        load_next = 1'b0;
                        hitmiss_eval_next = 1'b0;
                    end
                end
            end
        end

        default: next_state = IDLE;
    endcase

    // Cache-inhibit capture: set when transitioning from IDLE to CLOAD or CSTORE and dcqmem_ci_i is high
    // This requires that dcqmem_cycstb_i is active at that time (ensured by acceptance condition)
    if (state == IDLE && (next_state == CLOAD || next_state == CSTORE)) begin
        cache_inhibit_next = dcqmem_ci_i;
    end
end

// Output assignments
assign biu_read = (state == CLOAD && !cache_inhibit && tagcomp_miss) ||
                  (state == LREFILL3) ||
                  (state == SREFILL4);

assign biu_write = (state == CSTORE && store);

assign first_hit_ack = (state == CLOAD && !cache_inhibit && !tagcomp_miss) ||
                       (state == CSTORE && !cache_inhibit && !tagcomp_miss && biudata_valid);

assign first_miss_ack = ((state == CLOAD) || (state == CSTORE)) && biudata_valid;

assign first_miss_err = ((state == CLOAD) || (state == CSTORE)) && biudata_error;

assign burst = (state == CLOAD && !cache_inhibit && tagcomp_miss) ||
               (state == LREFILL3) ||
               (state == SREFILL4);

assign tag_we = biu_read && biudata_valid && !cache_inhibit;

assign dc_addr = hitmiss_eval ? start_addr : saved_addr;

// DCRAM write enable: during load refill if load=1, biudata_valid, not cache-inhibit: all lanes
// During store hit: first_store_hit_ack (combinational) and dcqmem_sel_i
wire first_store_hit_ack = (state == CSTORE && !cache_inhibit && !tagcomp_miss && biudata_valid);
always @(*) begin
    if (load && biudata_valid && !cache_inhibit && (state == CLOAD || state == LREFILL3 || state == SREFILL4))
        dcram_we = 4'b1111;
    else if (first_store_hit_ack)
        dcram_we = dcqmem_sel_i;
    else
        dcram_we = 4'b0;
end

endmodule

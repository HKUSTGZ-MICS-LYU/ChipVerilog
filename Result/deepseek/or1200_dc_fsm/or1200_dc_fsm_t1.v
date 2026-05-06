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

    parameter OR1200_DCLS = 4; // default value; adjust as needed
    parameter OR1200_DC_STORE_REFILL = 1; // enable store refill

    localparam IDLE      = 3'd0,
               CLOAD     = 3'd1,
               CSTORE    = 3'd2,
               LREFILL3  = 3'd3,
               SREFILL4  = 3'd4;

    reg [2:0] state, next_state;
    reg [31:0] saved_addr_r;
    reg [3:0] cnt;
    reg hitmiss_eval;
    reg store, load;
    reg cache_inhibit;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            saved_addr_r <= 32'd0;
            cnt <= 4'd0;
            hitmiss_eval <= 1'b0;
            store <= 1'b0;
            load <= 1'b0;
            cache_inhibit <= 1'b0;
        end else begin
            state <= next_state;
            // saved_addr_r, cnt, hitmiss_eval, store, load, cache_inhibit updated in combinational block
        end
    end

    always @* begin
        // Default values
        next_state = state;
        saved_addr_r = saved_addr_r;
        cnt = cnt;
        hitmiss_eval = hitmiss_eval;
        store = store;
        load = load;
        cache_inhibit = cache_inhibit;

        case (state)
            IDLE: begin
                if (dc_en && dcqmem_cycstb_i) begin
                    saved_addr_r = start_addr;
                    hitmiss_eval = 1'b1;
                    cache_inhibit = 1'b0; // cleared on entry
                    if (dcqmem_we_i) begin
                        store = 1'b1;
                        load = 1'b0;
                        next_state = CSTORE;
                    end else begin
                        store = 1'b0;
                        load = 1'b1;
                        next_state = CLOAD;
                    end
                end else begin
                    hitmiss_eval = 1'b0;
                    store = 1'b0;
                    load = 1'b0;
                    cache_inhibit = 1'b0;
                end
            end

            CLOAD: begin
                // detect cache-inhibit
                if (dcqmem_cycstb_i && dcqmem_ci_i) begin
                    cache_inhibit = 1'b1;
                end
                if (!dcqmem_cycstb_i || biudata_error) begin
                    // abort or error
                    next_state = IDLE;
                    hitmiss_eval = 1'b0;
                    load = 1'b0;
                    store = 1'b0;
                end else if (cache_inhibit && biudata_valid) begin
                    // cache-inhibited completed
                    next_state = IDLE;
                    hitmiss_eval = 1'b0;
                    load = 1'b0;
                end else if (!cache_inhibit && !tagcomp_miss) begin
                    // load hit
                    next_state = IDLE;
                    hitmiss_eval = 1'b0;
                    load = 1'b0;
                end else if (!cache_inhibit && tagcomp_miss && biudata_valid) begin
                    // first miss word returned
                    next_state = LREFILL3;
                    hitmiss_eval = 1'b0;
                    saved_addr_r[3:2] = saved_addr_r[3:2] + 2'd1;
                    cnt = OR1200_DCLS - 2;
                end
            end

            CSTORE: begin
                // detect cache-inhibit
                if (dcqmem_cycstb_i && dcqmem_ci_i) begin
                    cache_inhibit = 1'b1;
                end
                if (!dcqmem_cycstb_i || biudata_error) begin
                    // abort or error
                    next_state = IDLE;
                    hitmiss_eval = 1'b0;
                    store = 1'b0;
                    load = 1'b0;
                end else if (cache_inhibit && biudata_valid) begin
                    // cache-inhibited store completed
                    next_state = IDLE;
                    hitmiss_eval = 1'b0;
                    store = 1'b0;
                end else if (biudata_valid) begin
                    // write-through response received
                    if (!cache_inhibit && !tagcomp_miss) begin
                        // store hit
                        next_state = IDLE;
                        hitmiss_eval = 1'b0;
                        store = 1'b0;
                    end else if (OR1200_DC_STORE_REFILL && !cache_inhibit && tagcomp_miss) begin
                        // store miss with refill
                        next_state = SREFILL4;
                        hitmiss_eval = 1'b0;
                        store = 1'b0;
                        load = 1'b1;
                        cnt = OR1200_DCLS - 1;
                    end else begin
                        // store miss without refill or cache-inhibited already handled
                        next_state = IDLE;
                        hitmiss_eval = 1'b0;
                        store = 1'b0;
                    end
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 0) begin
                        cnt = cnt - 1;
                        saved_addr_r[3:2] = saved_addr_r[3:2] + 2'd1;
                    end else begin
                        next_state = IDLE;
                        load = 1'b0;
                    end
                end
            end

            SREFILL4: begin
                if (biudata_valid) begin
                    if (cnt != 0) begin
                        cnt = cnt - 1;
                        saved_addr_r[3:2] = saved_addr_r[3:2] + 2'd1;
                    end else begin
                        next_state = IDLE;
                        load = 1'b0;
                    end
                end
            end

            default: begin
                next_state = IDLE;
                hitmiss_eval = 1'b0;
                store = 1'b0;
                load = 1'b0;
                cache_inhibit = 1'b0;
            end
        endcase
    end

    // Output assignments
    assign saved_addr = saved_addr_r;

    // biu_read
    assign biu_read = (state == CLOAD && hitmiss_eval && tagcomp_miss && !cache_inhibit) ||
                      (state == LREFILL3) ||
                      (state == SREFILL4);

    // biu_write
    assign biu_write = (store == 1'b1);

    // dc_addr
    assign dc_addr = (hitmiss_eval) ? start_addr : saved_addr_r;

    // dcram_we
    assign dcram_we = ((load && biudata_valid && !cache_inhibit && (state == LREFILL3 || state == SREFILL4 || state == CLOAD)) ? 4'b1111 : 4'b0000) |
                      ((state == CSTORE && biudata_valid && !cache_inhibit && !tagcomp_miss) ? dcqmem_sel_i : 4'b0000);

    // tag_we
    assign tag_we = biu_read && biudata_valid && !cache_inhibit;

    // first_hit_ack
    assign first_hit_ack = (state == CLOAD && !tagcomp_miss && !cache_inhibit) ||
                           (state == CSTORE && biudata_valid && !tagcomp_miss && !cache_inhibit);

    // first_miss_ack
    assign first_miss_ack = ((state == CLOAD || state == CSTORE) && biudata_valid);

    // first_miss_err
    assign first_miss_err = ((state == CLOAD || state == CSTORE) && biudata_error);

    // burst
    assign burst = (state == CLOAD && tagcomp_miss && !cache_inhibit) ||
                   (state == LREFILL3) ||
                   (OR1200_DC_STORE_REFILL && state == SREFILL4);

endmodule

module or1200_ic_fsm (
    input clk,
    input rst,
    input ic_en,
    input icqmem_cycstb_i,
    input icqmem_ci_i,
    input tagcomp_miss,
    input biudata_valid,
    input biudata_error,
    input [31:0] start_addr,
    output reg [31:0] saved_addr,
    output reg [3:0] icram_we,
    output biu_read,
    output first_hit_ack,
    output first_miss_ack,
    output first_miss_err,
    output burst,
    output tag_we
);

    parameter OR1200_ICLS = 4;

    localparam IDLE = 2'd0;
    localparam CFETCH = 2'd1;
    localparam LREFILL3 = 2'd2;
    localparam IFETCH = 2'd3;

    reg [1:0] state, next_state;
    reg [31:0] saved_addr_r, next_saved_addr_r;
    reg [2:0] cnt, next_cnt;
    reg hitmiss_eval, next_hitmiss_eval;
    reg load, next_load;
    reg cache_inhibit, next_cache_inhibit;

    // Sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            saved_addr_r <= 32'h0;
            cnt <= 3'h0;
            hitmiss_eval <= 1'b0;
            load <= 1'b0;
            cache_inhibit <= 1'b0;
        end else begin
            state <= next_state;
            saved_addr_r <= next_saved_addr_r;
            cnt <= next_cnt;
            hitmiss_eval <= next_hitmiss_eval;
            load <= next_load;
            cache_inhibit <= next_cache_inhibit;
        end
    end

    // Next state and register update logic
    always @(*) begin
        next_state = state;
        next_saved_addr_r = saved_addr_r;
        next_cnt = cnt;
        next_hitmiss_eval = hitmiss_eval;
        next_load = load;
        next_cache_inhibit = cache_inhibit;

        case (state)
            IDLE: begin
                if (ic_en && icqmem_cycstb_i) begin
                    next_state = CFETCH;
                    next_saved_addr_r = start_addr;
                    next_hitmiss_eval = 1'b1;
                    next_load = 1'b1;
                    next_cache_inhibit = 1'b0;
                end else begin
                    next_state = IDLE;
                    next_hitmiss_eval = 1'b0;
                    next_load = 1'b0;
                    next_cache_inhibit = 1'b0;
                end
            end

            CFETCH: begin
                // Default next values (stay in CFETCH)
                // Actions when hitmiss_eval is high
                if (hitmiss_eval) begin
                    next_saved_addr_r[31:13] = start_addr[31:13];
                    if (icqmem_ci_i)
                        next_cache_inhibit = 1'b1;
                end

                // High priority return-to-IDLE conditions
                if (!ic_en || (hitmiss_eval && !icqmem_cycstb_i) || biudata_error || (cache_inhibit && biudata_valid)) begin
                    next_state = IDLE;
                    next_hitmiss_eval = 1'b0;
                    next_load = 1'b0;
                    next_cache_inhibit = 1'b0;
                    // saved_addr_r unchanged
                end else if (tagcomp_miss && biudata_valid) begin
                    // Miss, first word back
                    next_state = LREFILL3;
                    next_saved_addr_r[3:2] = next_saved_addr_r[3:2] + 1;
                    next_hitmiss_eval = 1'b0;
                    next_cnt = OR1200_ICLS - 2;
                    next_cache_inhibit = 1'b0;
                    // load remains 1
                end else if (!tagcomp_miss && !icqmem_ci_i) begin
                    // Cache hit, not inhibit
                    next_saved_addr_r = start_addr;
                    next_cache_inhibit = 1'b0;
                    // No change to state, hitmiss_eval, load
                end else begin
                    // Default: clear hitmiss_eval
                    next_hitmiss_eval = 1'b0;
                    // load and state unchanged; saved_addr_r and cache_inhibit already updated if needed
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 3'd0) begin
                        next_cnt = cnt - 1;
                        next_saved_addr_r[3:2] = saved_addr_r[3:2] + 1;
                    end else begin
                        next_state = IDLE;
                        next_hitmiss_eval = 1'b0;
                        next_load = 1'b0;
                        next_saved_addr_r = start_addr;
                    end
                end
                // else stay in LREFILL3
            end

            default: begin
                next_state = IDLE;
                next_hitmiss_eval = 1'b0;
                next_load = 1'b0;
                next_cache_inhibit = 1'b0;
            end
        endcase
    end

    // Combinational outputs
    assign biu_read = (hitmiss_eval & tagcomp_miss) | (!hitmiss_eval & load);
    assign icram_we = (biu_read & biudata_valid & !cache_inhibit) ? 4'hF : 4'h0;
    assign tag_we = (biu_read & biudata_valid & !cache_inhibit);
    assign first_hit_ack = (state == CFETCH) && hitmiss_eval && !tagcomp_miss && !cache_inhibit && !icqmem_ci_i;
    assign first_miss_ack = (state == CFETCH) && biudata_valid;
    assign first_miss_err = (state == CFETCH) && biudata_error;
    assign burst = ((state == CFETCH) && tagcomp_miss && !cache_inhibit) || (state == LREFILL3);
    assign saved_addr = saved_addr_r;

endmodule

module or1200_ic_fsm (
    input  wire         clk,
    input  wire         rst,
    input  wire         ic_en,
    input  wire         icqmem_cycstb_i,
    input  wire         icqmem_ci_i,
    input  wire         tagcomp_miss,
    input  wire         biudata_valid,
    input  wire         biudata_error,
    input  wire [31:0]  start_addr,
    output reg  [31:0]  saved_addr,
    output reg  [3:0]   icram_we,
    output wire         biu_read,
    output wire         first_hit_ack,
    output wire         first_miss_ack,
    output wire         first_miss_err,
    output wire         burst,
    output wire         tag_we
);

    // Local parameters
    localparam IDLE     = 2'b00;
    localparam CFETCH   = 2'b01;
    localparam LREFILL3 = 2'b10;
    localparam IFETCH   = 2'b11; // unused

    localparam OR1200_ICLS = 4;  // number of words per cache line (16 bytes = 4 words)

    // Registered signals
    reg [1:0]  state;
    reg [31:0] saved_addr_r;
    reg [1:0]  cnt;               // count down counter for remaining words in refill
    reg        hitmiss_eval;
    reg        load;
    reg        cache_inhibit;

    // Next state variables
    reg [1:0]  next_state;
    reg [31:0] next_saved_addr_r;
    reg [1:0]  next_cnt;
    reg        next_hitmiss_eval;
    reg        next_load;
    reg        next_cache_inhibit;

    // State and register update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            saved_addr_r   <= 32'b0;
            cnt            <= 2'b0;
            hitmiss_eval   <= 1'b0;
            load           <= 1'b0;
            cache_inhibit  <= 1'b0;
        end else begin
            state          <= next_state;
            saved_addr_r   <= next_saved_addr_r;
            cnt            <= next_cnt;
            hitmiss_eval   <= next_hitmiss_eval;
            load           <= next_load;
            cache_inhibit  <= next_cache_inhibit;
        end
    end

    // Next state logic
    always @(*) begin
        // Default: stay in current state, keep registers unchanged
        next_state          = state;
        next_saved_addr_r   = saved_addr_r;
        next_cnt            = cnt;
        next_hitmiss_eval   = hitmiss_eval;
        next_load           = load;
        next_cache_inhibit  = cache_inhibit;

        case (state)
            IDLE: begin
                if (ic_en && icqmem_cycstb_i) begin
                    // Accept new fetch request
                    next_state          = CFETCH;
                    next_saved_addr_r   = start_addr;
                    next_hitmiss_eval   = 1'b1;
                    next_load           = 1'b1;
                    next_cache_inhibit  = 1'b0;
                end else begin
                    // IDLE no request: clear transient control flags
                    next_hitmiss_eval   = 1'b0;
                    next_load           = 1'b0;
                    next_cache_inhibit  = 1'b0;
                end
            end

            CFETCH: begin
                // Default actions for CFETCH
                // Refresh saved_addr_r[31:13] while hitmiss_eval active
                if (hitmiss_eval) begin
                    next_saved_addr_r[31:13] = start_addr[31:13];
                end

                // Latch cache_inhibit if cache-inhibit access
                if (icqmem_ci_i) begin
                    next_cache_inhibit = 1'b1;
                end

                // Determine high-priority termination conditions
                // 1. ic_en deasserted
                // 2. Request withdrawn during evaluation (hitmiss_eval && !icqmem_cycstb_i)
                // 3. BIU error
                // 4. Cache-inhibit access completed (cache_inhibit && biudata_valid)
                if (!ic_en ||
                    (hitmiss_eval && !icqmem_cycstb_i) ||
                    biudata_error ||
                    (cache_inhibit && biudata_valid)) begin
                    // Terminate transaction: return to IDLE
                    next_state          = IDLE;
                    next_hitmiss_eval   = 1'b0;
                    next_load           = 1'b0;
                    next_cache_inhibit  = 1'b0;
                end else if (hitmiss_eval && tagcomp_miss && biudata_valid) begin
                    // Cache miss: first word returned -> refill
                    next_state          = LREFILL3;
                    // Increment word index for next word
                    next_saved_addr_r[3:2] = saved_addr_r[3:2] + 2'b01;
                    next_hitmiss_eval   = 1'b0;
                    next_cnt            = OR1200_ICLS - 2; // for 4-word line: 2
                    next_cache_inhibit  = 1'b0;
                end else if (hitmiss_eval && !tagcomp_miss && !icqmem_ci_i) begin
                    // Cache hit: update saved address, clear cache_inhibit
                    next_saved_addr_r   = start_addr;
                    next_cache_inhibit  = 1'b0;
                    // No state change; remain in CFETCH
                end else begin
                    // Default: clear hitmiss_eval (initial evaluation phase ends)
                    next_hitmiss_eval   = 1'b0;
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 2'b0) begin
                        // Not the last word: decrement counter and increment address
                        next_cnt            = cnt - 2'b01;
                        next_saved_addr_r[3:2] = saved_addr_r[3:2] + 2'b01;
                    end else begin
                        // Last word of refill: return to IDLE
                        next_state          = IDLE;
                        next_hitmiss_eval   = 1'b0;
                        next_load           = 1'b0;
                        next_saved_addr_r   = start_addr; // update with current start_addr
                    end
                end
                // else stay in LREFILL3, no changes
            end

            default: begin
                // IFETCH or undefined: go to IDLE
                next_state          = IDLE;
                next_hitmiss_eval   = 1'b0;
                next_load           = 1'b0;
                next_cache_inhibit  = 1'b0;
            end
        endcase
    end

    // Combinational outputs
    assign biu_read = (hitmiss_eval & tagcomp_miss) | (~hitmiss_eval & load);

    // icram_we and tag_we: asserted when biu_read & biudata_valid & not cache_inhibit
    always @(*) begin
        if (biu_read && biudata_valid && ~cache_inhibit) begin
            icram_we = 4'b1111;
            tag_we   = 1'b1;
        end else begin
            icram_we = 4'b0;
            tag_we   = 1'b0;
        end
    end

    assign first_hit_ack  = (state == CFETCH) && hitmiss_eval && !tagcomp_miss && !cache_inhibit && !icqmem_ci_i;
    assign first_miss_ack = (state == CFETCH) && biudata_valid;
    assign first_miss_err = (state == CFETCH) && biudata_error;
    assign burst          = ((state == CFETCH) && tagcomp_miss && !cache_inhibit) || (state == LREFILL3);

    assign saved_addr = saved_addr_r;

endmodule

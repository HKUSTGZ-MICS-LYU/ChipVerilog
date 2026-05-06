// or1200_ic_fsm: instruction-cache fetch-control finite state machine
module or1200_ic_fsm (
    input         clk,
    input         rst,
    input         ic_en,
    input         icqmem_cycstb_i,
    input         icqmem_ci_i,
    input         tagcomp_miss,
    input         biudata_valid,
    input         biudata_error,
    input  [31:0] start_addr,
    output [31:0] saved_addr,
    output [3:0]  icram_we,
    output        biu_read,
    output        first_hit_ack,
    output        first_miss_ack,
    output        first_miss_err,
    output        burst,
    output        tag_we
);

    // FSM state encoding
    localparam [1:0] IDLE     = 2'b00,
                     CFETCH   = 2'b01,
                     LREFILL3 = 2'b10,
                     IFETCH   = 2'b11; // defined but not used in transitions

    // OR1200 instruction cache line size in 32-bit words
    localparam OR1200_ICLS = 4;

    // State registers
    reg [31:0] saved_addr_r;
    reg [1:0]  state;
    reg [2:0]  cnt;
    reg        hitmiss_eval;
    reg        load;
    reg        cache_inhibit;

    // Next-state variables
    reg [1:0]  next_state;
    reg [31:0] next_saved_addr_r;
    reg [2:0]  next_cnt;
    reg        next_hitmiss_eval;
    reg        next_load;
    reg        next_cache_inhibit;

    // Output assignments
    assign saved_addr = saved_addr_r;

    // biu_read: combinational generation
    assign biu_read = (hitmiss_eval & tagcomp_miss) | (!hitmiss_eval & load);

    // Cache and tag write enables
    wire write_cond = biu_read & biudata_valid & ~cache_inhibit;
    assign icram_we = {4{write_cond}};
    assign tag_we   = write_cond;

    // First-word acknowledgement signals
    assign first_hit_ack  = (state == CFETCH) & hitmiss_eval & ~tagcomp_miss & ~cache_inhibit & ~icqmem_ci_i;
    assign first_miss_ack = (state == CFETCH) & biudata_valid;
    assign first_miss_err = (state == CFETCH) & biudata_error;

    // Burst indication
    assign burst = ((state == CFETCH) & hitmiss_eval & tagcomp_miss & ~cache_inhibit) |
                   (state == LREFILL3);

    // Sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            saved_addr_r   <= 32'd0;
            cnt            <= 3'd0;
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

    // Combinational next-state logic
    always @* begin
        // Default: retain current values
        next_state         = state;
        next_saved_addr_r  = saved_addr_r;
        next_cnt           = cnt;
        next_hitmiss_eval  = hitmiss_eval;
        next_load          = load;
        next_cache_inhibit = cache_inhibit;

        case (state)
            IDLE: begin
                if (ic_en & icqmem_cycstb_i) begin
                    // Accept new fetch request
                    next_state         = CFETCH;
                    next_saved_addr_r  = start_addr;
                    next_hitmiss_eval  = 1'b1;
                    next_load          = 1'b1;
                    next_cache_inhibit = 1'b0;
                end else begin
                    // No valid request, remain idle and clear flags
                    next_state         = IDLE;
                    next_hitmiss_eval  = 1'b0;
                    next_load          = 1'b0;
                    next_cache_inhibit = 1'b0;
                end
            end

            CFETCH: begin
                // Latch cache-inhibit attribute for the current access
                if (icqmem_ci_i)
                    next_cache_inhibit = 1'b1;

                // High-priority termination conditions:
                // 1. Instruction cache disabled
                // 2. Request withdrawn during initial evaluation
                // 3. BIU error
                // 4. Cache-inhibit access completed (valid data returned)
                if (~ic_en |
                    (~icqmem_cycstb_i & hitmiss_eval) |
                    biudata_error |
                    (cache_inhibit & biudata_valid)) begin
                    next_state         = IDLE;
                    next_hitmiss_eval  = 1'b0;
                    next_load          = 1'b0;
                    next_cache_inhibit = 1'b0;
                end
                // Miss: first external word has arrived
                else if (tagcomp_miss & biudata_valid) begin
                    next_state         = LREFILL3;
                    // Increment word address within the cache line
                    next_saved_addr_r  = {saved_addr_r[31:4], (saved_addr_r[3:2] + 2'd1), saved_addr_r[1:0]};
                    next_hitmiss_eval  = 1'b0;
                    next_cnt           = OR1200_ICLS - 2; // remaining words after the first
                    next_cache_inhibit = 1'b0;
                end
                // Cache hit (non-inhibited)
                else if (~tagcomp_miss & ~icqmem_ci_i) begin
                    // Update saved address with current start_addr
                    next_saved_addr_r  = start_addr;
                    next_cache_inhibit = 1'b0;
                    // Remain in CFETCH; hitmiss_eval and load are not cleared
                end
                // Request withdrawn during non-initial phase
                else if (~icqmem_cycstb_i) begin
                    next_state         = IDLE;
                    next_hitmiss_eval  = 1'b0;
                    next_load          = 1'b0;
                    next_cache_inhibit = 1'b0;
                end
                // No other condition met: end initial hit/miss evaluation
                else begin
                    next_hitmiss_eval = 1'b0;
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 3'd0) begin
                        // More words to refill
                        next_cnt          = cnt - 1'b1;
                        next_saved_addr_r = {saved_addr_r[31:4], (saved_addr_r[3:2] + 2'd1), saved_addr_r[1:0]};
                    end else begin
                        // Refill complete
                        next_state        = IDLE;
                        next_hitmiss_eval = 1'b0;
                        next_load         = 1'b0;
                        next_saved_addr_r = start_addr;
                    end
                end
                // else wait for biudata_valid
            end

            IFETCH: begin
                // IFETCH is defined but not used in transitions; keep safe defaults
                next_state = IDLE;
                next_hitmiss_eval = 1'b0;
                next_load         = 1'b0;
                next_cache_inhibit = 1'b0;
            end

            default: begin
                next_state = IDLE;
                next_hitmiss_eval = 1'b0;
                next_load         = 1'b0;
                next_cache_inhibit = 1'b0;
            end
        endcase
    end

endmodule

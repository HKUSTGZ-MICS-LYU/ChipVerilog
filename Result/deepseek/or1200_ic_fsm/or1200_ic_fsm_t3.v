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
    output reg tag_we
);

parameter OR1200_ICLS = 4; // Number of words in cache line

localparam IDLE     = 2'b00;
localparam CFETCH   = 2'b01;
localparam LREFILL3 = 2'b10;
localparam IFETCH   = 2'b11; // Not used

reg [1:0] state;
reg [1:0] next_state;
reg [31:0] saved_addr_r;
reg [2:0] cnt;
reg [2:0] cnt_next;
reg hitmiss_eval;
reg hitmiss_eval_next;
reg load;
reg load_next;
reg cache_inhibit;
reg cache_inhibit_next;

// Sequential logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        saved_addr_r <= 32'b0;
        cnt <= 0;
        hitmiss_eval <= 1'b0;
        load <= 1'b0;
        cache_inhibit <= 1'b0;
    end else begin
        state <= next_state;
        saved_addr_r <= saved_addr_r_next;
        cnt <= cnt_next;
        hitmiss_eval <= hitmiss_eval_next;
        load <= load_next;
        cache_inhibit <= cache_inhibit_next;
    end
end

// Combinational next state and register logic
wire in_idle       = (state == IDLE);
wire in_cfetch     = (state == CFETCH);
wire in_lrefill3   = (state == LREFILL3);

reg [31:0] saved_addr_r_next;

always @(*) begin
    // Default: stay in same state, keep all regs
    next_state = state;
    saved_addr_r_next = saved_addr_r;
    cnt_next = cnt;
    hitmiss_eval_next = hitmiss_eval;
    load_next = load;
    cache_inhibit_next = cache_inhibit;

    if (in_idle) begin
        if (ic_en && icqmem_cycstb_i) begin
            next_state = CFETCH;
            saved_addr_r_next = start_addr;
            hitmiss_eval_next = 1'b1;
            load_next = 1'b1;
            cache_inhibit_next = 1'b0;
        end else begin
            // Remain idle, clear flags
            hitmiss_eval_next = 1'b0;
            load_next = 1'b0;
            cache_inhibit_next = 1'b0;
        end
    end else if (in_cfetch) begin
        // Latch cache_inhibit if initial evaluation and icqmem_ci_i
        if (hitmiss_eval && icqmem_ci_i) begin
            cache_inhibit_next = 1'b1;
        end

        // High-priority termination conditions
        if (!ic_en ||
            (hitmiss_eval && !icqmem_cycstb_i) ||
            biudata_error ||
            (cache_inhibit && biudata_valid)) begin
            next_state = IDLE;
            hitmiss_eval_next = 1'b0;
            load_next = 1'b0;
            cache_inhibit_next = 1'b0;
        end else if (hitmiss_eval && tagcomp_miss && biudata_valid) begin
            // Miss and first data returned
            next_state = LREFILL3;
            // Increment saved_addr_r[3:2]
            saved_addr_r_next = saved_addr_r;
            saved_addr_r_next[3:2] = saved_addr_r[3:2] + 1;
            cnt_next = OR1200_ICLS - 2;
            hitmiss_eval_next = 1'b0;
            cache_inhibit_next = 1'b0;
        end else if (hitmiss_eval && !tagcomp_miss && !icqmem_ci_i) begin
            // Cache hit
            saved_addr_r_next = start_addr;
            cache_inhibit_next = 1'b0;
            // Stay in CFETCH, keep hitmiss_eval and load
        end else begin
            // Default in CFETCH: clear hitmiss_eval, keep load
            hitmiss_eval_next = 1'b0;
        end
    end else if (in_lrefill3) begin
        if (biudata_valid) begin
            if (cnt != 0) begin
                cnt_next = cnt - 1;
                saved_addr_r_next[3:2] = saved_addr_r[3:2] + 1;
            end else begin
                // Last word returned
                next_state = IDLE;
                hitmiss_eval_next = 1'b0;
                load_next = 1'b0;
                saved_addr_r_next = start_addr;
            end
        end
        // else stay in LREFILL3
    end
end

// Output assignments
assign biu_read = (hitmiss_eval & tagcomp_miss) | (!hitmiss_eval & load);
assign first_hit_ack = in_cfetch & hitmiss_eval & !tagcomp_miss & !cache_inhibit & !icqmem_ci_i;
assign first_miss_ack = in_cfetch & biudata_valid;
assign first_miss_err = in_cfetch & biudata_error;
assign burst = (in_cfetch & tagcomp_miss & !cache_inhibit) | in_lrefill3;

// Write enables: asserted only if BIU read active, data valid, and not cache-inhibit
wire we_en = biu_read & biudata_valid & !cache_inhibit;
always @(*) begin
    icram_we = {4{we_en}};
    tag_we = we_en;
end

// Assign saved_addr output from the register
always @(*) begin
    saved_addr = saved_addr_r;
end

endmodule

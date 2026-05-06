// Module: or1200_ic_fsm
// Instruction-cache fetch-control FSM

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
    output wire [31:0]  saved_addr,
    output reg  [3:0]   icram_we,
    output wire         biu_read,
    output wire         first_hit_ack,
    output wire         first_miss_ack,
    output wire         first_miss_err,
    output wire         burst,
    output wire         tag_we
);

    // State encoding
    localparam [1:0] IDLE     = 2'd0,
                     CFETCH   = 2'd1,
                     LREFILL3 = 2'd2,
                     IFETCH   = 2'd3; // defined but unused

    // Cache line size in 32-bit words
    localparam [2:0] OR1200_ICLS = 3'd4; // 4 words per line

    // Internal registers
    reg [31:0] saved_addr_r;
    reg [1:0]  state;
    reg [2:0]  cnt;
    reg        hitmiss_eval;
    reg        load;
    reg        cache_inhibit;

    // Output assignments
    assign saved_addr = saved_addr_r;

    // Combinational biu_read generation
    assign biu_read = (hitmiss_eval & tagcomp_miss) | (!hitmiss_eval & load);

    // Write enables for RAM and Tag
    assign tag_we  = biu_read & biudata_valid & !cache_inhibit;
    always @* begin
        if (biu_read & biudata_valid & !cache_inhibit)
            icram_we = 4'b1111;
        else
            icram_we = 4'b0000;
    end

    // First-word acknowledge signals
    assign first_hit_ack  = (state == CFETCH) & hitmiss_eval & !tagcomp_miss & !cache_inhibit & !icqmem_ci_i;
    assign first_miss_ack = (state == CFETCH) & biudata_valid;
    assign first_miss_err = (state == CFETCH) & biudata_error;

    // Burst indicator
    assign burst = ((state == CFETCH) & tagcomp_miss & !cache_inhibit) | (state == LREFILL3);

    // FSM sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            saved_addr_r   <= 32'd0;
            cnt            <= 3'd0;
            hitmiss_eval   <= 1'b0;
            load           <= 1'b0;
            cache_inhibit  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (ic_en & icqmem_cycstb_i) begin
                        state         <= CFETCH;
                        saved_addr_r  <= start_addr;
                        hitmiss_eval  <= 1'b1;
                        load          <= 1'b1;
                        cache_inhibit <= 1'b0;
                    end else begin
                        state         <= IDLE;
                        saved_addr_r  <= saved_addr_r; // hold value
                        hitmiss_eval  <= 1'b0;
                        load          <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                end

                CFETCH: begin
                    // Latch cache inhibit if requested
                    if (icqmem_ci_i)
                        cache_inhibit <= 1'b1;

                    if (hitmiss_eval)
                        saved_addr_r[31:13] <= start_addr[31:13];

                    // High-priority termination conditions
                    if (!ic_en | (!icqmem_cycstb_i & hitmiss_eval) | biudata_error |
                        (cache_inhibit & biudata_valid)) begin
                        state         <= IDLE;
                        hitmiss_eval  <= 1'b0;
                        load          <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                    // Miss with first data returned
                    else if (tagcomp_miss & biudata_valid) begin
                        state                   <= LREFILL3;
                        saved_addr_r[3:2]       <= saved_addr_r[3:2] + 2'd1;
                        hitmiss_eval            <= 1'b0;
                        cnt                     <= OR1200_ICLS - 2;
                        cache_inhibit           <= 1'b0;
                    end
                    // Normal hit (non-cache-inhibit, no miss)
                    else if (!tagcomp_miss & !icqmem_ci_i) begin
                        state         <= CFETCH;
                        saved_addr_r  <= start_addr;
                        cache_inhibit <= 1'b0;
                    end
                    // Request withdrawn while in CFETCH
                    else if (!icqmem_cycstb_i) begin
                        state         <= IDLE;
                        hitmiss_eval  <= 1'b0;
                        load          <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                    // Default: clear hitmiss_eval, remain in CFETCH
                    else begin
                        state         <= CFETCH;
                        hitmiss_eval  <= 1'b0;
                    end
                end

                LREFILL3: begin
                    if (biudata_valid) begin
                        if (cnt != 3'd0) begin
                            cnt                   <= cnt - 3'd1;
                            saved_addr_r[3:2]     <= saved_addr_r[3:2] + 2'd1;
                            state                 <= LREFILL3;
                        end else begin
                            // Refill complete
                            state                 <= IDLE;
                            hitmiss_eval          <= 1'b0;
                            load                  <= 1'b0;
                            saved_addr_r          <= start_addr;
                        end
                    end else begin
                        state <= LREFILL3;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

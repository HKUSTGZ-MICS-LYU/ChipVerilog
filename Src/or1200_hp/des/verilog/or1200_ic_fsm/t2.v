`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

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

    //--------------------------------------------------------------------------
    // FSM states
    //--------------------------------------------------------------------------
    localparam [1:0]
        IDLE     = 2'd0,
        CFETCH   = 2'd1,
        LREFILL3 = 2'd2,
        IFETCH   = 2'd3;   // defined but unused

    //--------------------------------------------------------------------------
    // Internal registers
    //--------------------------------------------------------------------------
    reg [31:0] saved_addr_r;
    reg [1:0]  state;
    reg [2:0]  cnt;
    reg        hitmiss_eval;
    reg        load;
    reg        cache_inhibit;

    assign saved_addr = saved_addr_r;

    //--------------------------------------------------------------------------
    // Combinational outputs
    //--------------------------------------------------------------------------

    // biu_read: miss during eval, or post-eval load still active
    assign biu_read = (hitmiss_eval & tagcomp_miss) | (~hitmiss_eval & load);

    // icram_we / tag_we: only on valid cacheable BIU read data
    assign icram_we = (biu_read & biudata_valid & ~cache_inhibit) ? 4'hf : 4'h0;
    assign tag_we   =  biu_read & biudata_valid & ~cache_inhibit;

    // first_hit_ack: hit during initial eval, not inhibited
    assign first_hit_ack = (state == CFETCH) & hitmiss_eval &
                           ~tagcomp_miss & ~cache_inhibit & ~icqmem_ci_i;

    // first_miss_ack / first_miss_err: any valid/error BIU response in CFETCH
    assign first_miss_ack = (state == CFETCH) & biudata_valid;
    assign first_miss_err = (state == CFETCH) & biudata_error;

    // burst: cacheable miss refill in CFETCH or all of LREFILL3
    assign burst = ((state == CFETCH) & tagcomp_miss & ~cache_inhibit) |
                   (state == LREFILL3);

    //--------------------------------------------------------------------------
    // Sequential FSM
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= IDLE;
            saved_addr_r  <= 32'h0;
            cnt           <= 3'h0;
            hitmiss_eval  <= 1'b0;
            load          <= 1'b0;
            cache_inhibit <= 1'b0;
        end else begin
            case (state)

                //--------------------------------------------------------------
                IDLE: begin
                    if (ic_en & icqmem_cycstb_i) begin
                        saved_addr_r  <= start_addr;
                        hitmiss_eval  <= 1'b1;
                        load          <= 1'b1;
                        cache_inhibit <= 1'b0;
                        state         <= CFETCH;
                    end else begin
                        hitmiss_eval  <= 1'b0;
                        load          <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                CFETCH: begin
                    // Latch cache-inhibit
                    if (icqmem_cycstb_i & icqmem_ci_i)
                        cache_inhibit <= 1'b1;

                    // Refresh upper tag bits during hit/miss eval
                    if (hitmiss_eval)
                        saved_addr_r[31:13] <= start_addr[31:13];

                    // High-priority return conditions
                    if (~ic_en ||
                        (~icqmem_cycstb_i & hitmiss_eval) ||
                        biudata_error ||
                        (cache_inhibit & biudata_valid)) begin
                        state         <= IDLE;
                        hitmiss_eval  <= 1'b0;
                        load          <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                    // Miss: first word returned → enter LREFILL3
                    else if (tagcomp_miss & biudata_valid) begin
                        state                <= LREFILL3;
                        hitmiss_eval         <= 1'b0;
                        cache_inhibit        <= 1'b0;
                        cnt                  <= `OR1200_ICLS - 3'd2;
                        saved_addr_r[3:2]    <= saved_addr_r[3:2] + 2'd1;
                    end
                    // Hit: stay in CFETCH, update saved_addr
                    else if (~tagcomp_miss & ~icqmem_ci_i) begin
                        saved_addr_r  <= start_addr;
                        cache_inhibit <= 1'b0;
                        // hitmiss_eval and load remain; no explicit IDLE transition
                    end
                    // Request withdrawn
                    else if (~icqmem_cycstb_i) begin
                        state         <= IDLE;
                        hitmiss_eval  <= 1'b0;
                        load          <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                    // Still waiting: end hitmiss_eval phase
                    else begin
                        hitmiss_eval <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                LREFILL3: begin
                    if (biudata_valid) begin
                        if (cnt != 3'h0) begin
                            cnt               <= cnt - 3'h1;
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                        end else begin
                            // Refill complete
                            state        <= IDLE;
                            hitmiss_eval <= 1'b0;
                            load         <= 1'b0;
                            saved_addr_r <= start_addr;
                        end
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
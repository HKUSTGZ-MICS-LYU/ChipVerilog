module or1200_ic_fsm(
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

localparam [1:0] IDLE     = 2'd0;
localparam [1:0] CFETCH   = 2'd1;
localparam [1:0] LREFILL3 = 2'd2;
localparam [1:0] IFETCH   = 2'd3;

localparam [2:0] OR1200_ICLS = 3'd4;

reg [31:0] saved_addr_r;
reg [1:0]  state;
reg [2:0]  cnt;
reg        hitmiss_eval;
reg        load;
reg        cache_inhibit;

assign saved_addr = saved_addr_r;

assign biu_read = (hitmiss_eval & tagcomp_miss) | (~hitmiss_eval & load);
assign tag_we = biu_read & biudata_valid & ~cache_inhibit;
assign icram_we = {4{tag_we}};

assign first_hit_ack = (state == CFETCH) & hitmiss_eval & ~tagcomp_miss & ~cache_inhibit & ~icqmem_ci_i;
assign first_miss_ack = (state == CFETCH) & biudata_valid;
assign first_miss_err = (state == CFETCH) & biudata_error;
assign burst = ((state == CFETCH) & tagcomp_miss & ~cache_inhibit) | (state == LREFILL3);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state          <= IDLE;
        saved_addr_r   <= 32'b0;
        cnt            <= 3'b0;
        hitmiss_eval   <= 1'b0;
        load           <= 1'b0;
        cache_inhibit  <= 1'b0;
    end
    else begin
        case (state)
            IDLE: begin
                if (ic_en && icqmem_cycstb_i) begin
                    state         <= CFETCH;
                    saved_addr_r  <= start_addr;
                    hitmiss_eval  <= 1'b1;
                    load          <= 1'b1;
                    cache_inhibit <= 1'b0;
                end
                else begin
                    state         <= IDLE;
                    hitmiss_eval  <= 1'b0;
                    load          <= 1'b0;
                    cache_inhibit <= 1'b0;
                end
            end

            CFETCH: begin
                if (!ic_en || (hitmiss_eval && !icqmem_cycstb_i) || biudata_error || (cache_inhibit && biudata_valid)) begin
                    state         <= IDLE;
                    hitmiss_eval  <= 1'b0;
                    load          <= 1'b0;
                    cache_inhibit <= 1'b0;
                end
                else if (tagcomp_miss && biudata_valid) begin
                    state              <= LREFILL3;
                    saved_addr_r[3:2]  <= saved_addr_r[3:2] + 2'd1;
                    hitmiss_eval       <= 1'b0;
                    cnt                <= OR1200_ICLS - 3'd2;
                    cache_inhibit      <= 1'b0;
                end
                else if (!tagcomp_miss && !icqmem_ci_i) begin
                    saved_addr_r   <= start_addr;
                    cache_inhibit  <= 1'b0;
                end
                else if (!icqmem_cycstb_i) begin
                    state         <= IDLE;
                    hitmiss_eval  <= 1'b0;
                    load          <= 1'b0;
                    cache_inhibit <= 1'b0;
                end
                else begin
                    if (icqmem_cycstb_i && icqmem_ci_i)
                        cache_inhibit <= 1'b1;
                    if (hitmiss_eval)
                        saved_addr_r[31:13] <= start_addr[31:13];
                    hitmiss_eval <= 1'b0;
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 3'b0) begin
                        cnt               <= cnt - 3'd1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end
                    else begin
                        state         <= IDLE;
                        hitmiss_eval  <= 1'b0;
                        load          <= 1'b0;
                        saved_addr_r  <= start_addr;
                    end
                end
            end

            IFETCH: begin
                state <= IDLE;
            end

            default: begin
                state         <= IDLE;
                hitmiss_eval  <= 1'b0;
                load          <= 1'b0;
                cache_inhibit <= 1'b0;
            end
        endcase
    end
end

endmodule

`ifndef OR1200_DCLS
`define OR1200_DCLS 4
`endif

module or1200_dc_fsm(
    input         clk,
    input         rst,
    input         dc_en,
    input         dcqmem_cycstb_i,
    input         dcqmem_ci_i,
    input         dcqmem_we_i,
    input  [3:0]  dcqmem_sel_i,
    input         tagcomp_miss,
    input         biudata_valid,
    input         biudata_error,
    input  [31:0] start_addr,
    output [31:0] saved_addr,
    output [3:0]  dcram_we,
    output        biu_read,
    output        biu_write,
    output        first_hit_ack,
    output        first_miss_ack,
    output        first_miss_err,
    output        burst,
    output        tag_we,
    output [31:0] dc_addr
);

localparam [2:0]
    IDLE     = 3'd0,
    CLOAD    = 3'd1,
    CSTORE   = 3'd2,
    LREFILL3 = 3'd3;

`ifdef OR1200_DC_STORE_REFILL
localparam [2:0] SREFILL4 = 3'd4;
`endif

reg [2:0]  state;
reg [31:0] saved_addr_r;
reg [31:0] cnt;
reg        hitmiss_eval;
reg        store;
reg        load;
reg        cache_inhibit;

wire first_store_hit_ack;
wire post_eval_transfer_active;
wire load_hit_ack;

assign saved_addr = saved_addr_r;

assign first_miss_ack = ((state == CLOAD) || (state == CSTORE)) && biudata_valid;
assign first_miss_err = ((state == CLOAD) || (state == CSTORE)) && biudata_error;

assign first_store_hit_ack = (state == CSTORE) && biudata_valid && !tagcomp_miss && !cache_inhibit;
assign load_hit_ack = (state == CLOAD) && hitmiss_eval && dcqmem_cycstb_i && !cache_inhibit && !tagcomp_miss;
assign first_hit_ack = load_hit_ack || first_store_hit_ack;

assign biu_write = store;
assign biu_read = (((state == CLOAD) || (state == CSTORE)) && hitmiss_eval && tagcomp_miss) ||
                  (load && !hitmiss_eval);

assign dcram_we = (load && biudata_valid && !cache_inhibit) ? 4'b1111 :
                  (first_store_hit_ack ? dcqmem_sel_i : 4'b0000);

assign tag_we = biu_read && biudata_valid && !cache_inhibit;

assign burst = ((state == CLOAD) && !cache_inhibit && tagcomp_miss) ||
               (state == LREFILL3)
`ifdef OR1200_DC_STORE_REFILL
               || (state == SREFILL4)
`endif
               ;

assign post_eval_transfer_active = !hitmiss_eval && (biu_read || biu_write);
assign dc_addr = post_eval_transfer_active ? saved_addr_r : start_addr;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state          <= IDLE;
        saved_addr_r   <= 32'b0;
        cnt            <= 32'b0;
        hitmiss_eval   <= 1'b0;
        store          <= 1'b0;
        load           <= 1'b0;
        cache_inhibit  <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                hitmiss_eval  <= 1'b0;
                store         <= 1'b0;
                load          <= 1'b0;
                cache_inhibit <= 1'b0;
                cnt           <= 32'b0;
                if (dc_en && dcqmem_cycstb_i) begin
                    saved_addr_r  <= start_addr;
                    hitmiss_eval  <= 1'b1;
                    cache_inhibit <= 1'b0;
                    if (dcqmem_we_i) begin
                        store <= 1'b1;
                        load  <= 1'b0;
                        state <= CSTORE;
                    end else begin
                        load  <= 1'b1;
                        store <= 1'b0;
                        state <= CLOAD;
                    end
                end
            end

            CLOAD: begin
                if (dcqmem_cycstb_i && dcqmem_ci_i)
                    cache_inhibit <= 1'b1;

                if ((!dcqmem_cycstb_i && hitmiss_eval) || biudata_error || (cache_inhibit && biudata_valid)) begin
                    state         <= IDLE;
                    load          <= 1'b0;
                    store         <= 1'b0;
                    hitmiss_eval  <= 1'b0;
                    cache_inhibit <= 1'b0;
                    cnt           <= 32'b0;
                end else if (!cache_inhibit && !tagcomp_miss) begin
                    state         <= IDLE;
                    load          <= 1'b0;
                    hitmiss_eval  <= 1'b0;
                    cache_inhibit <= 1'b0;
                    cnt           <= 32'b0;
                end else if (!cache_inhibit && tagcomp_miss && biudata_valid) begin
                    hitmiss_eval       <= 1'b0;
                    state              <= LREFILL3;
                    saved_addr_r[3:2]  <= saved_addr_r[3:2] + 2'd1;
                    cnt                <= (`OR1200_DCLS - 2);
                end
            end

            CSTORE: begin
                if (dcqmem_cycstb_i && dcqmem_ci_i)
                    cache_inhibit <= 1'b1;

                if ((!dcqmem_cycstb_i && hitmiss_eval) || biudata_error || (cache_inhibit && biudata_valid)) begin
                    state         <= IDLE;
                    store         <= 1'b0;
                    load          <= 1'b0;
                    hitmiss_eval  <= 1'b0;
                    cache_inhibit <= 1'b0;
                    cnt           <= 32'b0;
                end else if (biudata_valid && !tagcomp_miss) begin
                    state         <= IDLE;
                    store         <= 1'b0;
                    hitmiss_eval  <= 1'b0;
                    cache_inhibit <= 1'b0;
                    cnt           <= 32'b0;
                end else if (biudata_valid && tagcomp_miss) begin
`ifdef OR1200_DC_STORE_REFILL
                    state         <= SREFILL4;
                    store         <= 1'b0;
                    load          <= 1'b1;
                    hitmiss_eval  <= 1'b0;
                    cnt           <= (`OR1200_DCLS - 1);
`else
                    state         <= IDLE;
                    store         <= 1'b0;
                    hitmiss_eval  <= 1'b0;
                    cache_inhibit <= 1'b0;
                    cnt           <= 32'b0;
`endif
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 0) begin
                        cnt               <= cnt - 1'b1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end else begin
                        state         <= IDLE;
                        load          <= 1'b0;
                        hitmiss_eval  <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                end
            end

`ifdef OR1200_DC_STORE_REFILL
            SREFILL4: begin
                if (biudata_valid) begin
                    if (cnt != 0) begin
                        cnt               <= cnt - 1'b1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end else begin
                        state         <= IDLE;
                        load          <= 1'b0;
                        hitmiss_eval  <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end
                end
            end
`endif

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule

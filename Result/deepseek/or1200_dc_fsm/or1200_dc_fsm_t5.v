module or1200_dc_fsm #(
    parameter OR1200_DCLS = 4,
    parameter OR1200_DC_STORE_REFILL = 1
) (
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
    output reg biu_read,
    output reg biu_write,
    output reg first_hit_ack,
    output reg first_miss_ack,
    output reg first_miss_err,
    output reg burst,
    output reg tag_we,
    output reg [31:0] dc_addr
);

reg [2:0] state;
localparam IDLE = 0, CLOAD = 1, CSTORE = 2, LREFILL3 = 3, SREFILL4 = 4;

reg [31:0] saved_addr_r;
reg [1:0] cnt;
reg hitmiss_eval;
reg store;
reg load;
reg cache_inhibit;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        saved_addr_r <= 32'd0;
        cnt <= 2'd0;
        hitmiss_eval <= 1'b0;
        store <= 1'b0;
        load <= 1'b0;
        cache_inhibit <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (dc_en && dcqmem_cycstb_i) begin
                    saved_addr_r <= start_addr;
                    hitmiss_eval <= 1'b1;
                    cache_inhibit <= 1'b0;
                    if (!dcqmem_we_i) begin
                        state <= CLOAD;
                        load <= 1'b1;
                        store <= 1'b0;
                    end else begin
                        state <= CSTORE;
                        store <= 1'b1;
                        load <= 1'b0;
                    end
                end
            end

            CLOAD: begin
                if (!dcqmem_cycstb_i) begin
                    state <= IDLE;
                    hitmiss_eval <= 1'b0;
                    load <= 1'b0;
                    store <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else if (biudata_error) begin
                    state <= IDLE;
                    hitmiss_eval <= 1'b0;
                    load <= 1'b0;
                    store <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else begin
                    if (!cache_inhibit && dcqmem_ci_i && dcqmem_cycstb_i)
                        cache_inhibit <= 1'b1;

                    if (hitmiss_eval) begin
                        if (!tagcomp_miss && !cache_inhibit) begin
                            state <= IDLE;
                            hitmiss_eval <= 1'b0;
                            load <= 1'b0;
                        end else if (tagcomp_miss && !cache_inhibit) begin
                            if (biudata_valid) begin
                                state <= LREFILL3;
                                cnt <= OR1200_DCLS - 2'd2;
                                saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                                hitmiss_eval <= 1'b0;
                            end
                        end else if (cache_inhibit) begin
                            if (biudata_valid) begin
                                state <= IDLE;
                                hitmiss_eval <= 1'b0;
                                load <= 1'b0;
                                cache_inhibit <= 1'b0;
                            end
                        end
                    end
                end
            end

            CSTORE: begin
                if (!dcqmem_cycstb_i) begin
                    state <= IDLE;
                    hitmiss_eval <= 1'b0;
                    store <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else if (biudata_error) begin
                    state <= IDLE;
                    hitmiss_eval <= 1'b0;
                    store <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                end else begin
                    if (!cache_inhibit && dcqmem_ci_i && dcqmem_cycstb_i)
                        cache_inhibit <= 1'b1;

                    if (hitmiss_eval) begin
                        if (biudata_valid) begin
                            if (cache_inhibit) begin
                                state <= IDLE;
                                hitmiss_eval <= 1'b0;
                                store <= 1'b0;
                                cache_inhibit <= 1'b0;
                            end else if (!tagcomp_miss) begin
                                state <= IDLE;
                                hitmiss_eval <= 1'b0;
                                store <= 1'b0;
                            end else begin
                                if (OR1200_DC_STORE_REFILL) begin
                                    state <= SREFILL4;
                                    cnt <= OR1200_DCLS - 2'd1;
                                    load <= 1'b1;
                                    store <= 1'b0;
                                    hitmiss_eval <= 1'b0;
                                end else begin
                                    state <= IDLE;
                                    hitmiss_eval <= 1'b0;
                                    store <= 1'b0;
                                end
                            end
                        end
                    end
                end
            end

            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 2'd0) begin
                        cnt <= cnt - 2'd1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end else begin
                        state <= IDLE;
                        load <= 1'b0;
                        hitmiss_eval <= 1'b0;
                    end
                end
            end

            SREFILL4: begin
                if (biudata_valid) begin
                    if (cnt != 2'd0) begin
                        cnt <= cnt - 2'd1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end else begin
                        state <= IDLE;
                        load <= 1'b0;
                        hitmiss_eval <= 1'b0;
                    end
                end
            end
        endcase
    end
end

always_comb begin
    biu_read = 1'b0;
    biu_write = 1'b0;
    first_hit_ack = 1'b0;
    first_miss_ack = 1'b0;
    first_miss_err = 1'b0;
    burst = 1'b0;
    tag_we = 1'b0;
    dcram_we = 4'b0000;
    dc_addr = saved_addr_r;
    saved_addr = saved_addr_r;

    case (state)
        IDLE: begin
        end

        CLOAD: begin
            if (hitmiss_eval)
                dc_addr = start_addr;
            else
                dc_addr = saved_addr_r;

            if (hitmiss_eval && ((tagcomp_miss && !cache_inhibit) || cache_inhibit))
                biu_read = 1'b1;

            if (hitmiss_eval && !tagcomp_miss && !cache_inhibit)
                first_hit_ack = 1'b1;

            if (biudata_valid)
                first_miss_ack = 1'b1;

            if (biudata_error)
                first_miss_err = 1'b1;

            if (biu_read && !cache_inhibit)
                burst = 1'b1;

            if (biu_read && biudata_valid && !cache_inhibit)
                tag_we = 1'b1;

            if (load && biudata_valid && !cache_inhibit)
                dcram_we = 4'b1111;
        end

        CSTORE: begin
            if (hitmiss_eval)
                dc_addr = start_addr;
            else
                dc_addr = saved_addr_r;

            biu_write = store;

            if (store && biudata_valid && !cache_inhibit && !tagcomp_miss) begin
                dcram_we = dcqmem_sel_i;
                first_hit_ack = 1'b1;
            end

            if (biudata_valid)
                first_miss_ack = 1'b1;

            if (biudata_error)
                first_miss_err = 1'b1;
        end

        LREFILL3: begin
            dc_addr = saved_addr_r;
            biu_read = 1'b1;
            burst = 1'b1;

            if (biudata_valid && !cache_inhibit) begin
                dcram_we = 4'b1111;
                tag_we = 1'b1;
            end
        end

        SREFILL4: begin
            if (OR1200_DC_STORE_REFILL) begin
                dc_addr = saved_addr_r;
                biu_read = 1'b1;
                burst = 1'b1;

                if (biudata_valid && !cache_inhibit) begin
                    dcram_we = 4'b1111;
                    tag_we = 1'b1;
                end
            end
        end
    endcase
end

endmodule

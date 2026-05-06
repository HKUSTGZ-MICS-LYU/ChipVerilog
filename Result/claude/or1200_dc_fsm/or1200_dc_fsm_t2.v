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

parameter OR1200_DCLS = 4;

parameter IDLE = 3'b000;
parameter CLOAD = 3'b001;
parameter LREFILL3 = 3'b010;
parameter CSTORE = 3'b011;
parameter SREFILL4 = 3'b100;

reg [31:0] saved_addr_r;
reg [2:0] state;
reg [2:0] cnt;
reg hitmiss_eval;
reg store;
reg load;
reg cache_inhibit;

wire first_store_hit_ack;

assign saved_addr = saved_addr_r;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        state <= IDLE;
        saved_addr_r <= 32'b0;
        cnt <= 3'b0;
        hitmiss_eval <= 1'b0;
        store <= 1'b0;
        load <= 1'b0;
        cache_inhibit <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                hitmiss_eval <= 1'b0;
                load <= 1'b0;
                store <= 1'b0;
                
                if (dc_en && dcqmem_cycstb_i) begin
                    saved_addr_r <= start_addr;
                    hitmiss_eval <= 1'b1;
                    cache_inhibit <= dcqmem_ci_i;
                    
                    if (dcqmem_we_i) begin
                        state <= CSTORE;
                        store <= 1'b1;
                    end else begin
                        state <= CLOAD;
                        load <= 1'b1;
                    end
                end
            end
            
            CLOAD: begin
                if (!dcqmem_cycstb_i || biudata_error) begin
                    state <= IDLE;
                    load <= 1'b0;
                    hitmiss_eval <= 1'b0;
                end else if (cache_inhibit && biudata_valid) begin
                    state <= IDLE;
                    load <= 1'b0;
                    hitmiss_eval <= 1'b0;
                end else if (hitmiss_eval && tagcomp_miss && biudata_valid) begin
                    state <= LREFILL3;
                    cnt <= OR1200_DCLS - 2;
                    saved_addr_r[3:2] <= saved_addr_r[3:2] + 1;
                    hitmiss_eval <= 1'b0;
                end else if (hitmiss_eval && !tagcomp_miss && !cache_inhibit) begin
                    state <= IDLE;
                    load <= 1'b0;
                    hitmiss_eval <= 1'b0;
                end else begin
                    hitmiss_eval <= 1'b0;
                end
            end
            
            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 3'b0) begin
                        cnt <= cnt - 1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 1;
                    end else begin
                        state <= IDLE;
                        load <= 1'b0;
                        cnt <= 3'b0;
                    end
                end
            end
            
            CSTORE: begin
                if (!dcqmem_cycstb_i || biudata_error) begin
                    state <= IDLE;
                    store <= 1'b0;
                    hitmiss_eval <= 1'b0;
                end else if (cache_inhibit && biudata_valid) begin
                    state <= IDLE;
                    store <= 1'b0;
                    hitmiss_eval <= 1'b0;
                end else if (biudata_valid && hitmiss_eval && !tagcomp_miss) begin
                    state <= IDLE;
                    store <= 1'b0;
                    hitmiss_eval <= 1'b0;
                end else if (biudata_valid && tagcomp_miss) begin
                    state <= SREFILL4;
                    cnt <= OR1200_DCLS - 2;
                    saved_addr_r[3:2] <= saved_addr_r[3:2] + 1;
                    hitmiss_eval <= 1'b0;
                end else begin
                    hitmiss_eval <= 1'b0;
                end
            end
            
            SREFILL4: begin
                if (biudata_valid) begin
                    if (cnt != 3'b0) begin
                        cnt <= cnt - 1;
                        saved_addr_r[3:2] <= saved_addr_r[3:2] + 1;
                    end else begin
                        state <= IDLE;
                        load <= 1'b0;
                        store <= 1'b0;
                        cnt <= 3'b0;
                    end
                end
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

assign biu_read = (state == CLOAD && hitmiss_eval && tagcomp_miss) ||
                  (state == LREFILL3) ||
                  (state == SREFILL4);

assign biu_write = (state == CSTORE);

assign first_hit_ack = (state == CLOAD && hitmiss_eval && !tagcomp_miss && !cache_inhibit);

assign first_miss_ack = (state == CLOAD && hitmiss_eval && tagcomp_miss && biudata_valid && !biudata_error) ||
                        (state == CSTORE && hitmiss_eval && tagcomp_miss && biudata_valid && !biudata_error);

assign first_miss_err = (state == CLOAD && hitmiss_eval && biudata_error) ||
                        (state == CSTORE && hitmiss_eval && biudata_error);

assign burst = (state == CLOAD && hitmiss_eval && tagcomp_miss && biudata_valid) ||
               (state == LREFILL3) ||
               (state == SREFILL4);

assign first_store_hit_ack = (state == CSTORE && !tagcomp_miss && biudata_valid && !cache_inhibit);

assign tag_we = (state == LREFILL3 && biudata_valid && !cache_inhibit) ||
                (state == SREFILL4 && biudata_valid && !cache_inhibit && cnt == 3'b0);

assign dcram_we = ((state == LREFILL3 && biudata_valid && !cache_inhibit) ? 4'b1111 : 4'b0) |
                  ((state == CSTORE && !tagcomp_miss && biudata_valid && !cache_inhibit) ? dcqmem_sel_i : 4'b0) |
                  ((state == SREFILL4 && biudata_valid && !cache_inhibit) ? 4'b1111 : 4'b0);

assign dc_addr = (hitmiss_eval) ? start_addr : saved_addr_r;

endmodule

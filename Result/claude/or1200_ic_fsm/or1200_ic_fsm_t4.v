module or1200_ic_fsm(
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
    output reg biu_read,
    output reg first_hit_ack,
    output reg first_miss_ack,
    output reg first_miss_err,
    output reg burst,
    output reg tag_we
);

    localparam IDLE = 2'b00;
    localparam CFETCH = 2'b01;
    localparam LREFILL3 = 2'b10;
    
    localparam ICLS = 4;
    
    reg [31:0] saved_addr_r;
    reg [2:0] cnt;
    reg hitmiss_eval;
    reg load;
    reg cache_inhibit;
    reg [1:0] state;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            saved_addr_r <= 32'h0;
            cnt <= 3'b0;
            hitmiss_eval <= 1'b0;
            load <= 1'b0;
            cache_inhibit <= 1'b0;
            icram_we <= 4'b0;
            biu_read <= 1'b0;
            first_hit_ack <= 1'b0;
            first_miss_ack <= 1'b0;
            first_miss_err <= 1'b0;
            burst <= 1'b0;
            tag_we <= 1'b0;
        end else begin
            first_hit_ack <= 1'b0;
            first_miss_ack <= 1'b0;
            first_miss_err <= 1'b0;
            icram_we <= 4'b0;
            tag_we <= 1'b0;
            
            case (state)
                IDLE: begin
                    biu_read <= 1'b0;
                    burst <= 1'b0;
                    hitmiss_eval <= 1'b0;
                    load <= 1'b0;
                    cache_inhibit <= 1'b0;
                    
                    if (ic_en && icqmem_cycstb_i) begin
                        saved_addr_r <= start_addr;
                        hitmiss_eval <= 1'b1;
                        load <= 1'b1;
                        cache_inhibit <= icqmem_ci_i;
                        state <= CFETCH;
                    end
                end
                
                CFETCH: begin
                    if (!ic_en) begin
                        state <= IDLE;
                        hitmiss_eval <= 1'b0;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end else if (!icqmem_cycstb_i && hitmiss_eval) begin
                        state <= IDLE;
                        hitmiss_eval <= 1'b0;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end else if (biudata_error && hitmiss_eval) begin
                        state <= IDLE;
                        hitmiss_eval <= 1'b0;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                        first_miss_err <= 1'b1;
                    end else if (cache_inhibit && biudata_valid) begin
                        state <= IDLE;
                        hitmiss_eval <= 1'b0;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end else if (!tagcomp_miss && !cache_inhibit) begin
                        first_hit_ack <= 1'b1;
                        state <= IDLE;
                        hitmiss_eval <= 1'b0;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                    end else if (tagcomp_miss && biudata_valid && hitmiss_eval) begin
                        first_miss_ack <= 1'b1;
                        saved_addr_r[1:0] <= saved_addr_r[1:0] + 2'b01;
                        cnt <= (ICLS - 2);
                        hitmiss_eval <= 1'b0;
                        state <= LREFILL3;
                        icram_we <= 4'hf;
                        tag_we <= 1'b1;
                        burst <= 1'b1;
                    end else begin
                        if ((tagcomp_miss && !cache_inhibit) || (tagcomp_miss && cache_inhibit && !biudata_valid)) begin
                            biu_read <= 1'b1;
                            if (tagcomp_miss && !cache_inhibit) begin
                                burst <= 1'b1;
                            end
                        end else begin
                            biu_read <= 1'b0;
                        end
                    end
                end
                
                LREFILL3: begin
                    if (biudata_valid) begin
                        if (cnt != 3'b0) begin
                            cnt <= cnt - 3'b1;
                            saved_addr_r[1:0] <= saved_addr_r[1:0] + 2'b01;
                            icram_we <= 4'hf;
                            tag_we <= 1'b1;
                        end else begin
                            state <= IDLE;
                            hitmiss_eval <= 1'b0;
                            load <= 1'b0;
                            burst <= 1'b0;
                            saved_addr_r <= start_addr;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    always @(*) begin
        saved_addr = saved_addr_r;
    end

endmodule

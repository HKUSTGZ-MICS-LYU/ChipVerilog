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

    reg [31:0] saved_addr_r;
    reg [2:0] state;
    reg [2:0] cnt;
    reg hitmiss_eval;
    reg store_op;
    reg load_op;
    reg cache_inhibit_r;

    localparam IDLE = 3'b000;
    localparam CLOAD = 3'b001;
    localparam CSTORE = 3'b010;
    localparam LREFILL3 = 3'b011;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            saved_addr_r <= 32'b0;
            cnt <= 3'b0;
            hitmiss_eval <= 1'b0;
            store_op <= 1'b0;
            load_op <= 1'b0;
            cache_inhibit_r <= 1'b0;
            biu_read <= 1'b0;
            biu_write <= 1'b0;
            first_hit_ack <= 1'b0;
            first_miss_ack <= 1'b0;
            first_miss_err <= 1'b0;
            burst <= 1'b0;
            tag_we <= 1'b0;
            dcram_we <= 4'b0;
            dc_addr <= 32'b0;
            saved_addr <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (dc_en & dcqmem_cycstb_i) begin
                        saved_addr_r <= start_addr;
                        hitmiss_eval <= 1'b1;
                        store_op <= dcqmem_we_i;
                        load_op <= ~dcqmem_we_i;
                        cache_inhibit_r <= dcqmem_ci_i;
                        
                        if (dcqmem_we_i) begin
                            state <= CSTORE;
                            biu_write <= 1'b1;
                        end else begin
                            state <= CLOAD;
                            biu_read <= 1'b1;
                        end
                    end
                    biu_read <= 1'b0;
                    biu_write <= 1'b0;
                    first_hit_ack <= 1'b0;
                    first_miss_ack <= 1'b0;
                    first_miss_err <= 1'b0;
                    burst <= 1'b0;
                    tag_we <= 1'b0;
                end
                
                CLOAD: begin
                    if (biudata_valid) begin
                        if (tagcomp_miss | cache_inhibit_r) begin
                            first_miss_ack <= 1'b1;
                            state <= LREFILL3;
                            cnt <= 3'd2;
                            burst <= 1'b1;
                            dcram_we <= 4'b1111;
                        end else begin
                            first_hit_ack <= 1'b1;
                            state <= IDLE;
                        end
                    end
                    if (biudata_error) begin
                        first_miss_err <= 1'b1;
                        state <= IDLE;
                        biu_read <= 1'b0;
                    end
                end
                
                CSTORE: begin
                    if (biudata_valid) begin
                        if (tagcomp_miss) begin
                            state <= LREFILL3;
                            biu_read <= 1'b1;
                            biu_write <= 1'b0;
                            cnt <= 3'd2;
                        end else begin
                            first_hit_ack <= 1'b1;
                            state <= IDLE;
                            biu_write <= 1'b0;
                            dcram_we <= dcqmem_sel_i;
                        end
                    end
                    if (biudata_error) begin
                        first_miss_err <= 1'b1;
                        state <= IDLE;
                        biu_write <= 1'b0;
                    end
                end
                
                LREFILL3: begin
                    if (biudata_valid) begin
                        dcram_we <= 4'b1111;
                        tag_we <= 1'b1;
                        
                        if (cnt == 3'b0) begin
                            state <= IDLE;
                            biu_read <= 1'b0;
                            burst <= 1'b0;
                            tag_we <= 1'b0;
                            dcram_we <= 4'b0;
                        end else begin
                            cnt <= cnt - 1;
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 1;
                        end
                    end
                end
            endcase
            
            saved_addr <= saved_addr_r;
            dc_addr <= hitmiss_eval ? start_addr : saved_addr_r;
        end
    end

endmodule

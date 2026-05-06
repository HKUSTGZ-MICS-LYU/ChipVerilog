module or1200_ic_fsm(
    input clk,
    input rst,
    input ic_en,
    input icqmem_cycstb_i,
    input biudata_valid,
    input biudata_error,
    input [31:0] start_addr,
    input tagcomp_miss,
    output reg [31:0] saved_addr,
    output reg biu_read,
    output reg first_hit_ack,
    output reg first_miss_ack,
    output reg first_miss_err,
    output reg burst,
    output reg tag_we,
    output reg [3:0] icram_we,
    output reg [31:0] ic_addr
);

    reg [31:0] saved_addr_r;
    reg [2:0] state;
    reg [2:0] cnt;

    localparam IDLE = 3'b000;
    localparam CLOAD = 3'b001;
    localparam REFILL = 3'b010;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            saved_addr_r <= 32'b0;
            cnt <= 3'b0;
            biu_read <= 1'b0;
            first_hit_ack <= 1'b0;
            first_miss_ack <= 1'b0;
            first_miss_err <= 1'b0;
            burst <= 1'b0;
            tag_we <= 1'b0;
            icram_we <= 4'b0;
            ic_addr <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (ic_en & icqmem_cycstb_i) begin
                        saved_addr_r <= start_addr;
                        state <= CLOAD;
                        biu_read <= 1'b1;
                    end
                end
                
                CLOAD: begin
                    if (tagcomp_miss & biudata_valid) begin
                        first_miss_ack <= 1'b1;
                        state <= REFILL;
                        cnt <= 3'd2;
                        burst <= 1'b1;
                        icram_we <= 4'b1111;
                    end
                    else if (!tagcomp_miss & biudata_valid) begin
                        first_hit_ack <= 1'b1;
                        state <= IDLE;
                        biu_read <= 1'b0;
                    end
                    
                    if (biudata_error) begin
                        first_miss_err <= 1'b1;
                        state <= IDLE;
                        biu_read <= 1'b0;
                    end
                end
                
                REFILL: begin
                    if (biudata_valid) begin
                        icram_we <= 4'b1111;
                        tag_we <= 1'b1;
                        
                        if (cnt == 3'b0) begin
                            state <= IDLE;
                            biu_read <= 1'b0;
                            burst <= 1'b0;
                            tag_we <= 1'b0;
                            icram_we <= 4'b0;
                        end else begin
                            cnt <= cnt - 1;
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 1;
                        end
                    end
                end
            endcase
            
            saved_addr <= saved_addr_r;
            ic_addr <= start_addr;
        end
    end

endmodule

// Generated from or1200_ic_fsm/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_ic_fsm(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f to top level IC
    input ic_en,
    input icqmem_cycstb_i,
    input icqmem_ci_i,
    input tagcomp_miss,
    input biudata_valid,
    input biudata_error,
    input [31:0] start_addr,
    output [31:0] saved_addr,
    output [3:0] icram_we,
    output biu_read,
    output first_hit_ack,
    output first_miss_ack,
    output first_miss_err,
    output burst,
    output tag_we
);

reg [31:0] saved_addr_r;
reg [3:0] icram_we_r;
reg biu_read_r;
reg first_hit_ack_r;
reg first_miss_ack_r;
reg first_miss_err_r;
reg burst_r;
reg tag_we_r;
assign saved_addr = saved_addr_r;
assign icram_we = icram_we_r;
assign biu_read = biu_read_r;
assign first_hit_ack = first_hit_ack_r;
assign first_miss_ack = first_miss_ack_r;
assign first_miss_err = first_miss_err_r;
assign burst = burst_r;
assign tag_we = tag_we_r;

localparam IDLE = 2'd0;
localparam REFILL = 2'd1;
reg [1:0] state;
reg [31:0] saved_addr_reg;
reg [2:0] cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        saved_addr_reg <= 32'd0;
        cnt <= 3'd0;
    end else begin
        case (state)
            IDLE: if (ic_en && icqmem_cycstb_i) begin
                saved_addr_reg <= start_addr;
                if (tagcomp_miss)
                    state <= REFILL;
            end
            REFILL: if (biudata_valid) begin
                if (cnt == 3'd3)
                    state <= IDLE;
                else
                    cnt <= cnt + 1'b1;
            end
        endcase
    end
end

always @* begin
    saved_addr_r = saved_addr_reg;
    biu_read_r = (state == REFILL) || (state == IDLE && icqmem_cycstb_i);
    first_hit_ack_r = (state == IDLE) && !tagcomp_miss && icqmem_cycstb_i;
    first_miss_ack_r = (state == REFILL) && biudata_valid;
    first_miss_err_r = biudata_error;
    burst_r = (state == REFILL);
    tag_we_r = (state == REFILL) && biudata_valid;
    icram_we_r = ((state == REFILL) && biudata_valid) ? 4'hf : 4'h0;
end

endmodule

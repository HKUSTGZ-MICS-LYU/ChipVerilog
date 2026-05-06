`include "or1200_defines.v"


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
    output [31:0] saved_addr,
    output [3:0] icram_we,
    output biu_read,
    output first_hit_ack,
    output first_miss_ack,
    output first_miss_err,
    output burst,
    output tag_we
);
localparam IDLE=2'd0, CFETCH=2'd1, LREFILL3=2'd2;
reg [1:0] state;
reg [31:0] saved_addr_r;
reg [2:0] cnt;
reg hitmiss_eval, load, cache_inhibit;
assign saved_addr = saved_addr_r;
assign biu_read = (state==CFETCH && tagcomp_miss) || (state==LREFILL3 && load);
assign burst = ((state==CFETCH) && tagcomp_miss && !cache_inhibit) || (state==LREFILL3);
assign first_hit_ack = (state==CFETCH) && hitmiss_eval && !tagcomp_miss && !cache_inhibit;
assign first_miss_ack = (state==CFETCH) && tagcomp_miss && biudata_valid;
assign first_miss_err = (state==CFETCH) && tagcomp_miss && biudata_error;
assign icram_we = {4{biu_read & biudata_valid & !cache_inhibit}};
assign tag_we = biu_read & biudata_valid & !cache_inhibit;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE; saved_addr_r <= 32'b0; cnt <= 3'b0; hitmiss_eval <= 1'b0; load <= 1'b0; cache_inhibit <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                hitmiss_eval <= 1'b0; load <= 1'b0; cache_inhibit <= 1'b0; cnt <= 3'b0;
                if (ic_en && icqmem_cycstb_i) begin
                    state <= CFETCH; saved_addr_r <= start_addr; hitmiss_eval <= 1'b1; load <= 1'b1;
                end
            end
            CFETCH: begin
                if (icqmem_ci_i) cache_inhibit <= 1'b1;
                if (hitmiss_eval) saved_addr_r[31:4] <= start_addr[31:4];
                if (!ic_en || (hitmiss_eval && !icqmem_cycstb_i) || biudata_error || (cache_inhibit && biudata_valid)) begin
                    state <= IDLE; hitmiss_eval <= 1'b0; load <= 1'b0; cache_inhibit <= 1'b0;
                end else if (tagcomp_miss && biudata_valid) begin
                    state <= LREFILL3; saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1; cnt <= `OR1200_ICLS - 2; hitmiss_eval <= 1'b0; load <= 1'b1;
                end else if (!tagcomp_miss && !cache_inhibit) begin
                    state <= IDLE; hitmiss_eval <= 1'b0; load <= 1'b0;
                end
            end
            LREFILL3: begin
                if (biudata_valid) begin
                    if (cnt != 0) begin
                        cnt <= cnt - 3'd1; saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                    end else begin
                        state <= IDLE; hitmiss_eval <= 1'b0; load <= 1'b0; cache_inhibit <= 1'b0; saved_addr_r <= start_addr;
                    end
                end
                if (biudata_error) begin
                    state <= IDLE; hitmiss_eval <= 1'b0; load <= 1'b0; cache_inhibit <= 1'b0;
                end
            end
        endcase
    end
end
endmodule

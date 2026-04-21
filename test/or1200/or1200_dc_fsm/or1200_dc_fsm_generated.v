`include "timescale.v"
`include "or1200_defines.v"

`define OR1200_DCFSM_IDLE       3'd0
`define OR1200_DCFSM_CLOAD      3'd1
`define OR1200_DCFSM_LREFILL3   3'd2
`define OR1200_DCFSM_CSTORE     3'd3
`define OR1200_DCFSM_SREFILL4   3'd4

module or1200_dc_fsm(
	clk, rst,
	dc_en, dcqmem_cycstb_i, dcqmem_ci_i, dcqmem_we_i, dcqmem_sel_i,
	tagcomp_miss, biudata_valid, biudata_error, start_addr, saved_addr,
	dcram_we, biu_read, biu_write, first_hit_ack, first_miss_ack, first_miss_err,
	burst, tag_we, dc_addr
);

input			clk;
input			rst;
input			dc_en;
input			dcqmem_cycstb_i;
input			dcqmem_ci_i;
input			dcqmem_we_i;
input	[3:0]		dcqmem_sel_i;
input			tagcomp_miss;
input			biudata_valid;
input			biudata_error;
input	[31:0]		start_addr;
output	[31:0]		saved_addr;
output	[3:0]		dcram_we;
output			biu_read;
output			biu_write;
output			first_hit_ack;
output			first_miss_ack;
output			first_miss_err;
output			burst;
output			tag_we;
output	[31:0]		dc_addr;

reg	[31:0]		saved_addr_r;
reg	[2:0]		state;
reg	[2:0]		cnt;
reg			hitmiss_eval;
reg			store;
reg			load;
reg			cache_inhibit;
wire			first_store_hit_ack;

// Byte-level write enables for the data RAM
assign dcram_we = {4{load & biudata_valid & !cache_inhibit}} |
                  {4{first_store_hit_ack}} & dcqmem_sel_i;

// tag_we: asserted when valid refill data is received during a cacheable read sequence
assign tag_we = biu_read & biudata_valid & !cache_inhibit;

// biu_read: asserted during miss detection or while continuing a refill load sequence
assign biu_read  = (hitmiss_eval & tagcomp_miss) | (!hitmiss_eval & load);
assign biu_write = store;

// dc_addr: selects start_addr during hit/miss evaluation,
// switches to saved_addr during refill or external transactions
assign dc_addr    = (biu_read | biu_write) & !hitmiss_eval ? saved_addr : start_addr;
assign saved_addr = saved_addr_r;

// first_hit_ack: asserted in the same cycle as hit detection
assign first_hit_ack = (state == `OR1200_DCFSM_CLOAD) & !tagcomp_miss &
                        !cache_inhibit & !dcqmem_ci_i | first_store_hit_ack;
assign first_store_hit_ack = (state == `OR1200_DCFSM_CSTORE) & !tagcomp_miss &
                              biudata_valid & !cache_inhibit & !dcqmem_ci_i;
assign first_miss_ack = ((state == `OR1200_DCFSM_CLOAD) | (state == `OR1200_DCFSM_CSTORE)) &
                         biudata_valid;
assign first_miss_err = ((state == `OR1200_DCFSM_CLOAD) | (state == `OR1200_DCFSM_CSTORE)) &
                         biudata_error;

// burst: asserted after miss detection and during refill
assign burst = (state == `OR1200_DCFSM_CLOAD) & tagcomp_miss & !cache_inhibit
             | (state == `OR1200_DCFSM_LREFILL3)
`ifdef OR1200_DC_STORE_REFILL
             | (state == `OR1200_DCFSM_SREFILL4)
`endif
             ;

// Main FSM
always @(posedge clk or posedge rst) begin
	if (rst) begin
		state        <= #1 `OR1200_DCFSM_IDLE;
		saved_addr_r <= #1 32'b0;
		hitmiss_eval <= #1 1'b0;
		store        <= #1 1'b0;
		load         <= #1 1'b0;
		cnt          <= #1 3'b000;
		cache_inhibit <= #1 1'b0;
	end
	else
	case (state)
		`OR1200_DCFSM_IDLE:
			if (dc_en & dcqmem_cycstb_i & dcqmem_we_i) begin
				state        <= #1 `OR1200_DCFSM_CSTORE;
				saved_addr_r <= #1 start_addr;
				hitmiss_eval <= #1 1'b1;
				store        <= #1 1'b1;
				load         <= #1 1'b0;
				cache_inhibit <= #1 1'b0;
			end
			else if (dc_en & dcqmem_cycstb_i) begin
				state        <= #1 `OR1200_DCFSM_CLOAD;
				saved_addr_r <= #1 start_addr;
				hitmiss_eval <= #1 1'b1;
				store        <= #1 1'b0;
				load         <= #1 1'b1;
				cache_inhibit <= #1 1'b0;
			end
			else begin
				hitmiss_eval <= #1 1'b0;
				store        <= #1 1'b0;
				load         <= #1 1'b0;
				cache_inhibit <= #1 1'b0;
			end

		`OR1200_DCFSM_CLOAD: begin
			if (dcqmem_cycstb_i & dcqmem_ci_i)
				cache_inhibit <= #1 1'b1;
			if (hitmiss_eval)
				saved_addr_r[31:13] <= #1 start_addr[31:13];
			if ((hitmiss_eval & !dcqmem_cycstb_i) ||
			    (biudata_error) ||
			    ((cache_inhibit | dcqmem_ci_i) & biudata_valid)) begin
				state        <= #1 `OR1200_DCFSM_IDLE;
				hitmiss_eval <= #1 1'b0;
				load         <= #1 1'b0;
				cache_inhibit <= #1 1'b0;
			end
			else if (tagcomp_miss & biudata_valid) begin
				// cnt initialized to OR1200_DCLS-2 for load refill
				state        <= #1 `OR1200_DCFSM_LREFILL3;
				saved_addr_r[3:2] <= #1 saved_addr_r[3:2] + 1'd1;
				hitmiss_eval <= #1 1'b0;
				cnt          <= #1 `OR1200_DCLS-2;
				cache_inhibit <= #1 1'b0;
			end
			else if (!tagcomp_miss & !dcqmem_ci_i) begin
				state        <= #1 `OR1200_DCFSM_IDLE;
				hitmiss_eval <= #1 1'b0;
				load         <= #1 1'b0;
				cache_inhibit <= #1 1'b0;
			end
			else
				hitmiss_eval <= #1 1'b0;
		end

		`OR1200_DCFSM_LREFILL3: begin
			if (biudata_valid && (|cnt)) begin
				cnt          <= #1 cnt - 3'd1;
				saved_addr_r[3:2] <= #1 saved_addr_r[3:2] + 1'd1;
			end
			else if (biudata_valid) begin
				// update tag once refill sequence completes
				state <= #1 `OR1200_DCFSM_IDLE;
				load  <= #1 1'b0;
			end
		end

		`OR1200_DCFSM_CSTORE: begin
			if (dcqmem_cycstb_i & dcqmem_ci_i)
				cache_inhibit <= #1 1'b1;
			if (hitmiss_eval)
				saved_addr_r[31:13] <= #1 start_addr[31:13];
			if ((hitmiss_eval & !dcqmem_cycstb_i) ||
			    (biudata_error) ||
			    ((cache_inhibit | dcqmem_ci_i) & biudata_valid)) begin
				state        <= #1 `OR1200_DCFSM_IDLE;
				hitmiss_eval <= #1 1'b0;
				store        <= #1 1'b0;
				cache_inhibit <= #1 1'b0;
			end
`ifdef OR1200_DC_STORE_REFILL
			else if (tagcomp_miss & biudata_valid) begin
				// cnt initialized to OR1200_DCLS-1 for store refill
				state        <= #1 `OR1200_DCFSM_SREFILL4;
				hitmiss_eval <= #1 1'b0;
				store        <= #1 1'b0;
				load         <= #1 1'b1;
				cnt          <= #1 `OR1200_DCLS-1;
				cache_inhibit <= #1 1'b0;
			end
`endif
			else if (biudata_valid) begin
				state        <= #1 `OR1200_DCFSM_IDLE;
				hitmiss_eval <= #1 1'b0;
				store        <= #1 1'b0;
				cache_inhibit <= #1 1'b0;
			end
			else
				hitmiss_eval <= #1 1'b0;
		end

`ifdef OR1200_DC_STORE_REFILL
		`OR1200_DCFSM_SREFILL4: begin
			if (biudata_valid && (|cnt)) begin
				cnt          <= #1 cnt - 1'd1;
				saved_addr_r[3:2] <= #1 saved_addr_r[3:2] + 1'd1;
			end
			else if (biudata_valid) begin
				state <= #1 `OR1200_DCFSM_IDLE;
				load  <= #1 1'b0;
			end
		end
`endif

		default:
			state <= #1 `OR1200_DCFSM_IDLE;
	endcase
end

endmodule

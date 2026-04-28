`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_dc_fsm (
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

    //--------------------------------------------------------------------------
    // FSM state encoding
    //--------------------------------------------------------------------------
    localparam [2:0]
        IDLE     = 3'd0,
        CLOAD    = 3'd1,
        LREFILL3 = 3'd2,
        CSTORE   = 3'd3,
        SREFILL4 = 3'd4;

    reg [2:0]  state;
    reg [31:0] saved_addr_r;
    reg [`OR1200_DCLS-1:0] cnt;
    reg        hitmiss_eval;
    reg        store;
    reg        load;
    reg        cache_inhibit;

    assign saved_addr = saved_addr_r;

    //--------------------------------------------------------------------------
    // Combinational outputs
    //--------------------------------------------------------------------------

    // biu_read: miss evaluation or active refill load
    assign biu_read =
        ((state == CLOAD) && hitmiss_eval && tagcomp_miss && !cache_inhibit) ||
        ((state == CLOAD) && !hitmiss_eval && load) ||
        (state == LREFILL3) ||
`ifdef OR1200_DC_STORE_REFILL
        (state == SREFILL4) ||
`endif
        ((state == CLOAD) && cache_inhibit && dcqmem_cycstb_i);

    // biu_write: store flag active
    assign biu_write = store;

    // dc_addr: start_addr during hitmiss_eval, saved_addr afterward
    assign dc_addr = hitmiss_eval ? start_addr : saved_addr_r;

    // first_hit_ack: load hit in CLOAD, or store hit when biudata_valid
    wire first_store_hit_ack = (state == CSTORE) && biudata_valid &&
                               !tagcomp_miss && !cache_inhibit;

    assign first_hit_ack = ((state == CLOAD) && !tagcomp_miss &&
                            !cache_inhibit && hitmiss_eval) ||
                           first_store_hit_ack;

    // first_miss_ack: BIU data valid in CLOAD or CSTORE
    assign first_miss_ack = ((state == CLOAD) || (state == CSTORE)) &&
                             biudata_valid;

    // first_miss_err: BIU error in CLOAD or CSTORE
    assign first_miss_err = ((state == CLOAD) || (state == CSTORE)) &&
                             biudata_error;

    // burst: refill in progress
    assign burst =
        ((state == CLOAD) && tagcomp_miss && !cache_inhibit) ||
        (state == LREFILL3) ||
`ifdef OR1200_DC_STORE_REFILL
        (state == SREFILL4) ||
`endif
        1'b0;

    // dcram_we: all lanes during load refill, selected lanes during store hit
    assign dcram_we =
        (load && biudata_valid && !cache_inhibit &&
         (state == LREFILL3 || state == CLOAD)) ? 4'hf :
`ifdef OR1200_DC_STORE_REFILL
        (load && biudata_valid && !cache_inhibit &&
         state == SREFILL4) ? 4'hf :
`endif
        first_store_hit_ack ? dcqmem_sel_i :
        4'h0;

    // tag_we: valid non-inhibited BIU read data
    assign tag_we = biu_read && biudata_valid && !cache_inhibit;

    //--------------------------------------------------------------------------
    // Sequential FSM
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= IDLE;
            saved_addr_r  <= 32'd0;
            cnt           <= {`OR1200_DCLS{1'b0}};
            hitmiss_eval  <= 1'b0;
            store         <= 1'b0;
            load          <= 1'b0;
            cache_inhibit <= 1'b0;
        end else begin
            case (state)

                //--------------------------------------------------------------
                IDLE: begin
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

                //--------------------------------------------------------------
                CLOAD: begin
                    // Detect cache-inhibit
                    if (dcqmem_cycstb_i && dcqmem_ci_i)
                        cache_inhibit <= 1'b1;

                    if (biudata_error || (!dcqmem_cycstb_i && hitmiss_eval)) begin
                        // Aborted or error
                        state        <= IDLE;
                        hitmiss_eval <= 1'b0;
                        load         <= 1'b0;
                        cache_inhibit<= 1'b0;
                    end else if (cache_inhibit && biudata_valid) begin
                        // Cache-inhibited load complete
                        state        <= IDLE;
                        hitmiss_eval <= 1'b0;
                        load         <= 1'b0;
                        cache_inhibit<= 1'b0;
                    end else if (hitmiss_eval && !tagcomp_miss && !cache_inhibit) begin
                        // Load hit → return to IDLE
                        state        <= IDLE;
                        hitmiss_eval <= 1'b0;
                        load         <= 1'b0;
                    end else if (biudata_valid && !cache_inhibit) begin
                        // First miss word returned → enter LREFILL3
                        state                <= LREFILL3;
                        hitmiss_eval         <= 1'b0;
                        saved_addr_r[3:2]    <= saved_addr_r[3:2] + 2'd1;
                        cnt                  <= `OR1200_DCLS - 2;
                    end else begin
                        hitmiss_eval <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                LREFILL3: begin
                    if (biudata_valid) begin
                        if (cnt == {`OR1200_DCLS{1'b0}}) begin
                            state <= IDLE;
                            load  <= 1'b0;
                        end else begin
                            cnt               <= cnt - 1;
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                        end
                    end
                end

                //--------------------------------------------------------------
                CSTORE: begin
                    // Detect cache-inhibit
                    if (dcqmem_cycstb_i && dcqmem_ci_i)
                        cache_inhibit <= 1'b1;

                    if (biudata_error || (!dcqmem_cycstb_i && hitmiss_eval)) begin
                        // Aborted or error
                        state        <= IDLE;
                        hitmiss_eval <= 1'b0;
                        store        <= 1'b0;
                        cache_inhibit<= 1'b0;
                    end else if (biudata_valid) begin
                        hitmiss_eval <= 1'b0;
                        store        <= 1'b0;
`ifdef OR1200_DC_STORE_REFILL
                        if (!tagcomp_miss || cache_inhibit) begin
                            // Store hit or cache-inhibited: done
                            state        <= IDLE;
                            cache_inhibit<= 1'b0;
                        end else begin
                            // Store miss: enter SREFILL4
                            state        <= SREFILL4;
                            load         <= 1'b1;
                            cnt          <= `OR1200_DCLS - 1;
                            cache_inhibit<= 1'b0;
                        end
`else
                        state        <= IDLE;
                        cache_inhibit<= 1'b0;
`endif
                    end else begin
                        hitmiss_eval <= 1'b0;
                    end
                end

`ifdef OR1200_DC_STORE_REFILL
                //--------------------------------------------------------------
                SREFILL4: begin
                    if (biudata_valid) begin
                        if (cnt == {`OR1200_DCLS{1'b0}}) begin
                            state <= IDLE;
                            load  <= 1'b0;
                        end else begin
                            cnt               <= cnt - 1;
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'd1;
                        end
                    end
                end
`endif

                default: state <= IDLE;

            endcase
        end
    end

endmodule
`timescale 1ns / 1ps
module or1200_dc_fsm(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f to top level DC
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

    // Parameters
    parameter OR1200_DCLS = 4; // Number of words in cache line
    parameter OR1200_DC_STORE_REFILL = 1; // Enable store refill

    // State encoding
    localparam [1:0] IDLE = 2'b00,
                     CLOAD = 2'b01,
                     CSTORE = 2'b10,
                     LREFILL3 = 2'b11;
    localparam [1:0] SREFILL4 = 2'b11; // Reuse encoding for SREFILL4 if distinct, else need more bits
    // Given only four states explicitly named, we need at least 3 bits.
    // Let's define SREFILL4 separately.
    localparam [2:0] IDLE_ST    = 3'b000,
                     CLOAD_ST   = 3'b001,
                     CSTORE_ST  = 3'b010,
                     LREFILL3_ST = 3'b011,
                     SREFILL4_ST = 3'b100;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] saved_addr_r;
    reg [2:0] cnt; // Count remaining words in refill (0 to OR1200_DCLS-1)
    reg hitmiss_eval;
    reg store;
    reg load;
    reg cache_inhibit;

    // Registered outputs
    reg [31:0] saved_addr_reg;
    reg [3:0] dcram_we_reg;
    reg biu_read_reg;
    reg biu_write_reg;
    reg first_hit_ack_reg;
    reg first_miss_ack_reg;
    reg first_miss_err_reg;
    reg burst_reg;
    reg tag_we_reg;
    reg [31:0] dc_addr_reg;

    // Output assignments
    assign saved_addr = saved_addr_reg;
    assign dcram_we = dcram_we_reg;
    assign biu_read = biu_read_reg;
    assign biu_write = biu_write_reg;
    assign first_hit_ack = first_hit_ack_reg;
    assign first_miss_ack = first_miss_ack_reg;
    assign first_miss_err = first_miss_err_reg;
    assign burst = burst_reg;
    assign tag_we = tag_we_reg;
    assign dc_addr = dc_addr_reg;

    // Sequential logic (state and register updates)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE_ST;
            saved_addr_r <= 32'b0;
            cnt <= 3'b0;
            hitmiss_eval <= 1'b0;
            store <= 1'b0;
            load <= 1'b0;
            cache_inhibit <= 1'b0;
            saved_addr_reg <= 32'b0;
            dcram_we_reg <= 4'b0;
            biu_read_reg <= 1'b0;
            biu_write_reg <= 1'b0;
            first_hit_ack_reg <= 1'b0;
            first_miss_ack_reg <= 1'b0;
            first_miss_err_reg <= 1'b0;
            burst_reg <= 1'b0;
            tag_we_reg <= 1'b0;
            dc_addr_reg <= 32'b0;
        end else begin
            // Default assignments for registered outputs to avoid latches
            saved_addr_reg <= saved_addr_r;
            dcram_we_reg <= 4'b0;
            biu_read_reg <= 1'b0;
            biu_write_reg <= 1'b0;
            first_hit_ack_reg <= 1'b0;
            first_miss_ack_reg <= 1'b0;
            first_miss_err_reg <= 1'b0;
            burst_reg <= 1'b0;
            tag_we_reg <= 1'b0;
            dc_addr_reg <= start_addr; // Default to start_addr during eval

            // Combinational logic for next state and outputs based on current state
            case (state)
                IDLE_ST: begin
                    // Wait for request
                    if (dc_en && dcqmem_cycstb_i) begin
                        saved_addr_r <= start_addr;
                        hitmiss_eval <= 1'b1;
                        cache_inhibit <= 1'b0; // Will be detected later
                        if (dcqmem_we_i) begin
                            // Store request
                            state <= CSTORE_ST;
                            store <= 1'b1;
                            load <= 1'b0;
                        end else begin
                            // Load request
                            state <= CLOAD_ST;
                            load <= 1'b1;
                            store <= 1'b0;
                        end
                    end else begin
                        // No request, remain IDLE
                        hitmiss_eval <= 1'b0;
                        store <= 1'b0;
                        load <= 1'b0;
                        cache_inhibit <= 1'b0;
                        state <= IDLE_ST;
                    end
                end

                CLOAD_ST: begin
                    // Cache-inhibit detection (combinational from inputs)
                    if (dcqmem_cycstb_i && dcqmem_ci_i)
                        cache_inhibit <= 1'b1;

                    // Hit/miss evaluation
                    if (hitmiss_eval) begin
                        // Check abort condition: request deasserted before eval complete
                        if (!dcqmem_cycstb_i) begin
                            // Aborted
                            state <= IDLE_ST;
                            hitmiss_eval <= 1'b0;
                            load <= 1'b0;
                        end else if (biudata_error) begin
                            // BIU error during first access
                            state <= IDLE_ST;
                            hitmiss_eval <= 1'b0;
                            load <= 1'b0;
                            first_miss_err_reg <= 1'b1;
                        end else if (cache_inhibit) begin
                            // Cache-inhibited load: wait for BIU response, no refill
                            if (biudata_valid) begin
                                state <= IDLE_ST;
                                hitmiss_eval <= 1'b0;
                                load <= 1'b0;
                                first_miss_ack_reg <= 1'b1;
                                // dcram_we and tag_we suppressed by cache_inhibit
                            end else begin
                                biu_read_reg <= 1'b1; // Request BIU read
                            end
                        end else if (!tagcomp_miss) begin
                            // Load hit
                            state <= IDLE_ST;
                            hitmiss_eval <= 1'b0;
                            load <= 1'b0;
                            first_hit_ack_reg <= 1'b1;
                        end else begin
                            // Load miss: request BIU read
                            biu_read_reg <= 1'b1;
                            burst_reg <= 1'b1; // Start burst for miss
                            if (biudata_valid) begin
                                // First word of refill returned
                                state <= LREFILL3_ST;
                                hitmiss_eval <= 1'b0;
                                // Increment saved_addr_r[3:2] to next word
                                saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'b1;
                                cnt <= OR1200_DCLS - 2; // Remaining words after first
                                first_miss_ack_reg <= 1'b1;
                                // Write first word to DCRAM (all lanes) and tag if not cache_inhibit
                                if (!cache_inhibit) begin
                                    dcram_we_reg <= 4'b1111;
                                    tag_we_reg <= 1'b1;
                                end
                            end
                        end
                    end else begin
                        // hitmiss_eval is 0, but we shouldn't be here normally.
                        // Fallback: return to IDLE
                        state <= IDLE_ST;
                        load <= 1'b0;
                    end
                end

                CSTORE_ST: begin
                    // Cache-inhibit detection
                    if (dcqmem_cycstb_i && dcqmem_ci_i)
                        cache_inhibit <= 1'b1;

                    // Write-through: assert biu_write while store active
                    biu_write_reg <= 1'b1;

                    if (hitmiss_eval) begin
                        // Check abort
                        if (!dcqmem_cycstb_i) begin
                            state <= IDLE_ST;
                            hitmiss_eval <= 1'b0;
                            store <= 1'b0;
                        end else if (biudata_error) begin
                            state <= IDLE_ST;
                            hitmiss_eval <= 1'b0;
                            store <= 1'b0;
                            first_miss_err_reg <= 1'b1;
                        end else if (cache_inhibit) begin
                            // Cache-inhibited store: wait for BIU response
                            if (biudata_valid) begin
                                state <= IDLE_ST;
                                hitmiss_eval <= 1'b0;
                                store <= 1'b0;
                                first_miss_ack_reg <= 1'b1; // Acts as completion ack
                            end
                        end else if (!tagcomp_miss) begin
                            // Store hit: wait for write-through response
                            if (biudata_valid) begin
                                state <= IDLE_ST;
                                hitmiss_eval <= 1'b0;
                                store <= 1'b0;
                                first_hit_ack_reg <= 1'b1;
                                // Partial write to DCRAM using dcqmem_sel_i
                                dcram_we_reg <= dcqmem_sel_i;
                            end
                        end else begin
                            // Store miss
                            if (biudata_valid) begin
                                if (OR1200_DC_STORE_REFILL) begin
                                    // Enter store refill
                                    state <= SREFILL4_ST;
                                    hitmiss_eval <= 1'b0;
                                    store <= 1'b0;
                                    load <= 1'b1; // Set load for refill
                                    cnt <= OR1200_DCLS - 1;
                                    // Do not increment saved_addr_r on entry; start at current offset
                                    // No ack here; ack on miss handled by first_miss_ack? Spec says first_miss_ack asserted during CLOAD/CSTORE when biudata_valid.
                                    // Here we are in CSTORE with biudata_valid, so assert first_miss_ack.
                                    first_miss_ack_reg <= 1'b1;
                                end else begin
                                    // No refill, return to IDLE
                                    state <= IDLE_ST;
                                    hitmiss_eval <= 1'b0;
                                    store <= 1'b0;
                                    first_miss_ack_reg <= 1'b1;
                                end
                            end
                        end
                    end else begin
                        state <= IDLE_ST;
                        store <= 1'b0;
                    end
                end

                LREFILL3_ST: begin
                    // Continue load refill
                    biu_read_reg <= 1'b1; // BIU read active
                    burst_reg <= 1'b1;
                    if (biudata_valid) begin
                        // Write word to DCRAM (all lanes) and tag if not cache_inhibit
                        if (!cache_inhibit) begin
                            dcram_we_reg <= 4'b1111;
                            tag_we_reg <= 1'b1;
                        end
                        if (cnt != 0) begin
                            cnt <= cnt - 1;
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'b1;
                        end else begin
                            // Final word received
                            state <= IDLE_ST;
                            load <= 1'b0;
                            cnt <= 0;
                        end
                    end
                    // dc_addr uses saved_addr during refill
                    dc_addr_reg <= saved_addr_r;
                end

                SREFILL4_ST: begin
                    // Store refill (similar to LREFILL3 but started after store miss)
                    biu_read_reg <= 1'b1;
                    burst_reg <= 1'b1;
                    if (biudata_valid) begin
                        if (!cache_inhibit) begin
                            dcram_we_reg <= 4'b1111;
                            tag_we_reg <= 1'b1;
                        end
                        if (cnt != 0) begin
                            cnt <= cnt - 1;
                            saved_addr_r[3:2] <= saved_addr_r[3:2] + 2'b1;
                        end else begin
                            state <= IDLE_ST;
                            load <= 1'b0;
                            cnt <= 0;
                        end
                    end
                    dc_addr_reg <= saved_addr_r;
                end

                default: begin
                    state <= IDLE_ST;
                end
            endcase

            // Update dc_addr if in eval mode (hitmiss_eval active), use start_addr; else use saved_addr.
            // But careful: dc_addr_reg may have been overridden in states above. We set default to start_addr.
            // In refill states we explicitly set dc_addr_reg to saved_addr_r.
            // In CLOAD/CSTORE with hitmiss_eval, dc_addr_reg should be start_addr (default already).
            // However, in CLOAD/CSTORE when biu transfer active after hitmiss_eval cleared, we need saved_addr.
            // Let's refine: in CLOAD/CSTORE after hitmiss_eval cleared (but before transition), dc_addr should use saved_addr.
            // We'll handle this by overriding in those specific cases.
            // Since we already set dc_addr_reg in LREFILL3 and SREFILL4, we need to also set it in CLOAD/CSTORE when hitmiss_eval is 0 (i.e., during BIU transfer after eval).
            // But in our case, when hitmiss_eval becomes 0, we immediately transition or handle ack; but for the cycle when biudata_valid occurs and we are still in CLOAD/CSTORE, dc_addr should be saved_addr.
            // We'll add explicit assignment in CLOAD/CSTORE when hitmiss_eval is 0 and we are pending BIU response (biu_read or biu_write asserted).
            // Actually, in CLOAD miss case, after hitmiss_eval cleared and we wait for biudata_valid, we are still in CLOAD and biu_read is asserted. dc_addr should be saved_addr.
            // Similarly in CSTORE, after hitmiss_eval cleared, biu_write is asserted, dc_addr should be saved_addr.
            // We'll handle this in the case statements for CLOAD and CSTORE when hitmiss_eval is 0.

            // Re-apply overrides for dc_addr based on state and hitmiss_eval
            case (state)
                CLOAD_ST: begin
                    if (!hitmiss_eval) begin
                        // Post-eval BIU transfer in CLOAD (e.g., waiting for first refill word)
                        dc_addr_reg <= saved_addr_r;
                    end
                end
                CSTORE_ST: begin
                    if (!hitmiss_eval) begin
                        // Post-eval BIU transfer in CSTORE (store miss waiting for response)
                        dc_addr_reg <= saved_addr_r;
                    end
                end
                // LREFILL3_ST and SREFILL4_ST already set dc_addr_reg
            endcase

            // For biu_read and biu_write, we already set them in respective states.
            // Additional combinational logic for biu_read: asserted during miss eval or active refill load.
            // Already covered by explicit assignments in states.

            // first_miss_ack: asserted in CLOAD or CSTORE when biudata_valid=1 (already handled)
            // first_miss_err: asserted in CLOAD or CSTORE when biudata_error=1 (already handled)
            // first_hit_ack: handled in CLOAD and CSTORE.

            // burst: asserted in LREFILL3, SREFILL4, and during load miss eval in CLOAD (already handled).

            // tag_we: asserted when biu_read=1 and biudata_valid=1 and !cache_inhibit. We set it in appropriate places.

            // dcram_we: handled.

        end
    end

endmodule

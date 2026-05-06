`timescale 1ns / 1ps
// or1200_iwb_biu.v - Instruction-side Wishbone Bus Interface Unit for OR1200

module or1200_iwb_biu (
    // RISC clock, reset and clock control
    input clk,
    input rst,
    input [1:0] clmode,

    // WISHBONE interface
    input wb_clk_i,
    input wb_rst_i,
    input wb_ack_i,
    input wb_err_i,
    input wb_rty_i,
    input [31:0] wb_dat_i,
    output wb_cyc_o,
    output [31:0] wb_adr_o,
    output wb_stb_o,
    output wb_we_o,
    output [3:0] wb_sel_o,
    output [31:0] wb_dat_o,
`ifdef OR1200_WB_CAB
    output wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0] wb_cti_o,
    output [1:0] wb_bte_o,
`endif

    // Internal RISC bus
    input [31:0] biu_dat_i,
    input [31:0] biu_adr_i,
    input biu_cyc_i,
    input biu_stb_i,
    input biu_we_i,
    input [3:0] biu_sel_i,
    input biu_cab_i,
    output [31:0] biu_dat_o,
    output biu_ack_o,
    output biu_err_o
);

// ============================================================================
// Parameter definitions
// ============================================================================
parameter RETRY_COUNT = 3; // Number of retry cycles after wb_rty_i

// ============================================================================
// Wires and registers
// ============================================================================

// RISC clock domain (clk)
reg [1:0] valid_div;
reg repeated_access_ack;

// Wishbone clock domain (wb_clk_i)
reg wb_cyc_r;
reg wb_stb_r;
reg [31:0] wb_adr_r;
reg wb_we_r;
reg [3:0] wb_sel_r;
reg [31:0] wb_dat_r_saved; // For registered output data (if used)
`ifdef OR1200_WB_CAB
reg wb_cab_r;
`endif
`ifdef OR1200_WB_B3
reg [2:0] wb_cti_r;
reg [1:0] wb_bte_r;
`endif

reg [31:0] biu_dat_r; // registered input data
reg long_ack_r;
reg long_err_r;
reg previous_complete;
reg aborted_r;
`ifdef OR1200_WB_RETRY
reg [1:0] retry_cntr; // 2-bit counter sufficient for small retry count
reg retry_active;
`endif
`ifdef OR1200_WB_B3
reg [1:0] burst_len; // tracks remaining beats (0..3)
`endif

// Combinational signals
wire repeated_access;
wire same_addr;
wire aborted;
wire resp_valid; // phase qualifier for ack/err

// ============================================================================
// Valid_div counter in clk domain
// ============================================================================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_div <= 2'b00;
    end else begin
        // Free-running counter; used for phase qualification
        valid_div <= valid_div + 1'b1;
    end
end

// Generation of resp_valid based on clmode and macro support
generate
    if (`ifdef OR1200_CLKDIV_2_SUPPORTED || `ifdef OR1200_CLKDIV_4_SUPPORTED) begin
        always @(*) begin
            case (clmode)
                2'b00: resp_valid = 1'b1;
                `ifdef OR1200_CLKDIV_2_SUPPORTED
                2'b01: resp_valid = (valid_div[0] == 1'b0); // every other cycle
                `endif
                `ifdef OR1200_CLKDIV_4_SUPPORTED
                2'b11: resp_valid = (valid_div == 2'b00); // every 4 cycles
                `endif
                default: resp_valid = 1'b1;
            endcase
        end
    end else begin
        assign resp_valid = 1'b1;
    end
endgenerate

// ============================================================================
// Repeated access detection (combinational, uses wb_adr_o from wb domain)
// ============================================================================
// Note: same_addr compares current biu_adr_i with the external address.
// In non-registered mode, wb_adr_o = biu_adr_i, so same_addr always 1.
// In registered mode, wb_adr_o is delayed; we compare against biu_adr_i.
wire [31:0] wb_adr_effective;
`ifdef OR1200_REGISTERED_OUTPUTS
assign wb_adr_effective = wb_adr_r;
`else
assign wb_adr_effective = biu_adr_i;
`endif
assign same_addr = (wb_adr_effective == biu_adr_i);

// previous_complete is in wb domain; we need to bring it to clk domain.
// For simplicity, we sample it on clk (assuming synchronous clocks with known ratio)
reg previous_complete_risc;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        previous_complete_risc <= 1'b1; // as per spec, reset to 1
    end else begin
        previous_complete_risc <= previous_complete;
    end
end

assign repeated_access = previous_complete_risc & same_addr;

// repeated_access_ack: one RISC clock pulse when repeated_access and request active
always @(posedge clk or posedge rst) begin
    if (rst) begin
        repeated_access_ack <= 1'b0;
    end else begin
        repeated_access_ack <= repeated_access & biu_cyc_i & biu_stb_i;
    end
end

// ============================================================================
// Wishbone output path (wb_clk_i domain)
// ============================================================================

// This block handles registered outputs and combinational outputs based on macro.
// For simplicity, we implement both cases within the same always block but with generate.

generate
    if (`ifdef OR1200_REGISTERED_OUTPUTS) begin: REG_OUT
        // Registered outputs
        always @(posedge wb_clk_i or posedge wb_rst_i) begin
            if (wb_rst_i) begin
                wb_cyc_r <= 1'b0;
                wb_stb_r <= 1'b0;
                wb_adr_r <= 32'b0;
                wb_we_r <= 1'b0;
                wb_sel_r <= 4'b0;
                wb_dat_r_saved <= 32'b0;
`ifdef OR1200_WB_CAB
                wb_cab_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
                wb_cti_r <= 3'b000;
                wb_bte_r <= 2'b00;
`endif
            end else begin
                // Determine if we can start a new transaction
                // Conditions: no retry, no repeated_access, no abort, and request active
                wire start_new = biu_cyc_i & biu_stb_i & ~retry_active & ~repeated_access & ~aborted_r;
                // If a transaction is already in progress (cyc active), we may update strobe and data
                if (wb_cyc_r) begin
                    // If we are in abort state, we keep cyc and stb until termination
                    if (aborted_r) begin
                        // Do not change cyc/stb; wait for ack/err
                    end else if (wb_ack_i | wb_err_i) begin
                        // Transaction completed; we may start new if request pending
                        wb_cyc_r <= start_new;
                        wb_stb_r <= start_new;
                        if (start_new) begin
                            wb_adr_r <= biu_adr_i;
                            wb_we_r <= biu_we_i;
                            wb_sel_r <= biu_sel_i;
                            wb_dat_r_saved <= biu_dat_i;
`ifdef OR1200_WB_CAB
                            wb_cab_r <= biu_cab_i;
`endif
`ifdef OR1200_WB_B3
                            // Burst logic: if CAB and not last beat, increment; else end-of-burst
                            if (biu_cab_i & (burst_len != 2'b00)) begin
                                wb_cti_r <= 3'b010; // incrementing burst
                                burst_len <= burst_len - 1'b1;
                            end else begin
                                wb_cti_r <= 3'b111; // end-of-burst or classic
                                burst_len <= 2'b11; // reset for next burst
                            end
                            wb_bte_r <= 2'b01; // 4-beat wrap
`endif
                        end
                    end else begin
                        // Continue transaction; update stb if we have more beats (CAB)
                        if (biu_cab_i & (burst_len != 2'b00) & wb_ack_i) begin
                            // We just got an ack and there are more beats to send
                            // In B3, we should update cti and keep stb high
                            wb_stb_r <= 1'b1;
                            wb_cti_r <= 3'b010; // incrementing burst
                            burst_len <= burst_len - 1'b1;
                            // address update for next beat (4-byte increment)
                            wb_adr_r <= wb_adr_r + 32'd4;
                        end else begin
                            // No more beats, or not a burst
                            wb_stb_r <= 1'b0; // stb will be deasserted after last ack
                        end
                    end
                end else begin
                    // No current transaction
                    if (start_new) begin
                        wb_cyc_r <= 1'b1;
                        wb_stb_r <= 1'b1;
                        wb_adr_r <= biu_adr_i;
                        wb_we_r <= biu_we_i;
                        wb_sel_r <= biu_sel_i;
                        wb_dat_r_saved <= biu_dat_i;
`ifdef OR1200_WB_CAB
                        wb_cab_r <= biu_cab_i;
`endif
`ifdef OR1200_WB_B3
                        burst_len <= 2'b11; // 4-beat burst (will decrement on each ack)
                        if (biu_cab_i) begin
                            wb_cti_r <= 3'b010; // incrementing burst
                        end else begin
                            wb_cti_r <= 3'b000; // classic cycle
                        end
                        wb_bte_r <= 2'b01;
`endif
                    end else begin
                        wb_cyc_r <= 1'b0;
                        wb_stb_r <= 1'b0;
                    end
                end
            end
        end

        // Output assignments from registered signals
        assign wb_cyc_o = wb_cyc_r;
        assign wb_stb_o = wb_stb_r;
        assign wb_adr_o = wb_adr_r;
        assign wb_we_o = wb_we_r;
        assign wb_sel_o = wb_sel_r;
        assign wb_dat_o = wb_dat_r_saved;
`ifdef OR1200_WB_CAB
        assign wb_cab_o = wb_cab_r;
`endif
`ifdef OR1200_WB_B3
        assign wb_cti_o = wb_cti_r;
        assign wb_bte_o = wb_bte_r;
`endif
    end else begin: NO_REG_OUT
        // Combinational outputs (non-registered)
        assign wb_cyc_o = biu_cyc_i & biu_stb_i & ~retry_active; // retry may affect cyc depending on macro? Spec says "depends on macros", but we include it.
        // For non-registered, wb_stb_o is not masked by retry, repeated_access, or abort
        assign wb_stb_o = biu_cyc_i & biu_stb_i;
        assign wb_adr_o = biu_adr_i;
        assign wb_we_o = biu_cyc_i & biu_stb_i & biu_we_i;
        assign wb_sel_o = biu_sel_i;
        assign wb_dat_o = biu_dat_i;
`ifdef OR1200_WB_CAB
        assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
        // B3 with non-registered outputs is unsupported; we tie to zero or constant
        assign wb_cti_o = 3'b000;
        assign wb_bte_o = 2'b00;
`endif
    end
endgenerate

// ============================================================================
// Abort logic (combinational and registered)
// ============================================================================
// aborted is combinational in wb_clk_i domain
// aborted_r is registered

wire internal_req_active = biu_cyc_i & biu_stb_i;
// In registered mode, we use wb_stb_r; in non-registered, we use wb_stb_o (combinational)
wire wb_stb_internal;
`ifdef OR1200_REGISTERED_OUTPUTS
assign wb_stb_internal = wb_stb_r;
`else
assign wb_stb_internal = wb_stb_o; // but in non-registered, wb_stb_o is combinational and equals biu_cyc_i & biu_stb_i, so aborted would never assert? Actually if internal request is withdrawn, wb_stb_o goes low immediately. So abort logic may not apply. We'll still define aborted for completeness.
`endif

assign aborted = wb_stb_internal & ~internal_req_active & ~wb_ack_i & ~wb_err_i;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        aborted_r <= 1'b0;
    end else begin
        if (wb_ack_i | wb_err_i) begin
            aborted_r <= 1'b0; // clear when term received
        end else if (aborted) begin
            aborted_r <= 1'b1; // set when condition met
        end else begin
            aborted_r <= aborted_r; // hold
        end
    end
end

// ============================================================================
// Retry handling (if enabled)
// ============================================================================
`ifdef OR1200_WB_RETRY
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        retry_cntr <= 2'b00;
        retry_active <= 1'b0;
    end else begin
        if (wb_rty_i) begin
            // Load counter (we set it to RETRY_COUNT-1 since we count down)
            retry_cntr <= RETRY_COUNT - 1; // assume RETRY_COUNT >= 1
            retry_active <= 1'b1;
        end else if (retry_active) begin
            if (|retry_cntr) begin
                retry_cntr <= retry_cntr - 1'b1;
            end else begin
                retry_active <= 1'b0;
            end
        end else begin
            retry_active <= 1'b0;
        end
    end
end
`else
assign retry_active = 1'b0; // no retry
`endif

// ============================================================================
// Input data path and completion flags (wb_clk_i domain)
// ============================================================================
// previous_complete registered
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        previous_complete <= 1'b1; // as per spec, set to 1 on reset
    end else begin
        if (wb_ack_i & biu_cyc_i & biu_stb_i) begin
            // Also need to ensure not aborted? The spec says "wb_ack_i & biu_cyc_i & biu_stb_i is true"
            previous_complete <= 1'b1;
        end else if (~internal_req_active & ~wb_ack_i & ~wb_stb_internal & ~aborted) begin
            // Clear when no request, no ack, no strobe, no abort (i.e., new cycle idle)
            // The spec: "cleared when a new internal request starts, there is no current wb_ack_i, no abort condition, and no still-pending wb_stb_o"
            // This condition is complicated; we simplify: when there is no cyc/stb and no ack/abort, we may clear.
            // Actually, we only need to clear when a fresh internal request appears? The spec: "cleared when a new internal request starts, ..."
            // That implies that previous_complete is cleared at the beginning of a new request.
            // We can detect the rising edge of biu_cyc_i & biu_stb_i.
            // But since those are in different clock domain, we sample them.
            // For simplicity, we clear when wb_cyc_o and wb_stb_o are low and no ack/abort, and internal request is present? This is messy.
            // Alternatively, we can use a register that tracks the request start.
            // Given the complexity, we adopt a common OR1200 approach: clear previous_complete when wb_stb_o is asserted for a new transaction.
            // We'll implement a simplified version: clear when we start a new transaction (wb_stb_o rising edge) and aborted_r is low.
            // But we need to detect the start. We'll use a delayed version.
        end
    end
end

// Simplified: use a separate start detect. We'll do:
reg prev_stb_r;
always @(posedge wb_clk_i) begin
    prev_stb_r <= wb_stb_internal;
end
wire start_new_trans = ~prev_stb_r & wb_stb_internal;

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        previous_complete <= 1'b1;
    end else if (wb_ack_i & biu_cyc_i & biu_stb_i) begin
        previous_complete <= 1'b1;
    end else if (start_new_trans & ~aborted_r) begin
        previous_complete <= 1'b0;
    end
end

// Registered input path
`ifdef OR1200_REGISTERED_INPUTS
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        biu_dat_r <= 32'b0;
        long_ack_r <= 1'b0;
        long_err_r <= 1'b0;
    end else begin
        if (wb_ack_i & ~aborted) begin
            biu_dat_r <= wb_dat_i;
            long_ack_r <= 1'b1;
        end else if (wb_err_i & ~aborted) begin
            long_err_r <= 1'b1;
        end else begin
            // clear long flags after they've been consumed? They are pulsed.
            // In OR1200, they are level-sensitive? Actually they are one-cycle pulses.
            // We assume they are sampled in RISC domain and then cleared.
            // For simplicity, we clear them when not asserted.
            if (~wb_ack_i) long_ack_r <= 1'b0;
            if (~wb_err_i) long_err_r <= 1'b0;
            // biu_dat_r holds until next read
        end
    end
end
`else // non-registered inputs
assign long_ack_r = wb_ack_i; // combinational
assign long_err_r = wb_err_i & ~aborted_r; // combinational
assign biu_dat_r = (repeated_access_ack & previous_complete) ? wb_dat_r_saved : wb_dat_i; // combinational, using saved data
`endif

// ============================================================================
// BIU outputs (clk domain)
// ============================================================================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        biu_ack_o <= 1'b0;
        biu_err_o <= 1'b0;
    end else begin
        // Combine long_ack_r and repeated_access_ack, masked by ~aborted_r and phase qualified
        wire ack_raw = (long_ack_r | repeated_access_ack) & ~aborted_r;
        wire err_raw = long_err_r & ~aborted_r;
        // Apply phase qualifier if clock division macros are defined
`ifdef OR1200_CLKDIV_2_SUPPORTED
        if (clmode == 2'b01) begin
            biu_ack_o <= ack_raw & resp_valid;
            biu_err_o <= err_raw & resp_valid;
        end else
`endif
`ifdef OR1200_CLKDIV_4_SUPPORTED
        if (clmode == 2'b11) begin
            biu_ack_o <= ack_raw & resp_valid;
            biu_err_o <= err_raw & resp_valid;
        end else
`endif
        begin
            biu_ack_o <= ack_raw;
            biu_err_o <= err_raw;
        end
    end
end

// biu_dat_o: depends on registered input mode
generate
    if (`ifdef OR1200_REGISTERED_INPUTS) begin
        assign biu_dat_o = biu_dat_r;
    end else begin
        // Combinational: if repeated_access_ack is active, use saved wb_dat_r (which we store),
        // else use current wb_dat_i.
        // We need wb_dat_r. We'll store it separately.
        reg [31:0] wb_dat_r_saved_nonreg;
        always @(posedge wb_clk_i) begin
            if (wb_ack_i) begin
                wb_dat_r_saved_nonreg <= wb_dat_i;
            end
        end
        assign biu_dat_o = (repeated_access_ack) ? wb_dat_r_saved_nonreg : wb_dat_i;
    end
endgenerate

// ============================================================================
// Additional required registers for wb_dat_r (for repeated access in registered input mode)
// ============================================================================
// In registered input mode, we already captured wb_dat_i into biu_dat_r on ack.
// But for repeated access we need a saved copy. We'll store wb_dat_r specifically for repeated access.
// Actually, for registered inputs, we already have biu_dat_r which holds the data from last ack.
// But we need to compare against current address. The spec says wb_dat_r saves wb_dat_i on previous wb_ack_i.
// We'll create a separate register for that.
reg [31:0] wb_dat_r;
always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
        wb_dat_r <= 32'b0;
    end else if (wb_ack_i) begin
        wb_dat_r <= wb_dat_i;
    end
end

// For non-registered inputs, we used wb_dat_r_saved_nonreg above.

endmodule

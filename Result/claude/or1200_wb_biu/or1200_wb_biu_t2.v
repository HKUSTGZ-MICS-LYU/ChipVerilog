module or1200_wb_biu(
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
    output reg wb_cyc_o,
    output reg [31:0] wb_adr_o,
    output reg wb_stb_o,
    output reg wb_we_o,
    output reg [3:0] wb_sel_o,
    output reg [31:0] wb_dat_o,
`ifdef OR1200_WB_CAB
    output reg wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output reg [2:0] wb_cti_o,
    output reg [1:0] wb_bte_o,
`endif

    // Internal RISC bus
    input [31:0] biu_dat_i,
    input [31:0] biu_adr_i,
    input biu_cyc_i,
    input biu_stb_i,
    input biu_we_i,
    input [3:0] biu_sel_i,
    input biu_cab_i,
    output reg [31:0] biu_dat_o,
    output reg biu_ack_o,
    output reg biu_err_o
);

    // Internal registers
    reg [1:0] valid_div;
    reg [1:0] burst_len;
    reg [31:0] wb_dat_o_reg;
    reg long_ack_o;
    reg long_err_o;
    reg aborted_r;
    reg [6:0] retry_cntr;

    // Wishbone clock domain registers
    reg wb_ack_sync_r;
    reg wb_err_sync_r;
    reg wb_rty_sync_r;
    reg [31:0] wb_dat_sync;

    // Internal wires
    wire long_ack_comb;
    wire long_err_comb;
    wire aborted;
    wire retry;
    wire new_request;
    wire request_active;
    wire stb_hold;
    wire div_valid;

    // Frequency division logic based on clmode
    // clmode[1:0]: 00=1:1, 01=1:2, 10=1:4, 11=reserved
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_div <= 2'b00;
        end else begin
            valid_div <= valid_div + 2'b01;
        end
    end

    // Determine when to gate ACK/ERR based on clock division mode
    assign div_valid = (clmode == 2'b00) ? 1'b1 :
                       (clmode == 2'b01) ? (valid_div == 2'b01 || valid_div == 2'b11) :
                       (clmode == 2'b10) ? (valid_div == 2'b11) :
                       1'b0;

    // Abort signal: external transfer in progress but internal request withdrawn
    assign aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~(wb_ack_i | wb_err_i);

    // Retry signal: when retry counter is active
    assign retry = (retry_cntr != 7'b0);

    // Long ACK/ERR from Wishbone
    assign long_ack_comb = wb_ack_i & ~aborted_r;
    assign long_err_comb = wb_err_i & ~aborted_r;

    // New request detection
    assign new_request = biu_cyc_i & biu_stb_i & ~(wb_cyc_o & wb_stb_o);

    // Burst length counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            burst_len <= 2'b00;
        end else if (new_request) begin
            burst_len <= biu_cab_i ? 2'b11 : 2'b00;
        end else if (wb_ack_i & wb_stb_o & burst_len != 2'b00) begin
            burst_len <= burst_len - 2'b01;
        end
    end

    // Retry counter logic
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            retry_cntr <= 7'b0;
        end else if (wb_rty_i) begin
            retry_cntr <= 7'h7f;
        end else if (retry_cntr != 7'b0) begin
            retry_cntr <= retry_cntr - 7'b1;
        end
    end

    // Abort register: latches abort condition until ack/err
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            aborted_r <= 1'b0;
        end else if (long_ack_comb | long_err_comb) begin
            aborted_r <= 1'b0;
        end else if (aborted) begin
            aborted_r <= 1'b1;
        end
    end

    // Long ACK and ERR output latches (from Wishbone side)
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            long_ack_o <= 1'b0;
            long_err_o <= 1'b0;
        end else begin
            if (wb_ack_i & ~aborted_r) begin
                long_ack_o <= 1'b1;
            end else if (div_valid) begin
                long_ack_o <= 1'b0;
            end

            if (wb_err_i & ~aborted_r) begin
                long_err_o <= 1'b1;
            end else if (div_valid) begin
                long_err_o <= 1'b0;
            end
        end
    end

    // Read data latch
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_dat_sync <= 32'b0;
        end else if (wb_ack_i) begin
            wb_dat_sync <= wb_dat_i;
        end
    end

    // Output ACK and ERR signals with frequency division gating
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            biu_ack_o <= 1'b0;
            biu_err_o <= 1'b0;
            biu_dat_o <= 32'b0;
        end else begin
            if (div_valid) begin
                biu_ack_o <= long_ack_o;
                biu_err_o <= long_err_o;
            end else begin
                biu_ack_o <= 1'b0;
                biu_err_o <= 1'b0;
            end

            if (long_ack_o & div_valid) begin
                biu_dat_o <= wb_dat_sync;
            end
        end
    end

    // Wishbone command and address path
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_adr_o <= 32'b0;
            wb_sel_o <= 4'b0;
            wb_we_o <= 1'b0;
            wb_dat_o <= 32'b0;
            wb_cab_o <= 1'b0;
            wb_cti_o <= 3'b0;
            wb_bte_o <= 2'b0;
        end else if (new_request & ~retry) begin
            wb_adr_o <= biu_adr_i;
            wb_sel_o <= biu_sel_i;
            wb_we_o <= biu_we_i;
            wb_dat_o <= biu_dat_i;
            wb_cab_o <= biu_cab_i;
        end

        // CTI updates during burst
        if (rst) begin
            wb_cti_o <= 3'b000;
        end else if (new_request & ~retry) begin
            if (biu_cab_i) begin
                wb_cti_o <= 3'b010;  // Incrementing burst
            end else begin
                wb_cti_o <= 3'b111;  // End of burst (single cycle)
            end
        end else if (wb_ack_i & wb_stb_o & burst_len != 2'b00) begin
            if (burst_len == 2'b01) begin
                wb_cti_o <= 3'b111;  // Last beat of burst
            end else begin
                wb_cti_o <= 3'b010;  // Continue burst
            end
        end

        if (rst) begin
            wb_bte_o <= 2'b01;  // Fixed to 4-beat wrap
        end
    end

    // Wishbone cycle and strobe control
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
        end else begin
            // CYC logic: normal operation uses biu_cyc_i, forced active during abort
            if (aborted & ~(long_ack_comb | long_err_comb)) begin
                wb_cyc_o <= 1'b1;
            end else begin
                wb_cyc_o <= biu_cyc_i & ~retry;
            end

            // STB logic: assert when new request and not in retry
            if (new_request & ~retry) begin
                wb_stb_o <= 1'b1;
            end else if (long_ack_comb | long_err_comb) begin
                wb_stb_o <= 1'b0;
            end else if (aborted & (long_ack_comb | long_err_comb)) begin
                wb_stb_o <= 1'b0;
            end
        end
    end

endmodule

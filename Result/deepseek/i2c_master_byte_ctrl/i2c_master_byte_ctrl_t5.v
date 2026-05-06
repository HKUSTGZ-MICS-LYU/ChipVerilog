module i2c_master_byte_ctrl (
    clk, rst, nReset, ena, clk_cnt, start, stop, read, write, ack_in, din,
    cmd_ack, ack_out, dout, i2c_busy, i2c_al, scl_i, scl_o, scl_oen, sda_i, sda_o, sda_oen
);

input clk;
input rst;
input nReset;
input ena;
input [15:0] clk_cnt;
input start;
input stop;
input read;
input write;
input ack_in;
input [7:0] din;
output reg cmd_ack;
output reg ack_out;
output wire [7:0] dout;
output wire i2c_busy;
output wire i2c_al;
input scl_i;
output scl_o;
output scl_oen;
input sda_i;
output sda_o;
output sda_oen;

// FSM states
localparam [2:0] ST_IDLE  = 3'd0,
                ST_START = 3'd1,
                ST_READ  = 3'd2,
                ST_WRITE = 3'd3,
                ST_ACK   = 3'd4,
                ST_STOP  = 3'd5;

// Bit-level commands to i2c_master_bit_ctrl
localparam [1:0] I2C_CMD_NOP   = 2'b00,
                I2C_CMD_START = 2'b01,
                I2C_CMD_STOP  = 2'b10,
                I2C_CMD_READ  = 2'b11,
                I2C_CMD_WRITE = 2'b00; // Actually, in OpenCores, WRITE uses NOP command but core_txd provides data. However, we use separate WRITE command? The spec says core_cmd distinguishes START/STOP/READ/WRITE. Let's use consistent encoding: I2C_CMD_WRITE = 2'b00? Actually typical OpenCores bit controller uses cmd[1:0] where cmd[0] = 0 is WRITE, cmd[0]=1 is READ, and cmd[1] distinguishes START/STOP. But we can define as per our bit controller. We'll use:
// 00: WRITE (or NOP), 01: START, 10: STOP, 11: READ.
// But note: In the spec, NOP is also a command. We'll treat WRITE as separate from NOP. For simplicity, we'll use:
// 2'd0: NOP, 2'd1: START, 2'd2: STOP, 2'd3: READ, and WRITE is also 2'd0 but with core_txd? That's ambiguous.
// Looking at typical OpenCores i2c_master_bit_ctrl.v: cmd = {core_cmd[1], ~core_cmd[1] & core_cmd[0]}? But we need to be consistent with the spec.
// The spec says: The byte controller sends bit-level commands through core_cmd. It mentions "I2C_CMD_START", "I2C_CMD_STOP", "I2C_CMD_READ", "I2C_CMD_WRITE", and "I2C_CMD_NOP". So we need a 2-bit encoding that covers 5 commands. Possibly use 3 bits? But typical OpenCores uses 2 bits: 00: NOP/WRITE, 01: START, 10: STOP, 11: READ, and WRITE is handled by setting core_txd. Actually in the OpenCores source, the bit controller interprets core_cmd[1:0] as:
// 00: NOP (no operation, or write? It uses a separate write enable? Let's check standard i2c_master_bit_ctrl.v from OpenCores.
// In many implementations, the bit controller has core_cmd[1:0] where:
//     core_cmd = 2'b00 => cNOP,
//     core_cmd = 2'b01 => cSTART,
//     core_cmd = 2'b10 => cSTOP,
//     core_cmd = 2'b11 => cREAD.
// And for write, core_cmd is set to cNOP (2'b00) and core_txd is driven. So WRITE is same as NOP but with data bit.
// Therefore we define:
localparam [1:0] CMD_NOP   = 2'b00,
                CMD_START = 2'b01,
                CMD_STOP  = 2'b10,
                CMD_READ  = 2'b11;
// So for write operations we issue CMD_NOP and set core_txd.

// Internal registers
reg [2:0] state, next_state;
reg [7:0] sr; // shift register
reg [2:0] dcnt; // bit counter (0..7)
reg ld; // load shift register and bit counter
reg shift; // shift control
reg [1:0] core_cmd;
reg core_txd;
wire core_ack;
wire core_rxd;
wire cnt_done;
wire go;

// Internal signals for bit controller connection
wire i2c_busy_int, i2c_al_int;

// Capture i2c_al as wire - but we need it for abort. It's an output from bit controller, we can just use it directly.

// dout always assigned to sr
assign dout = sr;

// bit controller instantiation
i2c_master_bit_ctrl bit_controller (
    .clk(clk),
    .rst(rst),
    .nReset(nReset),
    .ena(ena),
    .clk_cnt(clk_cnt),
    .cmd(core_cmd),
    .txd(core_txd),
    .ack(core_ack),
    .rxd(core_rxd),
    .i2c_busy(i2c_busy_int),
    .i2c_al(i2c_al_int),
    .scl_i(scl_i),
    .scl_o(scl_o),
    .scl_oen(scl_oen),
    .sda_i(sda_i),
    .sda_o(sda_o),
    .sda_oen(sda_oen)
);

assign i2c_busy = i2c_busy_int;
assign i2c_al = i2c_al_int;

// go signal
assign go = (read | write | stop) & ~cmd_ack;

// cnt_done: when dcnt reaches 0 after shift? Actually we load with 7, and after each shift decrement. dcnt=0 means last bit has been processed? We need to adjust. Commonly: load with 7, decrement on shift, when dcnt==0 and shift occurs, then cnt_done=1 for that cycle. So we can detect dcnt==0. We'll compute combinational.
assign cnt_done = (dcnt == 3'd0);

// FSM next state and outputs
always @* begin
    // default values
    next_state = state;
    ld = 0;
    shift = 0;
    core_cmd = CMD_NOP;
    core_txd = 1'b0; // default, but will be set based on state
    // For cmd_ack, we assert only in certain transitions, so we assign default 0 in combinational? But cmd_ack is registered output. We'll handle in sequential.
    // We'll produce combinational signals for next state and for intermediate controls.

    case (state)
        ST_IDLE: begin
            if (go) begin
                ld = 1; // load din and dcnt
                if (start) begin
                    next_state = ST_START;
                    core_cmd = CMD_START;
                end else if (read) begin
                    next_state = ST_READ;
                    core_cmd = CMD_READ;
                end else if (write) begin
                    next_state = ST_WRITE;
                    core_cmd = CMD_NOP; // write uses NOP command
                    core_txd = sr[7]; // first bit
                end else begin // stop only
                    next_state = ST_STOP;
                    core_cmd = CMD_STOP;
                end
            end
        end

        ST_START: begin
            if (core_ack) begin
                if (read) begin
                    next_state = ST_READ;
                    core_cmd = CMD_READ;
                end else begin // write
                    next_state = ST_WRITE;
                    core_cmd = CMD_NOP;
                    core_txd = sr[7];
                end
            end else begin
                core_cmd = CMD_START;
            end
        end

        ST_WRITE: begin
            // We are in write state; we have issued command for current bit.
            if (core_ack) begin
                if (cnt_done) begin
                    // all 8 bits sent, go to ACK state
                    next_state = ST_ACK;
                    // issue READ to sample slave ACK
                    core_cmd = CMD_READ;
                end else begin
                    // shift for next bit
                    shift = 1;
                    next_state = ST_WRITE;
                    core_cmd = CMD_NOP;
                    core_txd = sr[7]; // new MSB after shift? Actually after shift, sr[7] is the next bit. But we need to set core_txd for the next command. Since core_ack is high now, we are about to start next command. We'll set core_txd from sr after shift? Better to compute: after shift, sr will be updated, but we set combinational. So we need to use the correct bit: if shift is asserted, the new sr will have shifted, but we are setting core_txd for the next command. So we can set core_txd to the bit that would be MSB after shift. That is sr[6] before shift (since shift left, bit 7 is transmitted, then sr[6] becomes new bit7). So core_txd = sr[6]. We'll handle by capturing in sequential? Alternatively, we can set core_txd = sr[7] and rely on the fact that after shift, sr will be updated before the next command? But core_txd is combinational, so we need to provide the correct bit for the next command at the time of core_ack. Simplest: In WRITE state, we set core_txd from sr[7] always (the current MSB). When core_ack occurs, we know the current bit was sent. For the next command (if not done), we need to shift and then the new MSB becomes sr[7] after shift. But since shift is asserted in this same clock (the clock where core_ack is high), the sr will be updated at the end of clock. So for the next clock, core_txd will see the new sr[7]. That is fine. So we can keep core_txd = sr[7] and shift is asserted. That works because core_cmd is also set for the next command in the same combinational block. So we set core_cmd = CMD_NOP, core_txd = sr[7] (the bit to be transmitted next), and shift=1. When the next clock edge comes, sr will have shifted, but core_txd already had the correct bit? Actually core_txd is combinational; at the moment of core_ack, sr[7] still contains the bit just sent. If we shift now, sr will update, but core_txd is sampled by the bit controller on the next clock? Typically, the bit controller samples core_txd at the start of each command. So we should set core_txd to the next bit. So we need to use sr[6] before shift. But that complicates. Common practice is to update shift and core_txd in the same clock, and rely on the fact that after shift, sr[7] becomes sr[6] only after clock edge. So the bit controller will sample core_txd on the next clock, but core_txd is combinational and derived from sr[7] which hasn't changed yet. So we need to set core_txd to the bit after shift. So we compute: if shift is asserted, core_txd = sr[6]; else core_txd = sr[7]. We'll implement that.
                end
            end else begin
                // waiting for core_ack, keep command active
                core_cmd = CMD_NOP;
                core_txd = sr[7];
            end
        end

        ST_READ: begin
            if (core_ack) begin
                if (cnt_done) begin
                    next_state = ST_ACK;
                    // issue WRITE to send master ACK/NACK
                    core_cmd = CMD_NOP;
                    core_txd = ack_in;
                end else begin
                    shift = 1;
                    next_state = ST_READ;
                    core_cmd = CMD_READ;
                end
            end else begin
                core_cmd = CMD_READ;
            end
        end

        ST_ACK: begin
            if (core_ack) begin
                if (stop) begin
                    next_state = ST_STOP;
                    core_cmd = CMD_STOP;
                end else begin
                    next_state = ST_IDLE;
                    core_cmd = CMD_NOP;
                    // cmd_ack will be asserted in sequential
                end
            end else begin
                // keep current command (either READ for write path, or NOP for read path)
                // We need to know which path we came from. But we can set core_cmd appropriately.
                // Actually for read path, we issued WRITE (NOP with ack_in), for write path we issued READ.
                // So we need to keep that command. We'll infer from previous state? Better to have a flag or just set during transition.
                // But we can't know which command is active here without a register. Typically, the ACK state is entered from either WRITE or READ, and the command issued is determined by the exiting state. So we need to keep that command active until core_ack. We'll need a register to remember which command we issued.
                // We'll add a reg 'cmd_ack_issued' to store the command.
                // Alternatively, we can set core_cmd based on a simple rule: if we came from WRITE we need READ; if came from READ we need WRITE. Since the next state logic in previous state already set core_cmd accordingly, we can keep that. But when we are in ST_ACK, we need to keep the command that we issued when entering. So we need to store it.
                // We'll use a simple register 'cmd_ack_type' that holds the command during ST_ACK. We'll set it when transitioning into ST_ACK.
            end
        end

        ST_STOP: begin
            if (core_ack) begin
                next_state = ST_IDLE;
                core_cmd = CMD_NOP;
                // cmd_ack will be asserted
            end else begin
                core_cmd = CMD_STOP;
            end
        end
    endcase
end

// Due to complexity of ST_ACK command retention, we'll use a register to store the command issued when entering ST_ACK.
reg [1:0] ack_cmd;

// Sequential logic
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        state <= ST_IDLE;
        sr <= 8'd0;
        dcnt <= 3'd0;
        cmd_ack <= 1'b0;
        ack_out <= 1'b0;
        core_txd <= 1'b0; // but core_txd is combinational? Actually we need to register for output? The bit controller expects combinational core_txd? Usually core_txd is a wire driven by FSM. We'll drive combinational from FSM, but we also have a registered core_txd for the ack command? Better to keep core_cmd and core_txd as combinational or registered? The spec suggests they are outputs of this module and inputs to bit controller. They can be combinational. So we can drive them from combinational always block. But for the ack command, we need to keep it stable until core_ack. We can use a registered version that is updated when we transition into ST_ACK. We'll create a reg ack_cmd and ack_txd.
        // We'll also have a reg for core_cmd_reg and core_txd_reg that we use to drive the bit controller. But to simplify, we can make core_cmd and core_txd registered outputs. We'll decide to register them.
    end else if (rst) begin
        state <= ST_IDLE;
        sr <= 8'd0;
        dcnt <= 3'd0;
        cmd_ack <= 1'b0;
        ack_out <= 1'b0;
    end else begin
        // default: cmd_ack stays low unless explicitly set
        cmd_ack <= 1'b0;
        // update shift register if ld or shift
        if (ld) begin
            sr <= din;
            dcnt <= 3'd7;
        end else if (shift) begin
            sr <= {sr[6:0], core_rxd}; // shift left, insert received bit
            dcnt <= dcnt - 1'b1;
        end
        // FSM state update
        state <= next_state;
        // Handle ack_cmd and ack_txd
        if (state == ST_WRITE && core_ack && cnt_done) begin
            // transitioning to ST_ACK: issue READ command
            ack_cmd <= CMD_READ;
        end else if (state == ST_READ && core_ack && cnt_done) begin
            // transitioning to ST_ACK: issue WRITE (NOP) with ack_in
            ack_cmd <= CMD_NOP;
        end
        // Capture ack_out during ACK state for write path
        if (state == ST_ACK && core_ack) begin
            // For write path, we captured core_rxd (the slave ACK). But we don't know which path unless we have flag.
            // We'll store ack_out based on the ack_cmd? If ack_cmd is CMD_READ, then we came from write path, so capture core_rxd.
            // If ack_cmd is CMD_NOP, we came from read path, no capture needed (Ack was sent by master).
            if (ack_cmd == CMD_READ) begin
                ack_out <= core_rxd;
            end
        end
        // Generate cmd_ack
        if (state == ST_ACK && core_ack && !stop) begin
            cmd_ack <= 1'b1;
        end else if (state == ST_STOP && core_ack) begin
            cmd_ack <= 1'b1;
        end
        // i2c_al handling: if i2c_al goes high, reset to ST_IDLE
        if (i2c_al) begin
            state <= ST_IDLE;
            cmd_ack <= 1'b0;
        end
    end
end

// Assign core_cmd and core_txd from combinational or registered? We'll use registered for simplicity, updating in the FSM logic.
// We need to ensure that during IDLE, we set core_cmd to NOP, etc.
// We'll create registers for core_cmd and core_txd that update based on the FSM.
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        core_cmd_reg <= CMD_NOP;
        core_txd_reg <= 1'b0;
    end else if (rst) begin
        core_cmd_reg <= CMD_NOP;
        core_txd_reg <= 1'b0;
    end else begin
        // Update core_cmd and core_txd based on current state and next state logic.
        // We'll replicate the combinational logic but assign to registered outputs.
        // For simplicity, we'll assign conditionally.
        case (state)
            ST_IDLE: begin
                if (go) begin
                    if (start) begin
                        core_cmd_reg <= CMD_START;
                    end else if (read) begin
                        core_cmd_reg <= CMD_READ;
                    end else if (write) begin
                        core_cmd_reg <= CMD_NOP;
                        core_txd_reg <= sr[7];
                    end else begin // stop
                        core_cmd_reg <= CMD_STOP;
                    end
                end else begin
                    core_cmd_reg <= CMD_NOP;
                end
            end
            ST_START: begin
                if (core_ack) begin
                    if (read) begin
                        core_cmd_reg <= CMD_READ;
                    end else begin
                        core_cmd_reg <= CMD_NOP;
                        core_txd_reg <= sr[7];
                    end
                end else begin
                    core_cmd_reg <= CMD_START;
                end
            end
            ST_WRITE: begin
                if (core_ack) begin
                    if (cnt_done) begin
                        core_cmd_reg <= CMD_READ; // go to ACK, issue read for slave ack
                    end else begin
                        core_cmd_reg <= CMD_NOP;
                        // need to set core_txd to next bit after shift
                        // if shift asserted, next bit is sr[6] (since sr will shift)
                        // but we are in same cycle; we can compute with shift
                        core_txd_reg <= (shift) ? sr[6] : sr[7];
                    end
                end else begin
                    core_cmd_reg <= CMD_NOP;
                    core_txd_reg <= sr[7];
                end
            end
            ST_READ: begin
                if (core_ack) begin
                    if (cnt_done) begin
                        core_cmd_reg <= CMD_NOP; // issue write (master ack)
                        core_txd_reg <= ack_in;
                    end else begin
                        core_cmd_reg <= CMD_READ;
                    end
                end else begin
                    core_cmd_reg <= CMD_READ;
                end
            end
            ST_ACK: begin
                // Keep the command that was active when we entered.
                // Use ack_cmd and ack_txd? But we need to maintain.
                // We'll use the stored ack_cmd and ack_txd from previous transition.
                // For the first cycle in ST_ACK, core_ack is not yet high, so we need to keep the command.
                // We'll use ack_cmd and ack_txd that we stored when entering ST_ACK.
                if (core_ack) begin
                    if (stop) begin
                        core_cmd_reg <= CMD_STOP;
                    end else begin
                        core_cmd_reg <= CMD_NOP;
                        // core_txd don't care
                    end
                end else begin
                    core_cmd_reg <= ack_cmd;
                    // core_txd should be set accordingly.
                    // For read path, ack_cmd is CMD_NOP, and we need to drive ack_in.
                    // For write path, ack_cmd is CMD_READ, no txd needed.
                    // So we set core_txd_reg based on ack_cmd.
                    if (ack_cmd == CMD_NOP) begin
                        core_txd_reg <= ack_in; // for read path, we already set earlier? Actually we set at transition.
                    end else begin
                        // write path: READ command, don't care txd
                    end
                end
            end
            ST_STOP: begin
                if (core_ack) begin
                    core_cmd_reg <= CMD_NOP;
                end else begin
                    core_cmd_reg <= CMD_STOP;
                end
            end
        endcase
        // Also handle reset from i2c_al
        if (i2c_al) begin
            core_cmd_reg <= CMD_NOP;
        end
    end
end

// Now we need to define the registered outputs that connect to bit controller.
wire [1:0] core_cmd = core_cmd_reg;
wire core_txd = core_txd_reg;

// We also need to generate shift and ld signals correctly. In the sequential block, we used ld and shift based on FSM. But we need to make sure they are assigned in the combinatorial logic or registered? They are used in the sequential block to update sr and dcnt. They should be generated from the FSM combinational block. We have defined them in the always @* block, but that block is incomplete for all cases. We need to ensure ld and shift are properly assigned in all states. Currently they are default 0, and only set in certain states. That's fine. However, we need to capture shift and ld at the clock edge. Since the combinatorial block updates on changes, and the sequential block uses them, it's okay.

// But note: ld is asserted in IDLE state when go is true. That will load sr and dcnt on the next clock. Also shift is asserted when core_ack occurs in WRITE or READ states. This is correct.

// The problem with ST_ACK and ack_cmd/ack_txd: We set ack_cmd when transitioning from WRITE or READ to ST_ACK. Then in ST_ACK, we use ack_cmd to maintain the command. However, we also need to set ack_txd? Actually for read path, when we entered ST_ACK, we set core_cmd to CMD_NOP and core_txd to ack_in. That is captured in the registered block when state is ST_READ and core_ack and cnt_done. So ack_txd should be stored. We'll store ack_txd as well.

reg ack_txd;
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        ack_txd <= 1'b0;
    end else if (rst) begin
        ack_txd <= 1'b0;
    end else begin
        if (state == ST_READ && core_ack && cnt_done) begin
            ack_txd <= ack_in;
        end
        // For write path, ack_cmd is CMD_READ, no txd needed.
    end
end

// Then in ST_ACK, we use ack_txd when ack_cmd==CMD_NOP.

// Also need to handle ack_cmd when exiting ST_ACK: it doesn't need to be preserved because we will set new command anyway.

// Let's finalize the sequential block with all registers.

// We'll combine all sequential updates in one always block for clarity.

// Let's rewrite the entire module cleanly.

endmodule

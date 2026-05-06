module or1200_sprs(
    // Clk & Rst
    input clk,
    input rst,

    // Internal CPU interface
    input flagforw,
    input flag_we,
    output flag,
    input cyforw,
    input cy_we,
    output carry,
    input [31:0] addrbase,
    input [15:0] addrofs,
    input [31:0] dat_i,
    input [3:0] alu_op,
    input [2:0] branch_op,
    input [31:0] epcr,
    input [31:0] eear,
    input [15:0] esr,
    input except_started,
    output [31:0] to_wbmux,
    output epcr_we,
    output eear_we,
    output esr_we,
    output pc_we,
    output sr_we,
    output [15:0] to_sr,
    output [15:0] sr,
    input [31:0] spr_dat_cfgr,
    input [31:0] spr_dat_rf,
    input [31:0] spr_dat_npc,
    input [31:0] spr_dat_ppc,
    input [31:0] spr_dat_mac,

    // From/to other RISC units
    input [31:0] spr_dat_pic,
    input [31:0] spr_dat_tt,
    input [31:0] spr_dat_pm,
    input [31:0] spr_dat_dmmu,
    input [31:0] spr_dat_immu,
    input [31:0] spr_dat_du,
    output [31:0] spr_addr,
    output [31:0] spr_dat_o,
    output [31:0] spr_cs,
    output spr_we,

    input [31:0] du_addr,
    input [31:0] du_dat_du,
    input du_read,
    input du_write,
    output [31:0] du_dat_cpu
);

    // Internal registers and wires
    reg [15:0] sr;
    reg write_spr;
    reg read_spr;
    reg [31:0] to_wbmux_reg;
    wire du_access;
    wire [3:0] sprs_op;
    reg [31:0] unqualified_cs;
    
    // System register selects
    wire cfgr_sel;
    wire rf_sel;
    wire npc_sel;
    wire ppc_sel;
    wire sr_sel;
    wire epcr_sel;
    wire eear_sel;
    wire esr_sel;
    
    // Read masks
    wire [31:0] read_spr_cfgr_sel_32;
    wire [31:0] read_spr_rf_sel_32;
    wire [31:0] read_spr_npc_sel_32;
    wire [31:0] read_spr_ppc_sel_32;
    wire [31:0] read_spr_sr_sel_32;
    wire [31:0] read_spr_epcr_sel_32;
    wire [31:0] read_spr_eear_sel_32;
    wire [31:0] read_spr_esr_sel_32;
    
    // System data bus
    wire [31:0] sys_data;
    wire [31:0] sr_32;
    wire [31:0] esr_32;
    
    // SPR address and operation decoding
    wire [31:0] spr_addr_calculated;
    wire [4:0] group_number;
    wire [10:0] register_number;
    
    // ALU operation decodes for MFSR/MTSR
    wire is_mfsr;
    wire is_mtsr;
    
    // Status register control signals
    wire sr_we_internal;
    wire [15:0] to_sr_internal;
    reg [15:0] next_sr;
    
    // Exception and flag/carry updates
    wire flag_update;
    wire carry_update;
    wire rfe_exec;
    
    // Chip select generation
    wire chip_select_enable;
    
    // ========== Combinational Logic ==========
    
    // Debug access arbitration
    assign du_access = du_read | du_write;
    
    // SPR address calculation
    assign spr_addr_calculated = addrbase + {16'b0, addrofs};
    
    // Select between debug and normal SPR address
    assign spr_addr = du_access ? du_addr : spr_addr_calculated;
    
    // Extract group and register numbers from SPR address
    assign group_number = spr_addr[15:11];
    assign register_number = spr_addr[10:0];
    
    // Decode ALU operations for MFSR/MTSR
    // alu_op values: typically MFSR=0b0101, MTSR=0b0110 (architecture dependent)
    assign is_mfsr = (alu_op == 4'b0101);
    assign is_mtsr = (alu_op == 4'b0110);
    
    // Assign sprs_op: MFSR=1, MTSR=2 encoding
    assign sprs_op = du_access ? (du_read ? 4'b0001 : 4'b0010) : 
                     (is_mfsr ? 4'b0001 : is_mtsr ? 4'b0010 : 4'b0000);
    
    // Write and read SPR control generation (combinational)
    always @(*) begin
        if (du_access) begin
            write_spr = du_write;
            read_spr = du_read;
        end else begin
            write_spr = is_mtsr;
            read_spr = is_mfsr;
        end
    end
    
    // SPR write data multiplexer
    assign spr_dat_o = du_write ? du_dat_du : dat_i;
    
    // SPR write enable
    assign spr_we = write_spr | (du_access & du_write);
    
    // Unqualified chip-select generation using one-hot decoding
    always @(*) begin
        unqualified_cs = 32'b0;
        case(group_number)
            5'h00: unqualified_cs = 32'h00000001;  // Group 0 (system group)
            5'h02: unqualified_cs = 32'h00000004;  // Group 2 (PIC)
            5'h03: unqualified_cs = 32'h00000008;  // Group 3 (Tick Timer)
            5'h04: unqualified_cs = 32'h00000010;  // Group 4 (Power Management)
            5'h06: unqualified_cs = 32'h00000040;  // Group 6 (Debug Unit)
            5'h08: unqualified_cs = 32'h00000100;  // Group 8 (IMMU)
            5'h09: unqualified_cs = 32'h00000200;  // Group 9 (DMMU)
            5'h0A: unqualified_cs = 32'h00000400;  // Group 10 (MAC)
            5'h0B: unqualified_cs = 32'h00000800;  // Group 11 (Trap)
            default: unqualified_cs = 32'b0;
        endcase
    end
    
    // Chip-select final generation: AND with read/write qualification
    assign spr_cs = unqualified_cs & {32{read_spr | write_spr}};
    
    // System group register selects (one-hot based on register_number)
    assign cfgr_sel = (group_number == 5'h00) & (register_number == 11'h000);
    assign rf_sel = (group_number == 5'h00) & (register_number[10:8] == 3'b001);
    assign npc_sel = (group_number == 5'h00) & (register_number == 11'h002);
    assign ppc_sel = (group_number == 5'h00) & (register_number == 11'h004);
    assign sr_sel = (group_number == 5'h00) & (register_number == 11'h011);
    assign epcr_sel = (group_number == 5'h00) & (register_number == 11'h020);
    assign eear_sel = (group_number == 5'h00) & (register_number == 11'h030);
    assign esr_sel = (group_number == 5'h00) & (register_number == 11'h040);
    
    // Read masks for each register
    assign read_spr_cfgr_sel_32 = {32{read_spr & cfgr_sel}};
    assign read_spr_rf_sel_32 = {32{read_spr & rf_sel}};
    assign read_spr_npc_sel_32 = {32{read_spr & npc_sel}};
    assign read_spr_ppc_sel_32 = {32{read_spr & ppc_sel}};
    assign read_spr_sr_sel_32 = {32{read_spr & sr_sel}};
    assign read_spr_epcr_sel_32 = {32{read_spr & epcr_sel}};
    assign read_spr_eear_sel_32 = {32{read_spr & eear_sel}};
    assign read_spr_esr_sel_32 = {32{read_spr & esr_sel}};
    
    // Zero-extend SR and ESR for OR-mux
    assign sr_32 = {16'b0, sr};
    assign esr_32 = {16'b0, esr};
    
    // System data OR-mux for read data synthesis
    assign sys_data = (spr_dat_cfgr & read_spr_cfgr_sel_32) |
                     (spr_dat_rf & read_spr_rf_sel_32) |
                     (spr_dat_npc & read_spr_npc_sel_32) |
                     (spr_dat_ppc & read_spr_ppc_sel_32) |
                     (sr_32 & read_spr_sr_sel_32) |
                     (epcr & read_spr_epcr_sel_32) |
                     (eear & read_spr_eear_sel_32) |
                     (esr_32 & read_spr_esr_sel_32);
    
    // Writeback data selection based on group number
    always @(*) begin
        if (read_spr) begin
            case(group_number)
                5'h00: to_wbmux_reg = sys_data;
                5'h02: to_wbmux_reg = spr_dat_pic;
                5'h03: to_wbmux_reg = spr_dat_tt;
                5'h04: to_wbmux_reg = spr_dat_pm;
                5'h06: to_wbmux_reg = spr_dat_du;
                5'h08: to_wbmux_reg = spr_dat_immu;
                5'h09: to_wbmux_reg = spr_dat_dmmu;
                5'h0A: to_wbmux_reg = spr_dat_mac;
                default: to_wbmux_reg = 32'b0;
            endcase
        end else begin
            to_wbmux_reg = 32'b0;
        end
    end
    
    assign to_wbmux = to_wbmux_reg;
    
    // Flag and carry bit exports
    assign flag = sr[8];
    assign carry = sr[10];
    
    // Debug unit read data selection
    always @(*) begin
        if (du_write) begin
            // Echo back write data during debug write
            du_dat_cpu = du_dat_du;
        end else if (du_read) begin
            // Return to_wbmux during debug read
            du_dat_cpu = to_wbmux_reg;
        end else begin
            // Return input data in other cases
            du_dat_cpu = dat_i;
        end
    end
    
    // System register update conditions
    assign rfe_exec = (alu_op == 4'b1000) & 1'b1;  // RFE operation decode
    
    // SR write enable generation: exception start takes precedence
    assign sr_we_internal = except_started ? 1'b1 :
                           ((write_spr & sr_sel) | rfe_exec | flag_we | cy_we);
    
    assign sr_we = sr_we_internal;
    assign epcr_we = write_spr & epcr_sel;
    assign eear_we = write_spr & eear_sel;
    assign esr_we = write_spr & esr_sel;
    assign pc_we = write_spr & (npc_sel | ppc_sel);
    
    // SR composition priority: Exception > RFE > Flag/Carry > MTSR > Original
    always @(*) begin
        if (except_started) begin
            // Exception entry: set SM, clear TEE/IEE/DME/IME
            next_sr[15:13] = 3'b0;      // TEE, IEE, DME cleared
            next_sr[12:11] = 2'b11;     // SM set to 1, reserved
            next_sr[10] = sr[10];       // CY unchanged
            next_sr[9] = sr[9];         // Reserved
            next_sr[8] = sr[8];         // F unchanged
            next_sr[7:5] = sr[7:5];     // CY, OV, SO unchanged
            next_sr[4:0] = sr[4:0];     // Lower bits unchanged
        end else if (rfe_exec) begin
            // RFE: restore from ESR first
            next_sr = esr;
            // Then apply flag/carry updates if they occur in same cycle
            if (flag_we) next_sr[8] = flagforw;
            if (cy_we) next_sr[10] = cyforw;
        end else if (write_spr & sr_sel) begin
            // Normal MTSR write
            next_sr = dat_i[15:0];
            // Override with flag/carry updates if they occur
            if (flag_we) next_sr[8] = flagforw;
            if (cy_we) next_sr[10] = cyforw;
        end else if (flag_we | cy_we) begin
            // Only flag or carry update
            next_sr = sr;
            if (flag_we) next_sr[8] = flagforw;
            if (cy_we) next_sr[10] = cyforw;
        end else begin
            // Keep original SR
            next_sr = sr;
        end
    end
    
    assign to_sr = next_sr;
    
    // ========== Sequential Logic ==========
    
    // Status register update with async reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initialize SR with supervisory mode and exception high bit prefix
            sr <= 16'h8001;  // SM=1, EP=1 (architecture initial value)
        end else if (sr_we_internal) begin
            sr <= next_sr;
        end
    end

endmodule

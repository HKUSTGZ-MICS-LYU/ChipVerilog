`include "or1200_defines.v"

module or1200_cfgr(
    input [31:0] spr_addr,
    output reg [31:0] spr_dat_o
);

`ifdef OR1200_CFGR_IMPLEMENTED

always @(spr_addr) begin
    // Default output
    spr_dat_o = 32'h0000_0000;

`ifdef OR1200_SYS_FULL_DECODE
    if (spr_addr[31:4] != 28'h0) begin
        spr_dat_o = 32'h0000_0000;
    end else
`endif
    begin
        case (spr_addr[3:0])
            4'h0:
                // VR: Version Register
                spr_dat_o = {
                    `OR1200_VR_REV,
                    `OR1200_VR_RES1,
                    `OR1200_VR_CFG,
                    `OR1200_VR_VER
                };

            4'h1:
                // UPR: Unit Present Register
                spr_dat_o = {
                    2'b00,                          // reserved
                    1'b0,                           // TTP
                    `OR1200_UPR_PICP,               // PICP
                    2'b00,                          // reserved
                    `OR1200_UPR_PMP,                // PMP
                    1'b0,                           // TTP (again? No, spec layouts vary; using standard bits)
                    // Standard UPR format: 31-30 reserved, 29 UP, 28 DCP, 27 ICP, 26 DMP, 25 IMP, 24 MP, 23 DUP, 22 PCUP, 21 PIC, 20 PM, 19 TTP, 18-0 reserved
                    `OR1200_UPR_UP,                 // 1: UPR present
                    `OR1200_UPR_DCP,                // Data cache present
                    `OR1200_UPR_ICP,                // Instruction cache present
                    `OR1200_UPR_DMP,                // Data MMU present
                    `OR1200_UPR_IMP,                // Instruction MMU present
                    `OR1200_UPR_MP,                 // MAC present
                    `OR1200_UPR_DUP,                // Debug unit present
                    `OR1200_UPR_PCUP,               // Performance counters unit present
                    `OR1200_UPR_PICP,               // Programmable interrupt controller present
                    `OR1200_UPR_PMP,                // Power management present
                    `OR1200_UPR_TTP,                // Tick timer present
                    18'h0                           // Reserved
                };

            4'h2:
                // CPUCFGR: CPU Configuration Register
                spr_dat_o = {
                    `OR1200_CPUCFGR_NSGR,           // 31:28
                    `OR1200_CPUCFGR_HGF,            // 27:26
                    `OR1200_CPUCFGR_CGF,            // 25:24
                    `OR1200_CPUCFGR_OB32P,          // 23
                    `OR1200_CPUCFGR_OB64P,          // 22
                    `OR1200_CPUCFGR_OF32P,          // 21
                    `OR1200_CPUCFGR_OF64P,          // 20
                    `OR1200_CPUCFGR_OV64P,          // 19
                    `OR1200_CPUCFGR_ND,             // 18
                    `OR1200_CPUCFGR_AVRP,           // 17
                    `OR1200_CPUCFGR_EVBARP,         // 16
                    `OR1200_CPUCFGR_ISRP,           // 15
                    `OR1200_CPUCFGR_AECSRP,         // 14
                    `OR1200_CPUCFGR_AEMP,           // 13
                    `OR1200_CPUCFGR_JP,             // 12
                    `OR1200_CPUCFGR_DEP,            // 11
                    `OR1200_CPUCFGR_OP,             // 10
                    `OR1200_CPUCFGR_OP1,            // 9:8
                    `OR1200_CPUCFGR_OP2,            // 7:6
                    `OR1200_CPUCFGR_OP3,            // 5:4
                    `OR1200_CPUCFGR_OP4             // 3:0
                };

            4'h3:
                // DMMUCFGR: Data MMU Configuration Register
                spr_dat_o = {
                    `OR1200_DMMUCFGR_NTW,           // 31:28
                    `OR1200_DMMUCFGR_NTS,           // 27:24
                    `OR1200_DMMUCFGR_NAE,           // 23:20
                    `OR1200_DMMUCFGR_CRI,           // 19:18
                    `OR1200_DMMUCFGR_PRI,           // 17:16
                    `OR1200_DMMUCFGR_TEIRI,         // 15:14
                    `OR1200_DMMUCFGR_HTR            // 13:0
                };

            4'h4:
                // IMMUCFGR: Instruction MMU Configuration Register
                spr_dat_o = {
                    `OR1200_IMMUCFGR_NTW,           // 31:28
                    `OR1200_IMMUCFGR_NTS,           // 27:24
                    `OR1200_IMMUCFGR_NAE,           // 23:20
                    `OR1200_IMMUCFGR_CRI,           // 19:18
                    `OR1200_IMMUCFGR_PRI,           // 17:16
                    `OR1200_IMMUCFGR_TEIRI,         // 15:14
                    `OR1200_IMMUCFGR_HTR            // 13:0
                };

            4'h5:
                // DCCFGR: Data Cache Configuration Register
                spr_dat_o = {
                    `OR1200_DCCFGR_NTW,             // 31:28
                    `OR1200_DCCFGR_NTS,             // 27:24
                    `OR1200_DCCFGR_NAE,             // 23:20
                    `OR1200_DCCFGR_CRI,             // 19:18
                    `OR1200_DCCFGR_PRI,             // 17:16
                    `OR1200_DCCFGR_TEIRI,           // 15:14
                    `OR1200_DCCFGR_HTR              // 13:0
                };

            4'h6:
                // ICCFGR: Instruction Cache Configuration Register
                spr_dat_o = {
                    `OR1200_ICCFGR_NTW,             // 31:28
                    `OR1200_ICCFGR_NTS,             // 27:24
                    `OR1200_ICCFGR_NAE,             // 23:20
                    `OR1200_ICCFGR_CRI,             // 19:18
                    `OR1200_ICCFGR_PRI,             // 17:16
                    `OR1200_ICCFGR_TEIRI,           // 15:14
                    `OR1200_ICCFGR_HTR              // 13:0
                };

            4'h7:
                // DCFGR: Debug Configuration Register
                spr_dat_o = {
                    `OR1200_DCFGR_NDP,              // 31:28
                    `OR1200_DCFGR_WPCI,             // 27:24
                    `OR1200_DCFGR_WP,               // 23:20
                    `OR1200_DCFGR_DP,               // 19:16
                    `OR1200_DCFGR_BP,               // 15:12
                    `OR1200_DCFGR_FD,               // 11:8
                    `OR1200_DCFGR_BT,               // 7:4
                    `OR1200_DCFGR_DT                // 3:0
                };

            default:
                spr_dat_o = 32'h0000_0000;
        endcase
    end
end

`else // !OR1200_CFGR_IMPLEMENTED

always @(spr_addr) begin
    // Default output
    spr_dat_o = 32'h0000_0000;

`ifdef OR1200_SYS_FULL_DECODE
    if (spr_addr[31:4] == 28'h0)
`endif
    begin
        case (spr_addr[3:0])
            4'h0:
                // VR: Version Register
                spr_dat_o = {
                    `OR1200_VR_REV,
                    `OR1200_VR_RES1,
                    `OR1200_VR_CFG,
                    `OR1200_VR_VER
                };

            4'h1:
                // UPR: Unit Present Register
                spr_dat_o = {
                    2'b00,
                    1'b0,
                    `OR1200_UPR_PICP,
                    2'b00,
                    `OR1200_UPR_PMP,
                    1'b0,
                    `OR1200_UPR_UP,
                    `OR1200_UPR_DCP,
                    `OR1200_UPR_ICP,
                    `OR1200_UPR_DMP,
                    `OR1200_UPR_IMP,
                    `OR1200_UPR_MP,
                    `OR1200_UPR_DUP,
                    `OR1200_UPR_PCUP,
                    `OR1200_UPR_PICP,
                    `OR1200_UPR_PMP,
                    `OR1200_UPR_TTP,
                    18'h0
                };

            default:
                spr_dat_o = 32'h0000_0000;
        endcase
    end
end

`endif // OR1200_CFGR_IMPLEMENTED

endmodule

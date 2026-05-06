// or1200_dmmu_tlb.v
//
// OR1200 Data MMU TLB: entry storage, SPR access, decode, and hit logic.

module or1200_dmmu_tlb
  (
   input         clk,
   input         rst,

   // I/F for translation
   input         tlb_en,
   input  [31:0] vaddr,
   output        hit,
   output [31:13] ppn,
   output        uwe,
   output        ure,
   output        swe,
   output        sre,
   output        ci,

`ifdef OR1200_BIST
   // RAM BIST
   input mbist_si_i,
   output mbist_so_o,
   input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

   // SPR access
   input         spr_cs,
   input         spr_write,
   input  [31:0] spr_addr,
   input  [31:0] spr_dat_i,
   output [31:0] spr_dat_o
   );

   // Local parameters
   localparam DTLB_INDXW = 6;
   localparam DTLB_ENTRIES = 64;

   // Match RAM width: 13 bits VPN + 1 bit V = 14
   localparam MR_WIDTH = 14;
   // Translate RAM width: 19 bits PPN + 4 perms + 1 CI = 24
   localparam TR_WIDTH = 24;

   // Internal signals
   wire [DTLB_INDXW-1:0] tlb_index;
   wire                  tlb_mr_en;
   wire                  tlb_tr_en;
   wire                  tlb_mr_we;
   wire                  tlb_tr_we;
   wire [MR_WIDTH-1:0]   tlb_mr_ram_in;
   wire [MR_WIDTH-1:0]   tlb_mr_ram_out;
   wire [TR_WIDTH-1:0]   tlb_tr_ram_in;
   wire [TR_WIDTH-1:0]   tlb_tr_ram_out;
   wire [31:19]          vpn;
   wire                  v;
   wire [31:13]          ppn_int;
   wire                  swe_int, sre_int, uwe_int, ure_int, ci_int;

   // Index selection: SPR access has priority
   assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

   // RAM enable signals
   // Match RAM enable: translation request OR SPR match-register access
   assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
   // Translate RAM enable: translation request OR SPR translate-register access
   assign tlb_tr_en = tlb_en | (spr_cs &  spr_addr[7]);

   // RAM write enables: only during SPR writes
   assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];
   assign tlb_tr_we = spr_cs & spr_write &  spr_addr[7];

   // Match RAM write data: {vpn[31:19], v}
   assign tlb_mr_ram_in = { spr_dat_i[31:19], spr_dat_i[0] };

   // Translate RAM write data: {ppn[31:13], swe, sre, uwe, ure, ci}
   assign tlb_tr_ram_in = { spr_dat_i[31:13],
                            spr_dat_i[9],
                            spr_dat_i[8],
                            spr_dat_i[7],
                            spr_dat_i[6],
                            spr_dat_i[1] };

   // Instantiate Match RAM
`ifdef OR1200_RAM_MODELS_VIRTEX
   // Virtex-specific RAM instantiation (placeholder)
   // In a real design, this would be a Virtex RAM primitive.
   // For this implementation, we assume a behavioral equivalent is acceptable
   // to maintain functional correctness. The interface is kept identical.
   // Since no explicit Virtex model is provided, we use a generic behavioral
   // RAM with the same ports for simulation purposes.
   reg [MR_WIDTH-1:0] mr_ram [0:DTLB_ENTRIES-1];
   integer            mr_idx;
   always @(posedge clk) begin
      if (tlb_mr_we)
        mr_ram[tlb_index] <= tlb_mr_ram_in;
   end
   assign tlb_mr_ram_out = mr_ram[tlb_index];
`else
   // Generic OR1200 single-port RAM
   or1200_spram_64x14 u_match_ram (
      .clk   (clk),
      .rst   (rst),
      .ce    (tlb_mr_en),
      .we    (tlb_mr_we),
      .addr  (tlb_index),
      .di    (tlb_mr_ram_in),
      .do    (tlb_mr_ram_out)
   );
`endif

   // Instantiate Translate RAM
`ifdef OR1200_RAM_MODELS_VIRTEX
   reg [TR_WIDTH-1:0] tr_ram [0:DTLB_ENTRIES-1];
   integer            tr_idx;
   always @(posedge clk) begin
      if (tlb_tr_we)
        tr_ram[tlb_index] <= tlb_tr_ram_in;
   end
   assign tlb_tr_ram_out = tr_ram[tlb_index];
`else
   or1200_spram_64x24 u_translate_ram (
      .clk   (clk),
      .rst   (rst),
      .ce    (tlb_tr_en),
      .we    (tlb_tr_we),
      .addr  (tlb_index),
      .di    (tlb_tr_ram_in),
      .do    (tlb_tr_ram_out)
   );
`endif

   // Decode Match RAM output
   assign vpn = tlb_mr_ram_out[13:1];
   assign v   = tlb_mr_ram_out[0];

   // Decode Translate RAM output
   assign ppn_int = tlb_tr_ram_out[23:5];
   assign swe_int = tlb_tr_ram_out[4];
   assign sre_int = tlb_tr_ram_out[3];
   assign uwe_int = tlb_tr_ram_out[2];
   assign ure_int = tlb_tr_ram_out[1];
   assign ci_int  = tlb_tr_ram_out[0];

   // Hit logic: compare VPN and valid bit (not gated by tlb_en)
   assign hit = (vpn == vaddr[31:19]) & v;

   // Output assignments
   assign ppn = ppn_int;
   assign uwe = uwe_int;
   assign ure = ure_int;
   assign swe = swe_int;
   assign sre = sre_int;
   assign ci  = ci_int;

   // SPR read data output
   reg [31:0] spr_dat_o_reg;
   always @* begin
      if (spr_cs & ~spr_write) begin
         if (~spr_addr[7]) begin
            // Match register read format
            // spr_dat_o[31:19] = vpn
            // spr_dat_o[18:13] = tlb_index masked by v
            // spr_dat_o[12:1]  = reserved 0
            // spr_dat_o[0]     = v
            spr_dat_o_reg = { vpn,
                              tlb_index & {DTLB_INDXW{v}},
                              12'b0,
                              v };
         end else begin
            // Translate register read format
            // spr_dat_o[31:13] = ppn
            // spr_dat_o[12:10] = reserved 0
            // spr_dat_o[9]    = swe
            // spr_dat_o[8]    = sre
            // spr_dat_o[7]    = uwe
            // spr_dat_o[6]    = ure
            // spr_dat_o[5:2]  = reserved 0
            // spr_dat_o[1]    = ci
            // spr_dat_o[0]    = 0
            spr_dat_o_reg = { ppn_int,
                              3'b0,
                              swe_int,
                              sre_int,
                              uwe_int,
                              ure_int,
                              4'b0,
                              ci_int,
                              1'b0 };
         end
      end else begin
         spr_dat_o_reg = 32'h00000000;
      end
   end
   assign spr_dat_o = spr_dat_o_reg;

`ifdef OR1200_BIST
   // BIST support placeholder
   assign mbist_so_o = 1'b0;
`endif

endmodule

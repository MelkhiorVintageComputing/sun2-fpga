`timescale 1ns / 1ps

`define SERIAL_VZ50938

`ifdef SERIAL_VZ50938
 `define FAST_SERIAL
`else
 `define SERIAL_SUSKA
`endif

`ifdef SERIAL_SUSKA
 `define FAST_SERIAL
`endif

// `define MEM_SIM_ONLY

`define DEVICE_8BITS_ON_32BITS_BUS

`define LANCE_ETHERNET

`ifdef DEVICE_8BITS_ON_32BITS_BUS
// extract/expand low-order 8-bits
function [31:0] EXPAND_8BITS (input [7:0] VAL);
   begin
      EXPAND_8BITS = {VAL, VAL, VAL, VAL};
   end
endfunction
function [7:0] EXTRACT_8BITS (input [31:0] X, input [1:0] A);
   begin
      case (A)
	2'b11: EXTRACT_8BITS = X[ 7: 0];
	2'b10: EXTRACT_8BITS = X[15: 8];
	2'b01: EXTRACT_8BITS = X[23:16];
	2'b00: EXTRACT_8BITS = X[31:24];
      endcase
   end
endfunction
`else
// extract/expand high-order 8-bits
function [31:0] EXPAND_8BITS (input [7:0] VAL);
   begin
      EXPAND_8BITS = {VAL, 24'h000000};
   end
endfunction
function [7:0] EXTRACT_8BITS (input [31:0] X, input [1:0] A);
   begin
      EXTRACT_8BITS = X[31:24];
   end
endfunction
`endif

module sun3_fpga(/* clock, reset */
		 input 		CLK,
		 input 		clk32k768, // improveme
		 input 		clk4m9152,
		 input 		clk50m,
		 input 		sys_reset, // board reset => also CPU reset
		 /* CPU */
		 input [31:0] 	P_ADR_IN,
		 input [31:0] 	P_DATA_IN,
		 output [31:0] 	P_DATA_OUT,
		 input 		P_DATA_EN,
		 output 	P_BERR_n,
		 input 		P_RESET_n, // CPU reset, not full board
		 output 	P_HALT_n,
		 input [2:0] 	P_FC,
		 output 	P_AVEC_n,
		 output [2:0] 	P_IPL_n,
		 input 		P_IPEND_n,
		 output [1:0] 	P_DSACK_n,
		 input [1:0] 	P_SIZ,
		 input 		P_AS_n,
		 input 		P_RW_n,
		 input 		P_RMC_n,
		 input 		P_DS_n,
		 input 		P_ECS_n,
		 input 		P_OCS_n,
		 input 		P_DBEN_n,
		 input 		P_BUS_EN,
		 output 	P_STERM_n,
		 input 		P_STATUS_n,
		 input 		P_REFILL_n,
		 output 	P_BR_n,
		 input 		P_BG_n,
		 output 	P_BGACK_n,
		 /* serial */
		 output 	tx,
		 input 		rx,
		 /* kbd, mouse */
		 output 	kbd_tx,
		 input 		kbd_rx,
		 input 		mou_rx,
`ifdef LANCE_ETHERNET
`ifdef ETH_RMII
		 /* RMII eth */
		 output [1:0] 	phy_txd,
		 output 	phy_tx_en,
		 input [1:0] 	phy_rxd,
		 input 		phy_rx_er,
		 input 		phy_rx_dv,
		 input 		phy_int_n,
		 output 	phy_reset_n,
`else
		 /* MII eth */
		 output [3:0] 	phy_txd,
		 output 	phy_tx_en,
		 output 	phy_tx_er,
		 input 		phy_tx_clk,
		 input 		phy_col,
		 input [3:0] 	phy_rxd,
		 input 		phy_rx_dv,
		 input 		phy_rx_er,
		 input 		phy_rx_clk,
		 input 		phy_crs,
		 input 		phy_int_n,
		 output 	phy_reset_n,
`endif // !`ifdef ETH_RMII
		 /* debug */
		 output [63:0] 	last_dma,
		 output [255:0] iv,
`endif //  `ifdef LANCE_ETHERNET
		 /* video irq */
		 input 		V_INT,
		 /* leds, debug */
		 output [7:0] 	leds,
		 output 	en_boot,
		 input 		diag_switch,
		 //output [2:0]  berrd,
		 output [7:0] 	todebug,
		 /* wishbone */
		 output 	wb_cyc_o,
		 output 	wb_stb_o,
		 output [29:0] 	wb_adr_o,
		 output [31:0] 	wb_dat_o,
		 output [3:0] 	wb_sel_o,
		 output 	wb_we_o,
		 input [31:0] 	wb_dat_i,
		 input 		wb_ack_i
		 );
   
   //assign P_BR_n = 1'b1; // FIXME ? we have nothing doing DMA yet
   //assign P_BGACK_n = 1'b1;

   wire 		       eth_clk;
   //assign eth_clk = CLK;
   assign eth_clk = clk50m; // cannot switch to clk50m until the both bridges are updated
   

   assign P_AVEC_n = 1'b0;
   assign P_STERM_n = 1'b1; // 68k30l has sterm, '020 doesn't
   
   wire 			 EN_DEV;
   wire 			 DISACC;
   
   assign P_HALT_n = 1'b1; // FIXME ?

   // layers shortcuts
   wire FC_CTRLLAYER;
   wire FC_CPUCYCLE;
   wire FC_UDATA, FC_UPROG, FC_SDATA, FC_SPROG;
   wire FC_GENERAL;

   /* 0x0: reserved, unused */
   assign FC_UDATA     = (SUN3_FC == 3'h1);
   assign FC_UPROG     = (SUN3_FC == 3'h2);
   assign FC_CTRLLAYER = (SUN3_FC == 3'h3);
   /* 0x4: reserved, unused */
   assign FC_SDATA     = (SUN3_FC == 3'h5);
   assign FC_SPROG     = (SUN3_FC == 3'h6);
   assign FC_CPUCYCLE  = (SUN3_FC == 3'h7);
   assign FC_GENERAL   = ~FC_CTRLLAYER & ~FC_CPUCYCLE;

   wire EN_BOOT; // positive logic view of EN_BOOTn
   assign en_boot = EN_BOOT;
   
   // match wire for variable-timing area
   wire 			 MATCH_VME32_32;
`ifdef LANCE_ETHERNET
   wire 			 MATCH_AMDLE;
`endif
   wire 			 MATCH_MEM;
   wire 			 MATCH_FB;
   
   wire [31:0] 			 ethernetdma_addr_out;
   wire [31:0] 			 ethernetdma_data_out;
   wire [2:0] 			 ethernetdma_fc_out;
   wire [1:0] 			 ethernetdma_siz_out;
   wire 			 ethernetdma_as_n_out;
   wire 			 ethernetdma_ds_n_out;
   wire 			 ethernetdma_rw_n_out;
   wire [1:0] 			 ethernetdma_dsack_n;
   wire 			 ethernetdma_br_n_out;
   wire 			 ethernetdma_bg_n;
   wire 			 ethernetdma_bgack_n_out;
   
   wire [31:0] 			 SUN3_ADR_IN;
   wire [31:0] 			 SUN3_DATA_IN;
   wire [2:0] 			 SUN3_FC;
   wire [1:0] 			 SUN3_SIZ;
   wire 			 SUN3_AS_n;
   wire 			 SUN3_RW_n;
   wire 			 SUN3_DS_n;
   
`ifdef LANCE_ETHERNET
   wire 			 ethernet_dma_active = (~ethernetdma_br_n_out & ~ethernetdma_bgack_n_out);
`else
   wire 			 ethernet_dma_active = 1'b0;
   assign 			 ethernetdma_br_n_out = 1'b1;
   assign 			 ethernetdma_bgack_n_out = 1'b1;
`endif

   assign SUN3_ADR_IN  = ethernet_dma_active ? ethernetdma_addr_out : P_ADR_IN;
   assign SUN3_DATA_IN = ethernet_dma_active ? ethernetdma_data_out : P_DATA_IN;
   assign SUN3_FC      = ethernet_dma_active ? ethernetdma_fc_out   : P_FC;
   assign SUN3_SIZ     = ethernet_dma_active ? ethernetdma_siz_out  : P_SIZ;
   assign SUN3_AS_n    = ethernet_dma_active ? ethernetdma_as_n_out : P_AS_n;
   assign SUN3_RW_n    = ethernet_dma_active ? ethernetdma_rw_n_out : P_RW_n;
   assign SUN3_DS_n    = ethernet_dma_active ? ethernetdma_ds_n_out : P_DS_n;
   assign P_BR_n = ethernetdma_br_n_out; // FIXME: multiple DMA sources
   assign ethernetdma_bg_n = P_BG_n; // CHECKME: multiple DMA sources
   assign P_BGACK_n = ethernetdma_bgack_n_out; // FIXME: multiple DMA sources

`ifndef LANCE_ETHERNET
   assign todebug = {~P_RESET_n, ~P_HALT_n, ~SUN3_AS_n, P_RESET_n,
		      P_IPL_n[0] & P_IPL_n[1] & P_IPL_n[2], EN_BOOT, MATCH_PROM_BOOT, CLK};
`endif  

`ifdef LANCE_ETHERNET
   reg [63:0] 			 last_dma_reg;
   reg [255:0] 			 iv_reg;
   //reg [63:0] 			 iv_reg;
   
   assign last_dma = last_dma_reg;
   //assign last_dma = moredebug;
   
   //assign iv[255:192] = iv_reg;
   assign iv = iv_reg;
   
   
   always @(negedge CLK)
     begin
	if (ethernet_dma_active & ~P_DSACK_n[0] & ~SUN3_RW_n
	    & ( (ethernetdma_data_out[ 7: 0] == 8'hCE) |
		(ethernetdma_data_out[23:16] == 8'hCE) |
		(ethernetdma_addr_out[23:0] == 24'hF00048 )))
	  // & ~SUN3_RW_n & ~P_DSACK_n[0] /* & ~ethernetdma_rw_n_out & ~dma_rec */) // & ~P_DSACK_n[0] 
	  begin
	     last_dma_reg[31: 0] <= ethernetdma_addr_out;
	     last_dma_reg[63:32] <= ethernetdma_data_out; // P_DATA_OUT;
	     iv_reg[ 31:  0] <= last_dma_reg[31: 0];
	     iv_reg[ 63: 32] <= last_dma_reg[63:32];
	     iv_reg[ 95: 64] <= iv_reg[ 31:  0];
	     iv_reg[127: 96] <= iv_reg[ 63: 32];
	     iv_reg[159:128] <= iv_reg[ 95: 64];
	     iv_reg[191:160] <= iv_reg[127: 96];
	     iv_reg[223:192] <= iv_reg[159:128];
	     iv_reg[255:224] <= iv_reg[191:160];
	  end
	  
	//if (ethernet_dma_active & ~P_DSACK_n[0] & ~SUN3_RW_n & (ethernetdma_addr_out == 32'hFFF00048))// & ~SUN3_RW_n & ~P_DSACK_n[0] /* & ~ethernetdma_rw_n_out & ~dma_rec */) // & ~P_DSACK_n[0] 
	//  begin
	//     iv_reg[31: 0] <= ethernetdma_addr_out;
	//     iv_reg[63:32] <= ethernetdma_data_out;
	//  end
     end // always @ (negedge CLK)
`endif //  `ifdef LANCE_ETHERNET
   
   // SUN3_AS_n timing
   reg C_S3, C_S5, C_S7, C_S9;
   always @(negedge CLK)
     begin
	if (~SUN3_AS_n)        C_S3 <= 1'b1;
	if (~SUN3_AS_n & C_S3) C_S5 <= 1'b1;
	if (~SUN3_AS_n & C_S5) C_S7 <= 1'b1;
	if (~SUN3_AS_n & C_S7) C_S9 <= 1'b1;
	if ( SUN3_AS_n)
	  begin
	     C_S3 <= 1'b0;
	     C_S5 <= 1'b0;
	     C_S7 <= 1'b0;
	     C_S9 <= 1'b0;
	  end
     end
   reg C_S4r, C_S6r, C_S8r, C_S10r, C_S12r, C_S14r, C_S16r, C_S18r, TIMEOUT;
   always @(posedge CLK)
     begin
	// SUN3_AS_n deasserts on a negedge... so those can last 1/2 cycles past the end of SUN3_AS_n
	if (~SUN3_AS_n & C_S3 ) C_S4r <= 1'b1;
	if (~SUN3_AS_n & C_S4r) C_S6r <= 1'b1;
	if (~SUN3_AS_n & C_S6r) C_S8r <= 1'b1;
	if (~SUN3_AS_n & C_S8r) C_S10r <= 1'b1;
	if (~SUN3_AS_n & C_S10r) C_S12r <= 1'b1;
	if (~SUN3_AS_n & C_S12r) C_S14r <= 1'b1;
	if (~SUN3_AS_n & C_S14r) C_S16r <= 1'b1;
	if (~SUN3_AS_n & C_S16r) C_S18r <= 1'b1;
	if (~SUN3_AS_n & C_S18r & !MATCH_VME32_32 & !MATCH_MEM & !MATCH_FB // CHECKME: sun3, too soon?
`ifdef LANCE_ETHERNET
	    & !MATCH_AMDLE
`endif
	    ) TIMEOUT <= 1'b1;
	
	if ( SUN3_AS_n)
	  begin
	     C_S4r <= 1'b0;
	     C_S6r <= 1'b0;
	     C_S8r <= 1'b0;
	     C_S10r <= 1'b0;
	     C_S12r <= 1'b0;
	     C_S14r <= 1'b0;
	     C_S16r <= 1'b0;
	     C_S18r <= 1'b0;
	     TIMEOUT <= 1'b0;
	  end
     end
   wire C_S4, C_S6, C_S8, C_S10, C_S12, C_S14, C_S16, C_S18;
   assign C_S4 = C_S4r & ~SUN3_AS_n;
   assign C_S6 = C_S6r & ~SUN3_AS_n;
   assign C_S8 = C_S8r & ~SUN3_AS_n;
   assign C_S10 = C_S10r & ~SUN3_AS_n;
   assign C_S12 = C_S12r & ~SUN3_AS_n;
   assign C_S14 = C_S14r & ~SUN3_AS_n;
   assign C_S16 = C_S16r & ~SUN3_AS_n;
   assign C_S18 = C_S18r & ~SUN3_AS_n;
   
   // match wire for the control/mmu space
   // can match early because they only depend on the SUN3_A address
   wire 			 MATCH_CTX, MATCH_SMAP, MATCH_PMAP;
   wire 			 MATCH_IDPROM, MATCH_SYSEN, MATCH_BERR, MATCH_DIAG, MATCH_UARTBYP;
   assign MATCH_IDPROM  = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h0);
   assign MATCH_PMAP    = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h1); // Long
   assign MATCH_SMAP    = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h2);
   assign MATCH_CTX     = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h3);
   assign MATCH_SYSEN   = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h4);
   //assign MATCH_UDVMA   = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h5); // optional (not on 3/60)
   assign MATCH_BERR    = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h6);
   assign MATCH_DIAG    = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h7);
   //assign MATCH_CTAGS   = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h8); // optional
   //assign MATCH_CDATA   = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'h9); // optional
   //assign MATCH_COPS    = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'hA); // optional
   //assign MATCH_BOPS    = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'hB); // optional
   /* 0xC to 0xE: unused */
   assign MATCH_UARTBYP = (FC_CTRLLAYER) & (SUN3_ADR_IN[31:28] == 4'hF);

   wire 			 MATCH_PROM_BOOT;
   assign MATCH_PROM_BOOT  = ((FC_SPROG) & (EN_BOOT)); // at boot (bit from SYSEN): all Supervisor Program are from the PROM

   wire 			 WR;
   assign WR = ~SUN3_DS_n & ~SUN3_AS_n & ~SUN3_RW_n;
   wire 			 RD;
   assign RD = ~SUN3_DS_n & ~SUN3_AS_n &  SUN3_RW_n;

   // MMU & control layers
   wire [7:0] 			 ctx_out;
   wire [7:0] 			 ia_smap2pmap; // fixme: parametrizable
   wire [18:0] 			 ma_pmap2devices; // only 16-bits in e.g. 3/60 // fixme: parametrizable
   wire [7:0] 			 ps_pmap2devices; // fixme: parametrizable
   wire [3:0] 			 mmu_stat_in; 

   wire [31:0] 			 pa_forshow; // more readable as a wave, no functional use
   assign pa_forshow = {ma_pmap2devices, SUN3_ADR_IN[12:0]};			 
   // For use of the MMU: As SUN3_ADR_IN (and FC) are valid from C_S1=>C_S2 and CTX is valid from the last update
   // ia_smap2pmap is valid from C_S3=>C_S4
   // *_pmap2devices are valid from C_S5=>C_S6
   sun3_mmu mmu(.CLK(CLK),
		/* matching */
		.MATCH_CTX(MATCH_CTX),
		.MATCH_SMAP(MATCH_SMAP),
		.MATCH_PMAP_PS(MATCH_PMAP),
		.MATCH_PMAP_MA(MATCH_PMAP),
		.WR(WR),
		.RD(RD),
		/* CPU signals */
		.P_DIN(SUN3_DATA_IN),
		.P_A(SUN3_ADR_IN),
		.P_FC(SUN3_FC),
		/* timing signals */
		.C_S4(C_S4),
		.C_S6(C_S6),
		.C_S8(C_S8),
		/* MMU outputs */
		.ctx_out(ctx_out),
		.ia_smap2pmap(ia_smap2pmap),
		.ma_pmap2devices(ma_pmap2devices),
		.ps_pmap2devices(ps_pmap2devices),
		/* stats */
		.EN_DEV(EN_DEV),
		.DISACC(DISACC),
		.stat_in(mmu_stat_in)
	    );
   
   /* split the 8 protection/status bits by name */
   wire 			 MODIFY, ACCESS, MMU_X, MMU_S, MMU_W, MMU_V;
   wire [1:0] 			 TYPE;
   assign MODIFY  = ps_pmap2devices[0];
   assign ACCESS  = ps_pmap2devices[1];
   assign TYPE[0] = ps_pmap2devices[2];
   assign TYPE[1] = ps_pmap2devices[3];
   assign MMU_X   = ps_pmap2devices[4];
   assign MMU_S   = ps_pmap2devices[5];
   assign MMU_W   = ps_pmap2devices[6];
   assign MMU_V   = ps_pmap2devices[7];
   assign mmu_stat_in[0] = MODIFY | WR;
   assign mmu_stat_in[1] = 1'b1;
   assign mmu_stat_in[2] = TYPE[0]; // IMPROVEME: behavior matches the HW, but we don't need to rewrite TYPE
   assign mmu_stat_in[3] = TYPE[1];
   

   // combinatorial protection check on Page Map output
   wire 			 BERR_P, BERR_V, BERR_T;
   // EN_DEV from 3/60:u102, minus R_ACK
   // normally, EN_DEV is further qualified by TYPE (from MMU) and some PA bits
   // EN_DEV is valid from C_S1=>C_S2 (when SUN3_ADR_IN & FC become valid)
   assign EN_DEV = ((SUN3_ADR_IN[31:28] == 4'h0) & (FC_UPROG)           ) |
		   ((SUN3_ADR_IN[31:28] == 4'h0) & (FC_UDATA | FC_SDATA)) |
		   ((SUN3_ADR_IN[31:28] == 4'hF) & (FC_UPROG)           ) |
		   ((SUN3_ADR_IN[31:28] == 4'hF) & (FC_UDATA | FC_SDATA)) |
		   ((SUN3_ADR_IN[31:28] == 4'h0) & (FC_UPROG | FC_SPROG) & !EN_BOOT) |
		   ((SUN3_ADR_IN[31:28] == 4'hF) & (FC_UPROG | FC_SPROG) & !EN_BOOT);
   // DISACC in 3/60:u232
   // DISACC becomes valid during C_S6, when the MMU signalsoutput signals become valid
   assign DISACC = ((!MMU_V                  & EN_DEV) |                   /* access not valid [also BERR_V] */
		    ( MMU_V & MMU_S          & EN_DEV & !SUN3_FC[2]) |          /* supervisor-only access but not supervisor request (FC2==1 is supervisor) [also BERR_P]*/
		    ( MMU_V         & !MMU_W & EN_DEV            & WR)); /* read-only access but attempting to write [also BERR_P] */
   // BERR.P, BERR.V in 3/60:u232
   assign BERR_V =  (!MMU_V                  & EN_DEV);
   assign BERR_P = (( MMU_V & MMU_S          & EN_DEV & !SUN3_FC[2]) |
		    ( MMU_V         & !MMU_W & EN_DEV            & WR));
   // BERR.T: custom
   assign BERR_T = TIMEOUT;
   
   
   // IDPROM, read-only
   wire [7:0] 			 idprom_out;
   idprom_sun3 idprom(.CLK(CLK),
		      .idx(SUN3_ADR_IN[4:0]),
		      .dout(idprom_out)
		      );

   // Diagnostic register, write-only
   gen8bit_reg diag(.CLK(CLK),
		    .din(EXTRACT_8BITS(SUN3_DATA_IN, SUN3_ADR_IN[1:0])),
		    .WR(WR & MATCH_DIAG & C_S4),
		    .dout(leds), // directly to the leds
		    .CLR_n(1'b1)
		    );
   
   // Bus Error Register, read-only
   wire [7:0] 			 berr_in;
   wire [7:0] 			 berr_out;
   wire 			 BERRCLK, BERR;
   
   //assign berr_in = {1'b1, 1'b1, FPAENERR, FPABERR, VMEBERR, TIMEOUT, PROTERR, INVALID}; // this is from the architecture manual
   //assign berr_in = {WDOGn, 1'b1, 1'b1, 1'b1, 1'b1, BERR_Tn, BERR_Pn, BERR_Vn}; // this is from the 3/60 schematics
   //assign berr_in = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, BERR_T, BERR_P, BERR_V}; // we use positive logic // fixme: watchdog?
   assign berr_in = { BERR_V, BERR_P, BERR_T, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 }; // grr, bit order (timeout is 0x20) // we use positive logic // fixme: watchdog?
   
   gen8bit_reg berr(.CLK(CLK),
		    .din(berr_in),
		    .WR(BERRCLK), // will capture on C_S7=>C_S8
		    .dout(berr_out),
		    .CLR_n(~sys_reset /*1'b1 */) /* FIXME: how is supposed to be initialized ??? */
		    );
   assign BERRCLK	= (C_S6 & (BERR_P | BERR_T | BERR_V)); // FIXME: timing?
   assign BERR	        = (C_S6 & (BERR_P | BERR_T | BERR_V)); // FIXME: timing?
   assign P_BERR_n = ~BERR;

   // System Enable register
   wire [7:0] 			 sys_out;
   gen8bit_reg sys(.CLK(CLK),
		   .din(EXTRACT_8BITS(SUN3_DATA_IN, SUN3_ADR_IN[1:0])),
		   .WR(WR & MATCH_SYSEN & C_S4),
		   .dout(sys_out),
		   .CLR_n(~sys_reset) // reset by INIT- on real HW
		   );
   /* split the 8 system bits by name */
   wire 			 EN_DIAG, EN_FPA, EN_COPY, EN_VIDEO, EN_CACHE, EN_SDVMA, EN_FPP, EN_BOOTn;
   
   assign EN_DIAG  = diag_switch; //sys_out[0];
   assign EN_FPA   = sys_out[1]; // we repurpose as 'enable wishbone' for a one-shot trigger during early boot
   assign EN_COPY  = sys_out[2];
   assign EN_VIDEO = sys_out[3];
   assign EN_CACHE = sys_out[4];
   assign EN_SDVMA = sys_out[5];
   assign EN_FPP   = sys_out[6];
   assign EN_BOOTn = sys_out[7];
   assign EN_BOOT = ~EN_BOOTn;
   

   // output readable info when we change sysen
   always @(sys_out) begin
      $display("System Enable Register updated");
      $display("\tRead back Diag Switch: %x", EN_DIAG);
      $display("\tEnable FPA: %x", EN_FPA);
      $display("\tEnable Copy to Video Mem: %x", EN_COPY);
      $display("\tEnable Video: %x", EN_VIDEO);
      $display("\tEnable External Cache: %x", EN_CACHE);
      $display("\tEnable System DVMA: %x", EN_SDVMA);
      $display("\tEnable FPP: %x", EN_FPP);
      $display("\tBoot State (O => boot, 1 => normal): %x", EN_BOOTn);
   end // always @ (sys_out)

   // PROM (two access modes: at boot using SUN3_A, or mapped but matched through MA), read-only
   // handled by the two match signals in the bus section, the PROM itself always output whatever is addressed
   wire [31:0] 			 prom_out;
   bootrom32 bootrom(.CLK(CLK),
		     .idx(SUN3_ADR_IN[15:2]),
		     .dout(prom_out)
		     );

   // match wire for devices
   // matching late as we need to be sure the MA is now valid, two clocks after the address is valid
   // that happens on entry in S2 (rising edge), so on that edge IA becomes valid
   // then on entry in S4 MA becomes valid
   wire 			 MATCH_KBDMS, MATCH_SERIAL, MATCH_EEPROM, MATCH_TIMER;
   wire 			 MATCH_MEMERR_CTRL, MATCH_MEMERR_ADDR;
   wire 			 MATCH_IRQREG, MATCH_PROM;
   assign MATCH_KBDMS    = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h0) & C_S6;
   assign MATCH_SERIAL   = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h1) & C_S6;
   assign MATCH_EEPROM   = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h2) & C_S6;
   assign MATCH_TIMER    = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h3) & C_S6;
   assign MATCH_MEMERR_CTRL = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h4) & C_S6 & (SUN3_ADR_IN[2:0] == 3'h0);
   assign MATCH_MEMERR_ADDR = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h4) & C_S6 & (SUN3_ADR_IN[2:0] == 3'h4);
   assign MATCH_IRQREG   = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h5) & C_S6;
   //assign MATCH_I82586   = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h6) & C_S6;
   //assign MATCH_CMAP     = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h7) & C_S6; // color FB only
   
   assign MATCH_PROM     = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h8) & C_S6;
`ifdef LANCE_ETHERNET
   assign MATCH_AMDLE    = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h9) & C_S6;
`endif
   //assign MATCH_SCSI     = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hA) & C_S6;
   //assign MATCH_RSVD1    = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hB) & C_S6;
   //assign MATCH_RSVD2    = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hC) & C_S6;
   //assign MATCH_RSVD3    = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hD) & C_S6;
   //assign MATCH_DEP      = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hE) & C_S6; // uninstalled Data Encryption Processor
   //assign MATCH_ECCREG   = (EN_DEV) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hF) & C_S6; // ECC memory only

   wire 			 MATCH_MEMX;
   //assign MATCH_MEM      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18: 7] == 12'h000) & C_S6; // "physically" installed, here just 512k
   assign MATCH_MEM      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18: 8] == 11'h000) & C_S6; // "physically" installed, here just the two megs
   //assign MATCH_MEM      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18: 9] == 10'h000) & C_S6; // "physically" installed, here just the 4 megs
   //assign MATCH_MEM      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:10] ==  9'h000) & C_S6; // "physically" installed, here just the 8 megs
   //assign MATCH_MEM      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:11] ==  8'h00) & C_S6; // "physically" installed, here just the 16 megs
   //assign MATCH_MEM      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:12] ==  7'h00) & C_S6; // "physically" installed, here just the 32 megs
   /*
    assign MATCH_MEM      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & ((ma_pmap2devices[18:11] == 8'h00) || 
								  (ma_pmap2devices[18:11] == 8'h01) || 
								  (ma_pmap2devices[18:11] == 8'h02)) & C_S6; // "physically" installed, here just the 48 megs
    */
   //assign MATCH_MEM      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:13] ==  6'h00) & C_S6; // "physically" installed, here just the 64 megs
   //assign MATCH_MEM      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:14] ==  5'h00) & C_S6; // "physically" installed, here the 128 megs
   
   assign MATCH_MEMX     = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:15] == 4'h0) & C_S6; // addressable, 256 MiB (?) // CHECKME: sun3 behavior

   wire 			 MATCH_FBX;
   assign MATCH_FBX      = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:11] == 8'hFF) & (ma_pmap2devices[10:8] == 3'h0) & C_S6; // architectural: 2 MiB
   assign MATCH_FB       = (EN_DEV) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:11] == 8'hFF) & (ma_pmap2devices[10:5] == 6'h00) & C_S6; // BW: 256 KiB
       
   /* VME spaces, no default timing, FYI only */
   /* ... except VME32_32 we use for CSR and temporary SRAM */
   //assign MATCH_VME16_32 = (EN_DEV) & (TYPE == 2'h2) & !DISACC;
   //assign MATCH_VME16_16 = (EN_DEV) & (TYPE == 2'h2) & !DISACC & (ma_pmap2devices[18:11] == 8'hFF));
   //assign MATCH_VME16_08 = (EN_DEV) & (TYPE == 2'h2) & !DISACC & (ma_pmap2devices[18:3] == 16'hFFFF));
   assign MATCH_VME32_32 = (EN_DEV) & (TYPE == 2'h3) & !DISACC & C_S6;
   //assign MATCH_VME32_16 = (EN_DEV) & (TYPE == 2'h3) & !DISACC & (ma_pmap2devices[18:11] == 8'hFF));
   //assign MATCH_VME32_08 = (EN_DEV) & (TYPE == 2'h3) & !DISACC & (ma_pmap2devices[18:3] == 16'hFFFF));
   /* won't even bother with the FPA */

   wire [7:0] 			 timer_out;
   wire 			 timer_bus_en;
   wire 			 timer_int_n;
   
 icm7170 timerchip(.CLK(CLK),
		   .RESETn(~sys_reset), // no reset on real HW
		   .A(SUN3_ADR_IN[4:0]),
		   .D_IN(EXTRACT_8BITS(SUN3_DATA_IN, SUN3_ADR_IN[1:0])),
		   .D_OUT(timer_out),
		   .D_EN(timer_bus_en),
		   .RD(~MATCH_TIMER | ~RD),
		   .WR(~MATCH_TIMER | ~WR),
		   .CS(1'b0),
		   .INTERRUPT(timer_int_n));

   wire 			 EN_LLBYTE, EN_LUBYTE, EN_ULBYTE, EN_UUBYTE;

`ifdef MEM_SIM_ONLY
   /* the actual memory. For now it's just synchronous RAM */
   /* should probably be moved to some "real" RAM with variable timings, which will require changing the bus mux below */
   wire [31:0] 			 mem_out;
   sram_sync_32bits_bytewritable #(.IDX_WIDTH(19)) mainmem (.CLK(CLK),
							  .idx({ma_pmap2devices[7:0],SUN3_ADR_IN[12:2]}),
							  .WRll(WR & MATCH_MEM & EN_LLBYTE),
							  .WRlu(WR & MATCH_MEM & EN_LUBYTE),
							  .WRul(WR & MATCH_MEM & EN_ULBYTE),
							  .WRuu(WR & MATCH_MEM & EN_UUBYTE),
							  .din(SUN3_DATA_IN),
							  .dout(mem_out)
							  );
`else // !`ifdef SIM_ONLY
   wire [31:0] 			 wishbone_out;
   wire 			 w_ack;
   
   sun3_wishbone_bridge wbridge(.CLK(CLK),
				.RESET_n(~sys_reset), // don't reset on CPU-only reset, don't want to loose memory access then
				.SET_ENABLE(EN_FPA),
				.P_ADR_IN({ma_pmap2devices[18:0], SUN3_ADR_IN[12:0]}), // full physical
				.P_DATA_IN(SUN3_DATA_IN),
				.P_DATA_OUT(wishbone_out),
				.P_RW_n(SUN3_RW_n),
				.EN_LLBYTE(EN_LLBYTE),
				.EN_LUBYTE(EN_LUBYTE),
				.EN_ULBYTE(EN_ULBYTE),
				.EN_UUBYTE(EN_UUBYTE),
				.MATCH_MEM(MATCH_MEM),
				.MATCH_FB(MATCH_FB),
				.MATCH_VME32_32(MATCH_VME32_32), // we're going to put some support stuff, e.g. DDR CSRs, in VME space
				.W_ACK(w_ack),
				
				// wishbone
				.wb_cyc_o(wb_cyc_o),
				.wb_stb_o(wb_stb_o),
				.wb_adr_o(wb_adr_o),
				.wb_dat_o(wb_dat_o),
				.wb_sel_o(wb_sel_o),
				.wb_we_o(wb_we_o),
				.wb_dat_i(wb_dat_i),
				.wb_ack_i(wb_ack_i)
				);
   
`endif
   
   assign EN_LLBYTE = ( SUN3_ADR_IN[0] &  SUN3_ADR_IN[1]) | (                SUN3_ADR_IN[1]             &  SUN3_SIZ[1]) | (               ~SUN3_SIZ[0] & ~SUN3_SIZ[1]) | ( SUN3_ADR_IN[0] &                SUN3_SIZ[0] & SUN3_SIZ[1]);
   assign EN_LUBYTE = (~SUN3_ADR_IN[0] &  SUN3_ADR_IN[1]) | ( SUN3_ADR_IN[0] & ~SUN3_ADR_IN[1]             &  SUN3_SIZ[1]) | (~SUN3_ADR_IN[1] & ~SUN3_SIZ[0] & ~SUN3_SIZ[1]) | (               ~SUN3_ADR_IN[1] & SUN3_SIZ[0] & SUN3_SIZ[1]);
   assign EN_ULBYTE = ( SUN3_ADR_IN[0] & ~SUN3_ADR_IN[1]) | (               ~SUN3_ADR_IN[1] & ~SUN3_SIZ[0])             | (~SUN3_ADR_IN[1]             &  SUN3_SIZ[1]);
   assign EN_UUBYTE = (~SUN3_ADR_IN[0] & ~SUN3_ADR_IN[1]);
   
   /* serial port */
   wire [7:0] 			 serial_out;
   wire 			 serial_en;
   wire 			 serial_int_n; // FIXME: DOME
   wire 			 TxDA, TxDA_EN, RxDA;

   assign tx = TxDA;
   assign RxDA = rx;

`ifdef SERIAL_SUSKA
   SCC8530_TOP serial(
		      // System controls:
`ifndef FAST_SERIAL
		      .PCLK(clk4m9152), // in // sun3 expect a 4.9152 clock, like sun2
`else
		      .PCLK(CLK), // clock is 4x expected, so 9600 will be 38400
`endif		      
		      // Bus:
		      .DATA_IN(EXTRACT_8BITS(SUN3_DATA_IN, SUN3_ADR_IN[1:0])), // in
		      .DATA_OUT(serial_out), // out
		      .DATA_EN(serial_en), // out
		      
		      // Bus controls:
		      .CEn(1'b0), // in
		      .RDn(((~MATCH_SERIAL & ~MATCH_UARTBYP) | ~RD) & ~sys_reset), // in // ~sys_rese for HW reset, INIT- on real HW
		      .WRn(((~MATCH_SERIAL & ~MATCH_UARTBYP) | ~WR) & ~sys_reset), // in // ~sys_rese for HW reset, INIT- on real HW
		      .A_Bn(SUN3_ADR_IN[2]), // in
		      .D_Cn(SUN3_ADR_IN[1]), // in
		      
		      // Interrupt:
		      .INTACKn(1'b1), // in
		      .IEI(1'b1), // in
		      .IEO(), // out
		      .INTn(serial_int_n), // out // Open drain in 5380.
		      
		      // Serial Data:
		      .RxDA(RxDA), // in
		      .TxDA(TxDA), // out
		      .TxDA_EN(TxDA_EN), // out // This is an enhancement over the original chip.
		      .RxDB(), // in
		      .TxDB(), // out
		      
		      // Channel clocks:
		      .TRxCA_INn(), // in
		      .TRxCA_OUTn(), // out
		      .TRxCA_EN(), // out
		      .RTxCAn(), // in
		      .TRxCB_INn(), // in
		      .TRxCB_OUTn(), // out
		      .TRxCB_EN(), // out
		      .RTxCBn(), // in
		      
		      // Channel controls:
		      .SYNCA_IN(), // in
		      .SYNCA_OUT(), // out
		      .SYNCA_EN(), // out
		      .Wn_REQAn(), // out // Open drain in 5380.
		      .DTRn_REQAn(), // out
		      .RTSAn(), // out
		      .CTSAn(), // in
		      .DCDAn(), // in
		      .SYNCB_IN(), // in
		      .SYNCB_OUT(), // out
		      .SYNCB_EN(), // out
		      .Wn_REQBn(), // out
		      .DTRn_REQBn(), // out
		      .RTSBn(), // out
		      .CTSBn(), // in
		      .DCDBn() // in
		      );
`endif //  `ifdef SERIAL_SUSKA
   
`ifdef SERIAL_VZ50938
   z8530_scc  #(.SOFT_RESET_EN(1),
		.RR8_CTRL_POP(1),
		.BRG_SRC_A(1),
		.BRG_SRC_B(1),
		.UNIPLUS_BAUD_PATCH_B(0),
		.AUTO_ENABLES_EN(0),
		.RTXC_XTAL_FULLRATE_A(0),
		.RTXC_XTAL_FULLRATE_B(0),
		.RDWR_RESET_EN(1)
		) serial (// System Interface
			  .clk(CLK),           // CPU/bus clock (register file, interrupts, RR mux)
			  .pclk(clk4m9152),       // Alternative BRG/serializer clock (Zilog "PCLK")
			  .sclk(clk4m9152),          // Primary BRG/serializer clock (e.g. 3.6864 MHz)
			  .reset_n(1'b1),       // Active low reset (async assert)
			  
			  // CPU Interface
			  .cs_n(1'b0),          // Chip select (active low)
			  .rd_n(((~MATCH_SERIAL & ~MATCH_UARTBYP) | ~RD) & ~sys_reset),          // Read strobe (active low)
			  .wr_n(((~MATCH_SERIAL & ~MATCH_UARTBYP) | ~WR) & ~sys_reset),          // Write strobe (active low)
			  .a_b(SUN3_ADR_IN[2]),           // Channel select: 1=A, 0=B
			  .d_c(SUN3_ADR_IN[1]),           // Data/Control: 1=Data, 0=Control
			  .data_in(EXTRACT_8BITS(SUN3_DATA_IN, SUN3_ADR_IN[1:0])),       // Data input
			  .data_out(serial_out),      // Data output
			  .data_oe(serial_en),       // Data output enable
			  
			  // Interrupt
			  .int_n(serial_int_n),         // Interrupt output (active low)
			  .intack_n(1'b1),      // Interrupt acknowledge
			  
			  // Channel A Serial Interface
			  .rxca(),          // Receive clock A
			  .txca(),          // Transmit clock A
			  .rxda(RxDA),          // Receive data A
			  .txda(TxDA),          // Transmit data A
			  .ctsa_n(),        // Clear to send A (active low)
			  .dcda_n(),        // Data carrier detect A (active low)
			  .synca_n(),       // Sync A (async-mode input -> RR0[4], active low)
			  .rtsa_n(),        // Request to send A (active low)
			  .dtra_n(),        // Data terminal ready A (active low)
			  
			  // Channel B Serial Interface
			  .rxcb(),          // Receive clock B
			  .txcb(),          // Transmit clock B
			  .rxdb(),          // Receive data B
			  .txdb(),          // Transmit data B
			  .ctsb_n(),        // Clear to send B (active low)
			  .dcdb_n(),        // Data carrier detect B (active low)
			  .syncb_n(),       // Sync B (async-mode input -> RR0[4], active low)
			  .rtsb_n(),        // Request to send B (active low)
			  .dtrb_n()         // Data terminal ready B (active low)
			  );
`endif //  `ifdef SERIAL_VZ50938
   
   wire [7:0] 			 kbdms_out;
   wire 			 kbdms_en;
   wire 			 kbdms_int_n; // FIXME: DOME
   wire 			 KBDMS_TxDA, KBDMS_TxDA_EN;
   
   SCC8530_TOP kbdms(
		      // System controls:
		      .PCLK(clk4m9152 /* CLK */), // in // CHECKME: sun3 expect a 4.9152 clock, like sun2
		      
		      // Bus:
		      .DATA_IN(EXTRACT_8BITS(SUN3_DATA_IN, SUN3_ADR_IN[1:0])), // in
		      .DATA_OUT(kbdms_out), // out
		      .DATA_EN(kbdms_en), // out
		      
		      // Bus controls:
		      .CEn(1'b0), // in
		      .RDn((~MATCH_KBDMS | ~RD) & ~sys_reset), // in
		      .WRn((~MATCH_KBDMS | ~WR) & ~sys_reset), // in
		      .A_Bn(SUN3_ADR_IN[2]), // in
		      .D_Cn(SUN3_ADR_IN[1]), // in
		      
		      // Interrupt:
		      .INTACKn(1'b1), // in
		      .IEI(1'b1), // in
		      .IEO(), // out
		      .INTn(kbdms_int_n), // out // Open drain in 5380.
		      
		      // Serial Data:
		      .RxDA(), // in
		      .TxDA(KBDMS_TxDA), // out
		      .TxDA_EN(KBDMS_TxDA_EN), // out // This is an enhancement over the original chip.
		      .RxDB(), // in
		      .TxDB(), // out
		      
		      // Channel clocks:
		      .TRxCA_INn(), // in
		      .TRxCA_OUTn(), // out
		      .TRxCA_EN(), // out
		      .RTxCAn(), // in
		      .TRxCB_INn(), // in
		      .TRxCB_OUTn(), // out
		      .TRxCB_EN(), // out
		      .RTxCBn(), // in
		      
		      // Channel controls:
		      .SYNCA_IN(), // in
		      .SYNCA_OUT(), // out
		      .SYNCA_EN(), // out
		      .Wn_REQAn(), // out // Open drain in 5380.
		      .DTRn_REQAn(), // out
		      .RTSAn(), // out
		      .CTSAn(), // in
		      .DCDAn(), // in
		      .SYNCB_IN(), // in
		      .SYNCB_OUT(), // out
		      .SYNCB_EN(), // out
		      .Wn_REQBn(), // out
		      .DTRn_REQBn(), // out
		      .RTSBn(), // out
		      .CTSBn(), // in
		      .DCDBn() // in
		      );

   wire [7:0] 			 eeprom_out;
   eeprom eeprom(.CLK(CLK),
		 .idx(SUN3_ADR_IN[10:0]),
		 .WR(WR & MATCH_EEPROM),
		 .din(EXTRACT_8BITS(SUN3_DATA_IN, SUN3_ADR_IN[1:0])),
		 .dout(eeprom_out));
   
   
   // mem err crl reg
   // need to return 0 in the NMI handler
   // we can remove the bits in the PROM, but not in the OS
   wire [7:0] 			 memerr_ctrl_out;
   gen8bit_reg memerr_ctrl(.CLK(CLK),
			   .din(EXTRACT_8BITS(SUN3_DATA_IN, SUN3_ADR_IN[1:0])),
			   .WR(WR & MATCH_MEMERR_CTRL),
			   .dout(memerr_ctrl_out),
			   .CLR_n(~sys_reset)
			   );
   // mem err addr reg
   // return 0 on the bus always
   
   // IRQ reg
   wire [7:0] 			 irqreg_out;
   gen8bit_reg irqreg(.CLK(CLK),
		      .din(EXTRACT_8BITS(SUN3_DATA_IN, SUN3_ADR_IN[1:0])),
		      .WR(WR & MATCH_IRQREG),
		      .dout(irqreg_out),
		      .CLR_n(P_RESET_n)
		      );
   wire 	       EN_IRQ7, EN_IRQ6, EN_IRQ5, EN_IRQ4, EN_IRQ3, EN_IRQ2, EN_IRQ1, EN_INT;
   assign EN_IRQ7 = irqreg_out[7];
   assign EN_IRQ6 = irqreg_out[6];
   assign EN_IRQ5 = irqreg_out[5];
   assign EN_IRQ4 = irqreg_out[4];
   assign EN_IRQ3 = irqreg_out[3];
   assign EN_IRQ2 = irqreg_out[2];
   assign EN_IRQ1 = irqreg_out[1];
   assign EN_INT  = irqreg_out[0];

`ifdef LANCE_ETHERNET
   wire [31:0] 	       ethernet_out;
`endif
   
   // Answering the CPU
   // bus muxer. CPU has priority via DATA_EN, otherwise whomever is matched own the bus
   // ... with an implicit priority
   assign P_DATA_OUT = P_DATA_EN         ? SUN3_DATA_IN : // loopback
		       MATCH_CTX       ? EXPAND_8BITS(ctx_out) :
		       MATCH_SMAP      ? EXPAND_8BITS(ia_smap2pmap) :
		       MATCH_PMAP      ? {ps_pmap2devices, 5'h00, ma_pmap2devices} :
		       MATCH_SYSEN     ? EXPAND_8BITS({sys_out[7:1], diag_switch}) :
		       MATCH_BERR      ? EXPAND_8BITS(berr_out) :
		       MATCH_IDPROM    ? EXPAND_8BITS(idprom_out) :
		       MATCH_PROM_BOOT ? prom_out :
		       MATCH_PROM      ? prom_out :
`ifdef MEM_SIM_ONLY
		       MATCH_MEM       ? mem_out :
`else
		       MATCH_MEM       ? wishbone_out :
		       MATCH_VME32_32  ? wishbone_out :
		       MATCH_FB        ? wishbone_out :
`endif
		       MATCH_KBDMS     ? EXPAND_8BITS(kbdms_out) :
		       MATCH_SERIAL    ? EXPAND_8BITS(serial_out) :
		       MATCH_UARTBYP   ? EXPAND_8BITS(serial_out) :
		       MATCH_EEPROM    ? EXPAND_8BITS(eeprom_out) :
		       MATCH_MEMERR_CTRL ? EXPAND_8BITS(memerr_ctrl_out) :
		       MATCH_MEMERR_ADDR ? EXPAND_8BITS(8'h00) :
		       MATCH_TIMER     ? EXPAND_8BITS(timer_out) :
		       MATCH_IRQREG    ? EXPAND_8BITS(irqreg_out) :
`ifdef LANCE_ETHERNET
		       MATCH_AMDLE     ? ethernet_out :
`endif
		       32'hDEADBEEF;

   // DSACK generator. has knowledge of timings for all devices
   wire 	       DO_ACK;
`ifdef LANCE_ETHERNET
   wire [1:0] 	       ethernet_dsack_n_out;
`endif
   
   // For memory this will need updating if we use "real" (variable-timing) memory
   assign DO_ACK = ( // FIXME: 32 vs 16 vs 8 bits, sun3 (or rewire for eevryone to be 32-bits-like ?)
		     /* reads */
		     ( SUN3_RW_n & C_S4 & (MATCH_CTX | MATCH_IDPROM | MATCH_SYSEN | MATCH_BERR |              MATCH_PROM_BOOT | MATCH_MEMERR_CTRL | MATCH_MEMERR_ADDR)) | // entering S4, quick devices (RO or WR)
		     ( SUN3_RW_n & C_S4 & (MATCH_SMAP)) |  // entering S4, quick devices (CTX is 1 clock but went valid after being written, not affected by SUN3_A)
		     ( SUN3_RW_n & C_S4 & (MATCH_PMAP)) |  // entering S4, physical map needed an extra cycle
		     ( SUN3_RW_n & C_S6 & (MATCH_EEPROM | MATCH_TIMER | MATCH_IRQREG | MATCH_PROM)) | // entering S6, devices going through the MMU
`ifndef FAST_SERIAL
		     ( SUN3_RW_n & C_S10 & (MATCH_UARTBYP)) | // entering S4, SLOW serial (1/4 clock)		  
		     ( SUN3_RW_n & C_S12 & (MATCH_SERIAL)) | // entering S8, SLOW serial (1/4 clock)
`else
		     ( SUN3_RW_n & C_S4 & (MATCH_UARTBYP)) | // entering S4, FAST serial (4*1/4 clock)		  
		     ( SUN3_RW_n & C_S6 & (MATCH_SERIAL)) | // entering S8, FAST serial (4*1/4 clock)
`endif
		     ( SUN3_RW_n & C_S12 & (MATCH_KBDMS)) |  // entering S8, SLOW serial (1/4 clock)
`ifdef MEM_SIM_ONLY
		     ( SUN3_RW_n & C_S6 & (MATCH_MEM)) |
`else
		     ( SUN3_RW_n & w_ack & (MATCH_MEM | MATCH_VME32_32 | MATCH_FB)) | // wishbone
`endif
`ifdef LANCE_ETHERNET
		     ( SUN3_RW_n & ~ethernet_dsack_n_out[0] & (MATCH_AMDLE)) | // ethernet (PVC bridge)
`endif
		     /* writes */
		     (~SUN3_RW_n & C_S4 & (MATCH_CTX |                MATCH_SYSEN |              MATCH_DIAG |                   MATCH_MEMERR_CTRL)) | // entering S4, quick devices (WO or WR)
		     (~SUN3_RW_n & C_S4 & (MATCH_SMAP)) |  // entering S4, quick devices (CTX is 1 clock but went valid after being written, not affected by SUN3_A)
		     (~SUN3_RW_n & C_S4 & (MATCH_PMAP)) |  // entering S4, physical map needed an extra cycle
		     (~SUN3_RW_n & C_S6 & (MATCH_EEPROM | MATCH_TIMER | MATCH_IRQREG)) | // entering S6, devices going through the MMU
`ifndef FAST_SERIAL
		     (~SUN3_RW_n & C_S10 & (MATCH_UARTBYP)) | // entering S4, SLOW serial (1/4 clock)
		     (~SUN3_RW_n & C_S12 & (MATCH_SERIAL)) | // entering S8, SLOW serial (1/4 clock)
`else
		     (~SUN3_RW_n & C_S4 & (MATCH_UARTBYP)) | // entering S4, FAST serial (4*1/4 clock)		  
		     (~SUN3_RW_n & C_S6 & (MATCH_SERIAL)) | // entering S8, FAST serial (4*1/4 clock)
`endif
		     (~SUN3_RW_n & C_S12 & (MATCH_KBDMS)) | // entering S8, SLOW serial (1/4 clock)
`ifdef MEM_SIM_ONLY
		     (~SUN3_RW_n & C_S6 & (MATCH_MEM)) |
`else
		     (~SUN3_RW_n & w_ack & (MATCH_MEM | MATCH_VME32_32 | MATCH_FB)) | // wishbone
`endif
`ifdef LANCE_ETHERNET
		     (~SUN3_RW_n & ~ethernet_dsack_n_out[0] & (MATCH_AMDLE)) | // ethernet (PVC bridge)
`endif
		     1'b0);
   
   assign P_DSACK_n[0] = ~(DO_ACK); // we only have 8 and 32 bits for now, so everyone assert [0] (16-bits are [1] only]
`ifdef  DEVICE_8BITS_ON_32BITS_BUS
   assign P_DSACK_n[1] = ~(DO_ACK); // everybody is 32-bits
`else
   assign P_DSACK_n[1] = ~(DO_ACK & (MATCH_PMAP | MATCH_MEMERR_ADDR | MATCH_PROM_BOOT | MATCH_PROM | MATCH_MEMX | MATCH_VME32_32 | MATCH_FBX)); // 32-bits devices only
`endif
   
   
   // LEDS
   // as for the real thing, used for debugging (in simulation)
   always @(leds) begin
      $display("Leds are now %x", ~leds);
      case (~leds)
	8'hFF:$display(" => L_RESET");
	8'h00:$display(" => L_RUNNING");
	8'h01:$display(" => L_INITIAL");
	8'h02:$display(" => L_USERDOG");
	8'h03:$display(" => L_GOTMEM");
	8'h07:$display(" => L_AFTERDIAG");
	8'h11:$display(" => L_CONTEXT");
	8'h20:$display(" => L_HEARTBEAT");
	8'h21:$display(" => L_SM_CONST");
	8'h22:$display(" => L_SM_ADDR");
	8'h23:$display(" => L_SM_DATA");
	8'h31:$display(" => L_PM_CONST");
	8'h32:$display(" => L_PM_ADDR");
	8'h33:$display(" => L_PM_DATA");
	8'h40:$display(" => L_PROM");
	8'h50:$display(" => L_UART");
	8'h70:$display(" => L_M_MAP");
	8'h71:$display(" => L_M_CONST");
	8'h72:$display(" => L_M_ADDR");
	8'h7F:$display(" => L_PARITY");
	8'h81:$display(" => L_TIMER");
	8'h82:$display(" => L_DES");
	8'hF1:$display(" => L_SETUP_MEM");
	8'hF2:$display(" => L_SETUP_MAP");
	8'hF3:$display(" => L_SETUP_FB");
	8'hF4:$display(" => L_SETUP_KEYB");
	default: $display(" => unknown pattern!!!");
      endcase
      //$flushlog;
   end // always @ (leds)

   // interrupts
   wire 	       RTC, SCC_IRQ, E_IRQ, PAR_IRQ, S_IRQ;
   assign RTC = ~timer_int_n;
   /* SCC_IRQ is for both Z8530 */
   assign SCC_IRQ = ~(serial_int_n & kbdms_int_n);
   /* Ethernet */
`ifdef LANCE_ETHERNET
   wire 	       amdle_intr;
   assign E_IRQ = amdle_intr;
`else
   assign E_IRQ = 1'b0;
`endif
   /* no Parity support */
   assign PAR_IRQ = 1'b0;
   /* no Parity support */
   assign S_IRQ = 1'b0;
   
   sun3_irq_priority irqenc (.CLK(CLK),
    			     .EN_IRQ7(EN_IRQ7),
			     .EN_IRQ6(EN_IRQ6),
			     .EN_IRQ5(EN_IRQ5),
			     .EN_IRQ4(EN_IRQ4),
			     .EN_IRQ3(EN_IRQ3),
			     .EN_IRQ2(EN_IRQ2),
			     .EN_IRQ1(EN_IRQ1),
			     .EN_INT(EN_INT),
    			     .RTC(RTC),
			     .V_INT(V_INT),
			     .SCC_IRQ(SCC_IRQ),
			     .E_IRQ(E_IRQ),
			     .PAR_IRQ(PAR_IRQ),
			     .S_IRQ(S_IRQ),
			     .IPL_n(P_IPL_n));

   
`ifdef LANCE_ETHERNET
   // ETHERNET
   // first we need to be compatible to the VHDL code

   // PVC Write Interface Structure
   typedef struct      packed      {
      logic 	       req;     // Request signal
      logic [3:0]      be;      // Byte enables (4 bits)
      logic 	       wr;      // Write signal
      logic [31:0]     a;       // 32-bit address
      logic [3:0]      ah;      // High address bits (35:32)
      logic [31:0]     dw;      // Write data
   } type_pvc_w;
   
   // PVC Read Interface Structure
   typedef struct      packed      {
      logic 	       ack;     // Acknowledge
      logic [31:0]     dr;      // Read data
   } type_pvc_r;
   
   // PLOMB Burst Type Enumeration
   typedef enum        logic [1:0] {
				    PB_SINGLE = 2'b00,    // Single transfer
				    PB_BURST2 = 2'b01,    // 2-word burst
				    PB_BURST4 = 2'b10,    // 4-word burst
				    PB_BURST8 = 2'b11     // 8-word burst
				    } type_plomb_burst;
   
   // PLOMB Mode Constants
   parameter [1:0] PB_MODE_NOP    = 2'b00;  // No operation
   parameter [1:0] PB_MODE_WR     = 2'b01;  // Write operation
   parameter [1:0] PB_MODE_RD     = 2'b10;  // Read operation
   parameter [1:0] PB_MODE_WR_ACK = 2'b11;  // Write with acknowledge
   
   // PLOMB Write Interface Structure
   typedef struct      packed 		  {
      logic [31:0]     a;       // Address
      logic [3:0]      ah;      // High address bits (35:32) // SPARC, unused
      logic [7:0]      asi;     // Address Space Identifier // SPARC, hardwired to match FC == Supervisor/Data
      logic [31:0]     d;       // Data
      logic [3:0]      be;      // Byte enables
      logic [1:0]      mode;    // Access mode
      type_plomb_burst     burst;   // Burst type
      logic 	       cont;    // Contiguous access // unused?
      logic 	       cache;   // Cacheable // unused ?
      logic 	       lock;    // Lock signal // unused ?
      logic 	       req;     // Request
      logic 	       dack;    // Data acknowledge
   } type_plomb_w;
   
   // PLOMB Read Interface Structure
   typedef struct      packed 		  {
      logic [31:0]     d;       // Read data
      logic [1:0]      code;    // enum_plomb_code      
      logic 	       ack;     // Acknowledge
      logic 	       dreq;    // 
   } type_plomb_r;
   
   // MAC EMI Write Interface Structure
   typedef struct      packed 		  {
      logic [15:0]     d;        // Data (16-bit)
      logic 	       push;     // Write pulse (Impulsion écriture)
      logic 	       stp;      // Start Packet
      logic 	       enp;      // End Packet  
      logic [11:0]     len;      // Length (Longueur)
      logic 	       crcgen;   // CRC Generation (Emission CRC)
      logic 	       clr;      // Clear/Reset (Réinitialisation)
   } type_mac_emi_w;
   
   // MAC EMI Read Interface Structure  
   typedef struct      packed 		  {
      logic 	       fifordy;         // FIFO Ready
      logic 	       busy;            // Busy status
   } type_mac_emi_r;
   
   // MAC REC Write Interface Structure
   typedef struct      packed 		  {
      logic 	       pop;      // Pop word (Dépile mot)
      logic [47:0]     padr;     // MAC Destination Address (48-bit)
      logic [63:0]     ladrf;    // Hash filtering (Filtrage HASH) 
      logic 	       clr;      // Clear/Reset (Réinitialisation)
   } type_mac_rec_w;
   
   // MAC REC Read Interface Structure
   typedef struct      packed 		  {
      logic [15:0]     d;        // Received data (Données reçues)
      logic 	       deof;     // EOF bit synchronous with D (Bit EOF synchrone avec D)
      logic 	       fifordy;  // FIFO sufficiently full (FIFO suffisamment pleine)
      logic [11:0]     len;      // Last frame length (Longueur dernière trame)
      logic 	       crcok;    // CRC OK for last frame (CRC OK dernière trame)
      logic 	       eof;      // End of frame detected pulse (Fin de trame détectée)
   } type_mac_rec_r;
   
   type_pvc_w 			  amdle_w;
   type_pvc_r 			  amdle_r;
   type_plomb_w amdle_pw;
   type_plomb_r amdle_pr;
   
   type_mac_emi_w amdle_mac_emi_w;
   type_mac_emi_r amdle_mac_emi_r;
   type_mac_rec_w amdle_mac_rec_w;
   type_mac_rec_r amdle_mac_rec_r;
   
   //wire [7:0] 	       amdle_eth_ba;
   //wire 	       amdle_stopa;
   
   ts_lance #(.ASI(8'h0B)) ethernet (
				     .sel(amdle_w.req /*MATCH_AMDLE*/), // Checlme: amdle.w.req ?
				     .w(amdle_w),
				     .r(amdle_r),
				     .pw(amdle_pw),
				     .pr(amdle_pr),
				     .mac_emi_w(amdle_mac_emi_w),
				     .mac_emi_r(amdle_mac_emi_r),
				     .mac_rec_w(amdle_mac_rec_w),
				     .mac_rec_r(amdle_mac_rec_r),
				     .intr(amdle_intr),
				     .eth_ba(8'hff),
				     .stopa(1'b0),
				     .clk(eth_clk),
				     .reset(~P_RESET_n), // CHECKME: why 2 resets ???
				     .reset_n(P_RESET_n),
				     .iv() // (iv[191:0])
				     );


`ifdef BRIDGE_TO_ETH_VHDL
   mc68020_to_pvc_bridge bridge_to_eth(.mc_A({ma_pmap2devices[18:0],SUN3_ADR_IN[12:0]}), // full physical
				       .mc_D_IN(SUN3_DATA_IN),
				       .mc_D_OUT(ethernet_out), // out
				       .mc_FC(SUN3_FC), // unused
				       .mc_SIZ(SUN3_SIZ),
				       .mc_AS_N(SUN3_AS_n),
				       .mc_DS_N(SUN3_DS_n),
				       .mc_RW_N(SUN3_RW_n),
				       .mc_DSACK0_N(ethernet_dsack_n_out[0]), // out
				       .mc_DSACK1_N(ethernet_dsack_n_out[1]), // out, not actually used, redundant
				       .mc_CS_N(~MATCH_AMDLE),
				       .pvc_w(amdle_w),
				       .pvc_r(amdle_r),
				       .clk(CLK),
				       .reset_n(P_RESET_n)
				       );
`else // !`ifdef BRIDGE_TO_ETH_VHDL
   bridge_020_to_pvc bridge_to_eth(
				       .clk(eth_clk),
				       .reset_n(P_RESET_n),
				       .mc_CLK(CLK),
				       .mc_A({ma_pmap2devices[18:0],SUN3_ADR_IN[12:0]}), // full physical
				       .mc_D_IN(SUN3_DATA_IN),
				       .mc_D_OUT(ethernet_out), // out
				       .mc_FC(SUN3_FC), // unused
				       .mc_SIZ(SUN3_SIZ),
				       .mc_AS_N(SUN3_AS_n),
				       .mc_DS_N(SUN3_DS_n),
				       .mc_RW_N(SUN3_RW_n),
				       .mc_DSACK0_N(ethernet_dsack_n_out[0]), // out
				       .mc_DSACK1_N(ethernet_dsack_n_out[1]), // out, not actually used, redundant
				       .mc_CS_N(~MATCH_AMDLE),
				       .pvc_w(amdle_w),
				       .pvc_r(amdle_r)
				       );
`endif // !`ifdef BRIDGE_TO_ETH_VHDL

`ifdef BRIDGE_FROM_ETH_VHDL
   plomb_to_mc68020_bridge bridge_from_eth(
					   .plomb_w(amdle_pw),
					   .plomb_r(amdle_pr),
					   .mc_A_OUT(ethernetdma_addr_out),
					   .mc_D_IN(P_DATA_OUT),
					   .mc_D_OUT(ethernetdma_data_out),
					   .mc_FC(ethernetdma_fc_out),
					   .mc_SIZ(ethernetdma_siz_out),
					   .mc_AS_N_OUT(ethernetdma_as_n_out),
					   .mc_AS_N_IN(SUN3_AS_n),
					   .mc_DS_N(ethernetdma_ds_n_out),
					   .mc_RW_N(ethernetdma_rw_n_out),
					   .mc_DSACK0_N(P_DSACK_n[0]),
					   .mc_DSACK1_N(P_DSACK_n[1]), 
					   .mc_BERR_N(P_BERR_n),
					   .mc_BR_N(ethernetdma_br_n_out),
					   .mc_BG_N(ethernetdma_bg_n),
					   .mc_BGACK_N(ethernetdma_bgack_n_out),
					   .clk(CLK),
					   .reset_n(P_RESET_n)
					   );
`else // !`ifdef BRIDGE_FROM_ETH_VHDL
   bridge_plomb_to_020 bridge_from_eth(
					   .clk(eth_clk),
					   .reset_n(P_RESET_n),
					   .plomb_w(amdle_pw),
					   .plomb_r(amdle_pr),
					   .mc_CLK(CLK),
					   .mc_A_OUT(ethernetdma_addr_out),
					   .mc_D_IN(P_DATA_OUT),
					   .mc_D_OUT(ethernetdma_data_out),
					   .mc_FC(ethernetdma_fc_out),
					   .mc_SIZ(ethernetdma_siz_out),
					   .mc_AS_N_OUT(ethernetdma_as_n_out),
					   .mc_AS_N_IN(SUN3_AS_n),
					   .mc_DS_N(ethernetdma_ds_n_out),
					   .mc_RW_N(ethernetdma_rw_n_out),
					   .mc_DSACK0_N(P_DSACK_n[0]),
					   .mc_DSACK1_N(P_DSACK_n[1]), 
					   .mc_BERR_N(P_BERR_n),
					   .mc_BR_N(ethernetdma_br_n_out),
					   .mc_BG_N(ethernetdma_bg_n),
					   .mc_BGACK_N(ethernetdma_bgack_n_out),

				           .todebug(todebug)
					   );
`endif // !`ifdef BRIDGE_FROM_ETH_VHDL
`endif //  `ifdef LANCE_ETHERNET

`ifdef LANCE_ETHERNET
`ifdef ETH_RMII
   //wire [3:0] 	       phy_txd;    // MII Data               RMII : TXD[1:0]
     wire [1:0] phy_txd_high; 
   //wire 	       phy_tx_en;  // MII Transmit Enable    RMII : TX_EN
   wire 	       phy_tx_er;  // MII Transmit Error     RMII : Speed Detect
   wire 	       phy_tx_clk; // MII Transmit Clock     RMII : CLK = RX_CLK
   wire 	       phy_col;    // MII Collision (async.) RMII : Unused

   //wire [3:0] 	       phy_rxd;    // MII Data               RMII : RXD[1:0]
   wire [1:0] 	       phy_rxd_high;
   //wire 	       phy_rx_dv;  // MII Receive Data Valid RMII : CRS_DV
   //wire 	       phy_rx_er;  // MII Receive Error      RMII : Unused
   //wire 	       phy_rx_clk; // MII Receive Clock 25MHz/2.5MHz RMII : CLK
   wire 	       phy_crs;    // MII Carrier Sense (async.) : RMII : Unused
   
   //wire 	       phy_int_n; // input
   //wire 	       phy_reset_n; // output
   //assign phy_int_n = 1'b1;

   assign phy_rxd_high = 2'b0;
       
   ts_lance_mac eth_mac(
			.phy_txd({phy_txd_high, phy_txd}),
			.phy_tx_en(phy_tx_en),
			.phy_tx_er(phy_tx_er),
			.phy_tx_clk(phy_tx_clk), // unused (?)
			.phy_col(phy_col), // unused
			
			.phy_rxd({phy_rxd_high, phy_rxd}),
			.phy_rx_dv(phy_rx_dv),
			.phy_rx_er(phy_rx_er), // unused
			.phy_rx_clk(clk50m),
			.phy_crs(phy_crs), // unused
			
			.phy_int_n(phy_int_n),
			.phy_reset_n(phy_reset_n),
			
			// to MAC
			.mac_emi_w(amdle_mac_emi_w),
			.mac_emi_r(amdle_mac_emi_r),
			.mac_rec_w(amdle_mac_rec_w),
			.mac_rec_r(amdle_mac_rec_r),
			
			.clk(eth_clk),
			.reset_n(P_RESET_n)
			);
`else // !`ifdef ETH_RMII
   ts_lance_mac_mii ethmac(
			.phy_txd(phy_txd),
			.phy_tx_en(phy_tx_en),
			.phy_tx_er(phy_tx_er),
			.phy_tx_clk(phy_tx_clk),
			.phy_col(phy_col),
			
			.phy_rxd(phy_rxd),
			.phy_rx_dv(phy_rx_dv),
			.phy_rx_er(phy_rx_er),
			.phy_rx_clk(phy_rx_clk),
			.phy_crs(phy_crs),
			
			.phy_int_n(phy_int_n),
			.phy_reset_n(phy_reset_n),
			
			// to MAC
			.mac_emi_w(amdle_mac_emi_w),
			.mac_emi_r(amdle_mac_emi_r),
			.mac_rec_w(amdle_mac_rec_w),
			.mac_rec_r(amdle_mac_rec_r),
			
			.clk(eth_clk),
			.reset_na(P_RESET_n)
			   );
   
`endif // !`ifdef ETH_RMII
`endif //  `ifdef LANCE_ETHERNET
   
endmodule // sun2_fpga

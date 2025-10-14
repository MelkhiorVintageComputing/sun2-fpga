`timescale 1ns/1ns

`include "tolog.v"

module sun3_fpga(input 	     clk40,
		 input 	       clk32768, // improveme
		 output        CLK,
		 input [31:0]  P_ADR_IN,
		 input [31:0]  P_DATA_IN,
		 output [31:0] P_DATA_OUT,
		 input 	       P_DATA_EN,
		 output        P_BERR_n,
		 inout 	       P_RESET_n,
		 inout 	       P_HALT_n,
		 input [2:0]   P_FC,
		 output        P_AVEC_n,
		 output [2:0]  P_IPL_n,
		 input 	       P_IPEND_n,
		 output [1:0]  P_DSACK_n,
		 input [1:0]   P_SIZ,
		 input 	       P_AS_n,
		 input 	       P_RW_n,
		 input 	       P_RMC_n,
		 input 	       P_DS_n,
		 input 	       P_ECS_n,
		 input 	       P_OCS_n,
		 input 	       P_DBEN_n,
		 input 	       P_BUS_EN,
		 output        P_STERM_n,
		 input 	       P_STATUS_n,
		 input 	       P_REFILL_n,
		 output        P_BR_n,
		 input 	       P_BG_n,
		 output        P_BGACK_n
		 );
   
   pullup(P_BR_n); // FIXME
   pullup(P_BGACK_n);

   pullup(P_RESET_n); // FIXME
   pullup(P_HALT_n); // FIXME

   assign P_AVEC_n = 1'b0;
   assign P_STERM_n = 1'b1;
   
   wire 			 EN_DEV;
   wire 			 DISACC;
   
   assign CLK = clk40; // FIXME really fast Sun3 :-)

   reg 	POR_n;
   initial
     begin
	POR_n = 1'b1;
	#5 POR_n = 1'b0;
	#2000 POR_n = 1'b1;
     end
   assign P_RESET_n = POR_n; // FIXME
   assign (strong0, highz1) P_HALT_n = POR_n;

   // layers shortcuts
   wire FC_CTRLLAYER;
   wire FC_CPUCYCLE;
   /* 0x0: reserved, unused */
   assign FC_UDATA     = (P_FC == 3'h1);
   assign FC_UPROG     = (P_FC == 3'h2);
   assign FC_CTRLLAYER = (P_FC == 3'h3);
   /* 0x4: reserved, unused */
   assign FC_SDATA     = (P_FC == 3'h5);
   assign FC_SPROG     = (P_FC == 3'h6);
   assign FC_CPUCYCLE  = (P_FC == 3'h7);
   assign FC_GENERAL   = ~FC_CTRLLAYER & ~FC_CPUCYCLE;

   wire EN_BOOT; // positive logic view of EN_BOOTn

   // P_AS_n timing
   reg C_S3, C_S5, C_S7, C_S9;
   always @(negedge CLK)
     begin
	if (~P_AS_n)        C_S3 <= 1'b1;
	if (~P_AS_n & C_S3) C_S5 <= 1'b1;
	if (~P_AS_n & C_S5) C_S7 <= 1'b1;
	if (~P_AS_n & C_S7) C_S9 <= 1'b1;
	if ( P_AS_n)
	  begin
	     C_S3 <= 1'b0;
	     C_S5 <= 1'b0;
	     C_S7 <= 1'b0;
	     C_S9 <= 1'b0;
	  end
     end
   reg C_S4, C_S6, C_S8, C_S10, C_S12, C_S14, TIMEOUT;
   always @(posedge CLK)
     begin
	if (~P_AS_n & C_S3) C_S4 <= 1'b1;
	if (~P_AS_n & C_S4) C_S6 <= 1'b1;
	if (~P_AS_n & C_S6) C_S8 <= 1'b1;
	if (~P_AS_n & C_S8) C_S10 <= 1'b1;
	if (~P_AS_n & C_S10) C_S12 <= 1'b1;
	if (~P_AS_n & C_S12) C_S14 <= 1'b1;
	if (~P_AS_n & C_S14) TIMEOUT <= 1'b1; // CHECKME: sun3, too soon?
	if ( P_AS_n)
	  begin
	     C_S4 <= 1'b0;
	     C_S6 <= 1'b0;
	     C_S8 <= 1'b0;
	     C_S10 <= 1'b0;
	     C_S12 <= 1'b0;
	     C_S14 <= 1'b0;
	     TIMEOUT <= 1'b0;
	  end
     end

   // match wire for the control/mmu space
   // can match early because they only depend on the P_A address
   wire 			 MATCH_CTX, MATCH_SMAP, MATCH_PMAP;
   wire 			 MATCH_IDPROM, MATCH_SYSEN, MATCH_BERR, MATCH_DIAG, MATCH_UARTBYP;
   assign MATCH_IDPROM  = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h0);
   assign MATCH_PMAP    = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h1); // Long
   assign MATCH_SMAP    = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h2);
   assign MATCH_CTX     = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h3);
   assign MATCH_SYSEN   = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h4);
   //assign MATCH_UDVMA   = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h5); // optional (not on 3/60)
   assign MATCH_BERR    = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h6);
   assign MATCH_DIAG    = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h7);
   //assign MATCH_CTAGS   = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h8); // optional
   //assign MATCH_CDATA   = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'h9); // optional
   //assign MATCH_COPS    = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'hA); // optional
   //assign MATCH_BOPS    = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'hB); // optional
   /* 0xC to 0xE: unused */
   assign MATCH_UARTBYP = (FC_CTRLLAYER) & (P_ADR_IN[31:28] == 4'hF);

   wire [31:0] 			 pa_forshow; // more readable as a wave, no functional use
   assign pa_forshow = {ma_pmap2devices, P_ADR_IN[12:0]};

   wire 			 MATCH_PROM_BOOT;
   assign MATCH_PROM_BOOT  = ((FC_SPROG) & (EN_BOOT)); // at boot (bit from SYSEN): all Supervisor Program are from the PROM

   wire 			 WR;
   assign WR = ~P_DS_n & ~P_AS_n & ~P_RW_n;
   wire 			 RD;
   assign RD = ~P_DS_n & ~P_AS_n &  P_RW_n;

   // MMU & control layers
   wire [7:0] 			 ctx_out;
   wire [7:0] 			 ia_smap2pmap; // fixme: parametrizable
   wire [18:0] 			 ma_pmap2devices; // only 16-bits in e.g. 3/60 // fixme: parametrizable
   wire [7:0] 			 ps_pmap2devices; // fixme: parametrizable
   wire [3:0] 			 mmu_stat_in; 			 

   sun3_mmu mmu(.CLK(CLK),
		/* matching */
		.MATCH_CTX(MATCH_CTX),
		.MATCH_SMAP(MATCH_SMAP),
		.MATCH_PMAP_PS(MATCH_PMAP),
		.MATCH_PMAP_MA(MATCH_PMAP),
		.WR(WR),
		.RD(RD),
		/* CPU signals */
		.P_DIN(P_DATA_IN),
		.P_A(P_ADR_IN),
		.P_FC(P_FC),
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
   assign mmu_stat_in[2] = TYPE[0];
   assign mmu_stat_in[3] = TYPE[1];
   

   // combinatorial protection check on Page Map output, valid alongside ps_pmap2devices
   // FIXME: FINISHME
   wire 			 BERR_P, BERR_V, BERR_T;
   // EN_DEV from 3/60:u102, minus R_ACK
   // normally, EN_DEV is further qualified by TYPE (from MMU) and some PA bits
   assign EN_DEV = ((P_ADR_IN[31:28] == 4'h0) & (FC_UPROG)           ) |
		   ((P_ADR_IN[31:28] == 4'h0) & (FC_UDATA | FC_SDATA)) |
		   ((P_ADR_IN[31:28] == 4'hF) & (FC_UPROG)           ) |
		   ((P_ADR_IN[31:28] == 4'hF) & (FC_UDATA | FC_SDATA)) |
		   ((P_ADR_IN[31:28] == 4'h0) & (FC_UPROG | FC_SPROG) & !EN_BOOT) |
		   ((P_ADR_IN[31:28] == 4'hF) & (FC_UPROG | FC_SPROG) & !EN_BOOT);
   // DISACC in 3/60:u232
   assign DISACC = ((!MMU_V                  & EN_DEV) |                   /* access not valid [also BERR_V] */
		    ( MMU_V & MMU_S          & EN_DEV & !P_FC[2]) |          /* supervisor-only access but not supervisor request (FC2==1 is supervisor) [also BERR_P]*/
		    ( MMU_V         & !MMU_W & EN_DEV            & WR)); /* read-only access but attempting to write [also BERR_P] */
   // BERR.P, BERR.V in 3/60:u232
   assign BERR_V =  (!MMU_V                  & EN_DEV);
   assign BERR_P = (( MMU_V & MMU_S          & EN_DEV & !P_FC[2]) |
		    ( MMU_V         & !MMU_W & EN_DEV            & WR));
   // BERR.T: custom
   assign BERR_T = TIMEOUT;
   
   // IDPROM, read-only
   wire [7:0] 			 idprom_out;
   idprom_sun3 idprom(.CLK(CLK),
		      .idx(P_ADR_IN[4:0]),
		      .dout(idprom_out)
		      );

   // Diagnostic register, write-only
   wire [7:0] 			 leds;
   gen8bit_reg diag(.CLK(CLK),
		    .din(P_DATA_IN[31:24]),
		    .WR(WR & MATCH_DIAG & C_S4),
		    .dout(leds),
		    .CLR_n(1'b1)
		    );
   
   // Bus Error Register, read-only
   wire [7:0] 			 berr_in;
   wire [7:0] 			 berr_out;
   wire 			 BERRCLK;
   
   //assign berr_in = {1'b1, 1'b1, FPAENERR, FPABERR, VMEBERR, TIMEOUT, PROTERR, INVALID}; // this is from the architecture manual
   //assign berr_in = {WDOGn, 1'b1, 1'b1, 1'b1, 1'b1, BERR_Tn, BERR_Pn, BERR_Vn}; // this is from the 3/60 schematics
   //assign berr_in = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, BERR_T, BERR_P, BERR_V}; // we use positive logic // fixme: watchdog?
   assign berr_in = { BERR_V, BERR_P, BERR_T, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 }; // grr, bit order (timeout is 0x20) // we use positive logic // fixme: watchdog?
   
   gen8bit_reg berr(.CLK(CLK),
		    .din(berr_in),
		    .WR(BERRCLK),
		    .dout(berr_out),
		    .CLR_n(POR_n /*1'b1 */) /* FIXME: how is supposed to be initialized ??? */
		    );
   assign BERRCLK	= (C_S8 & (BERR_P | BERR_T | BERR_V)); // FIXME: timing?
   assign BERR	        = (C_S8 & (BERR_P | BERR_T | BERR_V)); // FIXME: timing?
   assign P_BERR_n = ~BERR;

   // System Enable register
   wire [7:0] 			 sys_out;
   gen8bit_reg sys(.CLK(CLK),
		   .din(P_DATA_IN[31:24]),
		   .WR(WR & MATCH_SYSEN & C_S4),
		   .dout(sys_out),
		   .CLR_n(P_RESET_n)
		   );
   /* split the 8 system bits by name */
   wire 			 EN_DIAG, EN_FPA, EN_COPY, EN_VIDEO, EN_CACHE, EN_SDVMA, EN_FPP, EN_BOOTn;
   
   assign EN_DIAG  = sys_out[0];
   assign EN_FPA   = sys_out[1];
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

   // PROM (two access modes: at boot using P_A, or mapped but matched through MA), read-only
   // handled by the two match signals in the bus section, the PROM itself always output whatever is addressed
   wire [31:0] 			 prom_out;
   bootrom32 bootrom(.CLK(CLK),
		     .idx(P_ADR_IN[15:2]),
		     .dout(prom_out)
		     );

   // match wire for devices
   // matching late as we need to be sure the MA is now valid, two clocks after the address is valid
   // that happens on entry in S2 (rising edge), so on that edge IA becomes valid
   // then on entry in S4 MA becomes valid
   wire 			 MATCH_KBDMS, MATCH_SERIAL, MATCH_EEPROM, MATCH_TIMER;
   wire 			 MATCH_IRQREG, MATCH_PROM;
   assign MATCH_KBDMS    = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h0) & C_S6;
   assign MATCH_SERIAL   = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h1) & C_S6;
   assign MATCH_EEPROM   = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h2) & C_S6;
   assign MATCH_TIMER    = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h3) & C_S6;
   //assign MATCH_MEMERR   = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h4) & C_S6; // no parity?
   assign MATCH_IRQREG   = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h5) & C_S6;
   //assign MATCH_I82586   = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h6) & C_S6;
   //assign MATCH_CMAP     = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h7) & C_S6; // color FB only
   
   assign MATCH_PROM     = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h8) & C_S6;
   //assign MATCH_AMDLE    = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'h9) & C_S6;
   //assign MATCH_SCSI     = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hA) & C_S6;
   //assign MATCH_RSVD1    = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hB) & C_S6;
   //assign MATCH_RSVD2    = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hC) & C_S6;
   //assign MATCH_RSVD3    = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hD) & C_S6;
   //assign MATCH_DEP      = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hE) & C_S6; // uninstalled Data Encryption Processor
   //assign MATCH_ECCREG   = (FC_GENERAL) & (TYPE == 2'h1) & !DISACC & (ma_pmap2devices[7:4] == 4'hF) & C_S6; // ECC memory only

   assign MATCH_MEM      = (FC_GENERAL) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:8] == 11'h000) & C_S6; // "physically" installed, here just the two megs
   assign MATCH_MEMX     = (FC_GENERAL) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:11] == 8'h00) & C_S6; // addressable // CHECKME: sun3 behavior
   //assign MATCH_FBMEMX   = (FC_GENERAL) & (TYPE == 2'h0) & !DISACC & (ma_pmap2devices[18:11] == 8'hFF) & C_S6; // addressable // CHECKME: sun3 behavior

   /* VME spaces, unused, no timing, FYI only */
   //assign MATCH_VME16_32 = (FC_GENERAL) & (TYPE == 2'h2) & !DISACC);
   //assign MATCH_VME16_16 = (FC_GENERAL) & (TYPE == 2'h2) & !DISACC & (ma_pmap2devices[18:11] == 8'hFF));
   //assign MATCH_VME16_08 = (FC_GENERAL) & (TYPE == 2'h2) & !DISACC & (ma_pmap2devices[18:3] == 16'hFFFF));
   //assign MATCH_VME32_32 = (FC_GENERAL) & (TYPE == 2'h3) & !DISACC);
   //assign MATCH_VME32_16 = (FC_GENERAL) & (TYPE == 2'h3) & !DISACC & (ma_pmap2devices[18:11] == 8'hFF));
   //assign MATCH_VME32_08 = (FC_GENERAL) & (TYPE == 2'h3) & !DISACC & (ma_pmap2devices[18:3] == 16'hFFFF));
   /* won't even bother with the FPA */

   wire [7:0] 			 timer_out;
   wire 			 timer_bus_en;
   wire 			 timer_int_n;
   
/* -----\/----- EXCLUDED -----\/-----
   ttl_icm7170_alt timerchip(.CLK(CLK),
			     .idx(P_ADR_IN[4:0]),
			     .din(P_DATA_IN[31:24]),
			     .dout(timer_out),
			     .RD(MATCH_TIMER & RD),
			     .WR(MATCH_TIMER & WR),
			     .int_n(timer_int_n));
 -----/\----- EXCLUDED -----/\----- */
   
 icm7170 timerchip(.rst_n(POR_n),
		   .a_in(P_ADR_IN[4:0]),
		   .d_bus_in(P_DATA_IN[31:24]),
		   .d_bus_out(timer_out),
		   .d_bus_en(timer_bus_en),
		   .rd_n(~MATCH_TIMER | ~RD),
		   .wr_n(~MATCH_TIMER | ~WR),
		   .cs_n(1'b0), 
		   .ale(1'b1),
		   // Oscillator
		   .osc_in(clk32768), 
		   .osc_out(),
		   .int_source(1'b0),
		   .int_out(timer_int_n),
		   .vdd_present(1'b1),
		   .vbackup_present(1'b1),
		   .use_ext_100hz(1'b0),
		   .clk_100hz(1'b0));

   /* the actual memory. For now it's just synchronous RAM */
   /* should probably be moved to some "real" RAM with variable timings, which will require changing the bus mux below */
   wire [31:0] 			 mem_out;
   wire 			 EN_LLBYTE, EN_LUBYTE, EN_ULBYTE, EN_UUBYTE;
   
   sram_sync_32bits_bytewritable #(.IDX_WIDTH(18)) mainmem (.CLK(CLK),
							  .idx({ma_pmap2devices[8:0],P_ADR_IN[10:2]}),
							  .WRll(WR & MATCH_MEM & EN_LLBYTE),
							  .WRlu(WR & MATCH_MEM & EN_LUBYTE),
							  .WRul(WR & MATCH_MEM & EN_ULBYTE),
							  .WRuu(WR & MATCH_MEM & EN_UUBYTE),
							  .din(P_DATA_IN),
							  .dout(mem_out)
							  );
   assign EN_LLBYTE = ( P_ADR_IN[0] &  P_ADR_IN[1]) | (                P_ADR_IN[1]             &  P_SIZ[1]) | (               ~P_SIZ[0] & ~P_SIZ[1]) | ( P_ADR_IN[0] &                P_SIZ[0] & P_SIZ[1]);
   assign EN_LUBYTE = (~P_ADR_IN[0] &  P_ADR_IN[1]) | ( P_ADR_IN[0] & ~P_ADR_IN[1]             &  P_SIZ[1]) | (~P_ADR_IN[1] & ~P_SIZ[0] & ~P_SIZ[1]) | (               ~P_ADR_IN[1] & P_SIZ[0] & P_SIZ[1]);
   assign EN_ULBYTE = ( P_ADR_IN[0] & ~P_ADR_IN[1]) | (               ~P_ADR_IN[1] & ~P_SIZ[0])             | (~P_ADR_IN[1]             &  P_SIZ[1]);
   assign EN_UUBYTE = (~P_ADR_IN[0] & ~P_ADR_IN[1]);
   
   /* serial port */
   wire [7:0] 			 serial_out;
   wire 			 serial_en;
   wire 			 serial_int_n; // FIXME: DOME
   wire 			 TxDA, TxDA_EN;
  
   tolog tolog(.CLK(CLK), .TxDA(TxDA)); // so we can trace only TxDA in the VCD, pulseview doesn't like too many signals
   
   SCC8530_TOP serial(
		      // System controls:
		      .PCLK(CLK), // in // CHECKME: sun3 expect a 4.9152 clock, like sun2
		      
		      // Bus:
		      .DATA_IN(P_DATA_IN[31:24]), // in
		      .DATA_OUT(serial_out), // out
		      .DATA_EN(serial_en), // out
		      
		      // Bus controls:
		      .CEn(1'b0), // in
		      .RDn(((~MATCH_SERIAL & ~MATCH_UARTBYP) | ~RD) & POR_n), // in // POR_n for HW reset
		      .WRn(((~MATCH_SERIAL & ~MATCH_UARTBYP) | ~WR) & POR_n), // in // POR_n for HW reset
		      .A_Bn(P_ADR_IN[2]), // in
		      .D_Cn(P_ADR_IN[1]), // in
		      
		      // Interrupt:
		      .INTACKn(1'b1), // in
		      .IEI(1'b1), // in
		      .IEO(), // out
		      .INTn(serial_int_n), // out // Open drain in 5380.
		      
		      // Serial Data:
		      .RxDA(), // in
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
   
   wire [7:0] 			 kbdms_out;
   wire 			 kbdms_en;
   wire 			 kbdms_int_n; // FIXME: DOME
   SCC8530_TOP kbdms(
		      // System controls:
		      .PCLK(CLK), // in // CHECKME: sun3 expect a 4.9152 clock, like sun2
		      
		      // Bus:
		      .DATA_IN(P_DATA_IN[31:24]), // in
		      .DATA_OUT(kbdms_out), // out
		      .DATA_EN(kbdms_en), // out
		      
		      // Bus controls:
		      .CEn(1'b0), // in
		      .RDn((~MATCH_KBDMS | ~RD) & POR_n), // in
		      .WRn((~MATCH_KBDMS | ~WR) & POR_n), // in
		      .A_Bn(P_ADR_IN[2]), // in
		      .D_Cn(P_ADR_IN[1]), // in
		      
		      // Interrupt:
		      .INTACKn(1'b1), // in
		      .IEI(1'b1), // in
		      .IEO(), // out
		      .INTn(kbdms_int_n), // out // Open drain in 5380.
		      
		      // Serial Data:
		      .RxDA(), // in
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

   wire [7:0] 			 eeprom_out;
   eeprom eeprom(.CLK(CLK),
		 .idx(P_ADR_IN[10:0]),
		 .WR(WR & MATCH_EEPROM),
		 .din(P_DATA_IN[31:24]),
		 .dout(eeprom_out));
   
   
   // IRQ reg
   wire [7:0] 			 irqreg_out;
   gen8bit_reg irqreg(.CLK(CLK),
		      .din(P_DATA_IN[31:24]),
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
   
   
   // Answering the CPU
   // bus muxer. CPU has priority via DATA_EN, otherwise whomever is matched own the bus
   assign P_DATA_OUT = P_DATA_EN         ? P_DATA_IN : // loopback
		       MATCH_CTX       ? {ctx_out, 24'h000000} :
		       MATCH_SMAP      ? {ia_smap2pmap, 24'h000000} :
		       MATCH_PMAP      ? {ps_pmap2devices, 5'h00, ma_pmap2devices} :
		       MATCH_SYSEN     ? {sys_out, 24'h000000} :
		       MATCH_BERR      ? {berr_out, 24'h000000} :
		       MATCH_IDPROM    ? {idprom_out, 24'h000000} :
		       MATCH_PROM_BOOT ? prom_out :
		       MATCH_PROM      ? prom_out :
		       MATCH_MEM       ? mem_out :
		       MATCH_KBDMS     ? {kbdms_out, 24'h000000} :
		       MATCH_SERIAL    ? {serial_out, 24'h000000} :
		       MATCH_UARTBYP   ? {serial_out, 24'h000000} :
		       MATCH_EEPROM    ? {eeprom_out, 24'h000000} :
		       MATCH_TIMER     ? {timer_out, 24'h000000} :
		       MATCH_IRQREG    ? {irqreg_out, 24'h000000} :
		       32'hDEADBEEF;

   // DSACK generator. has knowledge of timings for all devices
   wire 	       DO_ACK;
   
   // For memory this will need updating if we use "real" (variable-timing) memory
   assign DO_ACK = ( // FIXME: 32 vs 16 vs 8 bits, sun3 (or rewire for eevryone to be 32-bits-like ?)
		     /* reads */
		     ( P_RW_n & C_S4 & (MATCH_CTX | MATCH_IDPROM | MATCH_SYSEN | MATCH_BERR | MATCH_PROM_BOOT | MATCH_UARTBYP)) | // entering S4, quick devices
		     ( P_RW_n & C_S4 & (MATCH_SMAP)) |  // entering S4, quick devices (CTX is 1 clock but went valid after being written, not affected by P_A)
		     ( P_RW_n & C_S6 & (MATCH_PMAP)) |  // entering S6, physical map needed an extra cycle
		     ( P_RW_n & C_S8 & (MATCH_MEMX | MATCH_KBDMS | MATCH_SERIAL | MATCH_EEPROM | MATCH_TIMER | MATCH_IRQREG | MATCH_PROM)) | // entering S8, devices going through the MMU
		     /* writes */
		     (~P_RW_n & C_S4 & (MATCH_CTX | MATCH_SYSEN | MATCH_DIAG | MATCH_UARTBYP)) | // entering S4, quick devices
		     (~P_RW_n & C_S4 & (MATCH_SMAP)) |  // entering S4, quick devices (CTX is 1 clock but went valid after being written, not affected by P_A)
		     (~P_RW_n & C_S6 & (MATCH_PMAP)) |  // entering S6, physical map needed an extra cycle
		     (~P_RW_n & C_S8 & (MATCH_MEMX | MATCH_KBDMS | MATCH_SERIAL | MATCH_EEPROM | MATCH_TIMER | MATCH_IRQREG)) | // entering S8, devices going through the MMU
		     
		     1'b0);
   
   assign P_DSACK_n[0] = ~(DO_ACK); // we only have 8 and 32 bits for now, so everyone assert [0] (16-bits are [1] only]
   assign P_DSACK_n[1] = ~(DO_ACK & (MATCH_PMAP | MATCH_PROM_BOOT | MATCH_PROM | MATCH_MEM)); // 32-bits devices
   
   
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

   // CLOCKS // FIXME
/* -----\/----- EXCLUDED -----\/-----
   reg clk20;
   reg clk10;
   initial
     begin
	clk20 = 1'b0;
	clk10 = 1'b0;
     end
   always @(posedge clk40) clk20 <= ~clk20;
   always @(posedge clk20) clk10 <= ~clk10;
   assign C100 = clk10;
   assign C100_n = ~clk10;
 -----/\----- EXCLUDED -----/\----- */

   // interrupts
   wire 	       RTC, V_INT, SCC_IRQ, E_IRQ, PAR_IRQ, S_IRQ;
   assign RTC = ~timer_int_n;
   /* no video for now */
   assign V_INT = 1'b0;
   /* SCC_IRQ is for both Z8530 */
   assign SCC_IRQ = ~(serial_int_n & kbdms_int_n);
   /* no Ethernet for now */
   assign E_IRQ = 1'b0;
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
   
endmodule // sun2_fpga

`timescale 1ns / 1ps

module top(/* clock, reset */
	   input 	  CLK,
	   input 	  clk4m9152,
	   input 	  clk32k768,
	   input 	  clk50m,
	   /* reset */
	   input 	  sys_reset,
	   /* serial */
	   output 	  tx,
	   input 	  rx,
	   /* kbd, mouse */
	   output 	  kbd_tx,
	   input 	  kbd_rx,
	   input 	  mou_rx,
`ifdef LANCE_ETHERNET
`ifdef ETH_RMII
	   /* RMII eth */
	   output [1:0]   phy_txd,
	   output 	  phy_tx_en,
	   input [1:0] 	  phy_rxd,
	   input 	  phy_rx_er,
	   input 	  phy_rx_dv,
	   input 	  phy_int_n,
	   output 	  phy_reset_n,
`else
		 /* MII eth */
	   output [3:0]   phy_txd,
	   output 	  phy_tx_en,
	   output 	  phy_tx_er,
	   input 	  phy_tx_clk,
	   input 	  phy_col,
	   input [3:0] 	  phy_rxd,
	   input 	  phy_rx_dv,
	   input 	  phy_rx_er,
	   input 	  phy_rx_clk,
	   input 	  phy_crs,
	   input 	  phy_int_n,
	   output 	  phy_reset_n,
`endif // !`ifdef ETH_RMII
	   /* debug */
	   output [63:0]  last_dma,
	   output [255:0] iv,
`endif
	   /* video irq */
	   input 	  V_INT,
	   /* leds, debug */
	   output [7:0]   leds,
	   output 	  en_boot,
	   input 	  diag_switch,
	   //output [2:0]   berrd,
	   output [7:0]   todebug,
	   // output [31:0] PC,

	   /* wishbone */
	   output 	  wb_cyc_o,
	   output 	  wb_stb_o,
	   output [29:0]  wb_adr_o,
	   output [31:0]  wb_dat_o,
	   output [3:0]   wb_sel_o,
	   output 	  wb_we_o,
	   input [31:0]   wb_dat_i,
	   input 	  wb_ack_i
	   );
   wire [31:0] ADR_OUT;
   wire [31:0] DATA_IN;
   wire [31:0] DATA_OUT;
   wire        DATA_EN;
   wire        BERRn;
   wire        P_RESET_n;
   wire        P_HALT_n;
   wire [2:0]  FC_OUT;
   wire        AVECn;
   wire [2:0]  IPLn;
   wire        IPENDn;
   wire [1:0]  DSACKn;
   wire [1:0]  SIZE;
   wire        ASn;
   wire        RWn;
   wire        RMCn;
   wire        DSn;
   wire        ECSn;
   wire        OCSn;
   wire        DBENn;
   wire        BUS_EN;
   wire        STERMn;
   wire        STATUSn;
   wire        REFILLn;
   wire        BRn;
   wire        BGn;
   wire        BGACKn;

   wire [7:0]  leds_n;
   assign leds = ~leds_n;
   
   sun3_fpga sun3(.clk32k768(clk32k768), // improveme
		  .clk4m9152(clk4m9152),
		  .clk50m(clk50m),
		  .CLK(CLK),
		  .sys_reset(sys_reset),
        
		  // Address and data:
		  .P_ADR_IN(ADR_OUT),  // OUT for CPU, IN for sun3
		  .P_DATA_IN(DATA_OUT),// OUT for CPU, IN for sun3
		  .P_DATA_OUT(DATA_IN),// IN for CPU, OUT for sun3
		  .P_DATA_EN(DATA_EN), // Enables the data port.
		  
		  // System control:
		  .P_BERR_n(BERRn),
		  .P_RESET_n(P_RESET_n),
		  .P_HALT_n(P_HALT_n),
		  
		  // Processor status:
		  .P_FC(FC_OUT),// OUT for CPU, IN for sun3
		  
		  // Interrupt control:
		  .P_AVEC_n(AVECn),
		  .P_IPL_n(IPLn),
		  .P_IPEND_n(IPENDn),
		  
		  // Aynchronous bus control:
		  .P_DSACK_n(DSACKn),
		  .P_SIZ(SIZE),
		  .P_AS_n(ASn),
		  .P_RW_n(RWn),
		  .P_RMC_n(RMCn),
		  .P_DS_n(DSn),
		  .P_ECS_n(ECSn),
		  .P_OCS_n(OCSn),
		  .P_DBEN_n(DBENn), // Data buffer enable.
		  .P_BUS_EN(BUS_EN), // Enables ADR, ASn, DSn, RWn, RMCn, FC and SIZE.
		  
		  // Synchronous bus control:
		  .P_STERM_n(STERMn),
		  
		  // Status controls:
		  .P_STATUS_n(STATUSn),
		  .P_REFILL_n(REFILLn),
		  
		  // Bus arbitration control:
		  .P_BR_n(BRn),
		  .P_BG_n(BGn),
		  .P_BGACK_n(BGACKn),

		  .tx(tx),
		  .rx(rx),

		  .kbd_tx(kbd_tx),
		  .kbd_rx(kbd_rx),
		  .mou_rx(mou_rx),

`ifdef LANCE_ETHERNET
`ifdef ETH_RMII
		  .phy_txd(phy_txd),
		  .phy_tx_en(phy_tx_en),
		  .phy_rxd(phy_rxd),
		  .phy_rx_er(phy_rx_er),
		  .phy_rx_dv(phy_rx_dv),
		  .phy_int_n(phy_int_n),
		  .phy_reset_n(phy_reset_n),
`else
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
`endif // !`ifdef ETH_RMII
		  .last_dma(last_dma),
		  .iv(iv),
`endif
		  
		  .V_INT(V_INT),

		  .leds(leds_n),
		  .en_boot(en_boot),
		  .diag_switch(diag_switch),
		  //.berrd(berrd),
		  .todebug(todebug),
				
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
		  
   wire        RESET_INn;
   wire        HALT_INn;
   wire        RESET_OUT;
   wire        HALT_OUTn; // ignored
   
   assign RESET_INn = ~sys_reset; /* board reset => reset CPU */
   assign P_RESET_n = ~sys_reset & ~RESET_OUT; /* board reset or CPU reset => reset system */
   
   assign HALT_INn = ~sys_reset & ~RESET_OUT; /* board reset => reset CPU (HALTn seem needed) */

   WF68K30L_TOP suska_68k30l (
        .CLK(CLK),
        
        // Address and data:
        .ADR_OUT(ADR_OUT),
        .DATA_IN(DATA_IN),
        .DATA_OUT(DATA_OUT),
        .DATA_EN(DATA_EN), // Enables the data port.

        // System control:
        .BERRn(BERRn),
        .RESET_INn(RESET_INn),
        .RESET_OUT(RESET_OUT), // Open drain.
        .HALT_INn(HALT_INn),
        .HALT_OUTn(HALT_OUTn), // Open drain.
        
        // Processor status:
        .FC_OUT(FC_OUT),
        
        // Interrupt control:
        .AVECn(AVECn),
        .IPLn(IPLn),
        .IPENDn(IPENDn),

        // Aynchronous bus control:
        .DSACKn(DSACKn),
        .SIZE(SIZE),
        .ASn(ASn),
        .RWn(RWn),
        .RMCn(RMCn),
        .DSn(DSn),
        .ECSn(ECSn),
        .OCSn(OCSn),
        .DBENn(DBENn), // Data buffer enable.
        .BUS_EN(BUS_EN), // Enables ADR, ASn, DSn, RWn, RMCn, FC and SIZE.

        // Synchronous bus control:
        .STERMn(STERMn),

        // Status controls:
        .STATUSn(STATUSn),
        .REFILLn(REFILLn),

        // Bus arbitration control:
        .BRn(BRn),
        .BGn(BGn),
        .BGACKn(BGACKn)

	// ,.PC(PC)
    );

//`include "sun3-bootrom_check.v"
   
endmodule

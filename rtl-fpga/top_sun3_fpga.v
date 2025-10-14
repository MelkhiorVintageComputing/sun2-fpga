`timescale 1ns / 1ns

module top(input clk40, input clk32768);
   wire CLK;
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
   
   
   sun3_fpga sun3(.clk40(clk40),
		  .clk32768(clk32768),
		  .CLK(CLK),
        
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
		  .P_BGACK_n(BGACKn));
   
		  
   wire        RESET_INn;
   wire        HALT_INn;
   wire        RESET_OUT;
   wire        HALT_OUTn;
   
   assign RESET_INn = P_RESET_n; // FIXME, all that mess
   wire        RESET_OUT_bis;
   assign RESET_OUT = RESET_INn ? RESET_OUT_bis : 1'b0;
   assign (strong0, highz1) P_HALT_n = HALT_OUTn;
   assign HALT_INn = P_HALT_n;
  
   pullup(RESET_INn);

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
    );

   `include "sun3_check.v"
   
endmodule

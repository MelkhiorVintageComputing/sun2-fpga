module m68010_suska(
		    input  C100,
		    input  P_VPA_n,
		    input  P_BERR_n,
		    input  P_DTACK_n,
		    input  P_BR_n,
		    input  P_BGACK_n,

		    inout  P_RESET_n,
		    inout  P_HALT_n,

		    output P_AS_n,
		    output P_RW_n,
		    output P_UDS_n,
		    output P_LDS_n,
		    output P_BG_n,

		    input  IPL2_n,
		    input  IPL1_n,
		    input  IPL0_n,

		    output P_FC2,
		    output P_FC1,
		    output P_FC0,
   
		    inout  P_A1,
		    inout  P_A2,
		    inout  P_A3,
		    inout  P_A4,
		    inout  P_A5,
		    inout  P_A6,
		    inout  P_A7,
		    inout  P_A8,
		    inout  P_A9,
		    inout  P_A10,
		    inout  P_A11,
		    inout  P_A12,
		    inout  P_A13,
		    inout  P_A14,
		    inout  P_A15,
		    inout  P_A16,
		    inout  P_A17,
		    inout  P_A18,
		    inout  P_A19,
		    inout  P_A20,
		    inout  P_A21,
		    inout  P_A22,
		    inout  P_A23,

		    inout  P_D0,
		    inout  P_D1,
		    inout  P_D2,
		    inout  P_D3,
		    inout  P_D4,
		    inout  P_D5,
		    inout  P_D6,
		    inout  P_D7,
		    inout  P_D8,
		    inout  P_D9,
		    inout  P_D10,
		    inout  P_D11,
		    inout  P_D12,
		    inout  P_D13,
		    inout  P_D14,
		    inout  P_D15
		   );
   wire 		   BUS_EN;
   

   wire [15:0] 		   DATA_IN, DATA_OUT;
   wire 		   DATA_EN;
   assign DATA_IN = {P_D15,P_D14,P_D13,P_D12,P_D11,P_D10,P_D9,P_D8,P_D7,P_D6,P_D5,P_D4,P_D3,P_D2,P_D1,P_D0};
   assign P_D0 = DATA_EN ? DATA_OUT[0] : 1'bz;
   assign P_D1 = DATA_EN ? DATA_OUT[1] : 1'bz;
   assign P_D2 = DATA_EN ? DATA_OUT[2] : 1'bz;
   assign P_D3 = DATA_EN ? DATA_OUT[3] : 1'bz;
   assign P_D4 = DATA_EN ? DATA_OUT[4] : 1'bz;
   assign P_D5 = DATA_EN ? DATA_OUT[5] : 1'bz;
   assign P_D6 = DATA_EN ? DATA_OUT[6] : 1'bz;
   assign P_D7 = DATA_EN ? DATA_OUT[7] : 1'bz;
   assign P_D8 = DATA_EN ? DATA_OUT[8] : 1'bz;
   assign P_D9 = DATA_EN ? DATA_OUT[9] : 1'bz;
   assign P_D10 = DATA_EN ? DATA_OUT[10] : 1'bz;
   assign P_D11 = DATA_EN ? DATA_OUT[11] : 1'bz;
   assign P_D12 = DATA_EN ? DATA_OUT[12] : 1'bz;
   assign P_D13 = DATA_EN ? DATA_OUT[13] : 1'bz;
   assign P_D14 = DATA_EN ? DATA_OUT[14] : 1'bz;
   assign P_D15 = DATA_EN ? DATA_OUT[15] : 1'bz;

   wire [31:0] 		   ADR_OUT; // 68K10 has the full 32 bits
   assign P_A1 = BUS_EN ? ADR_OUT[1] : 1'bz;
   assign P_A2 = BUS_EN ? ADR_OUT[2] : 1'bz;
   assign P_A3 = BUS_EN ? ADR_OUT[3] : 1'bz;
   assign P_A4 = BUS_EN ? ADR_OUT[4] : 1'bz;
   assign P_A5 = BUS_EN ? ADR_OUT[5] : 1'bz;
   assign P_A6 = BUS_EN ? ADR_OUT[6] : 1'bz;
   assign P_A7 = BUS_EN ? ADR_OUT[7] : 1'bz;
   assign P_A8 = BUS_EN ? ADR_OUT[8] : 1'bz;
   assign P_A9 = BUS_EN ? ADR_OUT[9] : 1'bz;
   assign P_A10 = BUS_EN ? ADR_OUT[10] : 1'bz;
   assign P_A11 = BUS_EN ? ADR_OUT[11] : 1'bz;
   assign P_A12 = BUS_EN ? ADR_OUT[12] : 1'bz;
   assign P_A13 = BUS_EN ? ADR_OUT[13] : 1'bz;
   assign P_A14 = BUS_EN ? ADR_OUT[14] : 1'bz;
   assign P_A15 = BUS_EN ? ADR_OUT[15] : 1'bz;
   assign P_A16 = BUS_EN ? ADR_OUT[16] : 1'bz;
   assign P_A17 = BUS_EN ? ADR_OUT[17] : 1'bz;
   assign P_A18 = BUS_EN ? ADR_OUT[18] : 1'bz;
   assign P_A19 = BUS_EN ? ADR_OUT[19] : 1'bz;
   assign P_A20 = BUS_EN ? ADR_OUT[20] : 1'bz;
   assign P_A21 = BUS_EN ? ADR_OUT[21] : 1'bz;
   assign P_A22 = BUS_EN ? ADR_OUT[22] : 1'bz;
   assign P_A23 = BUS_EN ? ADR_OUT[23] : 1'bz;

   wire [2:0]		   FC_OUT;
   assign P_FC0 = BUS_EN ? FC_OUT[0] : 1'bz;
   assign P_FC1 = BUS_EN ? FC_OUT[1] : 1'bz;
   assign P_FC2 = BUS_EN ? FC_OUT[2] : 1'bz;

`ifdef UNPATCHED_68K10
   /* SUSKA 68K10 does the initial fetches as FC=2/5 rather than 6/6 */
   reg [3:0] 			   init_cnt;
   always @(negedge P_RESET_n or posedge P_RESET_n)
     begin
	init_cnt <= 0;
     end
   always @(negedge P_AS_n) begin
      if (init_cnt < 6) init_cnt <= init_cnt + 1;
   end
   wire [2:0] FC_OUT_raw;
   assign FC_OUT = (init_cnt < 6) ? 3'b110 : FC_OUT_raw;
`else // !`ifdef UNPATCHED_68K10
   wire [2:0] FC_OUT_raw;
   assign FC_OUT = FC_OUT_raw;
`endif // !`ifdef UNPATCHED_68K10
   

   wire 		   RESET_INn;
   wire 		   RESET_OUT;
   //reg [7:0]			   reset_ctn;
   //always @(posedge C100)
   //  begin
//	if (reset_ctn > 0) reset_ctn <= reset_ctn -1;
//	if (~P_RESET_n) reset_ctn <= 20;
   //  end
   //assign RESET_INn = (reset_ctn > 0) ? 1'b0 : 1'b1;
   assign RESET_INn = P_RESET_n;
   //assign P_RESET_n = BUS_EN ? RESET_OUT : 1'bz;
   //assign P_RESET_n = ~RESET_OUT ? ~RESET_OUT : 1'bz;
   //assign P_RESET_n = 1'bz;
   
   wire 		   RESET_OUT_bis;
   assign RESET_OUT = RESET_INn ? RESET_OUT_bis : 1'b0;

   //assign P_HALT_n = ~HALT_OUTn ? 1'b0: 1'bz;
   assign (strong0, highz1) P_HALT_n = HALT_OUTn;
   
   
   //wire 		   HALT_OUTn_bis ;
   //assign HALT_OUTn =  ~(RESET_INn & ~RESET_OUT) ? 1'b1 : HALT_OUTn_bis;
   
   //reg RESET_INn;
   //initial
   //  begin
	//RESET_INn = 1'b0;
	//#250 RESET_INn  = 1'b1;
   //  end

   wire 		   HALT_INn, HALT_OUTn;
   //assign HALT_INn = ~(RESET_INn & ~RESET_OUT) ? 1'b0 : P_HALT_n;
   //assign P_HALT_n = (BUS_EN & (RESET_INn & ~RESET_OUT)) ? ~HALT_OUTn : 1'bz;
   assign HALT_INn = P_HALT_n;
   

   wire 		   ASn, UDSn, LDSn, RWn;
   assign P_AS_n = (BUS_EN & (RESET_INn & ~RESET_OUT)) ? ASn : 1'bz;
   assign P_RW_n = (BUS_EN & (RESET_INn & ~RESET_OUT)) ? RWn : 1'bz;
   assign P_UDS_n = (BUS_EN & (RESET_INn & ~RESET_OUT)) ? UDSn : 1'bz;
   assign P_LDS_n = (BUS_EN & (RESET_INn & ~RESET_OUT)) ? LDSn : 1'bz;
   wire 		   BGn ;
   assign P_BG_n =  ~(RESET_INn & ~RESET_OUT) ? 1'b1 : BGn;

   
   
   wire 		   RMCn;
   wire 		   BUS_EN_bis;
   wire 		   DATA_EN_bis;

   assign BUS_EN = ~(RESET_INn & ~RESET_OUT) ? 1'b0 : BUS_EN_bis;
   assign DATA_EN = ~(RESET_INn & ~RESET_OUT) ? 1'b0 : DATA_EN_bis;

   wire 		   DTACKn ;
   assign DTACKn =  ~(RESET_INn & ~RESET_OUT) ? 1'b1 : P_DTACK_n;
   //assign DTACKn = 1'b1;
   
   wire 		   BERRn ;
   assign BERRn =  ~(RESET_INn & ~RESET_OUT) ? 1'b1 : P_BERR_n;
   wire 		   VPAn ;
   assign VPAn =  ~(RESET_INn & ~RESET_OUT) ? 1'b1 : P_VPA_n;
   
   
WF68K10_TOP suska_68k10(
.CLK(C100),
.DATA_IN(DATA_IN),
.BERRn(BERRn),
.RESET_INn(RESET_INn),
.HALT_INn(HALT_INn),
.AVECn(1'b1),
.IPLn({IPL2_n, IPL1_n, IPL0_n}),
.DTACKn(DTACKn),
.VPAn(VPAn),
.BRn(P_BR_n),
.BGACKn(P_BGACK_n),
.K6800n(1'b1),
.ADR_OUT(ADR_OUT),
.DATA_OUT(DATA_OUT),
.DATA_EN(DATA_EN_bis),
.RESET_OUT(RESET_OUT_bis),
.HALT_OUTn(HALT_OUTn),
.FC_OUT(FC_OUT_raw),
.ASn(ASn),
.RWn(RWn),
.RMCn(RMCn),
.UDSn(UDSn),
.LDSn(LDSn),
/* -----\/----- EXCLUDED -----\/-----
.DBENn,
 -----/\----- EXCLUDED -----/\----- */
.BUS_EN(BUS_EN_bis),
/* -----\/----- EXCLUDED -----\/-----
.E,
.VMAn,
.VMA_EN,
 -----/\----- EXCLUDED -----/\----- */
.BGn(BGn));
   
`ifdef DEBUG_SUSKA
   always @(negedge BUS_EN) $display("BUS_EN deasserts");
   always @(posedge BUS_EN) $display("BUS_EN asserts");
		       
/* -----\/----- EXCLUDED -----\/-----
   always @(posedge C100) $display("C100 asserts B (%x, %x, %x, %x ; %x, %x, %x ; %x ; %x %x)",
				   P_RESET_n, RESET_INn, RESET_OUT, BUS_EN,
				   P_BR_n, P_BGACK_n, P_BG_n,
				   ~{IPL2_n, IPL1_n, IPL0_n},
				   RWn, RMCn);
 -----/\----- EXCLUDED -----/\----- */
		       
   always @(posedge C100) $display("C100 asserts - CPU inputs are VPAn=%x BERRn=%x RESETn=%x HALTn=%x DTACKn=%x BRn=%x BGACKn=%x IPLn=%x", VPAn, BERRn, RESET_INn, HALT_INn, DTACKn, P_BR_n, P_BGACK_n, {IPL2_n, IPL1_n, IPL0_n});
   always @(posedge C100) $display("C100 asserts - CPU outputs are DATA_EN=%x BUS_EN=%x FC=%x RESET_OUT=%d HALT_OUT=%d ASn=%x RW_n=%x UDS=%x LDS=%x BGn=%x", DATA_EN_bis, BUS_EN_bis, FC_OUT, RESET_OUT_bis, HALT_OUTn, ASn, RWn, UDSn, LDSn, BGn);
   always @(posedge C100) $display("C100 asserts - CPU filtered outputs are DATA_EN=%x BUS_EN=%x FC=%x RESET_OUT=%d HALT_OUT=%d ASn=%x RW_n=%x UDS=%x LDS=%x BGn=%x", DATA_EN, BUS_EN, {P_FC2, P_FC1, P_FC0}, RESET_OUT, HALT_OUTn, P_AS_n, P_RW_n, P_UDS_n, P_LDS_n, P_BG_n);
`endif
   
   always @(negedge P_RESET_n) $display("P_RESET_n asserts (B)");
   always @(posedge P_RESET_n) $display("P_RESET_n deasserts (B)");

`include "check.v"
   
endmodule

`timescale 1ns / 1ns

// `define DEBUG_P2RAM 1
// `define DEBUG_IO 1
// `define DEBUG_PMAP_RD 1
// `define DEBUG_SMAP_WR 1
// `define DEBUG_RAM_IO 1
// `define DEBUG_S6 1
// `define DEBUG_SUSKA

`include "ttl_74F74.v"
`include "ttl_74F74_d.v"
`include "ttl_74F138.v"
`include "ttl_74LS148.v"
`include "ttl_74F151.v"
`include "ttl_74LS244.v"
`include "ttl_74LS245.v"
`include "ttl_74F251.v"
`include "ttl_74F257.v"
`include "ttl_74LS273.v"
`include "ttl_74F374.v"
`include "ttl_74LS393.v"
`include "ttl_74S491.v"
`include "ttl_74LS534.v"
`include "ttl_74LS633.v"
`include "ttl_74LS640.v"
`include "ttl_25LS2518.v"
`include "ttl_58167.v"

`include "ttl_74S288_idprom.v"
`include "ttl_27256_h.v"
`include "ttl_27256_l.v"
`include "ttl_2168_sram.v"

`include "pal20X10_u211.v"
`include "pal20L10_u212.v"
`include "pal16R4_u213.v"
`include "pal16R4_u316.v"
`include "pal16R4_u415.v"
`include "pal16R8_u602.v"
`include "pal16R4_u718.v"

`include "ttl_am2949.v"
`include "ttl_am9513.v"
`include "ttl_Z8530.v"

`include "m68010_model.v"
`include "m68010_cosim.v"
`include "m68010_suska.v"
`include "p2_ram.v"
`include "dpram_128k.v"
`include "p2_video.v"
`include "p2_kb.v"
`include "p2_intf.v"

`include "sun2_ttl.v"

module top(input clk40);

   wire C100;
   wire P_VPA_n;
   wire P_BERR_n;
   wire P_DTACK_n;
   wire P_BR_n;
   wire P_BGACK_n;

   wire P_RESET_n;
   wire P_HALT_n;

   wire P_AS_n;
   wire P_RW_n;
   wire P_UDS_n;
   wire P_LDS_n;
   wire P_BG_n;

   wire IPL2_n;
   wire IPL1_n;
   wire IPL0_n;

   wire P_FC2;
   wire P_FC1;
   wire P_FC0;
   
   wire P_A1;
   wire P_A2;
   wire P_A3;
   wire P_A4;
   wire P_A5;
   wire P_A6;
   wire P_A7;
   wire P_A8;
   wire P_A9;
   wire P_A10;
   wire P_A11;
   wire P_A12;
   wire P_A13;
   wire P_A14;
   wire P_A15;
   wire P_A16;
   wire P_A17;
   wire P_A18;
   wire P_A19;
   wire P_A20;
   wire P_A21;
   wire P_A22;
   wire P_A23;

   wire P_D0;
   wire P_D1;
   wire P_D2;
   wire P_D3;
   wire P_D4;
   wire P_D5;
   wire P_D6;
   wire P_D7;
   wire P_D8;
   wire P_D9;
   wire P_D10;
   wire P_D11;
   wire P_D12;
   wire P_D13;
   wire P_D14;
   wire P_D15;
   
   sun2_ttl sun2(
		 .clk40(clk40),
		 .C100(C100),
		 .P_VPA_n(P_VPA_n),
		 .P_BERR_n(P_BERR_n),
		 .P_DTACK_n(P_DTACK_n),
		 .P_BR_n(P_BR_n),
		 .P_BGACK_n(P_BGACK_n),

  		 .P_RESET_n(P_RESET_n),
		 .P_HALT_n(P_HALT_n),

		 .P_AS_n(P_AS_n),
		 .P_RW_n(P_RW_n),
		 .P_UDS_n(P_UDS_n),
		 .P_LDS_n(P_LDS_n),
		 .P_BG_n(P_BG_n),

		 .IPL2_n(IPL2_n),
		 .IPL1_n(IPL1_n),
		 .IPL0_n(IPL0_n),

		 .P_FC2(P_FC2),
		 .P_FC1(P_FC1),
		 .P_FC0(P_FC0),
   
		 .P_A1(P_A1),
		 .P_A2(P_A2),
		 .P_A3(P_A3),
		 .P_A4(P_A4),
		 .P_A5(P_A5),
		 .P_A6(P_A6),
		 .P_A7(P_A7),
		 .P_A8(P_A8),
		 .P_A9(P_A9),
		 .P_A10(P_A10),
		 .P_A11(P_A11),
		 .P_A12(P_A12),
		 .P_A13(P_A13),
		 .P_A14(P_A14),
		 .P_A15(P_A15),
		 .P_A16(P_A16),
		 .P_A17(P_A17),
		 .P_A18(P_A18),
		 .P_A19(P_A19),
		 .P_A20(P_A20),
		 .P_A21(P_A21),
		 .P_A22(P_A22),
		 .P_A23(P_A23),

		 .P_D0(P_D0),
		 .P_D1(P_D1),
		 .P_D2(P_D2),
		 .P_D3(P_D3),
		 .P_D4(P_D4),
		 .P_D5(P_D5),
		 .P_D6(P_D6),
		 .P_D7(P_D7),
		 .P_D8(P_D8),
		 .P_D9(P_D9),
		 .P_D10(P_D10),
		 .P_D11(P_D11),
		 .P_D12(P_D12),
		 .P_D13(P_D13),
		 .P_D14(P_D14),
		 .P_D15(P_D15)
		   );

`ifndef cosim
   m68010_model m68010(
`else
   m68010_suska m68010(
`endif
		 .C100(C100),
		 .P_VPA_n(P_VPA_n),
		 .P_BERR_n(P_BERR_n),
		 .P_DTACK_n(P_DTACK_n),
		 .P_BR_n(P_BR_n),
		 .P_BGACK_n(P_BGACK_n),

  		 .P_RESET_n(P_RESET_n),
		 .P_HALT_n(P_HALT_n),

		 .P_AS_n(P_AS_n),
		 .P_RW_n(P_RW_n),
		 .P_UDS_n(P_UDS_n),
		 .P_LDS_n(P_LDS_n),
		 .P_BG_n(P_BG_n),

		 .IPL2_n(IPL2_n),
		 .IPL1_n(IPL1_n),
		 .IPL0_n(IPL0_n),

		 .P_FC2(P_FC2),
		 .P_FC1(P_FC1),
		 .P_FC0(P_FC0),
   
		 .P_A1(P_A1),
		 .P_A2(P_A2),
		 .P_A3(P_A3),
		 .P_A4(P_A4),
		 .P_A5(P_A5),
		 .P_A6(P_A6),
		 .P_A7(P_A7),
		 .P_A8(P_A8),
		 .P_A9(P_A9),
		 .P_A10(P_A10),
		 .P_A11(P_A11),
		 .P_A12(P_A12),
		 .P_A13(P_A13),
		 .P_A14(P_A14),
		 .P_A15(P_A15),
		 .P_A16(P_A16),
		 .P_A17(P_A17),
		 .P_A18(P_A18),
		 .P_A19(P_A19),
		 .P_A20(P_A20),
		 .P_A21(P_A21),
		 .P_A22(P_A22),
		 .P_A23(P_A23),

		 .P_D0(P_D0),
		 .P_D1(P_D1),
		 .P_D2(P_D2),
		 .P_D3(P_D3),
		 .P_D4(P_D4),
		 .P_D5(P_D5),
		 .P_D6(P_D6),
		 .P_D7(P_D7),
		 .P_D8(P_D8),
		 .P_D9(P_D9),
		 .P_D10(P_D10),
		 .P_D11(P_D11),
		 .P_D12(P_D12),
		 .P_D13(P_D13),
		 .P_D14(P_D14),
		 .P_D15(P_D15)
		   );
   
endmodule

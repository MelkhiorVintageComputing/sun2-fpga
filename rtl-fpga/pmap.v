`timescale 1ns / 1ns

module pmap_sram(input CLK,
		 input [11:0]  idx,
		 input 	       WR_ma,
		 input 	       WR_ps,
		 input [11:0]  ma_in,
		 input [11:0]  ps_in,
		 output [11:0] ma_out,
		 output [11:0] ps_out
		 );



   sram_sync  #(.DATA_WIDTH(12), .IDX_WIDTH(12)) datamap (.CLK(CLK),
							   .idx(idx),
							   .WR(WR_ma),
							   .din(ma_in),
							   .dout(ma_out)
							   );
							   
   sram_sync #(.DATA_WIDTH(12), .IDX_WIDTH(12)) protmap (.CLK(CLK),
							   .idx(idx),
							   .WR(WR_ps),
							   .din(ps_in),
							   .dout(ps_out)
							   );
   
endmodule;


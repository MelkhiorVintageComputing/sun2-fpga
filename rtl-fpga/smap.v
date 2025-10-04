`timescale 1ns / 1ns
module smap_sram(input CLK,
		 input [11:0] idx,
		 input 	      WR,
		 input [7:0]  ia_in,
		 output [7:0] ia_out
		 );

   sram_sync #(.DATA_WIDTH(8), .IDX_WIDTH(12)) smap (.CLK(CLK),
						  .idx(idx),
						  .WR(WR),
						  .din(ia_in),
						  .dout(ia_out)
						  );
endmodule; // smap_sync

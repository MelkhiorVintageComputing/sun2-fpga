`timescale 1ns/1ns

module sram_sync_32bits_bytewritable #(parameter IDX_WIDTH=18) (input CLK,
								input [IDX_WIDTH-1:0] idx,
								input 		      WRll,
								input 		      WRlu,
								input 		      WRul,
								input 		      WRuu,
								input [31:0] 	      din,
								output [31:0] 	      dout
								);
   
   sram_sync #(.DATA_WIDTH(8), .IDX_WIDTH(IDX_WIDTH)) llbyte (.CLK(CLK),
							      .idx(idx),
							      .WR(WRll),
							      .din(din[7:0]),
							      .dout(dout[7:0])
							      );
   sram_sync #(.DATA_WIDTH(8), .IDX_WIDTH(IDX_WIDTH)) lubyte (.CLK(CLK),
							      .idx(idx),
							      .WR(WRlu),
							      .din(din[15:8]),
							      .dout(dout[15:8])
							      );
   
   sram_sync #(.DATA_WIDTH(8), .IDX_WIDTH(IDX_WIDTH)) ulbyte (.CLK(CLK),
							      .idx(idx),
							       .WR(WRul),
							      .din(din[23:16]),
							      .dout(dout[23:16])
							      );
   sram_sync #(.DATA_WIDTH(8), .IDX_WIDTH(IDX_WIDTH)) uubyte (.CLK(CLK),
								.idx(idx),
							      .WR(WRuu),
							      .din(din[31:24]),
							      .dout(dout[31:24])
							      );
   
endmodule // sram_sync_32bits_bytewritable


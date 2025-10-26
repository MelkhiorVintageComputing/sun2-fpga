`timescale 1ns / 1ps

module bootrom32(input CLK,
		 input [13:0] 	   idx,
		 output reg [31:0] dout
		 );
   
  always @(CLK)
    begin
       case(idx)
`include "bootrom_patched_32bits.v"
       endcase // case (idx)
    end

  endmodule // bootrom

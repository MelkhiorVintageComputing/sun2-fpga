`timescale 1ns/1ns

module bootrom(input CLK,
	       input [14:0] idx,
	       output reg [15:0] dout
	       );
   
  always @(CLK)
    begin
       case(idx)
`include "bootrom_patched_16bits.v"
       endcase; // case (idx)
    end;

  endmodule; // bootrom

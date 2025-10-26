`timescale 1ns / 1ps

`include "top_fpga.v"


module tb();
   reg clk40;
   reg cpu_trace = 0;
   
   top dut(.clk40(clk40));

   always
     begin
	// 39.3216 MHz, which is 9600*4096 so the UART are easy to deal with (as in the real hardware)
	#12.71565755208333333000 clk40 = 0;
	#12.71565755208333333000 clk40 = 1;
     end

  initial
    begin
       $timeformat(-9, 0, "ns", 7);
       $dumpfile("sun2.vcd");
       $dumpvars(0, dut.sun2.tolog);
       $dumpoff;
       
       
       //#1000 $dumpoff;
       //#500000 $finish;
       //#50000000 $finish;
    end
       

   always @(posedge clk40) if (~dut.sun2.TxDA_EN) $dumpon;
   
   always
     begin
	#100000000 $display("Time is %t", $realtime);
     end
   
endmodule


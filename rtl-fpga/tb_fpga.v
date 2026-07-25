`timescale 1ns / 1ps

`include "top_fpga.v"


module tb();
   reg clk40;
   reg cpu_trace = 0;
   reg sys_reset;
   wire rx, tx;
   
   top dut(.clk40(clk40),
	   .sys_reset(sys_reset),
	   .tx(tx),
	   .rx(rx));

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
       #5 sys_reset <= 1'b1;
       #2000 sys_reset <= 1'b0;
       
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


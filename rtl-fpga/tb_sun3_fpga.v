`timescale 1ns/1ps

`include "top_sun3_fpga.v"


module tb();
   reg clk40;
   reg clk32768;
   
   reg cpu_trace = 0;
   reg serial_trace = 0;
   
   
   top dut(.clk40(clk40), .clk32768(clk32768));

   always
     begin
	//// 39.3216 MHz, which is 9600*4096 so the UART are easy to deal with (as in the real hardware)
	//#12.71565755208333333000 clk40 = 0;
	//#12.71565755208333333000 clk40 = 1;
	#12.5 clk40 = 0;
	#12.5 clk40 = 1;
     end

   always
     begin
	// 32.768 kHz clock for ICM7170
	clk32768 = 1;
	#15258.789 clk32768 = 0;
	#15258.789 clk32768 = 1;
     end

  initial
    begin
       $timeformat(-9, 0, "ns", 7);
       $dumpfile("sun3.vcd");
       $dumpvars(0, dut.sun3.tolog);
       $dumpoff;
       
       //#100000 $finish;
       
       //#1000 $dumpoff;
       //#500000 $finish;
       //#50000000 $finish;
    end
       
   
   always @(posedge clk40) if (~dut.sun3.TxDA_EN) serial_trace = 1;
   always @(posedge clk40) if ( dut.sun3.TxDA_EN & serial_trace) $dumpon;
   
   always
     begin
	#100000000 $display("Time is %t", $realtime);
     end
   
endmodule


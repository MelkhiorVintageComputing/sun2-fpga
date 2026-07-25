`timescale 1ns / 1ps

`include "top_fpga.v"


module tb();
   reg clk40;
   reg cpu_trace = 0;
   reg sys_reset;
   wire rx, tx;
   wire clk4m9152;
   
   top dut(.clk40(clk40),
	   .clk4m9152(clk4m9152),
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
    end // initial begin

   // derive 39.3216 into 4.9152 MHz clock
   // we can change this with the new split-clock SCC
   reg [3:0] clk4m9152_ctr = 4'h0;
   always @(posedge clk40)
     begin
	clk4m9152_ctr <= clk4m9152_ctr + 1;
     end
   assign clk4m9152 = clk4m9152_ctr[3];

   always @(posedge clk40) if (~dut.sun2.TxDA_EN) $dumpon;
   
   always
     begin
	#100000000 $display("Time is %t", $realtime);
     end
   
endmodule


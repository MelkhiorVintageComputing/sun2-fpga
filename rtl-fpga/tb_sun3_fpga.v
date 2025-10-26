`timescale 1ns / 1ps

`include "top_sun3_fpga.v"

`include "tolog.v"

module tb();
   reg CLK;
   reg clk32k768;
   wire clk4m9152;
   wire rx, tx;
   reg sys_reset;
   
   
   reg cpu_trace = 0;
   reg serial_trace = 0;
   
   
   top dut(.CLK(CLK),
	   .clk32k768(clk32k768), 
	   .clk4m9152(clk4m9152),
	   .tx(tx),
	   .rx(rx),
	   .sys_reset(sys_reset));

   always
     begin
	CLK = 1;
	/* 19.6608 MHz default */
	#25.43131510416666666666 CLK = 0;
	#25.43131510416666666666 CLK = 1;
     end

   always
     begin
	/* 32.768 kHz clock for ICM7170 */
	clk32k768 = 1;
	#15258.789 clk32k768 = 0;
	#15258.789 clk32k768 = 1;
     end

   reg [1:0] clk4m9152_ctr = 2'h0;
   always @(posedge CLK)
     begin
	clk4m9152_ctr <= clk4m9152_ctr + 1;
     end
   assign clk4m9152 = clk4m9152_ctr[1];
   
       
   tolog tolog(.TxDA(tx));

  initial
    begin
       $timeformat(-9, 0, "ns", 7);
       $dumpfile("sun3.vcd");
       $dumpvars(0, tolog);
       $dumpoff;

       sys_reset = 1;
       #2000 sys_reset = 0;
       
       //#100000 $finish;
       
       //#1000 $dumpoff;
       //#500000 $finish;
       //#50000000 $finish;
    end
     
   always @(posedge CLK) if (~dut.sun3.TxDA_EN) serial_trace = 1;
   always @(posedge CLK) if ( dut.sun3.TxDA_EN & serial_trace) $dumpon;
   
   always
     begin
	#100000000 $display("Time is %t", $realtime);
     end
   
endmodule


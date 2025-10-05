module ttl_icm7170_alt #(parameter mscycle=100000) (input CLK,
		       input [4:0] idx,
		       input [7:0]  din,
		       output reg [7:0] dout,
		       input 	    RD,
		       input 	    WR,
		       output 	    int_n);
   
   reg [19:0] 			    ctr; 			    
   reg [7:0] 			    dregs[0:15];
   reg [7:0] 			    cregs[0:1];

   assign int_n = 1'b1;
  
   initial
     begin
	dregs[4'h0] <= 0;
	dregs[4'h1] <= 0;
	dregs[4'h2] <= 0;
	dregs[4'h3] <= 0;
	dregs[4'h4] <= 0;
	dregs[4'h5] <= 0;
	dregs[4'h6] <= 0;
	dregs[4'h7] <= 0;
	
	dregs[4'h8] <= 0; // s/100
	dregs[4'h9] <= 23; // hours
	dregs[4'ha] <= 59; // minute
	dregs[4'hb] <= 59; // second
	dregs[4'hc] <= 12; // month
	dregs[4'hd] <= 31; // day of month
	dregs[4'he] <= 20; // year
	dregs[4'hf] <= 4; // day of week

	cregs[0] <= 0;
	cregs[1] <= 0;
	
	dout <= 0;
	
     end
   
   always @(posedge CLK)
     begin 
	if (RD & ~idx[4]) dout <= dregs[idx];
	if (WR & ~idx[4]) dregs[idx] <= din;
	if (RD &  idx[4]) dout <= cregs[idx[0]];
	if (WR &  idx[4]) cregs[idx[0]] <= din;
     end

endmodule // ttl_icm7170

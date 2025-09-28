   
module ttl_74F74(input D,
		 input 	CLK,
		 input 	S,
		 input 	R,
		 output Q,
		 output Q_n, input RESET_n);

   reg q = 0;
   
   always @(posedge CLK or negedge R or negedge S)
     begin
         if (~R)
           q <= 0;
         else if (~S)
           q <= 1;
         else
           q <= D;
     end

   always @(negedge RESET_n or posedge RESET_n)
     begin
	q <= 0;
     end

   assign Q = q;
   assign Q_n = ~q;
   
endmodule

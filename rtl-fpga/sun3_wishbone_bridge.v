module sun3_wishbone_bridge (input SET_ENABLE,
			     input 	       RESET_n,
			     input 	       CLK,
			     // some CPU bus signals
			     input [31:0]      P_ADR_IN,
			     input [31:0]      P_DATA_IN,
			     output reg [31:0] P_DATA_OUT,
			     input 	       P_RW_n,
			     input 	       EN_LLBYTE,
			     input 	       EN_LUBYTE,
			     input 	       EN_ULBYTE,
			     input 	       EN_UUBYTE,
			     
			     // match : response
			     input 	       MATCH_MEM,
			     input 	       MATCH_FB,
			     input 	       MATCH_VME32_32,
			     output 	       W_ACK, 
			     
			     // wishbone
			     output 	       wb_cyc_o,
			     output 	       wb_stb_o,
			     output [29:0]     wb_adr_o,
			     output [31:0]     wb_dat_o,
			     output [3:0]      wb_sel_o,
			     output 	       wb_we_o,
			     input [31:0]      wb_dat_i,
			     input 	       wb_ack_i
);

   /* this creates a wishbone master in CLK domain */

   reg 					   wb_ack_i_prev;
   reg 					   ENABLE;
   
   
   assign wb_cyc_o = ~ENABLE ? 1'b0 : (MATCH_MEM | MATCH_VME32_32 | MATCH_FB) & ~wb_ack_i_prev;
   assign wb_stb_o = ~ENABLE ? 1'b0 : (MATCH_MEM | MATCH_VME32_32 | MATCH_FB) & ~wb_ack_i_prev;
   assign wb_adr_o = ~ENABLE ? 30'h00000000 : (MATCH_MEM ? {P_ADR_IN[31:2]} : // wishbone word-addressed, memory is based at 0
		                               (MATCH_VME32_32 ?  {P_ADR_IN[31:2]} : // we've matched the VME32 space to the Wishbone space
						(MATCH_FB ?  {11'h07F, P_ADR_IN[20:2]} : // in the last 2 MiB of DDR3, at 0x0FE00000
						30'h0C0FFEEE)));
`ifdef WB_LITTLE_ENDIAN
   assign wb_dat_o = ~ENABLE ? 32'h00000000 : {P_DATA_IN[ 7: 0], // wishbone little-endian
					       P_DATA_IN[15: 8],
					       P_DATA_IN[23:16],
					       P_DATA_IN[31:24]};
   assign wb_sel_o = ~ENABLE ? 4'h0 : (P_RW_n ? 4'hF : {EN_LLBYTE, EN_LUBYTE, EN_ULBYTE, EN_UUBYTE});
`else
   assign wb_dat_o = ~ENABLE ? 32'h00000000 : P_DATA_IN;
   assign wb_sel_o = ~ENABLE ? 4'h0 : (P_RW_n ? 4'hF : {EN_UUBYTE, EN_ULBYTE, EN_LUBYTE, EN_LLBYTE});
`endif
   assign wb_we_o  = ~ENABLE ? 1'b0 : ~P_RW_n;
   assign W_ACK = ~ENABLE ? 1'b0 : wb_ack_i;


   always @(posedge CLK)
     begin
	wb_ack_i_prev <= ~ENABLE ? 1'b0 : wb_ack_i;

	if (~RESET_n) ENABLE <= 1'b0;
	if (SET_ENABLE) ENABLE <= 1'b1; // one-shot trigger: once seen, the wishbone stays up until next (board) reset

	if (~ENABLE)
	  P_DATA_OUT <= 32'h00000000;

	if (ENABLE)
	  if(wb_ack_i & ~wb_we_o)
	    begin
`ifdef WB_LITTLE_ENDIAN
	       P_DATA_OUT <= {wb_dat_i[ 7: 0],
			      wb_dat_i[15: 8],
			      wb_dat_i[23:16],
			      wb_dat_i[31:24]};
`else
	       P_DATA_OUT <= wb_dat_i;
`endif
	    end // if (wb_ack_i & ~wb_we_o)
	  //else if (P_DATA_OUT[31:16] != 16'h2BAD)
	  //  P_DATA_OUT <= 32'h2BAD0000;
	  //else P_DATA_OUT[15:0] <= P_DATA_OUT[15:0] + 1;
	
     end

endmodule // sun3_wishbone_bridge

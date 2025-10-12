module sun3_mmu #(parameter CTX_VALID_BITS=3,
		  SMAP_IDX_WIDTH=14, /* 7188 SRAM */
		  SMAP_OUTPUT_BITS=8,
		  PMAP_IDX_WIDTH=12, /* 2168 SRAM */
		  PMAP_MA_OUTPUT_BITS=19,
		  PMAP_PS_OUTPUT_BITS=8)
   (input CLK,
    /* matching */
    input 	  MATCH_CTX,
    input 	  MATCH_SMAP,
    input 	  MATCH_PMAP_PS,
    input 	  MATCH_PMAP_MA,
    input 	  WR,
    input 	  RD,
    /* CPU signals */
    input [31:0]  P_DIN,
    input [31:0]  P_A,
    input [2:0]   P_FC, 
    /* timing signals */
    input 	  C_S4,
    input 	  C_S6, 
    /* MMU outputs */
    output [7:0]  ctx_out,
    output [SMAP_OUTPUT_BITS-1:0]  ia_smap2pmap,
    output [PMAP_MA_OUTPUT_BITS-1:0] ma_pmap2devices,
    output [PMAP_PS_OUTPUT_BITS-1:0] ps_pmap2devices
);

   localparam PAGE_IDX_BITS=13;
   localparam SEG_IDX_BITS=4;
   

   wire [CTX_VALID_BITS-1:0] 				    cx_ctx2smap; /* cx_ctx2smap is purely internal, ctx_out is the variant visible to the CPU */
   
   // Context register
   ctx_reg_sun3 #(.VALID_BITS(CTX_VALID_BITS)) ctx(.CLK(CLK),
						   .din(P_DIN[31:24]),
						   .WR(WR & MATCH_CTX & C_S4),
						   .dout(ctx_out), // 8-bits output (3 lsb used)
						   .cx(cx_ctx2smap) // 3-bits output 
						   );
   
   // Segment Map
   smap_sram #(.DATA_WIDTH(SMAP_OUTPUT_BITS), .IDX_WIDTH(SMAP_IDX_WIDTH)) smap(.CLK(CLK),
		  .idx({P_A[16+(SMAP_IDX_WIDTH-CTX_VALID_BITS):17],cx_ctx2smap}),
		  .WR(WR & MATCH_SMAP & C_S4),
		  .ia_in(P_DIN[31:32-SMAP_OUTPUT_BITS]),
		  .ia_out(ia_smap2pmap) // X-bits outputs: index in the PMap
		  );
   // Page Map
   pmap_sram #(.MA_DATA_WIDTH(PMAP_MA_OUTPUT_BITS), .PS_DATA_WIDTH(PMAP_PS_OUTPUT_BITS), .IDX_WIDTH(PMAP_IDX_WIDTH)) pmap(.CLK(CLK),
		  .idx({ia_smap2pmap,P_A[PAGE_IDX_BITS+SEG_IDX_BITS-1:PAGE_IDX_BITS]}),
		  .WR_ma(WR & MATCH_PMAP_MA & C_S6),
		  .WR_ps(WR & MATCH_PMAP_PS & C_S6),
		  .ma_in(P_DIN[PMAP_MA_OUTPUT_BITS-1:0]),
		  .ps_in(P_DIN[31:32-PMAP_PS_OUTPUT_BITS]),
		  .ma_out(ma_pmap2devices), // Y-bits output #1: physical address bits
		  .ps_out(ps_pmap2devices)  // 8-bits output #2: protection and status bits
		  );
   
  
endmodule // sun2_mmu

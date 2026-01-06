`timescale 1ns / 1ps

   // PLOMB Burst Type Enumeration
   typedef enum        logic [1:0] {
				    PB_SINGLE = 2'b00,    // Single transfer
				    PB_BURST2 = 2'b01,    // 2-word burst
				    PB_BURST4 = 2'b10,    // 4-word burst
				    PB_BURST8 = 2'b11     // 8-word burst
				    } type_plomb_burst;
   
   // PLOMB Mode Constants
   parameter [1:0] PB_MODE_NOP    = 2'b00;  // No operation
   parameter [1:0] PB_MODE_WR     = 2'b01;  // Write operation
   parameter [1:0] PB_MODE_RD     = 2'b10;  // Read operation
   parameter [1:0] PB_MODE_WR_ACK = 2'b11;  // Write with acknowledge

   parameter [1:0] PLOMB_OK       = 2'b00;
   parameter [1:0] PLOMB_ERROR    = 2'b01;
   parameter [1:0] PLOMB_FAULT    = 2'b10;
   parameter [1:0] PLOMB_SPEC     = 2'b11;
   
   // PLOMB Write Interface Structure
   typedef struct      packed 		  {
      logic [31:0]     a;       // Address
      logic [3:0]      ah;      // High address bits (35:32) // SPARC, unused
      logic [7:0]      asi;     // Address Space Identifier // SPARC, hardwired to match FC == Supervisor/Data
      logic [31:0]     d;       // Data
      logic [3:0]      be;      // Byte enables
      logic [1:0]      mode;    // Access mode
      type_plomb_burst     burst;   // Burst type
      logic 	       cont;    // Contiguous access // unused?
      logic 	       cache;   // Cacheable // unused ?
      logic 	       lock;    // Lock signal // unused ?
      logic 	       req;     // Request
      logic 	       dack;    // Data acknowledge
   } type_plomb_w;
   
   // PLOMB Read Interface Structure
   typedef struct      packed 		  {
      logic [31:0]     d;       // Read data
      logic [1:0]      code;    // enum_plomb_code      
      logic 	       ack;     // Acknowledge
      logic 	       dreq;    // 
   } type_plomb_r;

// Function to decode PLOMB mode to MC68020 control signals
function automatic logic [4:0] decode_plomb_mode(
    input logic [1:0] mode,
    input logic [3:0] be
);
    logic [4:0] result; // A(1:0) & RW_N & SIZ(1:0)
    
    // PLOMB modes: "00" = NOP, "01" = WR, "10" = RD, "11" = WR_ACK
    case (mode)
        2'b01, 2'b11: begin  // Write operations
            result[2] = 1'b0;  // RW_N = 0 (write)
        end
        2'b10: begin         // Read operation
            result[2] = 1'b1;  // RW_N = 1 (read)
        end
        default: begin       // NOP
            result[2] = 1'b1;  // Default to read
        end
    endcase
    
    // Determine transfer size from byte enables
    case (be)
        4'b1111: begin      // 32-bit transfer
            result[1:0] = 2'b00;  // Long word
        end
        4'b0011, 4'b1100: begin // 16-bit transfer
            result[1:0] = 2'b10;  // Word
        end
        4'b0001, 4'b0010, 4'b0100, 4'b1000: begin // 8-bit transfer
            result[1:0] = 2'b01;  // Byte
        end
        default: begin
            result[1:0] = 2'b00;  // Default to long word
        end
    endcase
    
    // Determine address from byte enables -- CHECKME: endianess
    case (be)
        4'b0001: begin
            result[4:3] = 2'b11;  // off by 3
        end
        4'b0010, 4'b0011: begin
            result[4:3] = 2'b10;  // off by 2
        end
        4'b0100: begin
            result[4:3] = 2'b01;  // off by 1
        end
        default: begin
            result[4:3] = 2'b00;  // Default to 4-bytes aligned
        end
    endcase
    
    return result;
endfunction // decode_plomb_mode

// Function to convert PLOMB ASI to MC68020 function codes
function automatic logic [2:0] asi_to_fc(
    input logic [7:0] asi
);
    logic [2:0] fc;
    
    // Map PLOMB ASI to MC68020 function codes
    // This is application-specific mapping
    case (asi)
        8'h0A: begin
            fc = 3'b001;  // User data
        end
        8'h08: begin
            fc = 3'b010;  // User program
        end
        8'h0B: begin
            fc = 3'b101;  // Supervisor data
        end
        8'h09: begin
            fc = 3'b110;  // Supervisor program
        end
        default: begin
            fc = 3'b001;  // Default user data
        end
    endcase
    
    return fc;
endfunction

   typedef enum        logic [2:0] {
				    FSMMC_IDLE       = 3'b000,
				    FSMMC_WAITFORBUS = 3'b001,
				    FSMMC_DELAY      = 3'b100,
				    FSMMC_READ       = 3'b010,
				    FSMMC_WRITE      = 3'b011
				    } type_mc_fsm_state;

module bridge_plomb_to_020 (
			    // Control signals
			    input 	  clk,
			    input 	  reset_n,
			    // PLOMB Bus Interface (Slave side)
			    input 	  type_plomb_w plomb_w,
			    output 	  type_plomb_r plomb_r,
			    
			    // MC68020 Bus Interface (Master side)
			    input 	  mc_CLK, // CPU clock
			    output [31:0] mc_A_OUT, // Address bus
			    input [31:0]  mc_D_IN, // Data bus
			    output [31:0] mc_D_OUT, // Data bus
			    output [2:0]  mc_FC, // Function codes
			    output [1:0]  mc_SIZ, // Transfer size
			    input 	  mc_AS_N_IN,
			    output 	  mc_AS_N_OUT,
			    output 	  mc_DS_N,
			    output 	  mc_RW_N,
			    input 	  mc_DSACK0_N,
			    input 	  mc_DSACK1_N,
			    input 	  mc_BERR_N,
    
			    // Bus Arbitration (for MC68020 bus mastering)
			    output 	  mc_BR_N,
			    input 	  mc_BG_N,
			    output 	  mc_BGACK_N,

			    // debug
			    output [7:0]  todebug
			    );

   // clk
   wire 				  req_fifo_wr;
   wire 				  req_fifo_full;
   wire [71:0] 				  req_fifo_din;
   // mc_CLK
   reg 					  req_fifo_rd;
   wire 				  req_fifo_empty;
   wire [71:0] 				  req_fifo_dout;

   // mc_CLK
   reg 					  data_fifo_wr;
   wire 				  data_fifo_full;
   wire [31:0] 				  data_fifo_din;
   // clk
   reg 					  data_fifo_rd;
   wire 				  data_fifo_empty;
   wire [31:0] 				  data_fifo_dout;
   reg 					  data_fifo_req_delay;

   // mc_CLK
   reg [2:0] 				  fsmmc_state;
   reg 					  br;
   reg 					  bgack;
   reg 					  as;
   reg [1:0] 				  plomb_status;
   reg [3:0] 				  delay_cnt;
   

   reg [31:0] 				  data_in_reg;
   
   
   assign mc_BR_N = ~br;
   assign mc_BGACK_N = ~bgack;
   assign mc_AS_N_OUT = ~as;
   assign mc_DS_N = ~as; // yup   

   assign req_fifo_din = {plomb_w.a[31:2], // 30
			  decode_plomb_mode(plomb_w.mode, plomb_w.be), // 5 (2A + 1RW + 2SIZ)
			  plomb_w.d, // 32
			  asi_to_fc(plomb_w.asi), // 3
			  2'b00 // 2, FIXME
			  };
   
   assign mc_A_OUT = req_fifo_dout[71:40];
   assign mc_RW_N =  req_fifo_dout[39];
   assign mc_SIZ =   req_fifo_dout[38:37];
   assign mc_D_OUT = req_fifo_dout[36:5];
   assign mc_FC =    req_fifo_dout[4:2];

   // reg fifo, clk side
   assign plomb_r.ack = ~req_fifo_full; // if we have a slot, ACK any request (this will discard NOP and empty request that aren't put into the FIFO)
   assign plomb_r.code = plomb_status;
   assign req_fifo_wr = plomb_w.req & // put the request in the FIFO if there's a request...
			(plomb_w.mode != PB_MODE_NOP) & // which isn't a NOP
			(plomb_w.be != 4'h0) & // and which isn't empty (no byte enabled)
			~req_fifo_full; // .. and there is room

   // data fifo, clk side
   assign data_fifo_din = data_in_reg;
   assign data_fifo_rd = plomb_w.dack;
   assign plomb_r.dreq = ~data_fifo_empty | // normal dreq - we have some values
			 data_fifo_req_delay; // read with empty be - just send back garbage one cycle after yje req to respect plomb timing
   always @(posedge clk) data_fifo_req_delay <= (plomb_w.req & (plomb_w.be == 4'h0) & (plomb_w.mode == PB_MODE_RD));
   assign plomb_r.d = data_fifo_dout;
   
   reg 					  C_S0, C_S1, C_S2, C_S3, C_S4, C_S5;
/*
   assign todebug = { fsmmc_state, // 3
		       plomb_w.req, // 1
		       req_fifo_empty, // 1
		       data_fifo_empty, // 1
		       plomb_r.dreq, // 1
		       bgack // 1
		       };
 */
   /*
   assign todebug = {bgack, // 1
		     //(fsmmc_state == FSMMC_WRITE), // 1
		     //C_S0, C_S1, C_S2, C_S3, C_S4, C_S5 // 6
		     fsmmc_state, // 3
		     req_fifo_rd, // 1
		     req_fifo_wr, // 1 
		     plomb_status // 2
		     //req_fifo_full,
		     //~req_fifo_empty
		     //data_fifo_rd,
		     //data_fifo_wr
		     };
    */
   assign todebug = {plomb_w.req, // 1
		     plomb_w.mode, // 2
		     plomb_w.be, // 4
		     bgack // 1
		     };
   
   always @(posedge mc_CLK)
     begin
	C_S0 <= 1'b0; // C_S0 is a one-cycle strobe (no wait state)
	              // C_S2 can have wait state
	C_S4 <= 1'b0; // C_S4 is a one-cycle strobe (no wait state)
	req_fifo_rd <= 1'b0;
	data_fifo_wr <= 1'b0;
	if (delay_cnt >= 4'h0) delay_cnt <= delay_cnt - 1;

	case (fsmmc_state)
	  FSMMC_IDLE:
	    begin
	       if (~req_fifo_empty) // some requets to handle
		 begin
		    // plomb_status <= PLOMB_OK;
		    if (~(br & bgack))  // we don't have the bus
		      begin
			 br <= 1'b1; // request the bus
			 fsmmc_state <= FSMMC_WAITFORBUS;
		      end
		    else
		      begin // we already have the bus, keep it
			 C_S0 <= 1'b1; // starts the cycle
			 if (mc_RW_N)
			   begin
			      // read
			      fsmmc_state <= FSMMC_READ;
			   end
			 else
			   begin
			      // write
			      fsmmc_state <= FSMMC_WRITE;
			   end
		      end
		 end // if (~req_fifo_empty)
	       else
		 begin
		    if (br & bgack) // we have the bus, return it to the CPU
		      begin
			 br <= 1'b0;
			 bgack <= 1'b0;
			 delay_cnt <= 4'h7;
			 fsmmc_state <= FSMMC_DELAY;
		      end
		 end // else: !if(~req_fifo_empty)
	    end // case: FSMMC_IDLE

	  FSMMC_DELAY:
	    begin
	       // extra delay cycle(s) to give the CPU a chance to use the bus
	       if (delay_cnt == 4'h0) fsmmc_state <= FSMMC_IDLE;
	    end

	  FSMMC_WAITFORBUS:
	    begin
	       if (~mc_BG_N & mc_AS_N_IN) // we are granted the bus (and it's not busy)
		 begin
		    bgack <= 1'b1; // ack the grant
		    C_S0 <= 1'b1; // starts the cycle
		    if (mc_RW_N)
		      begin
			 // read
			 fsmmc_state <= FSMMC_READ;
		      end
		    else
		      begin
			 // write
			 fsmmc_state <= FSMMC_WRITE;
		      end
		 end
	    end

	  FSMMC_WRITE:
	    begin
	       if (C_S1) // should always be the case, actually, we just wrote C_S0 the previous cycle
		 begin
		    C_S2 <= 1'b1;
		 end

	       if (C_S3)
		 begin
		    C_S2 <= 1'b0;
		    C_S4 <= 1'b1; // single cycle strobe
		    req_fifo_rd <= 1'b1; // single cycle strobe
		 end

	       if (C_S5)
		 begin
		    fsmmc_state <= FSMMC_IDLE;
		 end

	       if (~mc_BERR_N)
		 begin
		    C_S0 <= 1'b0;
		    C_S2 <= 1'b0;
		    C_S4 <= 1'b0;
		    req_fifo_rd <= 1'b0;
		    data_fifo_wr <= 1'b0;
		    fsmmc_state <= FSMMC_IDLE;
		    br <= 1'b0;
		    bgack <= 1'b0;
		    plomb_status <= PLOMB_ERROR;
		 end
	    end // case: FSMMC_WRITE

	  FSMMC_READ:
	    begin
	       if (C_S1) // should always be the case, actually, we just wrote C_S0 the previous cycle
		 begin
		    C_S2 <= 1'b1;
		 end

	       if (C_S3)
		 begin
		    C_S2 <= 1'b0;
		    C_S4 <= 1'b1; // single cycle strobe
		    req_fifo_rd <= 1'b1; // single cycle strobe
		 end

	       if (C_S5)
		 begin
		    // fixme: what if data_fifo_full !=0 ? (C_S5 is a strobe, can't delay here)
		    // the read should be faster than the write so likely not an issue...
		    data_fifo_wr <= 1'b1; // single cycle strobe
		    fsmmc_state <= FSMMC_IDLE;
		 end

	       if (~mc_BERR_N)
		 begin
		    C_S0 <= 1'b0;
		    C_S2 <= 1'b0;
		    C_S4 <= 1'b0;
		    req_fifo_rd <= 1'b0;
		    data_fifo_wr <= 1'b1; // single cycle strobe // this sends garbage, but at least the DMA won't keep trying the request
		    fsmmc_state <= FSMMC_IDLE;
		    br <= 1'b0;
		    bgack <= 1'b0;
		    plomb_status <= PLOMB_ERROR;
		 end // if (~mc_BERR_N)
	       
	    end // case: FSMMC_READ
	  
	endcase // case (fsmmc_state)

	if (~reset_n)
	  begin
	     C_S0 <= 1'b0;
	     C_S2 <= 1'b0;
	     C_S4 <= 1'b0;
	     req_fifo_rd <= 1'b0;
	     data_fifo_wr <= 1'b0;
	     fsmmc_state <= FSMMC_IDLE;
	     br <= 1'b0;
	     bgack <= 1'b0;
	     plomb_status <= PLOMB_OK;
	  end
	
     end // always @ (posedge mc_CLK)
   
   always @(negedge mc_CLK)
     begin
	as <= (C_S0 | C_S2); // cycle active on the bus, will stop on entry in S5
	C_S1 <= 1'b0; // C_S1 is a one-cycle strobe (no wait state)
	C_S3 <= 1'b0; // C_S3 is a one-cycle strobe (no wait state)
	C_S5 <= 1'b0; // C_S5 is a one-cycle strobe (no wait state)
	
	if (C_S0)
	  begin
	     C_S1 <= 1'b1; // single cycle strobe
	  end

	if (C_S2 & (~mc_DSACK0_N | ~mc_DSACK1_N))
	  begin
	     C_S3 <= 1'b1; // single cycle strobe
	  end

	if (C_S4)
	  begin
             data_in_reg <= mc_D_IN;
             C_S5 <= 1'b1; // single cycle strobe
	  end

	if (~mc_BERR_N & bgack) // react to buserror if we're bus master only
	  begin
	     data_in_reg <= 32'h8BADF00D;
	     //as <= 1'b0; // will be reset by the reset of C_S0 | C_S2
	     C_S1 <= 1'b0;
	     C_S3 <= 1'b0;
	     C_S5 <= 1'b0;
	  end
	
	if (~reset_n)
	  begin
	     data_in_reg <= 32'h2BAD2BAD;
	     //as <= 1'b0; // will be reset by the reset of C_S0 | C_S2
	     C_S1 <= 1'b0;
	     C_S3 <= 1'b0;
	     C_S5 <= 1'b0;
	  end
     end
   

   // request FIFO, async from device (clk) to CPU (mc_CLK) domains
   // 72 bits
   fifo_plomb_to_020_w req_fifo (
				 .rst(~reset_n),
				 .wr_clk(clk),
				 .rd_clk(mc_CLK),
				 .din(req_fifo_din),
				 .wr_en(req_fifo_wr),
				 .rd_en(req_fifo_rd),
				 .dout(req_fifo_dout),
				 .full(req_fifo_full),
				 .empty(req_fifo_empty),
				 .wr_rst_busy(), // fixme
				 .rd_rst_busy() // fixme
				 );

   // request FIFO, async from CPU (mc_CLK) to device (clk) domains
   // 32 bits
   fifo_plomb_to_020_r data_fifo (
				 .rst(~reset_n),
				 .wr_clk(mc_CLK),
				 .rd_clk(clk),
				 .din(data_fifo_din),
				 .wr_en(data_fifo_wr),
				 .rd_en(data_fifo_rd),
				 .dout(data_fifo_dout),
				 .full(data_fifo_full),
				 .empty(data_fifo_empty),
				 .wr_rst_busy(), // fixme
				 .rd_rst_busy() // fixme
				 );

   
endmodule // bridge_plomb_to_020

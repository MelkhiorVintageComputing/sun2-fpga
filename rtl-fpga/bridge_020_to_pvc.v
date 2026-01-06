`timescale 1ns / 1ps

   // PVC Write Interface Structure
   typedef struct      packed      {
      logic 	       req;     // Request signal
      logic [3:0]      be;      // Byte enables (4 bits)
      logic 	       wr;      // Write signal
      logic [31:0]     a;       // 32-bit address
      logic [3:0]      ah;      // High address bits (35:32)
      logic [31:0]     dw;      // Write data
   } type_pvc_w;
   
   // PVC Read Interface Structure
   typedef struct      packed      {
      logic 	       ack;     // Acknowledge
      logic [31:0]     dr;      // Read data
   } type_pvc_r;


module bridge_020_to_pvc(
			 input 	      reset_n,
			 
			 // MC68020 Bus Interface (Slave side)
			 input 	      mc_CLK,
			 input [31:0]  mc_A, // Address bus
			 input [31:0]  mc_D_IN, // Data bus (in)
			 output [31:0] mc_D_OUT, // Data bus (out)
			 input [2:0]  mc_FC, // Function codes (unused)
			 input [1:0]  mc_SIZ, // Transfer size
			 input 	      mc_AS_N, // Address strobe
			 input 	      mc_DS_N, // Data strobe (unused)
			 input 	      mc_RW_N, // Read/Write
			 output       mc_DSACK0_N, // Data acknowledge 0
			 output       mc_DSACK1_N, // Data acknowledge 1
			 input 	      mc_CS_N, // Chip select
	
			 // PVC Bus Interface (Master side)
			 input 	      clk,
			 output       type_pvc_w pvc_w, // PVC write interface
			 input 	      type_pvc_r pvc_r  // PVC read interface
	);

   // Task version for traditional Verilog
   function automatic logic [3:0] generate_byte_enables(
				  input logic [1:0] size,
				  input logic [1:0] addr
				  );
      
      logic [3:0] 				    be;
      
      case (size)
	2'b01: begin  // Byte transfer
           case (addr)
             2'b00: be = 4'b1000;  // Byte 0
             2'b01: be = 4'b0100;  // Byte 1
             2'b10: be = 4'b0010;  // Byte 2
             2'b11: be = 4'b0001;  // Byte 3
             default: be = 4'b0000;
           endcase
	end
	2'b10: begin  // Word transfer (16-bit)
           case (addr[1])
             1'b0: be = 4'b1100;   // Lower word
             1'b1: be = 4'b0011;   // Upper word
             default: be = 4'b0000;
           endcase
	end
	2'b00: begin  // Long word transfer (32-bit)
           be = 4'b1111;             // All bytes
	end
	default: begin
           be = 4'b0000;             // Invalid
	end
      endcase
      
      return be;
   endfunction // generate_byte_enables
   

   // mc_CLK
   reg 				  req_fifo_wr;
   wire 			  req_fifo_full;
   wire [71:0] 			  req_fifo_din;
   // clk
   wire 			  req_fifo_rd;
   wire 			  req_fifo_empty;
   wire [71:0] 			  req_fifo_dout;
   
   // clk
   wire 			  data_fifo_wr;
   wire 			  data_fifo_full;
   wire [31:0] 			  data_fifo_din;
   // mc_CLK
   reg 				  data_fifo_rd;
   wire 			  data_fifo_empty;
   wire [31:0] 			  data_fifo_dout;
   
   wire 			  cycle;
   reg 				  cycle_prev;
   reg 				  cycle_waiting;
   reg 				  cycle_rd_done;
   reg 				  ack;
   reg [31:0] 			  data_out_reg;

   assign cycle = ~mc_AS_N & ~mc_DS_N & ~mc_CS_N;
   assign mc_DSACK0_N = ~ack;
   assign mc_DSACK1_N = ~ack;
   assign mc_D_OUT = data_out_reg;
   
   assign req_fifo_din = {generate_byte_enables(mc_SIZ, mc_A[1:0]), // 4
			  ~mc_RW_N, // 1
			  mc_A[31:2], // 30
			  mc_D_IN, // 32
			  5'h00 // 5
			  };
   assign pvc_w.req = ~req_fifo_empty;
   assign pvc_w.be = req_fifo_dout[71:68];
   assign pvc_w.wr = req_fifo_dout[67];
   assign pvc_w.a  = {req_fifo_dout[66:37], 2'b00};
   assign pvc_w.ah = 4'h0;
   assign pvc_w.dw = req_fifo_dout[36:5];
   assign req_fifo_rd = pvc_r.ack; // request removed when acknowledged

   assign data_fifo_din = pvc_r.dr;
   assign data_fifo_wr = pvc_r.ack & ~req_fifo_dout[67]; // add data to the FIFO when reading
   
   always @(posedge mc_CLK)
     begin
	cycle_prev <= cycle; // for edge detection
	cycle_rd_done <= 1'b0;
	req_fifo_wr <= 1'b0;
	data_fifo_rd <= 1'b0;
	
	if (~cycle) ack <= 1'b0; // either no cycle, or cycle ended
	
	if ((cycle & ~cycle_prev) | cycle_waiting) // posedge on cycle while CS is asserted, or pending cycle
	  begin
	     if (~req_fifo_full)
	       begin
		  cycle_waiting <= 1'b0; // clean up flag just in case
		  req_fifo_wr <= 1'b1; // send request
		  if (~mc_RW_N) // write: fire and forget
		    begin
		       ack <= 1'b1; // terminate cycle immediately, this will when the cycle ends (as deasserted)
		    end
	       end
	     else
	       begin
		  cycle_waiting <= 1'b1;
	       end 
	  end // if ((cycle & ~cycle_prev) | cycle_waiting)

	if (cycle & mc_RW_N & ~data_fifo_empty) // outstanding read request
	  begin
	     data_out_reg <= data_fifo_dout;
	     data_fifo_rd <= 1'b1;
	     cycle_rd_done <= 1'b1;
	  end

	if (cycle & mc_RW_N & cycle_rd_done) // outstanding read request done
	  begin
	     ack <= 1'b1; // finish read cycle
	  end

	if (~reset_n)
	  begin
	     cycle_prev <= 1'b0;
	     cycle_rd_done <= 1'b0;
	     cycle_waiting <= 1'b0;
	     req_fifo_wr <= 1'b0;
	     data_fifo_rd <= 1'b0;
	     data_out_reg <= 32'hBAD2BAD2;
	  end
	
     end // always @ (posedge mc_CLK)
   
   
   // request FIFO, async from CPU (mc_CLK) to device (clk) domains
				   // 72 bits
   fifo_plomb_to_020_w req_fifo (
				 .rst(~reset_n),
				 .wr_clk(mc_CLK),
				 .rd_clk(clk),
				 .din(req_fifo_din),
				 .wr_en(req_fifo_wr),
				 .rd_en(req_fifo_rd),
				 .dout(req_fifo_dout),
				 .full(req_fifo_full),
				 .empty(req_fifo_empty),
				 .wr_rst_busy(), // fixme
				 .rd_rst_busy() // fixme
				 );

   // request FIFO, async from device (clk) to CPU (mc_CLK) domains
				   // 32 bits
   fifo_plomb_to_020_r data_fifo (
				 .rst(~reset_n),
				 .wr_clk(clk),
				 .rd_clk(mc_CLK),
				 .din(data_fifo_din),
				 .wr_en(data_fifo_wr),
				 .rd_en(data_fifo_rd),
				 .dout(data_fifo_dout),
				 .full(data_fifo_full),
				 .empty(data_fifo_empty),
				 .wr_rst_busy(), // fixme
				 .rd_rst_busy() // fixme
				 );

endmodule // bridge_020_to_pvc




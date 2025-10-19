`timescale 1ns/1ps
// icm7170.v
// Behavioral Verilog model of the ICM7170 RTC (functional simulation model).

module icm7170 (input 	 rst_n, // active low synchronous reset for simulation convenience
		// Bus interface (non-multiplexed or multiplexed via ALE)
		input [4:0]  a_in, // address inputs (when non-multiplexed)
		//inout  [7:0]  d_bus,       // bi-directional data bus D0..D7
		input [7:0]  d_bus_in, // data bus D0..D7
		output [7:0] d_bus_out, // data bus D0..D7
		output 	     d_bus_en,
		input 	     rd_n, // active low read
		input 	     wr_n, // active low write
		input 	     cs_n, // active low chip select
		input 	     ale, // address latch enable (for multiplexed buses)
		// Oscillator
		input 	     osc_in, // oscillator input (edges counted)
		output 	     osc_out, // oscillator output (tied to osc_in in this model)
		// Interrupt pins
		input 	     int_source, // INT SOURCE pin — used to gate interrupt output (modelled)
		output reg   int_out, // interrupt output (active LOW in this model)
		// Power pins (informational — behavior not modeled electrically)
		input 	     vdd_present, // when 0, chip is in backup / low-power (user may drive)
		input 	     vbackup_present,
		// Optional: force external 100Hz tick (useful in tests). If 1, clk_100hz is used,
		// otherwise internal divider uses osc_in and command reg freq select.
		input 	     use_ext_100hz,
		input 	     clk_100hz
		);
   
   // --------------------------- Parameters / constants -------------------------
   localparam ADDR_COUNTER_100TH = 5'h00; // 00h
   localparam ADDR_HOURS         = 5'h01; // 01h
   localparam ADDR_MINUTES       = 5'h02; // 02h
   localparam ADDR_SECONDS       = 5'h03; // 03h
   localparam ADDR_MONTH         = 5'h04; // 04h
   localparam ADDR_DATE          = 5'h05; // 05h
   localparam ADDR_YEAR          = 5'h06; // 06h
   localparam ADDR_DAYOFWEEK     = 5'h07; // 07h
   
   localparam ADDR_RAM_100TH     = 5'h08; // 08h ... 0Eh RAM
   localparam ADDR_RAM_HOURS     = 5'h09;
   localparam ADDR_RAM_MINUTES   = 5'h0A;
   localparam ADDR_RAM_SECONDS   = 5'h0B;
   localparam ADDR_RAM_MONTH     = 5'h0C;
   localparam ADDR_RAM_DATE      = 5'h0D;
   localparam ADDR_RAM_YEAR      = 5'h0E;
   localparam ADDR_RAM_DAYOFWEEK = 5'h0F;
   
   localparam ADDR_INT_STATUS    = 5'h10; // 10h (Status/Mask)
   localparam ADDR_CMD_REG       = 5'h11; // 11h (Command, write-only)
   
   // Supported oscillator freqs from datasheet:
   localparam OSC_32K   = 32768;
   localparam OSC_1M048 = 1048576;
   localparam OSC_2M097 = 2097152;
   localparam OSC_4M194 = 4194304;
   
   // --------------------------- Internal registers ----------------------------
   reg [7:0] 		     ram_alarm [0:6];    // alarm RAM words 100th, hr, min, sec, month, date, year (addresses 08-0E)
   reg 			     ram_mask [0:6];     // M bits: 0 -> compare enabled, 1 -> masked
   // Real-time counters (binary 0..99,0..59, etc)
   reg [6:0] 		     cnt_100th; // 0..99 (7 bits)
   reg [5:0] 		     cnt_sec;   // 0..59
   reg [5:0] 		     cnt_min;   // 0..59
   reg [7:0] 		     cnt_hour;  // 0..23 or 1..12 encoded with AM/PM bit in command mode
   reg [3:0] 		     cnt_month; // 1..12
   reg [5:0] 		     cnt_date;  // 1..31
   reg [6:0] 		     cnt_year;  // 0..99
   reg [2:0] 		     cnt_day;   // 0..6
   
   // Latch for consistent read-after-read behavior
   reg [7:0] 		     latch_time [0:7]; // latched snapshot of counters when 100th is read
   reg 			     data_latched;
   
   // Command/Control
   reg [7:0] 		     cmd_reg;  // write-only at 11h: D5 test, D4 int_en, D3 run/stop, D2 24/12, D1-D0 freq bits
   // Interrupt mask/status
   reg [7:0] 		     int_mask;   // write-only (10h) mask bits D0 alarm, D1 1/100, D2 1/10, D3 1s, D4 min, D5 hr, D6 day
   reg [7:0] 		     int_status; // read-only (10h) flags - bits set when corresponding counter increments or alarm occurred
   
   // Internal oscillator/tick generation
   integer 		     osc_freq_hz; // selected by cmd_reg D1-D0
   integer 		     base_div;    // integer cycles per 100Hz tick
   integer 		     rem_div;     // remainder used for Bresenham-like correction
   integer 		     rem_accum;   // accumulative remainder
   integer 		     cycle_count; // counts osc_in cycles toward a 100Hz tick
   
   // Address latch (for multiplexed bus)
   reg [4:0] 		     addr_latch;
   reg 			     ale_prev;
   
   // Data bus output driver
   reg [7:0] 		     d_out;
   reg 			     drive_bus;
   
   // Internal edge detectors
   reg 			     osc_in_prev;
   reg 			     rd_n_prev;
   reg 			     wr_n_prev;
   reg 			     cs_n_prev;
   
   // --------------------------- Initialization -------------------------------
   integer 		     i;
   initial begin
      // set sensible power-on defaults
      cmd_reg = 8'b00000101; // run=1, 24-hour default, freq bits default 01->1.048576MHz (arbitrary)
      int_mask = 8'h00;
      int_status = 8'h00;
      for (i=0;i<7;i=i+1) begin
         ram_alarm[i] = 8'h00;
         ram_mask[i]  = 1'b1; // masked by default
      end
      
      cnt_100th = 7'd0;
      cnt_sec   = 6'd0;
      cnt_min   = 6'd0;
      cnt_hour  = 8'd0;
      cnt_month = 4'd1;
      cnt_date  = 6'd1;
      cnt_year  = 7'd0;
      cnt_day   = 3'd0;
      
      data_latched = 1'b0;
      drive_bus = 1'b0;
      d_out = 8'h00;
      
      osc_in_prev = 0;
      rd_n_prev = 1;
      wr_n_prev = 1;
      cs_n_prev = 1;
      ale_prev = 0;
      
      // default oscillator freq mapping (start with selection bits)
      update_osc_params(.new_cmd_reg(8'b00000101));
   end
   
   // --------------------------- Helper tasks ---------------------------------
   task update_osc_params (input [7:0] new_cmd_reg);
      integer sel;
      integer f;
      begin
         sel = new_cmd_reg[1:0];
         case (sel)
           2'b00: f = OSC_32K;
           2'b01: f = OSC_1M048;
           2'b10: f = OSC_2M097;
           2'b11: f = OSC_4M194;
           default: f = OSC_32K;
         endcase
         osc_freq_hz = f;
         // compute integer base divisor and remainder for generating 100Hz tick
         base_div = f / 100;        // integer cycles per 100Hz
         rem_div  = f % 100;        // remainder cycles per 100Hz (accumulated)
         rem_accum = 0;
         cycle_count = 0;
	 $display("ICM7170: current setup is frequency %d (%d/%d)", f, base_div, rem_div);
      end
   endtask
   
   function is_leap;
      input integer y;
      begin
         // y is 0..99 meaning 19yy or 20yy. We'll treat 2000+ behaviour: leap years every 4.
         // For simple model: year divisible by 4 -> leap (correct for 1900/2000 edge not handled)
         is_leap = ((y % 4) == 0);
      end
   endfunction
   
   function [5:0] days_in_month;
      input integer m;
      input integer y;
      begin
         case (m)
           1,3,5,7,8,10,12: days_in_month = 6'd31;
           4,6,9,11: days_in_month = 6'd30;
           2: days_in_month = (is_leap(y) ? 6'd29 : 6'd28);
           default: days_in_month = 6'd31;
         endcase
      end
   endfunction
   
   // Increment calendar when seconds rollover etc.
   task advance_time_by_1_100th();
      integer flag_1_100s; // 1
      integer flag_1_10s; // 2
      integer flag_1_1s; // 3
      integer flag_1_1m; // 4
      integer flag_1_1h; // 5
      integer flag_1_1d; // 6
      
     begin
	 flag_1_100s = 0;
	 flag_1_10s = 0;
	 flag_1_1s = 0;
	 flag_1_1m = 0;
	 flag_1_1h = 0;
	 flag_1_1d = 0;
	
         if (!cmd_reg[3]) begin
            // run/stop bit D3 == 0 means stopped (spec says 0 stop). Our cmd_reg D3=1 => run
            // so only advance if run bit is 1.
            disable advance_time_by_1_100th;
         end
         // increment 100th
         cnt_100th = cnt_100th + 1;
         flag_1_100s = 1; // 1/100th increment flag
         if (cnt_100th >= 99) begin
            cnt_100th = 0;
            // increment seconds
            cnt_sec = cnt_sec + 1;
            flag_1_1s = 1; // 1s flag
            // 1/10s: if 100th low nibble 0 (i.e., every 10 increments)
            if ((cnt_100th % 10) == 9) begin
               flag_1_10s = 1; // 1/10 sec flag (simplified)
            end
	    
            if (cnt_sec >= 59) begin
               cnt_sec = 0;
               cnt_min = cnt_min + 1;
               flag_1_1m = 1; // minute flag
               if (cnt_min >= 59) begin
                  cnt_min = 0;
                  cnt_hour = cnt_hour + 1;
                  flag_1_1h = 1; // hour flag
                  if (cmd_reg[2] == 0) begin
                     // 24-hour mode
                     if (cnt_hour >= 23) begin
                        cnt_hour = 0;
                        // next day
                        cnt_day = (cnt_day + 1) % 7;
                        cnt_date = cnt_date + 1;
                        if (cnt_date >= days_in_month(cnt_month,cnt_year)) begin
                           cnt_date = 1;
                           cnt_month = cnt_month + 1;
                           if (cnt_month >= 12) begin
                              cnt_month = 1;
                              cnt_year = cnt_year + 1;
                              if (cnt_year >= 99) cnt_year = 0;
                           end
                        end
                        flag_1_1d = 1; // day flag
                     end
                  end else begin
                     // 12-hour mode handling (1..12 + AM/PM bit is not fully spec'd here)
                     // For simplicity, treat cnt_hour as 0..23 internally; formatting done on read.
                     if (cnt_hour >= 23) begin
                        cnt_hour = 0;
                        cnt_day = (cnt_day + 1) % 7;
                        cnt_date = cnt_date + 1;
                        if (cnt_date >= days_in_month(cnt_month,cnt_year)) begin
                           cnt_date = 1;
                           cnt_month = cnt_month + 1;
                           if (cnt_month >= 12) begin
                              cnt_month = 1;
                              cnt_year = cnt_year + 1;
                              if (cnt_year >= 99) cnt_year = 0;
                           end
                        end
                        flag_1_1d = 1; // day flag
                     end
                  end
               end
            end
         end // if (cnt_100th >= 99)

	 int_status = int_status |
		      (flag_1_100s ? 8'h02 : 8'h00) |
		      (flag_1_10s  ? 8'h04 : 8'h00) |
		      (flag_1_1s   ? 8'h08 : 8'h00) |
		      (flag_1_1m   ? 8'h10 : 8'h00) |
		      (flag_1_1h   ? 8'h20 : 8'h00) |
		      (flag_1_1d   ? 8'h40 : 8'h00);
	 
         // After the small increments, evaluate alarm compare
	 // this is off by 1/100th ? (as it will check the old value)
         do_alarm_compare();
	
         update_interrupt_output(.new_int_status(int_status |
						 (flag_1_100s ? 8'h02 : 8'h00) |
						 (flag_1_10s  ? 8'h04 : 8'h00) |
						 (flag_1_1s   ? 8'h08 : 8'h00) |
						 (flag_1_1m   ? 8'h10 : 8'h00) |
						 (flag_1_1h   ? 8'h20 : 8'h00) |
						 (flag_1_1d   ? 8'h40 : 8'h00)));
     end
   endtask
   
   task do_alarm_compare;
      integer idx;
      reg     match;
      begin
         // Compare real-time counters to corresponding RAM comparing only unmasked fields.
         // RAM mapping (as used): [0]=100th, [1]=hours, [2]=minutes, [3]=seconds, [4]=month, [5]=date, [6]=year
         // For each word if mask==0 then test equality; alarm triggers only if all enabled words equal.
         match = 1'b1;
         // 100th
         if (!ram_mask[0]) if (ram_alarm[0] != cnt_100th) match = 0;
         // hours (RAM stores in same raw format — read/write client will handle 12/24)
         if (!ram_mask[1]) if (ram_alarm[1] != cnt_hour) match = 0;
         if (!ram_mask[2]) if (ram_alarm[2] != cnt_min)  match = 0;
         if (!ram_mask[3]) if (ram_alarm[3] != cnt_sec)  match = 0;
         if (!ram_mask[4]) if (ram_alarm[4] != cnt_month) match = 0;
         if (!ram_mask[5]) if (ram_alarm[5] != cnt_date)  match = 0;
         if (!ram_mask[6]) if (ram_alarm[6] != cnt_year)  match = 0;
	 
         if (match) begin
            int_status[0] = 1'b1; // alarm flag
         end
      end
   endtask
   
   // Evaluate whether to assert interrupt output (int_out)
   task update_interrupt_output(input [7:0] new_int_status);
      reg any_enabled_and_flag;
      begin
	 // The datasheet: Interrupt output is enabled when command.D4 (interrupt enable) and
	 // at least one mask bit set that has corresponding status flag set. Also reading status resets output.
	 any_enabled_and_flag = 0;
	 // mask bits in int_mask D1..D6 correspond to day..1/100 etc as spec - map similarly:
	 // We'll consider D0 alarm, D1 1/100, D2 1/10, D3 1s, D4 min, D5 hr, D6 day
	 // status bits same mapping D0 alarm, D1 1/100, D2 1/10, D3 1s, D4 min, D5 hr, D6 day
	 for (integer b=0; b<=6; b=b+1) begin
            if (int_mask[b] && new_int_status[b]) any_enabled_and_flag = 1;
	 end
	 
	 if (cmd_reg[4] && any_enabled_and_flag) begin
            // interrupt enabled in command register
            // optionally gate by int_source pin: if int_source==0 then INT driven, else gated
            if (~int_source) int_out = 1'b0; else int_out = 1'b1;
	 end else begin
            int_out = 1'b1;
	 end
      end
   endtask
   
   // --------------------------- Oscillator / 100Hz tick generation -------------
   // We support either using external clk_100hz (use_ext_100hz=1) or derive from osc_in and cmd_reg frequency
   
   assign osc_out = osc_in; // simple passthrough for simulation
   
   always @(posedge osc_in or negedge rst_n) begin
      if (!rst_n) begin
         osc_in_prev <= 0;
      end else begin
         // nothing — using edge-driven logic below using posedge osc_in
      end
   end
   
   // Use posedge of osc_in to accumulate cycles and produce a 100Hz tick
   reg tick_100hz;
   initial tick_100hz = 0;
   
   integer extra;
   always @(posedge osc_in or negedge rst_n) begin
      if (!rst_n) begin
         tick_100hz <= 0;
         cycle_count <= 0;
         rem_accum <= 0;
      end else begin
         if (!use_ext_100hz) begin
            // accumulate cycles; base_div cycles normally, occasionally +1 when remainder accumulates >=100
            cycle_count = cycle_count + 1;
            // produce tick when cycle_count >= base_div + extra
            extra = (rem_accum >= 100) ? 1 : 0;
            if (cycle_count >= (base_div + extra)) begin
               cycle_count = 0;
               if (extra) rem_accum = rem_accum - 100;
               rem_accum = rem_accum + rem_div;
               tick_100hz <= 1;
            end else tick_100hz <= 0;
         end
      end
   end
   
   // If using external 100Hz, drive tick_100hz from clk_100hz (posedge)
   always @(posedge clk_100hz or negedge rst_n) begin
      if (!rst_n) begin
         tick_100hz <= 0;
      end else begin
         if (use_ext_100hz) tick_100hz <= 1;
      end
   end
   
   // Clear tick flag in next simulation delta to allow one-shot behavior
   always @(negedge osc_in or negedge clk_100hz or negedge rst_n) begin
      if (!rst_n) begin
         tick_100hz <= 0;
      end else begin
         // clear tick after propagation
         tick_100hz <= 0;
      end
   end
   
   wire [7:0] new_int_status;
   // On each 100Hz tick advance time by 1/100s
   always @(posedge tick_100hz or negedge rst_n) begin
      if (!rst_n) begin
         // nothing
      end else begin
         // If device in battery-only mode (vdd_present==0), still keep time; emulate that by still advancing
         advance_time_by_1_100th();
      end
   end
   
   // --------------------------- Bus interface -------------------------------
   // Address handling: support multiplexed bus via ALE. When ALE rising edge, latch a_in from d_bus[4:0].
   // If ALE tied to VDD in non-multiplexed mode, the external address lines are used directly.
   always @(negedge ale or negedge rst_n) begin
      if (!rst_n) addr_latch <= 5'h00;
      else addr_latch <= a_in;
   end
   
   function [4:0] current_addr(input ignored);
      begin
         // if ALE used for multiplexed bus, we assume user latched address into addr_latch.
         // If ALE never toggles and ALE==1 tied high, we just use a_in direct.
         if (~ale) current_addr = addr_latch;
         else current_addr = a_in;
      end
   endfunction
   
   // Read operation: when CS low and RD low, drive data bus with the register at current address
   reg [4:0] addr_current;
   always @(*) begin
      addr_current = current_addr(1'b0);
      drive_bus = 1'b0;
      d_out = 8'h00;
      if ((cs_n == 1'b0) && (rd_n == 1'b0)) begin
         case (addr_current)
           ADDR_COUNTER_100TH: begin
              // reading 100th latches time snapshot
              // latch_time is updated on read strobe detection below (edge on rd_n)
              d_out = latch_time[0];
              drive_bus = 1;
           end
           ADDR_HOURS: begin d_out = latch_time[1]; drive_bus = 1; end
           ADDR_MINUTES: begin d_out = latch_time[2]; drive_bus = 1; end
           ADDR_SECONDS: begin d_out = latch_time[3]; drive_bus = 1; end
           ADDR_MONTH: begin d_out = latch_time[4]; drive_bus = 1; end
           ADDR_DATE: begin d_out = latch_time[5]; drive_bus = 1; end
           ADDR_YEAR: begin d_out = latch_time[6]; drive_bus = 1; end
           ADDR_DAYOFWEEK: begin d_out = latch_time[7]; drive_bus = 1; end
	   
           ADDR_RAM_100TH: begin d_out = ram_alarm[0]; drive_bus = 1; end
           ADDR_RAM_HOURS:  begin d_out = ram_alarm[1]; drive_bus = 1; end
           ADDR_RAM_MINUTES:begin d_out = ram_alarm[2]; drive_bus = 1; end
           ADDR_RAM_SECONDS:begin d_out = ram_alarm[3]; drive_bus = 1; end
           ADDR_RAM_MONTH:  begin d_out = ram_alarm[4]; drive_bus = 1; end
           ADDR_RAM_DATE:   begin d_out = ram_alarm[5]; drive_bus = 1; end
           ADDR_RAM_YEAR:   begin d_out = ram_alarm[6]; drive_bus = 1; end
           ADDR_RAM_DAYOFWEEK: begin d_out = 8'h00; drive_bus = 1; end
	   
           ADDR_INT_STATUS: begin d_out = int_status; drive_bus = 1; end
           default: begin d_out = 8'h00; drive_bus = 1; end
         endcase
      end
   end
   
   //  data bus driver
   assign d_bus_out = d_out;
   assign d_bud_en = drive_bus;
   
   reg [7:0] wdata;
   // Writes: capture data when WR goes low with CS low
   always @(negedge wr_n or negedge rst_n) begin
      if (!rst_n) begin
         // nothing
      end else begin
         if (cs_n == 1'b0) begin
            addr_current = current_addr(1'b0);
            // Note: when multiplexed, external user should latch address via ALE prior to write.
            // Capture write data from d_bus (assuming external drives bus).
            wdata = d_bus_in;
            case (addr_current)
              ADDR_COUNTER_100TH: cnt_100th <= wdata[6:0];
              ADDR_HOURS:         cnt_hour  <= wdata; // writing expects correct format
              ADDR_MINUTES:       cnt_min   <= wdata[5:0];
              ADDR_SECONDS:       cnt_sec   <= wdata[5:0];
              ADDR_MONTH:         cnt_month <= wdata[3:0];
              ADDR_DATE:          cnt_date  <= wdata[5:0];
              ADDR_YEAR:          cnt_year  <= wdata[6:0];
              ADDR_DAYOFWEEK:     cnt_day   <= wdata[2:0];
	      
              // Alarm RAM writes and mask bit handling: For simplicity, we encode mask bit in MSB
              // If MSB==1 we treat it as masked (M bit), else unmasked. This follows datasheet idea.
              ADDR_RAM_100TH: begin ram_alarm[0] <= wdata; ram_mask[0] <= wdata[7]; end
              ADDR_RAM_HOURS:  begin ram_alarm[1] <= wdata; ram_mask[1] <= wdata[7]; end
              ADDR_RAM_MINUTES:begin ram_alarm[2] <= wdata; ram_mask[2] <= wdata[7]; end
              ADDR_RAM_SECONDS:begin ram_alarm[3] <= wdata; ram_mask[3] <= wdata[7]; end
              ADDR_RAM_MONTH:  begin ram_alarm[4] <= wdata; ram_mask[4] <= wdata[7]; end
              ADDR_RAM_DATE:   begin ram_alarm[5] <= wdata; ram_mask[5] <= wdata[7]; end
              ADDR_RAM_YEAR:   begin ram_alarm[6] <= wdata; ram_mask[6] <= wdata[7]; end
	      
              ADDR_INT_STATUS: begin
                 // interrupt mask register is write-only here - we assume writes set the mask bits
                 int_mask <= wdata;
              end
	      
              ADDR_CMD_REG: begin
                 // Command register write: update control bits and refresh oscillator params if freq bits changed
                 cmd_reg <= wdata;
                 update_osc_params(.new_cmd_reg(wdata));
              end
	      
              default: begin end
            endcase
         end
      end
   end
   
   // Read strobe edge detection for latching and status reset. The datasheet states
   // that reading the 1/100 counter latches the counters and that reading the Interrupt Status Register resets it.
   always @(posedge rd_n or negedge rst_n) begin
      if (!rst_n) begin
         // clear
      end else begin
         // rd_n rising edge -> if read of status register occurred (dsr read), reset status and int_out
         if ((cs_n == 1'b0) && (rd_n == 1'b1)) begin
            // Determine the address last read: a simplification - we use current_addr
            if (current_addr(1'b0) == ADDR_INT_STATUS) begin
               int_status <= 8'h00;
               // reading status resets the int transistor (clear int_out)
               update_interrupt_output(.new_int_status(8'h00));
            end
         end
      end
   end
   
   // Latch time snapshot on RD asserted to read the 1/100 seconds location.
   // Datasheet: counter data latched when 1/100s register is read. We'll capture on the falling edge of RD when reading that address.
   always @(negedge rd_n or negedge rst_n) begin
      if (!rst_n) begin
         data_latched <= 1'b0;
      end else begin
         if ((cs_n == 1'b0) && (current_addr(1'b0) == ADDR_COUNTER_100TH)) begin
            // capture snapshot into latch_time
            latch_time[0] <= {1'b0, cnt_100th}; // 7-bit field
            latch_time[1] <= cnt_hour;
            latch_time[2] <= {2'b00, cnt_min};  // 6 bits used
            latch_time[3] <= {2'b00, cnt_sec};
            latch_time[4] <= {4'b0000, cnt_month};
            latch_time[5] <= {2'b00, cnt_date};
            latch_time[6] <= {1'b0, cnt_year};
            latch_time[7] <= {5'b00000, cnt_day};
            data_latched <= 1'b1;
         end
      end
   end
   
   // If RD is wide > 0.01s then 100Hz counts are ignored per datasheet; not modeled here.
   
   // --------------------------- Utility: formatting on read -------------------
   // The chip returns hours in either 24-hour raw binary or 12-hour with AM/PM bit.
   // In this model, latch_time[1] holds raw internal binary 0..23. When driving bus we used latch_time directly.
   // If user needs 12-hour format, post-process in testbench or extend model.
   
   // --------------------------- End of module ------------------------------
endmodule

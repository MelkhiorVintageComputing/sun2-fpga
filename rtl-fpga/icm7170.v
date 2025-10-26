`timescale 1ns / 1ps

//==============================================================================
// ICM7170 Real-Time Clock - Verilog Implementation
// Based on Intersil ICM7170 Datasheet
//==============================================================================

module icm7170 (
    // Data Bus
    input [7:0]  D_IN, //  data bus D0-D7
    output [7:0] D_OUT, //  data bus D0-D7
    output 	 D_EN,
    
    // Address Bus
    input [4:0]  A, // Address inputs A0-A4
    
    // Control Signals
    input 	 RD, // Read strobe (active low)
    input 	 WR, // Write strobe (active low)
    input 	 CS, // Chip select (active low)
    input 	 ALE, // Address latch enable (active low)
    
    // Power Supply // unused
    //input         VDD,         // Positive supply
    //input         VSS,         // Ground
    //input         VBACKUP,     // Battery backup voltage

    input 	 RESETn, // extra RESET
    
    // Oscillator
    input 	 OSC_IN, // Crystal oscillator input
    output 	 OSC_OUT, // Crystal oscillator output
    
    // Interrupts
    output 	 INTERRUPT, // Interrupt output (open drain)
    input 	 INT_SOURCE   // Interrupt source select
);

//==============================================================================
// Internal Registers and Memory
//==============================================================================

// Time Counter Registers (Address 00h-07h)
reg [7:0] counter_hundredths;    // 00h: 1/100 seconds (0-99)
reg [7:0] counter_hours;         // 01h: Hours (0-23 or 1-12)
reg [7:0] counter_minutes;       // 02h: Minutes (0-59)
reg [7:0] counter_seconds;       // 03h: Seconds (0-59)
reg [7:0] counter_month;         // 04h: Month (1-12)
reg [7:0] counter_date;          // 05h: Date (1-31)
reg [7:0] counter_year;          // 06h: Year (0-99)
reg [7:0] counter_day_of_week;   // 07h: Day of week (0-6)

// Alarm RAM Registers (Address 08h-0Fh)
reg [7:0] alarm_hundredths;      // 08h: Alarm 1/100 seconds + mask bit
reg [7:0] alarm_hours;           // 09h: Alarm hours + mask bit
reg [7:0] alarm_minutes;         // 0Ah: Alarm minutes + mask bit
reg [7:0] alarm_seconds;         // 0Bh: Alarm seconds + mask bit
reg [7:0] alarm_month;           // 0Ch: Alarm month + mask bit
reg [7:0] alarm_date;            // 0Dh: Alarm date + mask bit
reg [7:0] alarm_year;            // 0Eh: Alarm year + mask bit
reg [7:0] alarm_day_of_week;     // 0Fh: Alarm day of week + mask bit

// Control Registers
reg [7:0] interrupt_mask_reg;    // 10h: Interrupt mask register (write)
reg [7:0] interrupt_status_reg;  // 10h: Interrupt status register (read)
reg [7:0] command_reg;           // 11h: Command register

// Latched time data for stable reads
reg [7:0] latched_hundredths;
reg [7:0] latched_hours;
reg [7:0] latched_minutes;
reg [7:0] latched_seconds;
reg [7:0] latched_month;
reg [7:0] latched_date;
reg [7:0] latched_year;
reg [7:0] latched_day_of_week;
reg       data_latched;

// Address latching for multiplexed bus
reg [4:0] latched_address;
reg       latched_cs;

//==============================================================================
// Clock Generation and Timing
//==============================================================================

// Oscillator frequency divider
reg [15:0] osc_divider;
reg        clk_4000hz;
reg [5:0]  clk_4000hz_div;
reg        clk_100hz;
reg [6:0]  clk_100hz_div;
reg        clk_1hz;

// Crystal frequency selection from command register
wire [1:0] crystal_freq_sel = command_reg[1:0];
wire [15:0] osc_div_ratio = (crystal_freq_sel == 2'b00) ? 16'd8 :      // 32.768kHz
                           (crystal_freq_sel == 2'b01) ? 16'd262 :     // 1.048576MHz
                           (crystal_freq_sel == 2'b10) ? 16'd524 :     // 2.097152MHz
                                                         16'd1048;     // 4.194304MHz

// Generate internal clocks
always @(posedge OSC_IN or negedge RESETn) begin
    if (!RESETn) begin
        osc_divider <= 16'd0;
        clk_4000hz <= 1'b0;
    end else begin
        if (osc_divider >= osc_div_ratio - 1) begin
            osc_divider <= 16'd0;
            clk_4000hz <= ~clk_4000hz;
        end else begin
            osc_divider <= osc_divider + 1;
        end
    end
end

// Generate 100Hz clock from 4000Hz (improveme: accuracy)
always @(posedge clk_4000hz or negedge RESETn) begin
    if (!RESETn) begin
        clk_4000hz_div <= 6'd0;
        clk_100hz <= 1'b0;
    end else begin
        if (clk_4000hz_div >= 6'd39) begin  // Divide by 40 (4000/100)
            clk_4000hz_div <= 6'd0;
            clk_100hz <= ~clk_100hz;
        end else begin
            clk_4000hz_div <= clk_4000hz_div + 1;
        end
    end
end

// Generate 1Hz clock from 100Hz
always @(posedge clk_100hz or negedge RESETn) begin
    if (!RESETn) begin
        clk_100hz_div <= 7'd0;
        clk_1hz <= 1'b0;
    end else begin
        if (clk_100hz_div >= 7'd49) begin  // Divide by 100
            clk_100hz_div <= 7'd0;
            clk_1hz <= ~clk_1hz;
        end else begin
            clk_100hz_div <= clk_100hz_div + 1;
        end
    end
end

//==============================================================================
// Address Latching for Multiplexed Bus
//==============================================================================

always @(negedge ALE) begin
    latched_address <= A;
    latched_cs <= CS;
end

// Select between direct and latched address
wire [4:0] effective_address = (ALE) ? A : latched_address;
wire       effective_cs = (ALE) ? CS : latched_cs;

//==============================================================================
// Time Counter Logic
//==============================================================================

// Simple binary increment function
function [7:0] binary_increment;
    input [7:0] val;
    input [7:0] max_val;
    begin
        if (val >= max_val) begin
            binary_increment = 8'd0;
        end else begin
            binary_increment = val + 1;
        end
    end
endfunction

// Time counter updates
wire run_enable = command_reg[3];  // Run/Stop bit
wire hour_format = command_reg[2]; // 12/24 hour format

always @(posedge clk_100hz or negedge RESETn) begin
    if (!RESETn) begin
        counter_hundredths <= 8'd0;
        counter_seconds <= 8'd0;
        counter_minutes <= 8'd0;
        counter_hours <= 8'd0;
        counter_date <= 8'd1;
        counter_month <= 8'd1;
        counter_year <= 8'd0;
        counter_day_of_week <= 8'd0;
        interrupt_status_reg <= 8'd0;
    end else if (run_enable) begin
        // Hundredths of seconds counter (0-99)
        counter_hundredths <= binary_increment(counter_hundredths, 8'd99);
        if (counter_hundredths == 8'd99) begin
            interrupt_status_reg[1] <= 1'b1;  // 1/100 sec flag
            
            // Seconds counter (0-59)
            counter_seconds <= binary_increment(counter_seconds, 8'd59);
            if (counter_seconds == 8'd59) begin
                interrupt_status_reg[3] <= 1'b1;  // Seconds flag
                
                // Minutes counter (0-59)
                counter_minutes <= binary_increment(counter_minutes, 8'd59);
                if (counter_minutes == 8'd59) begin
                    interrupt_status_reg[4] <= 1'b1;  // Minutes flag
                    
                    // Hours counter
                    if (hour_format) begin  // 24-hour format (0-23)
                        counter_hours <= binary_increment(counter_hours, 8'd23);
                        if (counter_hours == 8'd23) begin
                            interrupt_status_reg[5] <= 1'b1;  // Hours flag
                            // Day rollover logic would go here
                        end
                    end else begin  // 12-hour format (1-12)
                        if (counter_hours == 8'd12) begin
                            counter_hours <= 8'd1;
                        end else begin
                            counter_hours <= binary_increment(counter_hours & 8'h7F, 8'd12);
                        end
                    end
                end
            end
        end
        
        // Set 10Hz interrupt flag every 10 hundredths
        if (counter_hundredths % 10 == 9) begin
            interrupt_status_reg[2] <= 1'b1;  // 1/10 sec flag
        end
    end
end

//==============================================================================
// Data Latching Logic
//==============================================================================

// Latch time data when hundredths register is read
always @(negedge RD or negedge RESETn) begin
    if (!RESETn) begin
        data_latched <= 1'b0;
    end else if (!effective_cs && effective_address == 5'h00) begin
        // Reading hundredths register - latch all time data
        latched_hundredths <= counter_hundredths;
        latched_hours <= counter_hours;
        latched_minutes <= counter_minutes;
        latched_seconds <= counter_seconds;
        latched_month <= counter_month;
        latched_date <= counter_date;
        latched_year <= counter_year;
        latched_day_of_week <= counter_day_of_week;
        data_latched <= 1'b1;
    end
end

//==============================================================================
// Alarm Comparison Logic
//==============================================================================

wire alarm_match = (!alarm_hundredths[7] && (latched_hundredths == alarm_hundredths[6:0]) || alarm_hundredths[7]) &&
                   (!alarm_hours[7] && (latched_hours == alarm_hours[6:0]) || alarm_hours[7]) &&
                   (!alarm_minutes[7] && (latched_minutes == alarm_minutes[6:0]) || alarm_minutes[7]) &&
                   (!alarm_seconds[7] && (latched_seconds == alarm_seconds[6:0]) || alarm_seconds[7]) &&
                   (!alarm_month[7] && (latched_month == alarm_month[6:0]) || alarm_month[7]) &&
                   (!alarm_date[7] && (latched_date == alarm_date[6:0]) || alarm_date[7]) &&
                   (!alarm_year[7] && (latched_year == alarm_year[6:0]) || alarm_year[7]) &&
                   (!alarm_day_of_week[7] && (latched_day_of_week == alarm_day_of_week[6:0]) || alarm_day_of_week[7]);

always @(posedge clk_1hz) begin
    if (alarm_match && interrupt_mask_reg[0]) begin
        interrupt_status_reg[0] <= 1'b1;  // Alarm flag
    end
end

//==============================================================================
// Bus Interface Logic
//==============================================================================

// Data output multiplexer
reg [7:0] data_out;
wire read_enable = !RD && !effective_cs;
wire write_enable = !WR && !effective_cs;

always @(*) begin
    case (effective_address)
        5'h00: data_out = data_latched ? latched_hundredths : counter_hundredths;
        5'h01: data_out = data_latched ? latched_hours : counter_hours;
        5'h02: data_out = data_latched ? latched_minutes : counter_minutes;
        5'h03: data_out = data_latched ? latched_seconds : counter_seconds;
        5'h04: data_out = data_latched ? latched_month : counter_month;
        5'h05: data_out = data_latched ? latched_date : counter_date;
        5'h06: data_out = data_latched ? latched_year : counter_year;
        5'h07: data_out = data_latched ? latched_day_of_week : counter_day_of_week;
        5'h08: data_out = alarm_hundredths;
        5'h09: data_out = alarm_hours;
        5'h0A: data_out = alarm_minutes;
        5'h0B: data_out = alarm_seconds;
        5'h0C: data_out = alarm_month;
        5'h0D: data_out = alarm_date;
        5'h0E: data_out = alarm_year;
        5'h0F: data_out = alarm_day_of_week;
        5'h10: data_out = interrupt_status_reg;
        5'h11: data_out = 8'h00;  // Command register is write-only
        default: data_out = 8'h00;
    endcase
end

// Write operations
always @(posedge WR or negedge RESETn) begin
    if (!RESETn) begin
        command_reg <= 8'h00;
        interrupt_mask_reg <= 8'h00;
        alarm_hundredths <= 8'h80;  // Masked by default
        alarm_hours <= 8'h80;
        alarm_minutes <= 8'h80;
        alarm_seconds <= 8'h80;
        alarm_month <= 8'h80;
        alarm_date <= 8'h80;
        alarm_year <= 8'h80;
        alarm_day_of_week <= 8'h80;
    end else if (!effective_cs) begin
        case (effective_address)
            5'h00: counter_hundredths <= D_IN;
            5'h01: counter_hours <= D_IN;
            5'h02: counter_minutes <= D_IN;
            5'h03: counter_seconds <= D_IN;
            5'h04: counter_month <= D_IN;
            5'h05: counter_date <= D_IN;
            5'h06: counter_year <= D_IN;
            5'h07: counter_day_of_week <= D_IN;
            5'h08: alarm_hundredths <= D_IN;
            5'h09: alarm_hours <= D_IN;
            5'h0A: alarm_minutes <= D_IN;
            5'h0B: alarm_seconds <= D_IN;
            5'h0C: alarm_month <= D_IN;
            5'h0D: alarm_date <= D_IN;
            5'h0E: alarm_year <= D_IN;
            5'h0F: alarm_day_of_week <= D_IN;
            5'h10: interrupt_mask_reg <= D_IN;
            5'h11: command_reg <= D_IN;
        endcase
    end
end

// Clear interrupt status register on read
always @(posedge RD) begin
    if (!effective_cs && effective_address == 5'h10) begin
        interrupt_status_reg <= 8'h00;
    end
end

//==============================================================================
// Interrupt Generation
//==============================================================================

wire interrupt_enable = command_reg[4];
wire any_interrupt = |(interrupt_status_reg[6:0] & interrupt_mask_reg[6:0]);

// Set global interrupt flag
always @(*) begin
    if (any_interrupt) begin
        interrupt_status_reg[7] = 1'b1;
    end
end

//==============================================================================
// Output Assignments
//==============================================================================

// Bidirectional data bus
   assign D_OUT = data_out;
   assign D_EN = read_enable;
   

   // Interrupt output (open drain, active low)
   assign INTERRUPT = (interrupt_enable && any_interrupt) ? 1'b0 : 1'b1;
   
   // Oscillator output (simplified)
   assign OSC_OUT = ~OSC_IN;

endmodule // icm7170


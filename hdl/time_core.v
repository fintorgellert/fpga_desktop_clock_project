`timescale 1ns / 1ps

//********************************************************************************//
//
// Module: time_core
//
// Description:
// This module is the core of the clock's timekeeping functionality. It
// instantiates and connects a series of counters for seconds, minutes, hours,
// days, and months. A 1 Hz signal is generated from the main clock to drive
// the counters. The module supports loading a new time and date, and it
// outputs the current time for display and for the alarm logic.
//
// Inputs:
//   clk:           Global clock signal (100MHz).
//   rst:           Global reset signal.
//   load_settings: A flag to enable loading of new time and date values.
//   load_sec:      The second value to load.
//   load_min:      The minute value to load.
//   load_hour:     The hour value to load.
//   load_day:      The day value to load.
//   load_month:    The month value to load.
//
// Outputs:
//   actual_month:  The current month.
//   actual_day:    The current day.
//   actual_hour:   The current hour.
//   actual_min:    The current minute.
//   actual_sec:    The current second.
//   segm:          8-bit output for the 7-segment display segments.
//   dign:          8-bit output for controlling the 7-segment display digits.
//   led:           6-bit output for LEDs, used to display seconds.
//
//********************************************************************************//

module time_core(
        input clk,
        input rst,
        input load_settings,       
        input [5:0] load_sec,
        input [5:0] load_min,
        input [4:0] load_hour,
        input [4:0] load_day,
        input [3:0] load_month,
        output [3:0] actual_month,
        output [4:0] actual_day, actual_hour,
        output [5:0] actual_min, actual_sec,       
        output [7:0] segm,   
        output [7:0] dign,
        output [5:0] led
    );
    
    wire [5:0] sec, min, l;
    wire [4:0] hour; 
    wire [3:0] month; 
    wire [31:0] hex;
    wire [7:0] seg, dig;
    wire day_ce, hour_ce, min_ce, sec_ce;
    wire [3:0] mot, mou, dt, du, ht, hu, mit, miu;
      
    wire ce;
    rategen rategenerator(.clk(clk), .rst(rst), .cy(ce));

    bcd_unit_counter #(0, 59, 0) counter_sec (
        .clk(clk), 
        .rst(rst), 
        .ce(ce),
        .load_en(load_settings),
        .load_data(load_sec),
        .q(sec), 
        .cout(sec_ce)
    );
    
    bcd_unit_counter #(0, 59, 20) counter_min (
        .clk(clk), 
        .rst(rst), 
        .ce(ce&sec_ce),
        .load_en(load_settings),
        .load_data(load_min),
        .q(min), 
        .cout(min_ce)
    );        
        
   bcd_unit_counter #(0, 23, 4) counter_hour (
        .clk(clk), 
        .rst(rst), 
        .ce(ce&sec_ce&min_ce),
        .load_en(load_settings),
        .load_data({1'b0, load_hour}),
        .q(hour), 
        .cout(hour_ce)
    );
  
    day_counter day_counter (
        .clk(clk),
        .rst(rst),
        .ce(ce&sec_ce&min_ce&hour_ce),
        .load_en(load_settings),
        .load_day(load_day),
        .month_tens(mot),
        .month_units(mou),
        .du(du),
        .dt(dt),
        .cout(day_ce)
    );
    
     bcd_unit_counter #(1, 12, 8) counter_month (
        .clk(clk), 
        .rst(rst), 
        .ce(ce&sec_ce&min_ce&hour_ce&day_ce),
        .load_en(load_settings),
        .load_data({2'b0, load_month}), 
        .q(month), 
        .cout()
    );
    
    
    hex7seg segdecoder ( 
        .val(hex), 
        .cclk(clk), 
        .rst(rst), 
        .seg(seg), 
        .dig(dig)
    );
    
    hexled seconds_display (
        .val(sec),
        .rst(rst),
        .led(l)    
    );
    
    assign miu = min % 10;
    assign mit = min / 10;
    assign hu = hour % 10;
    assign ht = hour / 10;
    assign mou = month % 10;
    assign mot = month / 10;
    
    assign actual_month = month;
    assign actual_day   = dt * 10 + du;
    assign actual_hour  = hour;
    assign actual_min   = min;
    assign actual_sec  = sec;
    
    assign hex = { mot, mou, dt, du, ht, hu, mit, miu };
    assign segm = seg;
    assign dign = ~dig; 
    assign led = l;

endmodule

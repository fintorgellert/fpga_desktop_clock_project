`timescale 1ns / 1ps

/*
 * Module: time_core
 * -----------------
 * Purpose:
 *   The main time-keeping core of the clock.
 *   Contains the counters for Seconds, Minutes, Hours, Days, and Months.
 *   Increments time based on a 1Hz pulse from the `rategen` module.
 *   Handles cascading carries (e.g., second -> minute -> hour -> day -> month).
 *   Allows loading new time values (from manual setting or UART).
 *   Outputs current time to the 7-segment display driver.
 *
 * Inputs:
 *   - clk          : System clock.
 *   - rst          : Reset signal.
 *   - load_settings: Enable signal to load new time values.
 *   - load_sec     : Second value to load.
 *   - load_min     : Minute value to load.
 *   - load_hour    : Hour value to load.
 *   - load_day     : Day value to load.
 *   - load_month   : Month value to load.
 *
 * Outputs:
 *   - actual_month : Current month.
 *   - actual_day   : Current day.
 *   - actual_hour  : Current hour.
 *   - actual_min   : Current minute.
 *   - actual_sec   : Current second.
 *   - segm         : 7-segment display segments.
 *   - dign         : 7-segment display digits.
 *   - led          : LED output.
 */
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
        wire [4:0] hour; // 5 bit the hour (0-23)
        wire [3:0] month; // 4 bit the mounth (1-12)
    wire [31:0] hex;
    wire [7:0] seg, dig;
    wire day_ce, hour_ce, min_ce, sec_ce;
    wire [3:0] mot, mou, dt, du, ht, hu, mit, miu;
      
    // 1Hz enable signal
    wire ce;
    rategen rategenerator(.clk(clk), .rst(rst), .cy(ce));
    
    // seconds counter  0-59, default value 0
    bcd_unit_counter #(0, 59, 0) counter_sec (
        .clk(clk), 
        .rst(rst), 
        .ce(ce),
        .load_en(load_settings),
        .load_data(load_sec),
        .q(sec), 
        .cout(sec_ce)
    );
    
    
    // minuten counter 0-59, default value 20
    bcd_unit_counter #(0, 59, 20) counter_min (
        .clk(clk), 
        .rst(rst), 
        .ce(ce&sec_ce),
        .load_en(load_settings),
        .load_data(load_min),
        .q(min), 
        .cout(min_ce)
    );        
        
        
    // hour counter 0-23, default value 4
   bcd_unit_counter #(0, 23, 4) counter_hour (
        .clk(clk), 
        .rst(rst), 
        .ce(ce&sec_ce&min_ce),
        .load_en(load_settings),
        .load_data({1'b0, load_hour}),
        .q(hour), 
        .cout(hour_ce)
    );
  
    
    // day counter (1–31), depends on the month, default value 17
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
    
    
     // month counter (1–12), default value 8
     bcd_unit_counter #(1, 12, 8) counter_month (
        .clk(clk), 
        .rst(rst), 
        .ce(ce&sec_ce&min_ce&hour_ce&day_ce),
        .load_en(load_settings),
        .load_data({2'b0, load_month}), 
        .q(month), 
        .cout()
    );
    
    
    // display driver
    hex7seg segdecoder ( 
        .val(hex), 
        .cclk(clk), 
        .rst(rst), 
        .seg(seg), 
        .dig(dig)
    );
    
    // LED control
    hexled seconds_display (
        .val(sec),
        .rst(rst),
        .led(l)    
    );
    
    // generate segments from numbers, split into tens and units
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

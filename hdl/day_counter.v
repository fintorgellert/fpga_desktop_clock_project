`timescale 1ns / 1ps

//********************************************************************************//
//
// Module: day_counter
//
// Description:
// This module is a specialized BCD counter for tracking the days of the month.
// It correctly handles the varying number of days in each month (30 or 31),
// although it does not account for leap years (February is fixed at 28 days).
// The counter can be preset with a specific day.
//
// Inputs:
//   clk:         Clock signal.
//   rst:         Asynchronous reset signal.
//   ce:          Clock enable; the counter increments on the rising edge of clk
//                when ce is high.
//   month_tens:  The tens digit of the current month.
//   month_units: The units digit of the current month.
//   load_en:     Enables synchronous loading of `load_day`.
//   load_day:    5-bit value to be loaded as the current day.
//
// Outputs:
//   du:          The units digit of the current day.
//   dt:          The tens digit of the current day.
//   cout:        Carry out; asserted for one clock cycle when the counter
//                rolls over to the next month.
//
//********************************************************************************//

module day_counter(
        input clk,
        input rst,
        input ce,              
        input [3:0] month_tens,
        input [3:0] month_units,input load_en,
        input [4:0] load_day,
        output reg [3:0] du,   
        output reg [3:0] dt,  
        output reg cout        
    );
    
    reg [4:0] max_days; 
    wire [5:0] current_day;

    assign current_day = dt*10 + du;

    always @(*)
        case({month_tens, month_units})
            8'h01, 8'h03, 8'h05, 8'h07, 8'h08, 8'h10, 8'h12: max_days = 31;
            8'h04, 8'h06, 8'h09, 8'h11: max_days = 30;
            8'h02: max_days = 28; 
        endcase

    always @(posedge clk) 
        begin
            if (rst) 
                begin
                    du <= 4'd7;
                    dt <= 4'd1;
                    cout <= 0;
                end 
            else if (load_en)
                begin
                    du <= load_day % 10;
                    dt <= load_day / 10;
                    cout <= 0;
                end
            else if (ce) 
                begin
                    if (current_day == max_days) 
                        begin
                            du <= 4'd1;
                            dt <= 4'd0;
                            cout <= 1;
                        end
                    else
                        begin
                            cout <= 0;
                            if (du == 4'd9) 
                                begin
                                    du <= 4'd0;
                                    dt <= dt + 1;
                                end 
                            else
                                du <= du + 1;
                        end
                end
        end

endmodule

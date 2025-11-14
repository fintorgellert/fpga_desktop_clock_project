`timescale 1ns / 1ps

//********************************************************************************//
//
// Module: rategen
//
// Description:
// This module generates a 1 Hz clock enable signal from a 100 MHz input clock.
// It uses a counter that increments on each rising edge of the input clock.
// When the counter reaches 99,999,999, it asserts a carry-out signal for one
// clock cycle and then resets, effectively dividing the input clock by
// 100,000,000.
//
// Inputs:
//   clk: The 100 MHz input clock.
//   rst: An asynchronous reset signal.
//
// Outputs:
//   cy:  The 1 Hz clock enable signal, which is high for one cycle of the
//        input clock.
//
//********************************************************************************//

module rategen(
        input clk, rst,  
        output cy
    );

    reg [29:0] Q; 
    
    always @(posedge clk) 
        begin 
            if (rst | cy) 
                Q <= 0;
             else 
                Q <= Q + 1;
       end
    
    assign cy = (Q == 99_999_999);
    
endmodule

`timescale 1ns / 1ps

/*
 * Module: hexled
 * --------------
 * Purpose:
 *   Simple driver for LEDs.
 *   Displays the lower 6 bits of the input value on 6 LEDs.
 *
 * Inputs:
 *   - val : 6-bit value to display.
 *   - rst : Reset signal (clears the display).
 *
 * Outputs:
 *   - led : 6-bit output to drive the LEDs.
 */
module hexled(
    input [5:0] val,
    input rst,
    output [5:0] led
); 

    reg [5:0] disp;

    always @(*) 
        begin
            if (rst)
                disp <= 6'b0;   
            else
                disp <= val;       
        end
    
    assign led = disp;    
        
endmodule


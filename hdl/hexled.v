`timescale 1ns / 1ps

//********************************************************************************//
//
// Module: hexled
//
// Description:
// This module serves as a simple driver for a 6-bit LED display. It directly
// maps a 6-bit input value to the LEDs. The module includes a reset input to
// turn off all LEDs.
//
// Inputs:
//   val: A 6-bit value that determines which LEDs are lit.
//   rst: An asynchronous reset signal. When high, it turns off all LEDs.
//
// Outputs:
//   led: A 6-bit output that connects to the LEDs.
//
//********************************************************************************//

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


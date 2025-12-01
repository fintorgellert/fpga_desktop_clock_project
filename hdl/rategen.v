`timescale 1ns / 1ps

/*
 * Module: rategen
 * ---------------
 * Purpose:
 *   Rate generator / Clock divider.
 *   Generates a 1Hz enable pulse from the 100MHz system clock.
 *   Used to drive the seconds counter in the time core.
 *
 * Inputs:
 *   - clk : 100MHz System clock.
 *   - rst : Reset signal.
 *
 * Outputs:
 *   - cy  : One-cycle high pulse every 1 second (100,000,000 clock cycles).
 */
module rategen(
        input clk, rst,  
        output cy
    );

    reg [29:0] Q; // 100MHz -> 1Hz 
    
    always @(posedge clk) 
        begin 
            if (rst | cy) 
                Q <= 0;
             else 
                Q <= Q + 1;
       end
    
    assign cy = (Q == 99_999_999);
    
endmodule

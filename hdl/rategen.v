`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.10.2025 14:04:44
// Design Name: 
// Module Name: rategen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// File: rategen.v
module rategen(
        input clk, rst,  
        output cy
    );

    reg [29:0] Q; // 100MHz -> 1Hz (27 bit elég: 100e6 < 2^27)
    
    always @(posedge clk) 
        begin 
            if (rst | cy) 
                Q <= 0;
             else 
                Q <= Q + 1;
       end
    
    assign cy = (Q == 99_999_999);
    
endmodule

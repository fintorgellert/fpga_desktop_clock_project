`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.10.2025 14:04:11
// Design Name: 
// Module Name: hexled
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

// File: hexled.v
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


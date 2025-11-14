`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.10.2025 22:52:38
// Design Name: 
// Module Name: debounce
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


module debouncer(
        input btn,
        input clk,
        output d_btn
        );
    reg delay1, delay2, delay3;
    
    always @(posedge clk)
    begin
        delay1 <= btn;
        delay2 <= delay1;
        delay3 <= delay2;
    end
    
    assign d_btn = delay1 & delay2 & ~delay3;

endmodule


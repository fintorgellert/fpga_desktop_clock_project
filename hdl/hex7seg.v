`timescale 1ns / 1ps

//********************************************************************************//
//
// Module: hex7seg
//
// Description:
// This module drives an 8-digit, 7-segment display. It takes a 32-bit hex
// value and displays it across the eight digits. The module handles the
// multiplexing of the digits and the conversion from a 4-bit hex value to
// the corresponding 7-segment display pattern. It also controls the decimal
// points, enabling them for specific digits.
//
// Inputs:
//   val:   A 32-bit value to be displayed, where each 4-bit nibble corresponds
//          to one digit on the display.
//   cclk:  The clock signal for multiplexing the display.
//   rst:   Reset signal.
//
// Outputs:
//   seg:   An 8-bit output that drives the segments of the display (a-g and dp).
//   dig:   An 8-bit one-hot encoded output that selects which of the eight digits
//          is currently active.
//
//********************************************************************************//

module hex7seg(
    input [31:0] val,
    input cclk, rst,
    output [7:0] seg, 
    output [7:0] dig  
);

    reg [17:0] cnt; 
    
    always @(posedge cclk)  
        if (rst) 
           cnt <= 18'b0;
        else 
           cnt <= cnt + 1;
           
    wire [2:0] mpx;
    
    // Multiplexer select bitek
    assign mpx = cnt[17:15];
    
  
    assign dig = 8'b00000001 << mpx; 

    reg [3:0] digit;
  
    always @(*) 
        case(mpx)
            3'b000: digit = val[3:0];   
            3'b001: digit = val[7:4];   
            3'b010: digit = val[11:8];  
            3'b011: digit = val[15:12]; 
            3'b100: digit = val[19:16]; 
            3'b101: digit = val[23:20]; 
            3'b110: digit = val[27:24];  
            3'b111: digit = val[31:28];  
        endcase

    
    reg [7:0] disp;
    wire dp;
    
    assign dp = ~(mpx == 3'b010 || mpx == 3'b110);

    always @(*) 
        case(digit)
            4'h0: disp = {dp, 7'b0000001}; 
            4'h1: disp = {dp, 7'b1001111}; 
            4'h2: disp = {dp, 7'b0010010}; 
            4'h3: disp = {dp, 7'b0000110}; 
            4'h4: disp = {dp, 7'b1001100}; 
            4'h5: disp = {dp, 7'b0100100}; 
            4'h6: disp = {dp, 7'b0100000}; 
            4'h7: disp = {dp, 7'b0001111}; 
            4'h8: disp = {dp, 7'b0000000}; 
            4'h9: disp = {dp, 7'b0000100};  
            default: disp = 8'hFF; 
        endcase

    assign seg = disp;
    
endmodule

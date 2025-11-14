`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.10.2025 14:48:43
// Design Name: 
// Module Name: hex7seg
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


// File: hex7seg.v
module hex7seg(
    input [31:0] val,
    input cclk, rst,
    output [7:0] seg, // seg[7]=DP, seg[6]=g, seg[5]=f, seg[4]=e, seg[3]=d, seg[2]=c, seg[1]=b, seg[0]=a
    output [7:0] dig  // Digit Select (active high)
);

    // Számláló méret (18 bit) - 100MHz / 2^17 (kb. 763 Hz)
    reg [17:0] cnt; 
    
    always @(posedge cclk)  
        if (rst) 
           cnt <= 18'b0;
        else 
           cnt <= cnt + 1;
           
    wire [2:0] mpx;
    
    // Multiplexer select bitek
    assign mpx = cnt[17:15];
    
    // Digit Select: 4'b0001-tõl váltogat (aktív high)
    assign dig = 8'b00000001 << mpx; 

    reg [3:0] digit;
    
    // Multiplexer a kijelzendõ digit kiválasztására
    always @(*) 
        case(mpx)
            3'b000: digit = val[3:0];    // 0. digit (min_units)
            3'b001: digit = val[7:4];    // 1. digit (min_tens) 
            3'b010: digit = val[11:8];   // 2. digit (hour_units) - Itt kell a DP
            3'b011: digit = val[15:12];  // 3. digit (hour_tens)
            3'b100: digit = val[19:16];  // 4. digit (day_units)
            3'b101: digit = val[23:20];  // 5. digit (day_tens)  
            3'b110: digit = val[27:24];  // 6. digit (month_units) - Itt kell a DP
            3'b111: digit = val[31:28];  // 7. digit (month_tens)
        endcase

    
    reg [7:0] disp;
    wire dp;
    
    // DP bekapcsolva, ha a harmadik digit (hour_units, mpx=010) 
    // vagy az hetedig digit (day_units, mpx=110) aktív.
    // A seg[7] bitnek 0-nak kell lennie a DP bekapcsolásához (aktív alacsony).
    assign dp = ~(mpx == 3'b010 || mpx == 3'b110);

    // 7-seg dekóder (Aktív-alacsony: 0 = ON, 1 = OFF)
    // Bit sorrend: seg[6]=g, seg[5]=f, seg[4]=e, seg[3]=d, seg[2]=c, seg[1]=b, seg[0]=a
    // a(0), b(1), c(2), d(3), e(4), f(5), g(6)
    always @(*) 
        case(digit)
             // DP | g f e d c b a
            4'h0: disp = {dp, 7'b0000001}; // 0
            4'h1: disp = {dp, 7'b1001111}; // 1
            4'h2: disp = {dp, 7'b0010010}; // 2
            4'h3: disp = {dp, 7'b0000110}; // 3
            4'h4: disp = {dp, 7'b1001100}; // 4
            4'h5: disp = {dp, 7'b0100100}; // 5
            4'h6: disp = {dp, 7'b0100000}; // 6
            4'h7: disp = {dp, 7'b0001111}; // 7
            4'h8: disp = {dp, 7'b0000000}; // 8
            4'h9: disp = {dp, 7'b0000100}; // 9 
            default: disp = 8'hFF; 
        endcase

    // Segments output (aktiv-alacsony)
    assign seg = disp;
    
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.10.2025
// Design Name: 
// Module Name: day_counter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: BCD day counter
//////////////////////////////////////////////////////////////////////////////////


// File: day_counter.v
module day_counter(
        input clk,
        input rst,
        input ce,              
        input [3:0] month_tens,
        input [3:0] month_units,input load_en,
        input [4:0] load_day,
        output reg [3:0] du,   // nap egységek
        output reg [3:0] dt,   // nap tízesek
        output reg cout         // jelez, ha új hónap kezdõdik
    );
    
    reg [4:0] max_days; // hónap hossz, max 31
    wire [5:0] current_day; // BCD tízes + egység

    assign current_day = dt*10 + du;

    // Hónap szerint napok száma
    always @(*)
        case({month_tens, month_units})
            8'h01, 8'h03, 8'h05, 8'h07, 8'h08, 8'h10, 8'h12: max_days = 31;
            8'h04, 8'h06, 8'h09, 8'h11: max_days = 30;
            8'h02: max_days = 28; 
        endcase

    // Nap számlálás
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
                            cout <= 1; // új hónap kezdõdik
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

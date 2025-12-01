`timescale 1ns / 1ps

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

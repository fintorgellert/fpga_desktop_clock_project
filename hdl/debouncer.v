`timescale 1ns / 1ps

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


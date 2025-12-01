`timescale 1ns / 1ps

/*
 * Module: debouncer
 * -----------------
 * Purpose:
 *   Debounces a push-button input signal to prevent multiple triggers
 *   from a single press due to mechanical bouncing.
 *   Uses a 3-stage shift register to verify the signal stability.
 *
 * Inputs:
 *   - btn : Noisy button input signal.
 *   - clk : System clock.
 *
 * Outputs:
 *   - d_btn : Debounced button output (one-shot pulse).
 */
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


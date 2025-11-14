`timescale 1ns / 1ps

//********************************************************************************//
//
// Module: debouncer
//
// Description:
// This module debounces a mechanical button press to prevent multiple triggers
// from a single press. It uses a simple shift register to sample the button
// input over several clock cycles. A stable high signal is then output as a
// single, clean pulse.
//
// Inputs:
//   btn: The noisy input from the button.
//   clk: The clock signal.
//
// Outputs:
//   d_btn: The debounced button signal, which goes high for one clock cycle
//          after a stable press is detected.
//
//********************************************************************************//

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


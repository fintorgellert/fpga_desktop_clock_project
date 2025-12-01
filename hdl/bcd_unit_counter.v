`timescale 1ns / 1ps

/*
 * Module: bcd_unit_counter
 * ------------------------
 * Purpose:
 *   A configurable counter module used for seconds, minutes, and hours.
 *   It counts up when enabled (`ce`) and resets to a start value (`R`)
 *   when it reaches a limit (`N`). It also supports loading a specific value.
 *
 * Parameters:
 *   - R: Reset value (value to wrap around to).
 *   - N: Maximum value (value at which carry out occurs).
 *   - D: Default reset value (on system reset).
 *
 * Inputs:
 *   - clk      : System clock.
 *   - rst      : System reset.
 *   - ce       : Clock Enable (count enable).
 *   - load_en  : Enable loading a specific value.
 *   - load_data: The value to load when `load_en` is high.
 *
 * Outputs:
 *   - q   : Current counter value.
 *   - cout: Carry out signal (High when counter reaches N).
 */
module bcd_unit_counter #(
        parameter R = 0, N = 59, D = 0
    ) (
        input clk, rst,
        input ce, 
        input load_en,
        input [5:0] load_data,       
        output [5:0] q,
        output cout
    );
    
    reg [5:0] q_reg;
    wire q_reg_cout;

  always @(posedge clk) 
        if (rst)
            q_reg <= D;
        else if (load_en)
            q_reg <= load_data;
        else if (ce) 
            if (q_reg_cout)
                q_reg <= R;
            else
                q_reg <= q_reg + 1;
            
    assign q_reg_cout = (q_reg == N); 
    
    assign q = q_reg;
    assign cout = q_reg_cout;

endmodule

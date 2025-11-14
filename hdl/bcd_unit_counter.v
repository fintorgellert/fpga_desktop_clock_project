`timescale 1ns / 1ps

//********************************************************************************//
//
// Module: bcd_unit_counter
//
// Description:
// A flexible, parameterized counter module that can be configured to count up to
// a specific value (N), reset to a value (R), and be preset with a load value.
// It is designed to be a general-purpose unit for timekeeping elements like
// seconds, minutes, hours, etc.
//
// Parameters:
//   R: The value the counter resets to after reaching the terminal count (N).
//   N: The terminal count value. The counter counts from R up to N.
//   D: The default value loaded into the counter on a global reset.
//
// Inputs:
//   clk:       Clock signal.
//   rst:       Asynchronous reset signal.
//   ce:        Clock enable. The counter increments only when this is high.
//   load_en:   Enables synchronous loading of `load_data` into the counter.
//   load_data: 6-bit value to be loaded into the counter when `load_en` is high.
//
// Outputs:
//   q:         The 6-bit current count value.
//   cout:      Carry out. Asserted for one clock cycle when the counter reaches N.
//
//********************************************************************************//

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

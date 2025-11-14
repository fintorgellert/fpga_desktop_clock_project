`timescale 1ns / 1ps

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

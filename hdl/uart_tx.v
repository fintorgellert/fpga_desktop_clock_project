`timescale 1ns / 1ps

/*
 * Module: uart_tx
 * ---------------
 * Purpose:
 *   UART Transmitter module.
 *   Converts a parallel 8-bit byte into a serial stream of bits to be sent
 *   over the `tx` line. It adds a start bit and a stop bit to the data.
 *
 * Parameters:
 *   - CLK_FREQ : Frequency of the system clock in Hz (default: 100MHz).
 *   - BAUD_RATE: Desired baud rate for UART communication (default: 9600).
 *
 * Inputs:
 *   - clk     : System clock.
 *   - rst     : Reset signal (Active High).
 *   - tx_start: Pulse high to initiate transmission of `tx_data`.
 *   - tx_data : 8-bit parallel data to be transmitted.
 *
 * Outputs:
 *   - tx_busy : High while transmission is in progress.
 *   - tx      : Serial data output line.
 */
module uart_tx #(
        parameter CLK_FREQ = 100_000_000, 
        parameter BAUD_RATE = 9600         
    ) (
        input clk,           
        input rst,           
        input tx_start,      
        input [7:0] tx_data,  
        output tx_busy,       
        output reg tx         
    );
    
    localparam BAUD_CNT_MAX = (CLK_FREQ / BAUD_RATE) - 1; 

    localparam [2:0] 
        IDLE  = 3'd0,
        START = 3'd1,
        DATA  = 3'd2,
        STOP  = 3'd3;

    reg [2:0] state = IDLE;
    reg [$clog2(BAUD_CNT_MAX):0] baud_cnt = 0; 
    reg [3:0] bit_cnt = 0;                    
    reg [7:0] data_reg = 0;                    

    wire baud_tick = (baud_cnt == BAUD_CNT_MAX);
    
    assign tx_busy = (state != IDLE);

    always @(posedge clk) begin
        if (rst) 
            begin
                state <= IDLE;
                tx    <= 1'b1; 
                baud_cnt <= 0;
                bit_cnt <= 0;
            end 
        else 
            begin
                if (state != IDLE) 
                    begin
                        if (baud_tick) 
                            baud_cnt <= 0;
                        else
                            baud_cnt <= baud_cnt + 1;
                    end 
                else 
                    begin
                        baud_cnt <= 0;
                    end
            
            case (state)
                IDLE: begin
                    tx <= 1'b1; 
                    if (tx_start) begin
                        data_reg <= tx_data; 
                        bit_cnt <= 0;
                        state <= START;       
                    end
                end

                START: begin
                    tx <= 1'b0; 
                    if (baud_tick) begin
                        state <= DATA;
                    end
                end

                DATA: begin
                    tx <= data_reg[0]; 
                    if (baud_tick) begin
                        data_reg <= data_reg >> 1; 
                        bit_cnt <= bit_cnt + 1;
                        
                        if (bit_cnt == 7) begin
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (baud_tick) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end
    
endmodule

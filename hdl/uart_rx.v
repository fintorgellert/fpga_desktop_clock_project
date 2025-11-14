`timescale 1ns / 1ps

//********************************************************************************//
//
// Module: uart_rx
//
// Description:
// This module implements a Universal Asynchronous Receiver-Transmitter (UART)
// receiver. It is designed to be highly configurable, with parameters for the
// clock frequency and baud rate. The receiver uses oversampling to reliably
// detect the start bit and sample the data bits. It performs basic error
// checking for the stop bit.
//
// Parameters:
//   CLK_FREQ:  The frequency of the input clock in Hz.
//   BAUD_RATE: The desired baud rate for the UART communication.
//
// Inputs:
//   clk:       The system clock.
//   rst:       Reset signal.
//   rx_in:     The serial data input line from the UART bus.
//
// Outputs:
//   rx_data:   The 8-bit received data byte.
//   rx_done:   A single-cycle pulse indicating that a byte has been successfully
//              received.
//   rx_error:  A flag that indicates a framing error (invalid stop bit).
//
//********************************************************************************//

module uart_rx #(
            parameter CLK_FREQ = 100_000_000,
            parameter BAUD_RATE = 9600
        )(
            input clk,
            input rst,
            input rx_in,       
            output reg [7:0] rx_data, 
            output reg rx_done,     
            output reg rx_error     
    );
    
    localparam OVERSAMPLE = 16; 
    localparam CLK_PER_OS = CLK_FREQ / (BAUD_RATE * OVERSAMPLE); 

    reg [15:0] os_counter = 0;
    reg os_tick = 0;

    always @(posedge clk) begin
        if (rst) begin
            os_counter <= 0;
            os_tick <= 0;
        end else begin
            if (os_counter == CLK_PER_OS - 1) begin
                os_counter <= 0;
                os_tick <= 1;
            end else begin
                os_counter <= os_counter + 1;
                os_tick <= 0;
            end
        end
    end

    localparam IDLE = 3'd0;
    localparam START_BIT = 3'd1;
    localparam DATA_BITS = 3'd2;
    localparam STOP_BIT = 3'd3;

    reg [2:0] state = IDLE;
    reg [3:0] bit_count = 0;
    reg [7:0] data_buffer = 0;
    reg [3:0] os_bit_count = 0; 

    reg rx_in_r = 1'b1;
    always @(posedge clk) rx_in_r <= rx_in;
    
    always @(posedge clk) begin
        rx_done <= 1'b0;
        rx_error <= 1'b0;

        if (rst) begin
            state <= IDLE;
        end else if (os_tick) begin
            case (state)
                IDLE: begin
                    if (rx_in_r == 1'b0) begin
                        state <= START_BIT;
                        os_bit_count <= 1;
                    end
                end
                
                START_BIT: begin
                    if (os_bit_count == OVERSAMPLE / 2) begin 
                        if (rx_in_r == 1'b0) begin 
                            state <= DATA_BITS;
                            os_bit_count <= 0;
                            bit_count <= 0;
                            data_buffer <= 0;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        os_bit_count <= os_bit_count + 1;
                    end
                end
                
                DATA_BITS: begin
                    if (os_bit_count == OVERSAMPLE - 1) begin
                        data_buffer <= {rx_in_r, data_buffer[7:1]};
                        os_bit_count <= 0;
                        if (bit_count == 7) begin
                            state <= STOP_BIT;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                    end else begin
                        os_bit_count <= os_bit_count + 1;
                    end
                end
                
                STOP_BIT: begin
                    if (os_bit_count == OVERSAMPLE - 1) begin
                        if (rx_in_r == 1'b1) begin
                            rx_data <= data_buffer;
                            rx_done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            rx_error <= 1'b1;
                            state <= IDLE;
                        end
                    end else begin
                        os_bit_count <= os_bit_count + 1;
                    end
                end
            endcase
        end
    end
endmodule

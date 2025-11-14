`timescale 1ns / 1ps

//********************************************************************************//
//
// Module: alarm_control
//
// Description:
// This module implements the logic for setting, managing, and displaying an
// alarm. It features a state machine to handle different modes of operation,
// including setting the alarm time via switches or UART, monitoring the
// current time to trigger the alarm, and controlling visual feedback through
// 7-segment displays and RGB LEDs.
//
// Inputs:
//   clk:                Global clock signal.
//   rst:                Global reset signal.
//   ent:                Enter button press signal.
//   ret:                Return button press signal.
//   bstep:              Backstep button press signal.
//   uart_alarm_hour:    Hour value for the alarm, received via UART.
//   uart_alarm_minute:  Minute value for the alarm, received via UART.
//   is_uart_set:        A flag indicating that a new alarm time has been
//                       received via UART.
//   sw:                 6-bit input from slide switches, used for setting
//                       the alarm time manually.
//   actual_hour:        Current hour from the main timekeeping module.
//   actual_min:         Current minute from the main timekeeping module.
//   actual_sec:         Current second from the main timekeeping module.
//
// Outputs:
//   segm:               8-bit output for the 7-segment display segments.
//   dign:               8-bit output for controlling the 7-segment display digits.
//   alm_set_done:       Indicates that the alarm has been successfully set.
//   is_alarm_going_off: Indicates that the alarm is currently triggered.
//   rgb_led_1:          3-bit output for the first RGB LED.
//   rgb_led_2:          3-bit output for the second RGB LED.
//
//********************************************************************************//

module alarm_control(
        input clk,
        input rst, ent, ret, bstep,
        input [4:0] uart_alarm_hour, 
        input [5:0] uart_alarm_minute,
        input is_uart_set,
        input [5:0] sw,
        input [4:0] actual_hour,
        input [5:0] actual_min, actual_sec,
        output [7:0] segm, dign,
        output alm_set_done,
        output is_alarm_going_off,
        output [2:0] rgb_led_1, rgb_led_2
    );
    
    parameter ALARM_SET_HOURS   = 4'b0000;
    parameter ALARM_SET_MINUTES = 4'b0001;
    parameter ALARM_SET_DONE    = 4'b0010;

    parameter ALARM_IDLE_MODE   = 4'b1000; 
    parameter ALARM_ACTIVE_MODE = 4'b1001; 
    parameter ALARM_WAKE_MODE   = 4'b1010;

    reg [3:0] alarm_state = ALARM_IDLE_MODE; 
    reg [3:0] set_state = ALARM_SET_HOURS;  
    
    wire ent_wake_off_pulse;
        
    wire is_alarm_going_off_w;

    wire is_alarm_time;
    
    wire [2:0] rgb_l_1, rbg_l_2;
    
    wire [31:0] hex; 
    wire [7:0] seg, dig;
    
    wire [3:0] ht, hu, mt, mu;

    reg [5:0] alm_min;
    reg [4:0] alm_hour;

    reg [5:0] display_min;
    reg [4:0] display_hour;
 
    assign alm_set_done = (set_state == ALARM_SET_DONE); 
    assign is_alarm_going_off = (alarm_state == ALARM_WAKE_MODE);
    
    assign is_alarm_time = (alarm_state == ALARM_ACTIVE_MODE) &&
                           (actual_hour == alm_hour) && 
                           (actual_min == alm_min) &&
                           (actual_sec == 6'd0);
                           
    assign ent_wake_off_pulse = (alarm_state == ALARM_WAKE_MODE) ? ent : 1'b0;
    
    always @(posedge clk)
        begin 
            if (rst) 
                begin
                    set_state   <= ALARM_SET_HOURS;
                    alarm_state <= ALARM_IDLE_MODE;
                    alm_hour    <= 4'd0; 
                    alm_min     <= 6'd0;
                end
                
            else if (is_alarm_time) begin
                alarm_state <= ALARM_WAKE_MODE;
            end
            
            else if (ent_wake_off_pulse) begin
                alarm_state <= ALARM_IDLE_MODE;
            end
          
            else if ((alarm_state == ALARM_IDLE_MODE) && ent) begin
                alarm_state <= ALARM_SET_HOURS;
                set_state   <= ALARM_SET_HOURS;
            end
            
            else if (is_uart_set) begin
                alm_hour <= uart_alarm_hour;
                alm_min  <= uart_alarm_minute;
                alarm_state <= ALARM_ACTIVE_MODE; 
            end
            
            else begin
                case (alarm_state)
                    
                    ALARM_IDLE_MODE: begin
                    end
                    
                    ALARM_SET_HOURS, ALARM_SET_MINUTES, ALARM_SET_DONE: begin
                       
                        if (ret) begin
                            alarm_state <= ALARM_IDLE_MODE; 
                            set_state   <= ALARM_SET_HOURS;
                        end
                        
                        else if (bstep)
                            begin
                                case (set_state)
                                    ALARM_SET_HOURS:   set_state <= ALARM_SET_HOURS;
                                    ALARM_SET_MINUTES: set_state <= ALARM_SET_HOURS;
                                    ALARM_SET_DONE:    set_state <= ALARM_SET_MINUTES;
                                endcase 
                            end
                            
                        else if (ent)
                            begin
                                case (set_state)
                                    ALARM_SET_HOURS: 
                                        begin
                                            alm_hour <= (sw[4:0] > 23) ? 23 : sw[4:0];
                                            set_state <= ALARM_SET_MINUTES;
                                        end
                                    ALARM_SET_MINUTES:
                                        begin
                                            alm_min  <= (sw[5:0] > 59) ? 59 : sw[5:0];
                                            set_state <= ALARM_SET_DONE;
                                        end
                                    ALARM_SET_DONE:
                                        begin 
                                            alarm_state <= ALARM_ACTIVE_MODE;
                                            set_state   <= ALARM_SET_HOURS; 
                                        end 
                                endcase 
                            end
                    end 
                    
                    ALARM_ACTIVE_MODE: begin
                        if (ret)
                            alarm_state <= ALARM_IDLE_MODE;
                    end
                    
                    ALARM_WAKE_MODE: begin
                    end
                    
                    default: alarm_state <= ALARM_IDLE_MODE;
                endcase
            end
        end
        
        
    reg [25:0] blink_cnt = 0;
    wire blink_enable;
    reg [7:0] dig_mask;

    always @(posedge clk) 
        begin
            blink_cnt <= blink_cnt + 1;
        end
    
    assign blink_enable = blink_cnt[25];

    always @(*)
        begin 
            if (alarm_state >= ALARM_SET_HOURS && alarm_state <= ALARM_SET_DONE) begin
                display_hour = alm_hour;
                display_min  = alm_min;
            end else begin
                display_hour = alm_hour;
                display_min  = alm_min;
            end
            
            dig_mask = 8'b11111111;
            
            if (alarm_state >= ALARM_SET_HOURS && alarm_state <= ALARM_SET_DONE) begin 
                case (set_state)
                    ALARM_SET_HOURS:
                        begin 
                            display_hour = (sw[4:0] > 23) ? 23 : sw[4:0]; 
                            
                            if (blink_enable)
                                dig_mask = 8'b11110011; 
                            else
                                dig_mask = 8'b11111111;
                        end
                    ALARM_SET_MINUTES: 
                        begin
                            display_min  = (sw[5:0]) > 59 ? 59 : sw[5:0];
                            
                            if (blink_enable)
                                dig_mask = 8'b11111100;
                            else
                                dig_mask = 8'b11111111;
                        end
                    default: dig_mask = 8'b11111111;
                endcase 
            end
        end
            
        hex7seg segdecoder ( 
            .val(hex), 
            .cclk(clk), 
            .rst(rst), 
            .seg(seg), 
            .dig(dig)
        );
    
        RGB_controller RGB_contoller(
            .GCLK(clk),
            .alarm_state_in(alarm_state), 
            .RGB_LED_1_O(rgb_led_1), 
            .RGB_LED_2_O(rgb_led_2)
        );
    
        assign mu = display_min % 10;
        assign mt = display_min / 10;
        assign hu = display_hour % 10;
        assign ht = display_hour / 10;
        
        assign hex = { 16'hFFFF, ht, hu, mt, mu };
        assign segm = seg;
        assign dign = ~(dig & dig_mask);
       
endmodule

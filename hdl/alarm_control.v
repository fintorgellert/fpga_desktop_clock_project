`timescale 1ns / 1ps

/*
 * Module: alarm_control
 * ---------------------
 * Purpose:
 *   Manages the Alarm Mode of the clock.
 *   Handles setting the alarm time (Hour, Minute) via buttons or UART.
 *   Compares the current time with the alarm time and triggers the alarm.
 *   Controls the 7-segment display and RGB LEDs during alarm configuration and activation.
 *
 * Inputs:
 *   - clk               : System clock.
 *   - rst               : Reset signal.
 *   - ent, ret, bstep   : Control buttons (Enter, Return, Back-step).
 *   - uart_alarm_hour   : Alarm hour received via UART.
 *   - uart_alarm_minute : Alarm minute received via UART.
 *   - is_uart_set       : Flag indicating if alarm was set via UART.
 *   - sw                : Switches for setting time values manually.
 *   - actual_hour       : Current clock hour.
 *   - actual_min        : Current clock minute.
 *   - actual_sec        : Current clock second.
 *
 * Outputs:
 *   - segm              : 7-segment display segments.
 *   - dign              : 7-segment display digits (anodes).
 *   - alm_set_done      : Flag indicating manual alarm setting is complete.
 *   - is_alarm_going_off: Signal indicating the alarm is currently triggering.
 *   - rgb_led_1         : Control for RGB LED 1.
 *   - rgb_led_2         : Control for RGB LED 2.
 */
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
    
    reg alm_set_done_flag;
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
    
    // Edge detection
    reg ent_prev, bstep_prev;
    wire ent_pulse, bstep_pulse;
    
    assign ent_pulse = ent && ~ent_prev;
    assign bstep_pulse = bstep && ~bstep_prev;
 
    assign alm_set_done = alm_set_done_flag;
    assign is_alarm_going_off = (alarm_state == ALARM_WAKE_MODE);
    
    assign is_alarm_time = (alarm_state == ALARM_ACTIVE_MODE) &&
                           (actual_hour == alm_hour) && 
                           (actual_min == alm_min) &&
                           (actual_sec == 6'd0);
                           
    assign ent_wake_off_pulse = (alarm_state == ALARM_WAKE_MODE) ? ent_pulse : 1'b0;
    
    always @(posedge clk)
        begin 
            if (rst) 
                begin
                    set_state   <= ALARM_SET_HOURS;
                    alarm_state <= ALARM_IDLE_MODE;
                    alm_hour    <= 4'd0; 
                    alm_min     <= 6'd0;
                    alm_set_done_flag <= 1'b0;
                    ent_prev <= 1'b0;
                    bstep_prev <= 1'b0;
                end
            else
                begin
                    // Store previous button states
                    ent_prev <= ent;
                    bstep_prev <= bstep;
                    
                    // Always clear the done flag after one cycle
                    alm_set_done_flag <= 1'b0;
                    
                    if (is_alarm_time) begin
                        alarm_state <= ALARM_WAKE_MODE;
                    end
                    
                    else if (ent_wake_off_pulse) begin
                        alarm_state <= ALARM_IDLE_MODE;
                    end
                  
                    else if ((alarm_state == ALARM_IDLE_MODE) && ent_pulse) begin
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
                                
                                else if (bstep_pulse)
                                    begin
                                        case (set_state)
                                            ALARM_SET_HOURS:   set_state <= ALARM_SET_HOURS;
                                            ALARM_SET_MINUTES: set_state <= ALARM_SET_HOURS;
                                            ALARM_SET_DONE:    set_state <= ALARM_SET_MINUTES;
                                        endcase 
                                    end
                                    
                                else if (ent_pulse)
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
                                                    alm_set_done_flag <= 1'b1;
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

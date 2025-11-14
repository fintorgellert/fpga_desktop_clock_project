`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.10.2025 21:56:29
// Design Name: 
// Module Name: alarm_control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


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

//module alarm_control(
//        input clk,
//        input rst, ent, ret, bstep,
//        input [4:0] uart_alarm_hour, 
//        input [5:0] uart_alarm_minute,
//        input is_uart_set,
//        input [5:0] sw,
//        input [4:0] actual_hour,
//        input [5:0] actual_min, actual_sec,
//        output [7:0] segm, dign,
//        output alm_set_done,
//        output is_alarm_going_off,
//        output [2:0] rgb_led_1, rgb_led_2
//    );
    
//    parameter HOURS   = 2'b00;
//    parameter MINUTES = 2'b01;
//    parameter DONE    = 2'b10;
        
//    reg alm_active = 1'b0;
//    reg wake_mode = 1'b0;
    
//    wire ent_wake_off_pulse;
    
//    reg done;
//    reg [1:0] state = HOURS;
    
//    wire is_alarm_going_off_w;
    
//    wire is_alarm_time;
    
//    wire [2:0] rgb_l_1, rbg_l_2;
    
//    wire [31:0] hex; 
//    wire [7:0] seg, dig;
    
//    wire [3:0] ht, hu, mt, mu;
    
//    reg [5:0] alm_min;
//    reg [4:0] alm_hour;

//    reg [5:0] display_min;
//    reg [4:0] display_hour;
    
//    assign alm_set_done = done;
    
//    assign is_alarm_time = (alm_active) &&
//                           (actual_hour == alm_hour) && 
//                           (actual_min == alm_min) &&
//                           (actual_sec == 6'd0);                      
    
//    always @(posedge clk) 
//        begin
//            if (is_alarm_time && alm_active && wake_mode == 1'b0) begin 
//                wake_mode <= 1'b1;
//            end 
            
//            else if (ent_wake_off_pulse) begin 
//                wake_mode <= 1'b0;
//                alm_active <= 1'b0;
//            end
//        end
          
//    always @(posedge clk)
//        begin 
//            if (rst) 
//                begin
//                    state <= HOURS;
//                    done <= 1'b0;
//                    alm_hour <= 4'd0; 
//                    alm_min  <= 6'd0;
//                    alm_active <= 1'b0;
//                    wake_mode <= 1'b0;
//                end
                
//            else if (ret)
//                 state <= HOURS;
                 
//            else if (bstep)
//                begin
//                    case (state)
//                        HOURS:   state <= HOURS;
//                        MINUTES: state <= HOURS;
//                        DONE:    state <= MINUTES;
//                    endcase 
//                end
            
//            else if (is_uart_set) begin
//                alm_hour <= uart_alarm_hour;
//                alm_min  <= uart_alarm_minute;
//                alm_active <= 1'b1;
//            end
                
//            else if (ent && wake_mode == 0)
//                begin
//                   case (state)
//                        HOURS: 
//                            begin
//                                alm_hour <= (sw[4:0] > 23) ? 23 : sw[4:0];
//                                state <= MINUTES;
//                            end
//                        MINUTES:
//                            begin
//                                alm_min  <= (sw[5:0] > 59) ? 59 : sw[5:0];
//                                state <= DONE;
//                            end
//                        DONE:
//                            begin 
//                                done  <= 1'b1;
//                                alm_active <= 1'b1;
//                                state <= HOURS;
//                            end 
//                    endcase 
//                end
            
//            else
//                done <= 1'b0;
                
//        end
        
        
//    reg [25:0] blink_cnt = 0;
//    wire blink_enable;
//    reg [7:0] dig_mask;

//    always @(posedge clk) 
//        begin
//            blink_cnt <= blink_cnt + 1;
//        end
    
//    assign blink_enable = blink_cnt[25];
        
//    always @(*)
//        begin 
//            display_hour = alm_hour;
//            display_min  = alm_min;
            
//            begin 
//                case (state)
//                    HOURS:
//                        begin 
//                            display_hour = (sw[4:0] > 23) ? 23 : sw[4:0]; 
                            
//                            if (blink_enable)
//                                dig_mask = 8'b11110011; 
//                            else
//                                dig_mask = 8'b11111111;  
//                        end
//                    MINUTES: 
//                        begin
//                            display_min  = (sw[5:0]) > 59 ? 59 : sw[5:0];
                            
//                            if (blink_enable)
//                                dig_mask = 8'b11111100; 
//                            else
//                                dig_mask = 8'b11111111;
//                        end
//                    default: dig_mask = 8'b11111111;
//                endcase 
//            end
//        end
            
//    // kijelzõ  meghajtó
//    hex7seg segdecoder ( 
//        .val(hex), 
//        .cclk(clk), 
//        .rst(rst), 
//        .seg(seg), 
//        .dig(dig)
//    );
        
//    RGB_controller RGB_contoller(
//        .GCLK(clk),
//        .alm_active(alm_active),
//        .wake_mode(wake_mode),
//        .RGB_LED_1_O(rgb_led_1), 
//        .RGB_LED_2_O(rgb_led_2)
//    );
    
//    assign mu = display_min % 10;
//    assign mt = display_min / 10;
//    assign hu = display_hour % 10;
//    assign ht = display_hour / 10;
    
//    assign hex = { 16'hFFFF, ht, hu, mt, mu };
//    assign segm = seg;
//    assign dign = ~(dig & dig_mask);
    
//    assign ent_wake_off_pulse = wake_mode ? ent : 1'b0;
//    assign is_alarm_going_off = wake_mode;
       
//endmodule
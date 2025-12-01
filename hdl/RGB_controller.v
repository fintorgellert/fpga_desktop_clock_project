`timescale 1ns / 1ps

/*
 * Module: RGB_controller
 * ----------------------
 * Purpose:
 *   Controls two RGB LEDs based on the current alarm state.
 *   It supports three modes:
 *     - IDLE: LEDs are off.
 *     - ACTIVE (Fading): LEDs cycle through colors (fading effect).
 *     - WAKE (Blinking): LEDs blink red.
 *
 * Inputs:
 *   - GCLK          : Global system clock.
 *   - alarm_state_in: The current state of the alarm (IDLE, ACTIVE, WAKE).
 *
 * Outputs:
 *   - RGB_LED_1_O   : 3-bit control signal for RGB LED 1 (Red, Green, Blue).
 *   - RGB_LED_2_O   : 3-bit control signal for RGB LED 2 (Red, Green, Blue).
 */
module RGB_controller (
        input  GCLK,  
        input  [3:0] alarm_state_in,  
        output reg [2:0] RGB_LED_1_O, 
        output reg [2:0] RGB_LED_2_O
    );
    
    parameter [7:0] MAX_BRIGHTNESS = 8'd4;
    
    parameter ALARM_IDLE_MODE   = 4'b1000; // IDLE/OFF 
    parameter ALARM_ACTIVE_MODE = 4'b1001; // FADING 
    parameter ALARM_WAKE_MODE   = 4'b1010; // BLINKING 

    localparam [7:0]  WINDOW       = 8'b11111111;
    localparam [19:0] DELTA_COUNT_MAX = 20'd1000000;
    localparam [8:0]  VAL_COUNT_MAX = 9'b101111111;

    reg [7:0]  windowcount = 8'd0;
    reg [19:0] deltacount  = 20'd0;
    reg [8:0]  valcount    = 9'd0;
    
    reg [7:0] incVal;
    reg [7:0] decVal;

    reg [7:0] redVal, greenVal, blueVal;
    reg [7:0] redVal2, greenVal2, blueVal2;
    
    reg [25:0] blink_counter = 0; 
    reg blink_enable = 1'b0;
    
    always @(posedge GCLK) begin
        if (windowcount < WINDOW)
            windowcount <= windowcount + 1;
        else
            windowcount <= 0;
    end

    always @(posedge GCLK) begin
        if (deltacount < DELTA_COUNT_MAX)
            deltacount <= deltacount + 1;
        else
            deltacount <= 0;
    end

    always @(posedge GCLK) begin
        if (deltacount == 0) begin
            if (valcount < VAL_COUNT_MAX)
                valcount <= valcount + 1;
            else
                valcount <= 0;
        end
    end

    always @(*) begin
        incVal = {1'b0, valcount[6:0]};
        decVal[7] = 1'b0;
        decVal[6:0] = ~valcount[6:0];
    end
    
    always @(posedge GCLK) begin
        if (blink_counter < 26'd50_000_000)  
            blink_counter <= blink_counter + 1;
        else begin
            blink_counter <= 0;
            blink_enable <= ~blink_enable; 
        end
    end

    always @(*) begin
        redVal   = 8'd0;
        greenVal = 8'd0;
        blueVal  = 8'd0;
        
        case (alarm_state_in)
            
            ALARM_WAKE_MODE: begin // BLINKING
                if (blink_enable)
                    begin
                        redVal   = 8'hFF;
                        greenVal = 8'd0;
                        blueVal  = 8'd0;
                    end
            end
            
            ALARM_ACTIVE_MODE: begin // FADING
                case (valcount[8:7])
                    2'b00: begin
                        redVal   = (incVal   > MAX_BRIGHTNESS) ? MAX_BRIGHTNESS : incVal;
                        greenVal = (decVal   > MAX_BRIGHTNESS) ? MAX_BRIGHTNESS : decVal;
                        blueVal  = 8'd0;
                    end
                    2'b01: begin
                        redVal   = (decVal   > MAX_BRIGHTNESS) ? MAX_BRIGHTNESS : decVal;
                        greenVal = 8'd0;
                        blueVal  = (incVal   > MAX_BRIGHTNESS) ? MAX_BRIGHTNESS : incVal;
                    end
                    default: begin
                        redVal   = 8'd0;
                        greenVal = (incVal   > MAX_BRIGHTNESS) ? MAX_BRIGHTNESS : incVal;
                        blueVal  = (decVal   > MAX_BRIGHTNESS) ? MAX_BRIGHTNESS : decVal;
                    end
                endcase 
            end
            
            default: begin 
            end
        endcase

        redVal2   = redVal;
        greenVal2 = greenVal;
        blueVal2  = blueVal;
    end

    always @(posedge GCLK) begin
        // RGB LED 1
        RGB_LED_1_O[2] <= (redVal   > windowcount);
        RGB_LED_1_O[1] <= (greenVal > windowcount);
        RGB_LED_1_O[0] <= (blueVal  > windowcount);

        // RGB LED 2
        RGB_LED_2_O[2] <= (redVal2   > windowcount);
        RGB_LED_2_O[1] <= (greenVal2 > windowcount);
        RGB_LED_2_O[0] <= (blueVal2  > windowcount);
    end

endmodule

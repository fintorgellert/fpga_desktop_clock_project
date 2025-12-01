`timescale 1ns / 1ps

module clock_project_top (
        input CLK100MHZ, 
        input btn_rst, btn_set, btn_alm, btn_ent, btn_ret, btn_bstep,
        input [5:0] SW,
        input  rx,
        output tx,
        output reg [7:0] a_to_g,
        output reg [7:0] an,
        output reg [5:0] LED,
        output [2:0] I_RGB_LED, II_RGB_LED
    );
    
    parameter CLOCK = 2'b00;
    parameter SET   = 2'b01;
    parameter ALARM = 2'b10;
    
    parameter IDLE     = 3'b000;
    parameter MONTHS   = 3'b001;
    parameter DAYS     = 3'b010;
    parameter HOURS    = 3'b011;
    parameter MINUTES  = 3'b100;
    parameter SECONDS  = 3'b101;
    
    parameter ALARM_HOURS    = 3'b110;
    parameter ALARM_MINUTES  = 3'b111;
    
    parameter TX_IDLE  = 3'b000;
    parameter TX_MARKER= 3'b001;
    parameter TX_TYPE  = 3'b110; // 0xB0, 0xB1, 0xB2, 0xB3, 0xB0 values
    parameter TX_VALUE = 3'b111;
   
    reg [1:0] mode = CLOCK;
    reg [1:0] next_mode = CLOCK;

    wire set_done, alm_set_done;
    wire is_alarm_going_off_w;
   
    wire [5:0] actual_min, actual_sec; 
    wire [4:0] actual_day, actual_hour;
    wire [3:0] actual_month;
    
    reg [3:0] month_reg = 4'd0;
    reg [4:0] day_reg   = 5'd0;
    reg [4:0] hour_reg  = 5'd0;
    reg [5:0] min_reg   = 6'd0;
    reg [5:0] sec_reg   = 6'd0;
    
    wire month_change = (actual_month != month_reg);
    wire day_change   = (actual_day   != day_reg);
    wire hour_change  = (actual_hour  != hour_reg);
    wire min_change   = (actual_min   != min_reg);
    wire sec_change   = (actual_sec   != sec_reg);
           
    reg is_uart_alarm_set = 1'b0;
    reg [4:0] uart_alarm_hour = 5'h00;
    reg [5:0] uart_alarm_minute = 6'h00;
           
    reg [3:0] new_month = 4'h00;
    reg [4:0] new_day   = 5'h00;
    reg [4:0] new_hour  = 5'h00;
    reg [5:0] new_minute= 8'h00;
    reg [5:0] new_second= 8'h00;
    
    reg [2:0] tx_state = TX_IDLE;
    reg [7:0] tx_type_r = 8'b0;
    reg [7:0] tx_value_r = 8'b0;
    reg uart_tx_start = 1'b0; 
    
    reg [7:0] uart_data_to_send;   
    wire uart_tx_busy;
    
    reg [2:0] uart_rx_state = IDLE; 
    reg uart_set_pulse = 1'b0;
 
    wire [7:0] rx_data;
    wire rx_data_valid;
        
    reg final_load_time_en;
    reg [3:0] final_load_month;
    reg [4:0] final_load_day;
    reg [4:0] final_load_hour;
    reg [5:0] final_load_min;
    reg [5:0] final_load_sec;
        
    wire [5:0] set_sec, set_min;
    wire [4:0] set_hour, set_day;
    wire [3:0] set_month;
    
    wire btn_set_d, btn_alm_d, btn_ent_d, btn_ret_d, btn_bstep_d;
    reg btn_rst_time, btn_ent_set, btn_rst_set, btn_bstep_set, btn_bstep_alm, btn_ent_alm, btn_rst_alm;
    
    wire [7:0] seg_time, seg_set, seg_alarm;
    wire [7:0] dig_time, dig_set, dig_alarm;
    wire [5:0] led_time, led_set, led_alarm;
    
    reg load_settings_reg = 1'b0;
 
    reg set_done_prev = 1'b0, alm_set_done_prev = 1'b0;
    wire set_done_pulse, alm_set_done_pulse; 

    assign set_done_pulse = set_done & ~set_done_prev; 
    assign alm_set_done_pulse = alm_set_done & ~alm_set_done_prev;
    
    assign load_time_en = load_settings_reg | uart_set_pulse;

    always @(posedge CLK100MHZ)        
        begin            
            set_done_prev <= set_done;
            alm_set_done_prev <= alm_set_done; 
            
            mode <= next_mode;
            
            if (set_done_pulse)
                load_settings_reg <= 1'b1;
            else 
                load_settings_reg <= 1'b0;
        end
        
    always @(*)
        begin
            next_mode     = mode;
            btn_rst_time  = 1'b0; 
            btn_ent_set   = 1'b0;
            btn_rst_set   = 1'b0;
            btn_bstep_set = 1'b0;
            btn_bstep_alm = 1'b0;
            
            final_load_time_en = load_settings_reg;
            final_load_month   = set_month;
            final_load_day     = set_day;
            final_load_hour    = set_hour;
            final_load_min     = set_min;
            final_load_sec     = set_sec;
            
            a_to_g = seg_time; 
            an     = dig_time;
            LED    = led_time;
            
            if (uart_set_pulse) begin
                final_load_time_en = 1'b1;
                
                final_load_month = new_month;
                final_load_day   = new_day;
                final_load_hour  = new_hour;
                final_load_min   = new_minute;
                final_load_sec   = new_second;
            end
    
            case (mode) 
                                
                CLOCK: begin
                    btn_rst_time  = ~btn_rst; 
                    
                    if (btn_set_d) 
                        next_mode = SET; 
                        
                    else if (btn_alm_d)
                        next_mode = ALARM; 
                    
                end
    
                SET: begin
                    btn_ent_set   = btn_ent_d;  
                    btn_rst_set   = ~btn_rst;    
                    btn_bstep_set = btn_bstep_d; 
                    
                    a_to_g = seg_set;
                    an     = dig_set;
                    LED    = led_set;
            
                    if (set_done_pulse) 
                        next_mode = CLOCK;
                         
                    else if (btn_ret_d) 
                        next_mode = CLOCK;
                        
                    // RST button always returns to CLOCK
                    else if (~btn_rst)
                        next_mode = CLOCK;
    
                end
    
                ALARM: begin
                    btn_bstep_alm = btn_bstep_d; 
                    btn_rst_alm   = ~btn_rst;
                    btn_ent_alm   = btn_ent_d;
                     
                    a_to_g = seg_alarm;
                    an     = dig_alarm;
                    LED    = 6'b0;
                    
                    if (alm_set_done_pulse) 
                        next_mode = CLOCK; 
                        
                    else if (btn_ret_d)
                        next_mode = CLOCK;
                        
                    // RST button always returns to CLOCK
                    else if (~btn_rst)
                        next_mode = CLOCK;
                end
                
                default: begin
                    next_mode = CLOCK;
                end
            endcase
        end
                    
    always @(posedge CLK100MHZ) 
        begin
            uart_set_pulse <= 1'b0;
            is_uart_alarm_set <= 1'b0;
            
            if (rx_data_valid) 
                begin
                                    
                    case (uart_rx_state)
                        
                        IDLE: begin
                            if (rx_data == 8'hAA) begin
                                uart_rx_state <= MONTHS;
                            end
                            
                            else if (rx_data == 8'hBB) begin 
                                uart_rx_state <= ALARM_HOURS;
                            end
                        end
                        
                        MONTHS: begin
                            if (rx_data >= 8'd1 && rx_data <= 8'd12) begin 
                                new_month <= rx_data;
                                uart_rx_state <= DAYS;
                            end else begin
                                uart_rx_state <= IDLE; 
                            end
                        end
                        
                        DAYS: begin 
                            if (rx_data >= 8'd1 && rx_data <= 8'd31) begin
                                new_day <= rx_data;
                                uart_rx_state <= HOURS;
                            end else begin
                                uart_rx_state <= IDLE; 
                            end
                        end
                        
                        HOURS: begin
                            if (rx_data < 8'd24) begin 
                                new_hour <= rx_data;
                                uart_rx_state <= MINUTES;
                            end else begin
                                uart_rx_state <= IDLE; 
                            end
                        end
                        
                        MINUTES: begin 
                            if (rx_data < 8'd60) begin
                                new_minute <= rx_data;
                                uart_rx_state <= SECONDS; 
                            end else begin
                                uart_rx_state <= IDLE; 
                            end
                        end
                        
                        SECONDS: begin
                            if (rx_data < 8'd60) begin
                                new_second <= rx_data;
                  
                                uart_set_pulse <= 1'b1;
                                uart_rx_state <= IDLE;
                            end else begin
                                uart_rx_state <= IDLE; 
                            end
                        end
                        
                        ALARM_HOURS: begin
                            if (rx_data < 8'd24) begin 
                                uart_alarm_hour <= rx_data;
                                uart_rx_state <= ALARM_MINUTES;
                            end else begin
                                uart_rx_state <= IDLE; 
                            end
                        end
                        
                        ALARM_MINUTES: begin
                            if (rx_data < 8'd60) begin 
                                uart_alarm_minute <= rx_data;
                                is_uart_alarm_set <= 1'b1;
                                uart_rx_state <= IDLE;
                            end else begin
                                uart_rx_state <= IDLE; 
                            end
                        end                        
                        default: uart_rx_state <= IDLE;
                    endcase
                end
        end
    
    always @(posedge CLK100MHZ) 
        begin
        
            if (~btn_rst) 
                begin
                    uart_tx_start <= 1'b0;
                    tx_state <= TX_IDLE;
                    month_reg <= 4'd0;
                    day_reg   <= 5'd0;
                    hour_reg  <= 5'd0;
                    min_reg   <= 6'd0;
                    sec_reg   <= 6'd0;
                end 
           else
                begin
                    if (~uart_tx_busy) begin 
                        case (tx_state)
                        
                            TX_IDLE: begin
                                if (month_change) begin
                                    tx_type_r <= 8'hB4; 
                                    tx_value_r <= {4'b0000, actual_month};
                                    tx_state <= TX_TYPE;
                                    month_reg <= actual_month;
                                end
                                else if (day_change) begin
                                    tx_type_r <= 8'hB3; 
                                    tx_value_r <= {3'b000, actual_day};
                                    tx_state <= TX_TYPE;
                                    day_reg <= actual_day;
                                end
                                else if (hour_change) begin
                                    tx_type_r <= 8'hB2; 
                                    tx_value_r <= {3'b000, actual_hour};
                                    tx_state <= TX_TYPE;
                                    hour_reg <= actual_hour;
                                end
                                else if (min_change) begin
                                    tx_type_r <= 8'hB1; 
                                    tx_value_r <= {2'b00, actual_min};
                                    tx_state <= TX_TYPE;
                                    min_reg <= actual_min;
                                end
                                else if (sec_change) begin
                                    tx_type_r <= 8'hB0; 
                                    tx_value_r <= {2'b00, actual_sec};
                                    tx_state <= TX_TYPE;
                                    sec_reg <= actual_sec;
                                end
                            end
                            
                            TX_TYPE: begin
                                uart_data_to_send <= tx_type_r;
                                uart_tx_start <= 1'b1;
                                tx_state <= TX_MARKER;
                            end
                            
                            TX_MARKER: begin
                                uart_data_to_send <= 8'hBE;
                                uart_tx_start <= 1'b1;
                                tx_state <= TX_VALUE;
                            end
                            
                            TX_VALUE: begin 
                                uart_data_to_send <= tx_value_r;
                                uart_tx_start <= 1'b1;
                                tx_state <= TX_IDLE;
                            end
        
                            default: tx_state <= TX_IDLE;
                        endcase
                    end
                else
                    uart_tx_start <= 1'b0;
            end
        end
        
 
    // Button debouncing
    debouncer enter_debouncer(.btn(btn_ent), .clk(CLK100MHZ), .d_btn(btn_ent_d));
    debouncer set_debouncer(.btn(btn_set), .clk(CLK100MHZ), .d_btn(btn_set_d));
    debouncer alarm_debouncer(.btn(btn_alm), .clk(CLK100MHZ), .d_btn(btn_alm_d));
    debouncer return_debouncer(.btn(btn_ret), .clk(CLK100MHZ), .d_btn(btn_ret_d));
    debouncer back_step_debouncer(.btn(btn_bstep), .clk(CLK100MHZ), .d_btn(btn_bstep_d));
    
   // Desktop clock 
    time_core time_core(
        .clk(CLK100MHZ),
        .rst(btn_rst_time),
        .load_settings(final_load_time_en), 
        .load_sec(final_load_sec),
        .load_min(final_load_min),
        .load_hour(final_load_hour),
        .load_day(final_load_day),
        .load_month(final_load_month),
        .actual_month(actual_month),
        .actual_day(actual_day),    
        .actual_hour(actual_hour),
        .actual_min(actual_min),
        .actual_sec(actual_sec),
        .segm(seg_time),
        .dign(dig_time),
        .led(led_time)
    );
    
    // Settings
    set_control set_control (
        .clk(CLK100MHZ), 
        .rst(btn_rst_set), 
        .ent(btn_ent_set),
        .ret(btn_ret_d),
        .bstep(btn_bstep_set),
        .is_alarm_going_off(is_alarm_going_off_w),
        .sw(SW),
        .segm(seg_set), 
        .dign(dig_set),
        .led(led_set),
        .set_done(set_done),
        .out_sec(set_sec),
        .out_min(set_min),
        .out_hour(set_hour),
        .out_day(set_day),
        .out_month(set_month)
    );
    
    // Alarm    
    alarm_control alarm_control(
        .clk(CLK100MHZ),
        .rst(btn_rst_alm), 
        .ent(btn_ent_alm),
        .ret(btn_ret_d),
        .bstep(btn_bstep_alm),
        .actual_hour(actual_hour),
        .actual_min(actual_min),
        .actual_sec(actual_sec),
        .uart_alarm_hour(uart_alarm_hour),
        .uart_alarm_minute(uart_alarm_minute),
        .is_uart_set(is_uart_alarm_set),
        .sw(SW),
        .segm(seg_alarm), 
        .dign(dig_alarm),
        .alm_set_done(alm_set_done),
        .is_alarm_going_off(is_alarm_going_off_w),
        .rgb_led_1(I_RGB_LED),
        .rgb_led_2(II_RGB_LED)
    );
    
    // Incoming UART data
    uart_rx #(
            .CLK_FREQ  (100_000_000),
            .BAUD_RATE (9600)
        ) uart_rx (
            .clk(CLK100MHZ),
            .rst(1'b0), 
            .rx_in(rx),           
            .rx_data(rx_data),       
            .rx_done(rx_data_valid)
    );
    
    // Outgoing UART data
    uart_tx #(
            .CLK_FREQ(100_000_000), 
            .BAUD_RATE(9600)
        ) uart_tx (
            .clk(CLK100MHZ),        
            .rst(~btn_rst),         
            .tx_start(uart_tx_start),
            .tx_data(uart_data_to_send),
            .tx_busy(uart_tx_busy),
            .tx(tx)                 
    );

endmodule

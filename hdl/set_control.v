`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.10.2025 21:55:45
// Design Name: 
// Module Name: set_control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: FIXED - Removed double edge detection, RST now resets immediately
// 
// Dependencies: 
// 
// Revision:
// Revision 0.02 - Fixed button handling
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module set_control(
        input clk,
        input rst, ent, ret, bstep,
        input is_alarm_going_off,
        input [5:0] sw,
        output [7:0] segm, dign,
        output [5:0] led,
        output set_done,
        output [5:0] out_sec,
        output [5:0] out_min,
        output [4:0] out_hour,
        output [4:0] out_day,
        output [3:0] out_month
    );

    parameter MONTHS  = 3'b000;
    parameter DAYS    = 3'b001;
    parameter HOURS   = 3'b010;
    parameter MINUTES = 3'b011;
    parameter SECONDS = 3'b100;
    parameter DONE    = 3'b101;
    
    reg done;
    reg [2:0] state = MONTHS;
    
    reg [5:0] set_sec, set_min;
    reg [4:0] set_hour, set_day;
    reg [3:0] set_month;
    
    reg [5:0] disp_sec, disp_min;
    reg [4:0] disp_hour, disp_day;
    reg [3:0] disp_month;
    
    wire [31:0] hex;
    wire [7:0] seg, dig;
    wire [3:0] mot, mou, dt, du, ht, hu, mit, miu;
    wire [5:0] seconds;

    always @(posedge clk)
        begin 
            if (rst) 
                begin
                    state <= MONTHS;
                    done  <= 0;
                    set_month <= 1; 
                    set_day <= 1;
                    set_hour <= 0; 
                    set_min <= 0; 
                    set_sec <= 0;
                end
            else 
                begin
                    // RST signal takes priority
                    if (ret)
                        state <= MONTHS;
                    
                    // Use debouncer output directly (already a pulse from debouncer)
                    else if (bstep) 
                        begin
                            case (state)
                                MONTHS:  state <= MONTHS;
                                DAYS:    state <= MONTHS;
                                HOURS:   state <= DAYS;
                                MINUTES: state <= HOURS;
                                SECONDS: state <= MINUTES;
                                DONE:    state <= SECONDS;
                            endcase
                        end            
                    
                    else if (ent && is_alarm_going_off == 0)
                        begin
                            case (state)
                                MONTHS: 
                                    begin 
                                        set_month <= sw[3:0];
                                        if (set_month > 12) 
                                            set_month <= 12;
                                        else if (set_month < 1) 
                                            set_month <= 1;
                                        state <= DAYS;
                                    end
                                                
                                DAYS: 
                                    begin
                                        set_day <= sw[4:0];
                                        if (set_day < 1) 
                                            set_day <= 1;
                                        else
                                            begin
                                                case (set_month)
                                                    // 31-day months
                                                    4'd1, 4'd3, 4'd5, 4'd7, 4'd8, 4'd10, 4'd12: 
                                                        set_day <= (set_day > 31) ? 31 : set_day;
                                                    
                                                    // 30-day months
                                                    4'd4, 4'd6, 4'd9, 4'd11: 
                                                        set_day <= (set_day > 30) ? 30 : set_day;
                                                    
                                                    // February
                                                    4'd2: 
                                                        set_day <= (set_day > 28) ? 28 : set_day;                      
                                                    default:
                                                        set_day <= (set_day > 28) ? 28 : set_day;
                                                endcase
                                            end
                                        state <= HOURS;
                                    end  
                                                        
                                HOURS: 
                                    begin 
                                        set_hour <= (sw[4:0] > 23) ? 23 : sw[4:0];
                                        state <= MINUTES;
                                    end
                                  
                                MINUTES: 
                                    begin
                                        set_min <= (sw[5:0] > 59) ? 59 : sw[5:0];
                                        state <= SECONDS;
                                    end
                                    
                                SECONDS: 
                                    begin
                                        set_sec <= (sw[5:0] > 59) ? 59 : sw[5:0];
                                        state <= DONE;
                                    end
                                    
                                DONE:
                                    begin
                                        done <= 1;
                                        state <= MONTHS;
                                    end
                            endcase 
                        end
                    else
                        done <= 0;
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
            disp_month = (set_month < 1) ? 1 : set_month; 
            disp_day   = (set_day < 1) ? 1 : set_day; 
            disp_hour  = set_hour;
            disp_min   = set_min;
            disp_sec   = set_sec;

            begin
                case (state)
                    MONTHS: 
                        begin
                            disp_month = sw[3:0];
                            if (disp_month > 12) disp_month = 12;
                            else if (disp_month < 1) disp_month = 1;
                            
                            if (blink_enable) dig_mask = 8'b00111111;
                            else dig_mask = 8'b11111111;
                        end
                    DAYS: 
                        begin
                            disp_day = sw[4:0];
                            if (disp_day < 1) disp_day = 1;
                            else
                                begin
                                    case (disp_month)
                                        4'd1, 4'd3, 4'd5, 4'd7, 4'd8, 4'd10, 4'd12: 
                                            disp_day = (disp_day > 31) ? 31 : disp_day;
                                        4'd4, 4'd6, 4'd9, 4'd11: 
                                            disp_day = (disp_day > 30) ? 30 : disp_day;
                                        4'd2: 
                                            disp_day = (disp_day > 28) ? 28 : disp_day;                      
                                        default:
                                            disp_day = (disp_day > 28) ? 28 : disp_day;
                                    endcase
                                end
                                
                            if (blink_enable) dig_mask = 8'b11001111;
                            else dig_mask = 8'b11111111;
                        end
            
                    HOURS: 
                        begin
                            disp_hour = (sw[4:0] > 23) ? 23 : sw[4:0]; 
                        
                            if (blink_enable) dig_mask = 8'b11110011;
                            else dig_mask = 8'b11111111;
                        end
                        
                    MINUTES: 
                        begin
                            disp_min = (sw[5:0] > 59) ? 59 : sw[5:0];
                        
                            if (blink_enable) dig_mask = 8'b11111100;
                            else dig_mask = 8'b11111111;
                        end
                        
                    SECONDS:
                        begin
                            disp_sec = (sw[5:0] > 59) ? 59 : sw[5:0];
                            
                            if (blink_enable) disp_sec = 6'b0;
                            else dig_mask = 8'b11111111; 
                        end
                    default: dig_mask = 8'b11111111;
                endcase 
            end
        end

        // Display driver
        hex7seg segdecoder ( 
            .val(hex), 
            .cclk(clk), 
            .rst(rst), 
            .seg(seg), 
            .dig(dig)
        );

        // LED display
        hexled seconds_display (
            .val(seconds),
            .rst(rst),
            .led(led)    
        );

        // Convert display values to segments
        assign miu = disp_min % 10;
        assign mit = disp_min / 10;
        assign hu  = disp_hour % 10;
        assign ht  = disp_hour / 10;
        assign du  = disp_day % 10;
        assign dt  = disp_day / 10;
        assign mou = disp_month % 10;
        assign mot = disp_month / 10;
        
        assign out_sec   = set_sec;
        assign out_min   = set_min;
        assign out_hour  = set_hour;
        assign out_day   = set_day;
        assign out_month = set_month;
        assign hex = { mot, mou, dt, du, ht, hu, mit, miu };
        assign segm = seg;
        assign dign = ~(dig & dig_mask);
        assign set_done = done;
        assign seconds  = disp_sec;
        
endmodule


/*`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.10.2025 21:55:45
// Design Name: 
// Module Name: set_control
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


module set_control(
        input clk,
        input rst, ent, ret, bstep,
        input is_alarm_going_off,
        input [5:0] sw,
        output [7:0] segm, dign,
        output [5:0] led,
        output set_done,
        output [5:0] out_sec,
        output [5:0] out_min,
        output [4:0] out_hour,
        output [4:0] out_day,
        output [3:0] out_month
    );

    parameter MONTHS  = 3'b000;
    parameter DAYS    = 3'b001;
    parameter HOURS   = 3'b010;
    parameter MINUTES = 3'b011;
    parameter SECONDS = 3'b100;
    parameter DONE    = 3'b101;
    
    reg done;
    reg [2:0] state = MONTHS;
    
    reg [5:0] set_sec, set_min;
    reg [4:0] set_hour, set_day;
    reg [3:0] set_month;
    
    reg [5:0] disp_sec, disp_min;
    reg [4:0] disp_hour, disp_day;
    reg [3:0] disp_month;
    
    wire [31:0] hex;
    wire [7:0] seg, dig;
    wire [3:0] mot, mou, dt, du, ht, hu, mit, miu;
    wire [5:0] seconds;

    // --- ÚJ RÉSZ: Élvezérlés változói ---
    reg ent_prev;   // Tárolja az ent elõzõ állapotát
    reg bstep_prev; // Tárolja a bstep elõzõ állapotát
    wire ent_pulse; // Ez lesz az 1 ciklusos impulzus
    wire bstep_pulse; 

    // Élvezérlés logikája: Csak akkor 1, ha most 1, de az elõzõ ciklusban 0 volt
    assign ent_pulse   = ent && ~ent_prev;
    assign bstep_pulse = bstep && ~bstep_prev;
    // ------------------------------------

    always @(posedge clk)
        begin 
            if (rst) 
                begin
                    state <= MONTHS;
                    done  <= 0;
                    set_month <= 1; set_day = 1;
                    set_hour <= 0; set_min <= 0; set_sec <= 0;
                    
                    // Reseteljük a prev változókat is
                    ent_prev <= 0;
                    bstep_prev <= 0;
                end
            else 
                begin
                    // Minden órajelciklusban elmentjük a gombok jelenlegi állapotát
                    ent_prev <= ent;
                    bstep_prev <= bstep;

                    if (ret)
                        state <= MONTHS;
                    
                    // bstep helyett bstep_pulse használata
                    else if (bstep_pulse) 
                        begin
                            case (state)
                                MONTHS:  state <= MONTHS;
                                DAYS:    state <= MONTHS;
                                HOURS:   state <= DAYS;
                                MINUTES: state <= HOURS;
                                SECONDS: state <= MINUTES;
                                DONE:    state <= SECONDS;
                            endcase
                        end            
                    
                    // ent helyett ent_pulse használata
                    else if (ent_pulse && is_alarm_going_off == 0)
                        begin
                            case (state)
                                MONTHS: 
                                    begin 
                                        set_month = sw[3:0];
                                        if (set_month > 12) set_month = 12;
                                        else if (set_month < 1) set_month = 1;
                                        state <= DAYS;
                                    end
                                                
                                DAYS: 
                                    begin
                                        set_day = sw[4:0];
                                        if (set_day < 1) set_day = 1;
                                        else
                                            begin
                                                case (set_month)
                                                    // 31 napos hónapok
                                                    4'd1, 4'd3, 4'd5, 4'd7, 4'd8, 4'd10, 4'd12: 
                                                        set_day = (set_day > 31) ? 31 : set_day;
                                                    
                                                    // 30 napos hónapok
                                                    4'd4, 4'd6, 4'd9, 4'd11: 
                                                        set_day = (set_day > 30) ? 30 : set_day;
                                                    
                                                    // Február (2)
                                                    4'd2: 
                                                        set_day = (set_day > 28) ? 28 : set_day;                      
                                                    default:
                                                        set_day = (set_day > 28) ? 28 : set_day;
                                                endcase
                                            end
                                        state <= HOURS;
                                    end  
                                                        
                                HOURS: 
                                    begin 
                                        set_hour = (sw[4:0] > 23) ? 23 : sw[4:0];
                                        state <= MINUTES;
                                    end
                                  
                                MINUTES: 
                                    begin
                                        set_min  = (sw[5:0] > 59) ? 59 : sw[5:0];
                                        state <= SECONDS;
                                    end
                                    
                                SECONDS: 
                                    begin
                                        set_sec  = (sw[5:0] > 59) ? 59 : sw[5:0];
                                        state <= DONE;
                                    end
                                DONE:
                                    begin
                                        done <= 1;
                                        state <= MONTHS;
                                    end
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
            disp_month = (set_month < 1) ? 1 : set_month; 
            disp_day   = (set_day < 1) ? 1 : set_day; 
            disp_hour  = set_hour;
            disp_min   = set_min;
            disp_sec   = set_sec;

            begin
                case (state)
                    MONTHS: 
                        begin
                            disp_month = sw[3:0];
                            if (disp_month > 12) disp_month = 12;
                            else if (disp_month < 1) disp_month = 1;
                            
                            if (blink_enable) dig_mask = 8'b00111111;
                            else dig_mask = 8'b11111111;
                        end
                    DAYS: 
                        begin
                            disp_day = sw[4:0];
                            if (disp_day < 1) disp_day = 1;
                            else
                                begin
                                    case (disp_month)
                                        4'd1, 4'd3, 4'd5, 4'd7, 4'd8, 4'd10, 4'd12: 
                                            disp_day = (disp_day > 31) ? 31 : disp_day;
                                        4'd4, 4'd6, 4'd9, 4'd11: 
                                            disp_day = (disp_day > 30) ? 30 : disp_day;
                                        4'd2: 
                                            disp_day = (disp_day > 28) ? 28 : disp_day;                      
                                        default:
                                            disp_day = (disp_day > 28) ? 28 : disp_day;
                                    endcase
                                end
                                
                            if (blink_enable) dig_mask = 8'b11001111;
                            else dig_mask = 8'b11111111;
                        end
            
                    HOURS: 
                        begin
                            disp_hour = (sw[4:0] > 23) ? 23 : sw[4:0]; 
                        
                            if (blink_enable) dig_mask = 8'b11110011;
                            else dig_mask = 8'b11111111;
                        end
                        
                    MINUTES: 
                        begin
                            disp_min = (sw[5:0] > 59) ? 59 : sw[5:0];
                        
                            if (blink_enable) dig_mask = 8'b11111100;
                            else dig_mask = 8'b11111111;
                        end
                        
                    SECONDS:
                        begin
                            disp_sec = (sw[5:0] > 59) ? 59 : sw[5:0];
                            
                            if (blink_enable) disp_sec = 6'b0;
                            else dig_mask = 8'b11111111; 
                        end
                    default: dig_mask = 8'b11111111;
                endcase 
            end
        end

        // kijelzõ meghajt 
        hex7seg segdecoder ( 
            .val(hex), 
            .cclk(clk), 
            .rst(rst), 
            .seg(seg), 
            .dig(dig)
        );

        // led kapcsolás
        hexled seconds_display (
            .val(seconds),
            .rst(rst),
            .led(led)    
        );

        // segmensek létrehozása számokból
        assign miu = disp_min % 10;
        assign mit = disp_min / 10;
        assign hu  = disp_hour % 10;
        assign ht  = disp_hour / 10;
        assign du  = disp_day % 10;
        assign dt  = disp_day / 10;
        assign mou = disp_month % 10;
        assign mot = disp_month / 10;
        
        assign out_sec   = set_sec;
        assign out_min   = set_min;
        assign out_hour  = set_hour;
        assign out_day   = set_day;
        assign out_month = set_month;
        assign hex = { mot, mou, dt, du, ht, hu, mit, miu };
        assign segm = seg;
        assign dign = ~(dig & dig_mask);
        assign set_done = done;
        assign seconds  = disp_sec;
        
endmodule
*/
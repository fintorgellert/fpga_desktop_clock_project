# FPGA Clock Project

A comprehensive digital clock and alarm system implemented on the Nexys 4 DDR FPGA board. This project features real-time clock functionality, alarm capability, RGB LED indicators, 7-segment display output, and bidirectional UART communication with a PC application for monitoring and configuration.

## Project Overview

This project implements a complete timekeeping system with the following capabilities:

- **Real-time clock display** showing month, day, hour, minute, and second
- **Alarm clock functionality** with customizable hour and minute
- **Three alarm states**: idle (off), active (monitoring), and wake (triggering)
- **RGB LED indicators** providing visual feedback for alarm status
- **7-segment display** for viewing and setting time values
- **Three operational modes**: Clock display, Time/Date setting, and Alarm configuration
- **UART interface** for remote time synchronization and alarm setting from a PC application
- **Button-based user interface** for manual configuration

## Hardware Requirements

- **Nexys 4 DDR FPGA Board** with Artix-7 FPGA
- **100 MHz clock** input
- **6 push buttons** for user interaction
- **6 toggle switches** for value input
- **6 standard LEDs** for status indication
- **2 RGB LEDs** for alarm state visualization
- **8 7-segment display digits** for time/date display
- **USB-UART interface** for PC communication

## Project Structure

```
project_root/
├── constraints/
│   └── Nexys-4-DDR-Master.xdc       # FPGA pin constraints
├── hdl/                              # Verilog HDL source files
│   ├── clock_project_top.v          # Top-level module
│   ├── time_core.v                  # Core timekeeping logic
│   ├── set_control.v                # Time/date setting interface
│   ├── alarm_control.v              # Alarm management
│   ├── RGB_controller.v             # RGB LED control
│   ├── bcd_unit_counter.v           # BCD counter for seconds/minutes/hours
│   ├── day_counter.v                # Day and month counter
│   ├── hex7seg.v                    # 7-segment display decoder
│   ├── hexled.v                     # LED display driver
│   ├── debouncer.v                  # Button debouncing
│   ├── rategen.v                    # Timing rate generator
│   ├── uart_rx.v                    # UART receiver
│   └── uart_tx.v                    # UART transmitter
└── python_app/
    └── dual_mode_uart.py            # PC monitoring/control application
```

## Hardware Pin Mapping

### Clock and Control Signals
- **CLK100MHZ**: Pin E3 (100 MHz system clock)

### Buttons
- **btn_rst**: Pin C12 (Reset)
- **btn_set**: Pin M18 (Set mode)
- **btn_alm**: Pin M17 (Alarm mode)
- **btn_ent**: Pin N17 (Enter/Confirm)
- **btn_ret**: Pin P17 (Return/Cancel)
- **btn_bstep**: Pin P18 (Back/Step)

### Switches
- **SW[0:5]**: Pins J15, L16, M13, R15, R17, T18 (Value input)

### Standard LEDs
- **LED[0:5]**: Pins H17, K15, J13, N14, R18, V17

### RGB LEDs
- **I_RGB_LED[0:2]**: Pins G14, R11, N16 (Red, Green, Blue)
- **II_RGB_LED[0:2]**: Pins R12, M16, N15 (Red, Green, Blue)

### 7-Segment Display
- **a_to_g[0:7]**: Pins L18, T11, P15, K13, K16, R10, T10, H15 (Segments a-h)
- **an[0:7]**: Pins J17, J18, T9, J14, P14, T14, K2, U13 (Digit enables)

### UART Interface
- **rx**: Pin C4 (UART receive)
- **tx**: Pin D4 (UART transmit)

## Mode of Operation

### Clock Mode (Default)
Displays current date and time on the 7-segment display. Press **btn_set** to enter time-setting mode or **btn_alm** to enter alarm configuration mode.

### Time/Date Setting Mode
Allows manual configuration of month, day, hour, minute, and second using switch inputs and button navigation. The currently-selected field blinks on the display. Use **btn_bstep** to move backward, **btn_ent** to confirm and advance, and **btn_ret** to cancel.

### Alarm Configuration Mode
Set the alarm hour and minute using switches. The display shows the alarm time with the active field blinking. Confirm with **btn_ent** to activate the alarm, or press **btn_ret** to return to clock mode.

### Alarm States

**IDLE (0x8)**: Alarm is off. Press **btn_ent** in clock mode to enter alarm setting.

**ACTIVE (0x9)**: Alarm is set and monitoring. RGB LEDs display a smooth color-fading animation.

**WAKE (0xA)**: Alarm has triggered. RGB LEDs blink red. Press **btn_ent** to dismiss and return to idle.

## RGB LED Behavior

- **Idle Mode**: LEDs off
- **Active Mode**: Smooth color fading cycle (red → yellow → cyan → green → magenta → blue)
- **Wake Mode**: Red blinking

## Communication Protocol

### UART Configuration
- **Baud Rate**: 9600
- **Data Bits**: 8
- **Stop Bits**: 1
- **Parity**: None

### PC to FPGA (Clock Setting)
```
Byte 0: 0xAA (marker)
Byte 1: Month (1-12)
Byte 2: Day (1-31)
Byte 3: Hour (0-23)
Byte 4: Minute (0-59)
Byte 5: Second (0-59)
```

### PC to FPGA (Alarm Setting)
```
Byte 0: 0xBB (marker)
Byte 1: Hour (0-23)
Byte 2: Minute (0-59)
```

### FPGA to PC (Status Update)
```
Byte 0: Type indicator (0xB0-0xB4)
         0xB0: Second, 0xB1: Minute, 0xB2: Hour,
         0xB3: Day, 0xB4: Month
Byte 1: Value (appropriate range for type)
```

The FPGA automatically transmits updated time values whenever they change, allowing the PC application to remain synchronized with the board's clock.

## Python PC Application

The `dual_mode_uart.py` application provides a graphical interface for monitoring and configuring the FPGA clock.

### Features
- Real-time time and date display synchronized with FPGA
- Manual time setting with validation
- Automatic PC time synchronization
- Alarm configuration interface
- Connection status monitoring
- Dark-themed modern UI

### Requirements
- Python 3.6+
- tkinter (usually included with Python)
- pyserial

### Installation
```bash
pip install pyserial
```

### Running the Application
```bash
python dual_mode_uart.py
```

Update the `COM_PORT` variable in the script to match your system's serial port.

## Design Highlights

### Time Management
The system maintains accurate time through a cascading counter architecture:
- **Seconds counter**: 0-59, incremented by 1 Hz rate generator
- **Minutes counter**: 0-59, incremented when seconds reaches 59
- **Hours counter**: 0-23, incremented when minutes reaches 59
- **Day counter**: Handles months with 28, 30, or 31 days
- **Month counter**: 1-12, rolls over to January after December

### Debouncing
All buttons are debounced to filter out mechanical contact noise, ensuring reliable input detection.

### Display Multiplexing
The 7-segment display uses high-speed multiplexing to display all 8 digits, creating the illusion of simultaneous illumination while reducing power consumption.

### PWM-based RGB Control
RGB LEDs use PWM (pulse-width modulation) to achieve color mixing and brightness control, enabling smooth fading animations and blinking effects.

## Compilation and Deployment

1. Open the project in Xilinx Vivado
2. Add the constraint file (`Nexys-4-DDR-Master.xdc`) to the project
3. Add all Verilog files from the `hdl/` directory to the project
4. Run synthesis and implementation
5. Generate the bitstream
6. Program the FPGA using the JTAG interface

## Testing and Verification

- Verify button inputs respond correctly in each mode
- Test time advancement and overflow (seconds → minutes, minutes → hours, etc.)
- Confirm alarm triggers at the configured time
- Validate UART communication by monitoring the PC application
- Test RGB LED color animations and blinking patterns
- Verify 7-segment display multiplexing shows all digits correctly

## Future Enhancements

- Battery-backed real-time clock (RTC) for power-loss retention
- Snooze functionality for alarm dismissal
- Multiple alarm configurations
- Temperature display integration
- Wireless connectivity for remote monitoring
- Timer and stopwatch functions

## License

[Add appropriate license information here]

## Author

[Add author information here]
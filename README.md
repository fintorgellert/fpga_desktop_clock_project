# FPGA Desktop Clock Project

## Overview

This project implements a multi-functional desktop clock on an FPGA, featuring a Python-based GUI for advanced control and monitoring. The clock provides timekeeping (hours, minutes, seconds, day, month), an alarm, and visual feedback through 7-segment displays and RGB LEDs. The system is designed to be highly interactive, allowing users to set the time and alarm both manually on the FPGA board and remotely via the Python application.

## Features

- **Time and Date Display**: The clock displays the current time (HH:MM) and date (Month Day) on an 8-digit 7-segment display.
- **Manual and UART Control**: The time and alarm can be set using the buttons and switches on the FPGA board or through the Python GUI, which communicates with the FPGA over UART.
- **Alarm Functionality**: A configurable alarm can be set, which triggers a visual alert on the RGB LEDs.
- **Python GUI**: A user-friendly desktop application for monitoring the clock, setting the time, and configuring the alarm. It also provides a feature to sync the FPGA clock with the PC's time.
- **Visual Feedback**: Onboard LEDs are used to display the seconds, and RGB LEDs provide a visual indicator for the alarm status.

## Repository Structure

```
.
├── constraints/
│   └── Nexys-4-DDR-Master.xdc  # Constraints file for the Nexys 4 DDR board
├── hdl/
│   ├── RGB_controller.v        # Controls the RGB LEDs for the alarm
│   ├── alarm_control.v         # Manages the alarm logic
│   ├── bcd_unit_counter.v      # A generic BCD counter
│   ├── clock_project_top.v     # The top-level Verilog module
│   ├── day_counter.v           # A specialized counter for days of the month
│   ├── debouncer.v             # A simple button debouncer
│   ├── hex7seg.v               # Drives the 7-segment display
│   ├── hexled.v                # Drives the onboard LEDs
│   ├── rategen.v               # Generates a 1 Hz signal from the 100MHz clock
│   ├── set_control.v           # Manages the logic for setting the time
│   ├── time_core.v             # The core timekeeping module
│   ├── uart_rx.v               # UART receiver module
│   └── uart_tx.v               # UART transmitter module
├── python_app/
│   └── dual_mode_uart.py       # The Python GUI application
└── README.md
```

## Setup and Usage

### Prerequisites

- **Hardware**: A Xilinx FPGA board (the project is configured for a Nexys 4 DDR).
- **Software**:
    - Xilinx Vivado for synthesizing and implementing the Verilog code.
    - Python 3 with the `pyserial` and `tkinter` libraries installed.

### Hardware Setup

1. Clone the repository to your local machine.
2. Open the project in Xilinx Vivado.
3. Synthesize and implement the design.
4. Generate the bitstream and program the FPGA board.

### Python Application Setup

1. Navigate to the `python_app` directory.
2. Install the required Python libraries:
   ```bash
   pip install pyserial
   ```
3. Run the application:
   ```bash
   python dual_mode_uart.py
   ```

### Usage

#### On the FPGA Board

- **Setting the Time**:
  1. Press the "set" button to enter time-setting mode.
  2. Use the slide switches to set the month, then press "enter".
  3. Repeat for the day, hour, minute, and second.
  4. The clock will start running with the new time.
- **Setting the Alarm**:
  1. Press the "alarm" button to enter alarm-setting mode.
  2. Use the slide switches to set the hour, then press "enter".
  3. Repeat for the minute.

#### Python GUI

- **Monitoring**: The main screen of the application displays the current time and date received from the FPGA.
- **Setting the Time**:
  1. Click "Open Settings Panel".
  2. You can either set the time manually using the spinboxes or sync it with your PC's time.
- **Setting the Alarm**:
  1. In the settings panel, you can set the alarm time and enable/disable it.

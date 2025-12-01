# FPGA Desktop Clock with Python Control

A digital desktop clock implementation for the **Nexys 4 DDR** FPGA board (Artix-7), featuring a companion Python GUI application for time synchronization and alarm management via UART.

## Overview

This project implements a fully functional digital clock on an FPGA. It displays the date and time on the 7-segment display and uses LEDs for additional status. The clock includes an alarm feature and can be controlled manually via buttons on the board or remotely through a Python application running on a PC.

### Features

*   **FPGA Hardware (Verilog)**:
    *   Real-time clock (Seconds, Minutes, Hours, Days, Months).
    *   State machine control: Clock Mode, Setting Mode, Alarm Mode.
    *   Multiplexed 8-digit 7-segment display driver.
    *   UART Receiver/Transmitter (9600 baud) for PC communication.
    *   RGB LED control for alarm status (Fading/Blinking effects).
    *   Debounced button inputs.

*   **Software (Python)**:
    *   GUI Application (Tkinter).
    *   Automatic time synchronization with PC.
    *   Manual time setting interface.
    *   Alarm configuration.
    *   Real-time monitoring of FPGA clock status.

## Hardware Requirements

*   **Digilent Nexys 4 DDR** FPGA Board (Xilinx Artix-7 XC7A100T).
*   Micro-USB cable for programming and serial communication (UART).

## Software Requirements

*   **Xilinx Vivado** (for synthesizing and programming the FPGA).
*   **Python 3.6+**.
*   **pyserial** library.

## Directory Structure

*   `hdl/`: Contains all Verilog source files (`.v`).
    *   `clock_project_top.v`: Top-level module.
    *   `time_core.v`: Main time-keeping logic.
    *   `uart_rx.v` / `uart_tx.v`: Serial communication modules.
    *   ... and other support modules.
*   `python_app/`: Contains the Python GUI application.
    *   `dual_mode_uart.py`: Main application script.
*   `constraints/`: Contains the physical constraints file.
    *   `Nexys-4-DDR-Master.xdc`: Pin mappings for the board.

## Setup and Usage

### 1. FPGA Setup

1.  Open **Vivado**.
2.  Create a new project targeting the **Nexys 4 DDR** (Part: `xc7a100tcsg324-1`).
3.  Add all files from the `hdl/` directory as Design Sources.
4.  Add `constraints/Nexys-4-DDR-Master.xdc` as the Constraints file.
5.  Run **Synthesis**, **Implementation**, and **Generate Bitstream**.
6.  Connect the Nexys 4 DDR board via USB.
7.  Open **Hardware Manager** and program the device with the generated bitstream.

### 2. Python App Setup

1.  Ensure Python 3 is installed.
2.  Install the required dependency:
    ```bash
    pip install pyserial
    ```
3.  Check which COM port your Nexys 4 DDR is connected to (e.g., `COM3` on Windows, `/dev/ttyUSB1` on Linux).
4.  Edit `python_app/dual_mode_uart.py` and update the `COM_PORT` variable if necessary (default is often `COM11` or similar, check your system).
    ```python
    COM_PORT = 'COM3' # Example
    ```

### 3. Running the System

1.  **Start the FPGA**: Once programmed, the clock should start running (defaulting to 00:00:00).
2.  **Start the App**:
    ```bash
    python python_app/dual_mode_uart.py
    ```
3.  **Sync Time**:
    *   In the Python app, click **"Open Settings Panel"**.
    *   Under "Automatic PC Time Sync", click **"Sync PC Time Now and Return"**.
    *   The FPGA clock should instantly jump to match your computer's time.
4.  **Set Alarm**:
    *   In the Settings Panel, enter an Hour and Minute under "Alarm Clock Setting".
    *   Click **"Set Alarm and Return"**.
    *   When the time is reached, the FPGA's RGB LEDs will flash/fade to indicate the alarm.

## Usage on Board (Manual Control)

*   **BtnC (Center)**: Reset / Mode Select (depending on state).
*   **BtnU (Up)**: Enter Setting Mode.
*   **BtnD (Down)**: Enter Alarm Mode.
*   **BtnR (Right)**: Enter / Confirm.
*   **BtnL (Left)**: Return / Cancel.
*   **Switches [5:0]**: Adjust values in Setting/Alarm modes.

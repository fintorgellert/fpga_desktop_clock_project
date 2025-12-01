import tkinter as tk
from tkinter import messagebox, ttk
from datetime import datetime
import serial
import serial.tools.list_ports
import threading
import time
import calendar
import logging
import queue

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

COM_PORT = 'COM11'
BAUD_RATE = 9600

TYPE_SECOND = 0xB0
TYPE_MINUTE = 0xB1
TYPE_HOUR = 0xB2
TYPE_DAY = 0xB3
TYPE_MONTH = 0xB4

VALID_TYPES = {TYPE_SECOND, TYPE_MINUTE, TYPE_HOUR, TYPE_DAY, TYPE_MONTH}


class FpgaClockApp:
    """A Tkinter application for monitoring and setting an FPGA-based clock.

    This class encapsulates the entire functionality of the GUI application,
    including serial communication with the FPGA, displaying the time and date,
    and providing a user interface for setting the time and an alarm.
    """
    MONTH_NAMES = {
        1: "January", 2: "February", 3: "March", 4: "April", 5: "May", 6: "June",
        7: "July", 8: "August", 9: "September", 10: "October", 11: "November", 12: "December"
    }

    def __init__(self, master):
        """Initializes the FpgaClockApp.

        Args:
            master: The root Tkinter window.
        """
        self.master = master
        master.title("FPGA Clock Monitor & Setter")
        master.geometry("800x600")
        master.resizable(False, False)

        self.ser = None
        self.is_serial_open = False
        self.read_thread = None
        self.running = True
        self.is_setting_mode = False
        self.serial_queue = queue.Queue()

        now = datetime.now()
        self.time_data = {
            TYPE_MONTH: now.month,
            TYPE_DAY: now.day,
            TYPE_HOUR: now.hour,
            TYPE_MINUTE: now.minute,
            TYPE_SECOND: now.second,
        }
        self.current_year = now.year

        self.time_str = tk.StringVar(value="--:--:--")
        self.date_str = tk.StringVar(value="-- --.")
        self.status_str = tk.StringVar(value=f"Connecting to {COM_PORT}...")
        self.alarm_hour = tk.IntVar(value=8)
        self.alarm_minute = tk.IntVar(value=30)
        self.alarm_enabled = tk.BooleanVar(value=False)

        self.main_frame = tk.Frame(master)
        self.setting_frame = tk.Frame(master)

        self.vcmd_int = master.register(self._validate_int_wrapper)

        self.create_styles()
        self.create_main_monitor(self.main_frame)
        self.create_settings_panel(self.setting_frame)
        self.main_frame.pack(fill='both', expand=True)

        self.open_serial_port()

        self.master.after(50, self.check_serial_queue)

        master.protocol("WM_DELETE_WINDOW", self.on_closing)

        master.geometry("1024x720")

    def create_styles(self):
        """Creates and configures the ttk styles for the application.

        This method defines custom styles for buttons, frames, and labels used
        throughout the application to ensure a consistent dark theme.
        """
        style = ttk.Style()
        self.master.config(bg="#1E1E1E")
        style.theme_use('default')

        style.configure('Dark.TFrame', background='#1E1E1E')
        style.configure('Custom.TButton', font=('Inter', 12, 'bold'), padding=10,
                        background='#3498db', foreground='white', relief='flat')
        style.map('Custom.TButton', background=[('active', '#2980b9')])
        style.configure('Secondary.TButton', font=('Inter', 11), padding=8,
                        background='#2c3e50', foreground='#ecf0f1', relief='flat')
        style.map('Secondary.TButton', background=[('active', '#34495e')])
        style.configure('Alarm.TRadiobutton', background='#2c3e50', foreground='#ecf0f1',
                        font=('Inter', 11))
        style.map('Alarm.TRadiobutton', background=[('active', '#34495e')])
        style.configure('Small.Custom.TButton', font=('Inter', 11, 'bold'), padding=8,
                        background='#3498db', foreground='white', relief='flat')
        style.map('Small.Custom.TButton', background=[('active', '#2980b9')])
        style.configure('Panel.Header.TLabel', font=('Inter', 14, 'bold', 'underline'), background='#2c3e50',
                        foreground='#ecf0f1')

        style.configure('Return.TButton', font=('Inter', 14, 'bold'), padding=5,
                        background='#1E1E1E', foreground='#ecf0f1', relief='flat')
        style.map('Return.TButton', background=[('active', '#34495e')])

    def show_frame(self, frame_to_show):
        """Shows the specified frame and hides the others.

        Args:
            frame_to_show: The Tkinter frame to be displayed.
        """
        self.main_frame.pack_forget()
        self.setting_frame.pack_forget()
        frame_to_show.pack(fill='both', expand=True)


    def open_serial_port(self):
        """Opens the serial port and starts the reader thread."""
        try:
            ports = [p.device for p in serial.tools.list_ports.comports()]
            if COM_PORT not in ports:
                raise serial.SerialException(f"Port {COM_PORT} not found. Available: {ports or 'None'}")
            self.ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=0.01)
            self.is_serial_open = True
            self.status_str.set(f"Connected to {COM_PORT} @ {BAUD_RATE}")
            logging.info(f"Connected to {COM_PORT}")
            self.read_thread = threading.Thread(target=self.serial_reader_loop, daemon=True)
            self.read_thread.start()
        except serial.SerialException as e:
            self.is_serial_open = False
            err = f"Error opening {COM_PORT}: {e}"
            self.status_str.set(err)
            logging.error(err)
            messagebox.showerror("Serial Error", err)

    def serial_reader_loop(self):
        """Continuously reads from the serial port in a separate thread."""
        BUFFER = b''
        while self.running and self.is_serial_open:
            if self.is_setting_mode:
                time.sleep(0.01)
                continue
            try:
                if self.ser.in_waiting > 0:
                    raw_data = self.ser.read(self.ser.in_waiting)
                    if raw_data:
                        logging.info(f"RAW RX: {raw_data}")
                        BUFFER += raw_data
                while len(BUFFER) >= 2:
                    type_byte = BUFFER[0]
                    value_byte = BUFFER[1]
                    if type_byte in VALID_TYPES:
                        BUFFER = BUFFER[2:]
                        try:
                            self.serial_queue.put_nowait((type_byte, value_byte))
                            logging.info(f"DATA DECODED: Type={hex(type_byte)}, Value={value_byte}")
                        except queue.Full:
                            logging.warning("Serial queue is full, dropping data.")
                    else:
                        logging.warning(
                            f"SYNC ERROR: Unknown TYPE byte {hex(type_byte)} received. Dropping first byte.")
                        BUFFER = BUFFER[1:]
            except Exception as e:
                if self.running:
                    logging.error(f"Serial read error: {e}")
                time.sleep(0.01)
                continue
            time.sleep(0.005)

    def check_serial_queue(self):
        """Checks the serial queue for new data and updates the display.

        This method is called periodically by the Tkinter main loop. It polls
        the thread-safe queue for data received from the serial thread and
        updates the application's internal time state.
        """
        data_processed = False
        while not self.serial_queue.empty():
            try:
                type_byte, value_byte = self.serial_queue.get_nowait()
                self.time_data[type_byte] = value_byte
                data_processed = True
            except queue.Empty:
                break
            except Exception as e:
                logging.error(f"Error processing queue data: {e}")
                break
        if data_processed:
            self.update_display()
        self.master.after(50, self.check_serial_queue)

    def create_main_monitor(self, frame):
        """Creates the main monitor frame with the time and date display.

        Args:
            frame: The parent Tkinter frame.
        """
        frame.config(bg="#1E1E1E", padx=20, pady=20)
        tk.Label(frame, text="FPGA Time Display", font=("Inter", 18, "bold"), bg="#1E1E1E", fg="#ecf0f1").pack(
            pady=(10, 5))

        self.time_label = tk.Label(frame, textvariable=self.time_str, font=("Inter", 100, "bold"),
                                   bg="#2c3e50", fg="#3498db", relief=tk.RIDGE, bd=4, padx=20, pady=10)
        self.time_label.pack(pady=(10, 0), fill='x', padx=10)

        self.date_label = tk.Label(frame, textvariable=self.date_str, font=("Inter", 30, "normal"),
                                   bg="#2c3e50", fg="#ecf0f1", padx=20)
        self.date_label.pack(pady=(0, 10), fill='x', padx=10)

        ttk.Button(frame, text="Open Settings Panel", command=self.enter_settings, style='Custom.TButton').pack(
            pady=(20, 40), ipadx=20)

        tk.Label(frame, textvariable=self.status_str, font=("Inter", 10), bg="#1E1E1E", fg="#95a5a6").pack(
            side=tk.BOTTOM, fill='x', pady=10)

    def create_settings_panel(self, frame):
        """Creates the settings panel with options for setting the time and alarm.

        Args:
            frame: The parent Tkinter frame.
        """
        frame.config(bg="#1E1E1E", padx=20, pady=20)

        header_frame = tk.Frame(frame, bg="#1E1E1E")
        header_frame.pack(fill='x', pady=(0, 10))
        header_frame.grid_columnconfigure(0, weight=0)
        header_frame.grid_columnconfigure(1, weight=1)

        ttk.Button(header_frame, text="←", command=self.exit_settings, style='Return.TButton').grid(
            row=0, column=0, sticky='w', padx=(0, 20))

        tk.Label(header_frame, text="Clock & Alarm Settings", font=("Inter", 18, "bold"), bg="#1E1E1E",
                 fg="#ecf0f1").grid(
            row=0, column=1, sticky='ew', pady=(10, 5))

        main_options_container = tk.Frame(frame, bg="#1E1E1E")
        main_options_container.pack(fill='both', padx=10, pady=(0, 15), expand=True)
        main_options_container.grid_columnconfigure(0, weight=1)
        main_options_container.grid_rowconfigure(0, weight=1)
        main_options_container.grid_rowconfigure(1, weight=0)

        clock_options_row = tk.Frame(main_options_container, bg="#1E1E1E")
        clock_options_row.grid(row=0, column=0, sticky='nsew', pady=(0, 15))
        clock_options_row.grid_columnconfigure(0, weight=1)
        clock_options_row.grid_columnconfigure(1, weight=1)

        manual_frame = tk.Frame(clock_options_row, bg="#2c3e50", bd=1, relief=tk.SOLID, padx=15, pady=15)
        manual_frame.grid(row=0, column=0, sticky="nsew", padx=(0, 10))
        ttk.Label(manual_frame, text="1. Manual Time Setting", style='Panel.Header.TLabel').pack(pady=(0, 10),
                                                                                                 anchor='w')
        self.create_manual_settings(manual_frame)
        ttk.Button(manual_frame, text="Set Manual Time and Return",
                   command=lambda: self.set_clock_handler(manual=True),
                   style='Small.Custom.TButton').pack(pady=(15, 5), fill='x')

        auto_frame = tk.Frame(clock_options_row, bg="#2c3e50", bd=1, relief=tk.SOLID, padx=15, pady=15)
        auto_frame.grid(row=0, column=1, sticky="nsew", padx=(10, 0))
        ttk.Label(auto_frame, text="2. Automatic PC Time Sync", style='Panel.Header.TLabel').pack(pady=(0, 10),
                                                                                                  anchor='w')
        self.create_auto_settings(auto_frame)
        ttk.Button(auto_frame, text="Sync PC Time Now and Return",
                   command=lambda: self.set_clock_handler(manual=False),
                   style='Small.Custom.TButton').pack(pady=(15, 5), fill='x')

        alarm_options_row = tk.Frame(main_options_container, bg="#1E1E1E")
        alarm_options_row.grid(row=1, column=0, sticky='ew')

        alarm_frame = tk.Frame(alarm_options_row, bg="#2c3e50", bd=1, relief=tk.SOLID, padx=15, pady=15)
        alarm_frame.pack(fill='x', padx=0)

        ttk.Label(alarm_frame, text="3. Alarm Clock Setting (Hour/Minute)", style='Panel.Header.TLabel').pack(
            pady=(0, 10), anchor='w')
        self.create_alarm_settings(alarm_frame)
        ttk.Button(alarm_frame, text="Set Alarm and Return", command=self.set_alarm_handler,
                   style='Custom.TButton').pack(pady=(15, 5), fill='x')

    def _validate_int_wrapper(self, proposed_value, min_val, max_val):
        """Validates that a user input string is an integer within a specified range.

        This method is used as a wrapper for the Tkinter validation command.
        It handles empty strings as valid (intermediate state) and checks
        if the non-empty string is an integer between `min_val` and `max_val`.
        It also handles dynamic day limits based on the selected month.

        Args:
            proposed_value: The string value currently in the entry widget.
            min_val: The minimum allowed integer value (as a string or int).
            max_val: The maximum allowed integer value (as a string or int).

        Returns:
            True if the input is valid (empty or within range), False otherwise.
        """
        if not proposed_value:
            return True

        try:
            value = int(proposed_value)
            min_v = int(min_val)
            max_v = int(max_val)

            if min_v == 1 and max_v == 31:
                try:
                    month = self.m_month.get()
                    max_day_for_month = self.get_max_day(month)
                    return min_v <= value <= max_day_for_month
                except Exception:
                    return min_v <= value <= max_v

            return min_v <= value <= max_v
        except ValueError:
            return False 

    def create_manual_settings(self, frame):
        """Creates the widgets for manually setting the time.

        Args:
            frame: The parent Tkinter frame.
        """
        self.m_month = tk.IntVar(value=self.time_data.get(TYPE_MONTH, 1))
        self.m_day = tk.IntVar(value=self.time_data.get(TYPE_DAY, 1))
        self.m_hour = tk.IntVar(value=self.time_data.get(TYPE_HOUR, 0))
        self.m_minute = tk.IntVar(value=self.time_data.get(TYPE_MINUTE, 0))
        self.m_second = tk.IntVar(value=self.time_data.get(TYPE_SECOND, 0))

        grid_frame = tk.Frame(frame, bg="#2c3e50")
        grid_frame.pack(fill='x', pady=(0, 5))

        settings = [
            ("Month (1-12):", self.m_month, (1, 12), True),
            ("Day (1-31):", self.m_day, (1, 31), True),
            ("Hour (0-23):", self.m_hour, (0, 23), False),
            ("Minute (0-59):", self.m_minute, (0, 59), False),
            ("Second (0-59):", self.m_second, (0, 59), False),
        ]

        spinbox_style = {'bg': '#34495e', 'fg': '#ecf0f1', 'insertbackground': '#ecf0f1', 'relief': tk.FLAT,
                         'width': 5}

        for i, (label, var, (from_, to), needs_trace) in enumerate(settings):
            tk.Label(grid_frame, text=label, bg="#2c3e50", fg="#ecf0f1", font=('Inter', 10)).grid(row=i, column=0,
                                                                                                  sticky='w', pady=2,
                                                                                                  padx=5)
            spin = tk.Spinbox(grid_frame, from_=from_, to=to, textvariable=var, wrap=True,
                              validate='all',
                              validatecommand=(self.vcmd_int, '%P', str(from_), str(to)),
                              **spinbox_style)

            if needs_trace:
                if label == "Day (1-31):":
                    self.day_spinbox = spin
                var.trace_add("write", lambda *args: self.update_max_day())

            spin.grid(row=i, column=1, sticky='ew', pady=2, padx=5)

        grid_frame.grid_columnconfigure(1, weight=1)
        grid_frame.grid_columnconfigure(0, weight=1)


    def create_auto_settings(self, frame):
        """Creates the widgets for automatically syncing the time with the PC.

        Args:
            frame: The parent Tkinter frame.
        """
        content_frame = tk.Frame(frame, bg="#2c3e50")
        content_frame.pack(expand=True, fill='both')

        tk.Label(content_frame, text="Uses your computer's current time", bg="#2c3e50", fg="#ecf0f1",
                 font=('Inter', 11)).pack(pady=(10, 5))
        tk.Label(content_frame, text="Current System Time:", bg="#2c3e50", fg="#ecf0f1",
                 font=('Inter', 10)).pack(pady=(10, 5))

        self.pc_time_label = tk.Label(content_frame, text="", bg="#2c3e50", font=('Inter', 20, 'bold'), fg="#3498db")
        self.pc_time_label.pack(pady=5)

        tk.Label(content_frame, text="Note: Clock sync is instantaneous.", bg="#2c3e50", fg="#95a5a6",
                 font=('Inter', 9, 'italic')).pack(pady=(15, 0))
        self.update_pc_time_display()

    def create_alarm_settings(self, frame):
        """Creates the widgets for setting the alarm.

        Args:
            frame: The parent Tkinter frame.
        """
        grid_frame = tk.Frame(frame, bg="#2c3e50")
        grid_frame.pack(fill='x', pady=(0, 20))

        tk.Label(grid_frame, text="Alarm Time (HH:MM):", bg="#2c3e50", fg="#ecf0f1", font=('Inter', 11, 'bold')).grid(
            row=0, column=0, sticky='w', pady=5, padx=10)

        time_frame = tk.Frame(grid_frame, bg="#2c3e50")
        time_frame.grid(row=0, column=1, sticky='ew', pady=5, padx=10)
        time_frame.grid_columnconfigure(0, weight=1)
        time_frame.grid_columnconfigure(2, weight=1)

        spinbox_style = {'bg': '#34495e', 'fg': '#ecf0f1', 'insertbackground': '#ecf0f1', 'relief': tk.FLAT, 'width': 5}

        tk.Spinbox(time_frame, from_=0, to=23, textvariable=self.alarm_hour, wrap=True,
                   validate='all',
                   validatecommand=(self.vcmd_int, '%P', "0", "23"),
                   **spinbox_style).grid(
            row=0, column=0, sticky='e')

        tk.Label(time_frame, text=":", bg="#2c3e50", fg="#ecf0f1", font=('Inter', 12, 'bold')).grid(
            row=0, column=1, padx=5)

        tk.Spinbox(time_frame, from_=0, to=59, textvariable=self.alarm_minute, wrap=True,
                   validate='all',
                   validatecommand=(self.vcmd_int, '%P', "0", "59"),
                   **spinbox_style).grid(
            row=0, column=2, sticky='w')

        grid_frame.grid_columnconfigure(1, weight=1)

        tk.Label(frame,
                 text="Note: Sending alarm setting temporarily pauses data reading.",
                 bg="#2c3e50", fg="#95a5a6", font=('Inter', 9, 'italic')).pack(pady=(10, 0), anchor='w')

    def get_month_name(self, month_num):
        """Returns the name of the month for a given month number.

        Args:
            month_num: The number of the month (1-12).

        Returns:
            The name of the month as a string.
        """
        return self.MONTH_NAMES.get(month_num, "Invalid Month")

    def update_display(self):
        """Updates the time and date display with the latest data.

        Formats the current time and date stored in `self.time_data` and
        updates the Tkinter StringVars (`self.time_str` and `self.date_str`)
        bound to the UI labels.
        """
        month = self.time_data.get(TYPE_MONTH, 0)
        day = self.time_data.get(TYPE_DAY, 0)
        hour = self.time_data.get(TYPE_HOUR, 0)
        minute = self.time_data.get(TYPE_MINUTE, 0)
        second = self.time_data.get(TYPE_SECOND, 0)
        if all(isinstance(v, int) and v >= 0 for v in [month, day, hour, minute, second]):
            time_part = f"{hour:02d}:{minute:02d}:{second:02d}"
            self.time_str.set(time_part)
            month_name = self.get_month_name(month)
            date_part = f"{month_name} {day:02d}"
            self.date_str.set(date_part)
        else:
            self.time_str.set("--:--:--")
            self.date_str.set("-- --")

    def get_max_day(self, month):
        """Gets the maximum number of days for a given month.

        Args:
            month: The month (1-12).

        Returns:
            The number of days in the month.
        """
        try:
            return calendar.monthrange(self.current_year, month)[1]
        except ValueError:
            return 31

    def update_max_day(self, *args):
        """Updates the maximum day of the month in the day spinbox."""
        try:
            month = self.m_month.get()
            if 1 <= month <= 12:
                max_day = self.get_max_day(month)
                self.day_spinbox.config(to=max_day)
                if self.m_day.get() > max_day:
                    self.m_day.set(max_day)
        except Exception:
            pass

    def enter_settings(self):
        """Enters the settings mode.

        Switches the UI to the settings panel and pauses the serial reader
        (to prevent display updates while editing). Initializes the settings
        fields with the current time values.
        """
        if not self.is_serial_open:
            messagebox.showerror("Serial Error", "Cannot enter settings: Serial port is not open.")
            return
        self.is_setting_mode = True
        try:
            self.ser.reset_input_buffer()
        except Exception:
            pass
        self.m_month.set(self.time_data.get(TYPE_MONTH, 1))
        self.m_day.set(self.time_data.get(TYPE_DAY, 1))
        self.m_hour.set(self.time_data.get(TYPE_HOUR, 0))
        self.m_minute.set(self.time_data.get(TYPE_MINUTE, 0))
        self.m_second.set(self.time_data.get(TYPE_SECOND, 0))
        self.update_max_day()
        self.show_frame(self.setting_frame)
        self.status_str.set("In Settings Mode: UART RX paused.")

    def exit_settings(self):
        """Exits the settings mode.

        Returns the UI to the main monitor view and resumes serial data processing.
        """
        self.is_setting_mode = False
        self.show_frame(self.main_frame)
        self.status_str.set("Main Monitor: UART RX resumed.")

    def set_clock_handler(self, manual=True):
        """Handles the logic for setting the clock, either manually or automatically.

        Args:
            manual: A boolean indicating whether to set the time manually (True) or
                sync with the PC (False).
        """
        if manual:
            try:
                month = self.m_month.get()
                day = self.m_day.get()
                hour = self.m_hour.get()
                minute = self.m_minute.get()
                second = self.m_second.get()

                max_day = self.get_max_day(month)
                if not (
                        1 <= month <= 12 and 1 <= day <= max_day and 0 <= hour <= 23 and 0 <= minute <= 59 and 0 <= second <= 59):
                    messagebox.showerror("Input Error",
                                         "Please check all fields. A value is outside its valid range (e.g., Day/Month mismatch, Hour > 23).")
                    return

                self.send_clock_data(month, day, hour, minute, second)
            except tk.TclError:
                messagebox.showerror("Input Error", "Please ensure all fields contain valid numbers.")
                return
        else:
            now = datetime.now()
            self.send_clock_data(now.month, now.day, now.hour, now.minute, now.second)
        self.exit_settings()

    def send_clock_data(self, month, day, hour, minute, second):
        """Sends the clock data to the FPGA via the serial port.

        Args:
            month: The month to set.
            day: The day to set.
            hour: The hour to set.
            minute: The minute to set.
            second: The second to set.
        """
        if not self.is_serial_open:
            messagebox.showerror("Serial Error", "Serial port is not open.")
            return
        data = [0xAA, month, day, hour, minute, second]
        month_name = self.get_month_name(month)
        status_time = f"{month_name} {day:02d} | {hour:02d}:{minute:02d}:{second:02d}"
        try:
            self.ser.write(bytes(data))
            self.status_str.set(f"Clock set: {status_time} sent to FPGA. Returning to monitor...")
            logging.info(f"Sent (Clock): {data}")
        except Exception as e:
            messagebox.showerror("Serial Error", f"Error sending data: {e}")
            self.status_str.set(f"Error sending data: {e}")

    def set_alarm_handler(self):
        """Handles the logic for setting the alarm.

        Validates the alarm hour and minute inputs. If valid, sends the
        alarm configuration to the FPGA and returns to the main view.
        """
        if not self.is_serial_open:
            messagebox.showerror("Serial Error", "Serial port is not open.")
            return
        try:
            alarm_h = self.alarm_hour.get()
            alarm_m = self.alarm_minute.get()
            alarm_on = 1 if self.alarm_enabled.get() else 0

            if not (0 <= alarm_h <= 23 and 0 <= alarm_m <= 59):
                messagebox.showerror("Input Error", "Please ensure Alarm Hour (0-23) and Minute (0-59) are valid.")
                return

            self.send_alarm_data(alarm_h, alarm_m, alarm_on)
        except tk.TclError:
            messagebox.showerror("Input Error", "Please ensure Hour and Minute contain valid numbers.")
            return
        self.exit_settings()

    def send_alarm_data(self, hour, minute, enabled):
        """Sends the alarm data to the FPGA via the serial port.

        Args:
            hour: The alarm hour to set.
            minute: The alarm minute to set.
            enabled: A boolean indicating whether the alarm is enabled.
        """
        data = [0xBB, hour, minute]
        status_alarm = f"{hour:02d}:{minute:02d} | {'Enabled' if enabled else 'Disabled'}"
        try:
            self.ser.write(bytes(data))
            self.status_str.set(f"Alarm set: {status_alarm} sent to FPGA. Returning to monitor...")
            logging.info(f"Sent (Alarm): {data}")
        except Exception as e:
            messagebox.showerror("Serial Error", f"Error sending alarm data: {e}")
            self.status_str.set(f"Error sending alarm data: {e}")

    def update_pc_time_display(self):
        """Updates the display of the PC's current time.

        Recursively calls itself every 1000ms to keep the "Current System Time"
        label on the settings panel updated.
        """
        now = datetime.now()
        month_name = self.get_month_name(now.month)
        date_part = f"{month_name} {now.day:02d}"
        time_part = now.strftime("%H:%M:%S")
        formatted_pc_time = f"{time_part}\n{date_part}"
        self.pc_time_label.config(text=formatted_pc_time)
        self.master.after(1000, self.update_pc_time_display)

    def on_closing(self):
        """Handles the closing of the application window.

        Stops the serial reader thread, closes the serial connection,
        and destroys the Tkinter root window.
        """
        self.running = False
        if self.read_thread and self.read_thread.is_alive():
            self.read_thread.join(timeout=0.05)
        if self.is_serial_open:
            try:
                self.ser.close()
            except Exception:
                pass
        self.master.destroy()


if __name__ == '__main__':
    try:
        import serial
        import serial.tools.list_ports
    except ImportError:
        root_dummy = tk.Tk()
        root_dummy.withdraw()
        messagebox.showerror("Dependency Error",
                             "The 'pyserial' library is required. Please install it with 'pip install pyserial'.")
        root_dummy.destroy()
        exit(1)

    root = tk.Tk()
    app = FpgaClockApp(root)
    root.mainloop()

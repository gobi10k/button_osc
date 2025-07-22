# Button to OSC Sender

This script listens for button presses on a Raspberry Pi's GPIO pin and sends OSC messages to another computer on the same network. It also provides a simple GUI to monitor the button presses locally.

## Prerequisites

*   A Raspberry Pi with Raspberry Pi OS.
*   A button connected to GPIO pin 15 and ground.
*   An Ethernet connection between your Raspberry Pi and another computer.

## Installation

1.  **Install required Python libraries:**

    Open a terminal on your Raspberry Pi and run the following commands to install the necessary libraries:

    ```bash
    pip install python-osc
    pip install RPi.GPIO
    ```

2.  **Save the script:**

    Save the Python code as `button_osc_sender.py` on your Raspberry Pi.

## Running the Script

1.  **Run from the terminal:**

    Open a terminal and navigate to the directory where you saved `button_osc_sender.py`. Run the script with the following command:

    ```bash
    python button_osc_sender.py
    ```

2.  **Button Press GUI:**

    A small window will appear on your Raspberry Pi's desktop, displaying "Waiting for button press...". When you press the button, the message will change to "Button Pressed!" for a short duration.

3.  **Receiving OSC Messages:**

    On the other computer, you will need an application that can receive OSC messages. Make sure it is listening on port 8000. When the button is pressed on the Raspberry Pi, it will send an OSC message to the address `/button/press` with a value of `1`.

## How it Works

*   **Network Detection:** The script automatically finds the IP address of the `eth0` (Ethernet) interface on the Raspberry Pi. This is the address it will send the OSC messages to.
*   **GPIO:** It uses the `RPi.GPIO` library to detect a button press on GPIO pin 15. The pin is configured with a pull-up resistor, so you should connect the button between the pin and ground.
*   **OSC:** It uses the `python-osc` library to send OSC messages.
*   **GUI:** It uses the `tkinter` library, which is part of the standard Python library, to create the graphical user interface.

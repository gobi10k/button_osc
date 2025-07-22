import tkinter as tk
import RPi.GPIO as GPIO
from pythonosc import udp_client
import socket
import fcntl
import struct

# --- Configuration ---
BUTTON_PIN = 15
OSC_PORT = 8000
OSC_ADDRESS = "/button/press"

# --- Function to get the IP address of the ethernet connection ---
def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15].encode('utf-8'))
    )[20:24])

# --- Find the ethernet interface and IP address ---
try:
    eth_interface = 'eth0'
    ip_address = get_ip_address(eth_interface)
    print(f"Found ethernet interface {eth_interface} with IP address: {ip_address}")
except IOError:
    print("Error: Could not find eth0 interface. Please ensure your Raspberry Pi is connected via Ethernet.")
    exit()


# --- OSC Client Setup ---
client = udp_client.SimpleUDPClient(ip_address, OSC_PORT)

# --- GPIO Setup ---
GPIO.setmode(GPIO.BCM)
GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

# --- GUI Setup ---
window = tk.Tk()
window.title("Button Press Monitor")
status_label = tk.Label(window, text="Waiting for button press...", font=("Helvetica", 24))
status_label.pack(pady=20, padx=20)

# --- Button Press Callback ---
def button_callback(channel):
    print("Button pressed!")
    status_label.config(text="Button Pressed!")
    client.send_message(OSC_ADDRESS, 1)
    window.update()
    # Revert the message after a short delay
    window.after(500, lambda: status_label.config(text="Waiting for button press..."))


# --- Register the button press event ---
GPIO.add_event_detect(BUTTON_PIN, GPIO.FALLING, callback=button_callback, bouncetime=300)

# --- Main Loop ---
print("Ready to send OSC messages. Press the button.")
print("Press Ctrl+C to exit.")

window.mainloop()

# --- Cleanup ---
GPIO.cleanup()

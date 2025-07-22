#!/bin/bash

echo "==== Raspberry Pi OSC Broadcaster Complete Setup ===="
echo "This will install, configure, and fix all components"

# === Configuration ===
USERNAME=$(whoami)
HOME_DIR="/home/$USERNAME"
SCRIPT_PATH="$HOME_DIR/osc_button.py"
SERVICE_PATH="/etc/systemd/system/osc_button.service"
LAUNCH_SCRIPT="$HOME_DIR/launch_osc.sh"
LOG_DIR="$HOME_DIR/osc_logs"
VENV_DIR="$HOME_DIR/osc_env"

# === 1. Install Dependencies ===
echo -e "\n🔧 INSTALLING DEPENDENCIES"
sudo apt-get update
sudo apt-get install -y python3-venv python3-tk python3-dev nmap

# === 2. Setup Python Environment ===
echo -e "\n🐍 CREATING PYTHON ENVIRONMENT"
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install python-osc RPi.GPIO netifaces

# === 3. Create the Python Script ===
echo -e "\n📝 CREATING PYTHON SCRIPT"
cat > "$SCRIPT_PATH" <<'EOL'
import tkinter as tk
import RPi.GPIO as GPIO
from pythonosc import udp_client
import netifaces as ni
import socket

# --- Configuration ---
BUTTON_PIN = 15
OSC_PORT = 8000
OSC_ADDRESS = "/button/press"

def get_ip_address():
    interfaces = ni.interfaces()
    for interface in interfaces:
        if interface.startswith('eth') or interface.startswith('wlan'):
            try:
                ip = ni.ifaddresses(interface)[ni.AF_INET][0]['addr']
                return ip
            except (KeyError, IndexError):
                continue
    return None

ip_address = get_ip_address()
if not ip_address:
    print("Error: Could not find a valid network interface.")
    exit()

print(f"Found IP address: {ip_address}")

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
EOL

# === 4. Fix GPIO Access ===
echo -e "\n🔌 CONFIGURING GPIO"
sudo usermod -a -G gpio $USERNAME
sudo bash -c 'cat > /etc/udev/rules.d/99-gpiomem.rules' <<'EOL'
SUBSYSTEM=="bcm2835-gpiomem", KERNEL=="gpiomem", GROUP="gpio", MODE="0660"
EOL

# === 5. Create Launch Script ===
echo -e "\n🚀 CREATING LAUNCH SCRIPT"
mkdir -p "$LOG_DIR"
cat > "$LAUNCH_SCRIPT" <<EOL
#!/bin/bash
export DISPLAY=:0
export XAUTHORITY=$HOME_DIR/.Xauthority
LOG_DIR="$LOG_DIR"
mkdir -p "\$LOG_DIR"
exec > >(tee -a "\$LOG_DIR/runtime.log") 2>&1
source "$VENV_DIR/bin/activate"
python "$SCRIPT_PATH"
EOL

chmod +x "$LAUNCH_SCRIPT"

# === 6. Create Systemd Service ===
echo -e "\n🛠️ CREATING SYSTEMD SERVICE"
sudo bash -c "cat > $SERVICE_PATH" <<EOL
[Unit]
Description=OSC Button Broadcaster
After=graphical.target

[Service]
User=$USERNAME
Group=gpio
WorkingDirectory=$HOME_DIR
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$HOME_DIR/.Xauthority"
ExecStart=$LAUNCH_SCRIPT
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=graphical.target
EOL

# === 7. Setup Autostart ===
echo -e "\n🖥️ CONFIGURING AUTOSTART"
mkdir -p "$HOME_DIR/.config/autostart"
cat > "$HOME_DIR/.config/autostart/osc-broadcaster.desktop" <<EOL
[Desktop Entry]
Type=Application
Name=OSC Broadcaster
Comment=OSC Button Broadcaster GUI
Exec=bash -c 'source $HOME_DIR/osc_env/bin/activate && $LAUNCH_SCRIPT'
Hidden=false
X-GNOME-Autostart-enabled=true
EOL

# === 8. Enable and Start Service ===
echo -e "\n🚀 STARTING SERVICES"
sudo systemctl daemon-reload
sudo systemctl enable --now osc_button.service

# === 9. Create Diagnostic Tools ===
echo -e "\n🛠️ CREATING DIAGNOSTIC TOOLS"
cat > "$HOME_DIR/check_osc.sh" <<'EOL'
#!/bin/bash
echo "=== Service Status ==="
systemctl status osc_button.service --no-pager

echo -e "\n=== GPIO Status ==="
ls -l /dev/gpiomem 2>/dev/null || echo "GPIO device not found"

echo -e "\n=== Display Status ==="
echo "DISPLAY: $DISPLAY"
echo "XAUTHORITY: $XAUTHORITY"

echo -e "\n=== Recent Logs ==="
tail -n 20 $HOME/osc_logs/*.log 2>/dev/null
EOL

chmod +x "$HOME_DIR/check_osc.sh"

# === 10. Final Steps ===
echo -e "\n✅ SETUP COMPLETE"
echo "The system will now reboot to apply all changes."
echo "After reboot, the OSC broadcaster will start automatically."
echo "To check the status, run './check_osc.sh' from your home directory."

# Reboot to apply group changes and start the service
sudo reboot

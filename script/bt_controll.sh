#!/usr/bin/env bash
# Bluetooth management script using dmenu

# Function to get Bluetooth status and devices
get_bluetooth_info() {
    # Get Bluetooth power status
    powered=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')
    
    # Set toggle option based on current status
    if [[ "$powered" == "yes" ]]; then
        toggle="󰂲  Disable Bluetooth"
        # Get paired devices with their connection status
        devices=$(bluetoothctl devices | while read -r _ mac name; do
            connected=$(bluetoothctl info "$mac" | grep "Connected:" | awk '{print $2}')
            if [[ "$connected" == "yes" ]]; then
                echo "󰂱  $name"
            else
                echo "󰂯  $name"
            fi
        done)
    else
        toggle="󰂯  Enable Bluetooth"
        devices=""
    fi
    
    # Add scan option
    scan_option="󰑐  Scan for Devices"
}

# Function to safely stop scanning
stop_scanning() {
    # Try to stop scanning, suppress all output and errors
    bluetoothctl scan off >/dev/null 2>&1 || true
    
    # Alternative method: use expect or timeout to handle bluetoothctl
    # timeout 1 bluetoothctl scan off >/dev/null 2>&1 || true
}

# Get initial Bluetooth info
get_bluetooth_info

# Create menu options
menu_options="$toggle\n$scan_option"
if [[ -n "$devices" ]]; then
    menu_options="$menu_options\n$devices"
fi

# Use dmenu to select an option
chosen_option=$(echo -e "$menu_options" | dmenu -i -p "󰂯 Bluetooth Devices:")

# Handle the selected option
if [[ "$chosen_option" == "" ]]; then
    exit
elif [[ "$chosen_option" == "󰂯  Enable Bluetooth" ]]; then
    if bluetoothctl power on >/dev/null 2>&1; then
        notify-send "󰂱  Bluetooth Enabled" "Bluetooth has been turned on"
    else
        notify-send "Error" "Failed to enable Bluetooth"
    fi
elif [[ "$chosen_option" == "󰂲  Disable Bluetooth" ]]; then
    if bluetoothctl power off >/dev/null 2>&1; then
        notify-send "󰂲  Bluetooth Disabled" "Bluetooth has been turned off"
    else
        notify-send "Error" "Failed to disable Bluetooth"
    fi
elif [[ "$chosen_option" == "󰑐  Scan for Devices" ]]; then
    # Ensure we start fresh - stop any existing scan first
    stop_scanning
    
    # Start scanning for devices
    notify-send "󰑐 Bluetooth Scan" "Scanning for devices..."
    
    # Use a more robust scanning approach
    {
        echo "scan on"
        sleep 5
        echo "scan off"
        echo "quit"
    } | bluetoothctl >/dev/null 2>&1 &
    
    # Wait for scanning to complete
    wait
    
    # Small delay to ensure devices are discovered
    sleep 1
    
    # Restart the script to show new devices
    exec "$0"
else
    # Extract device name from the selected option (remove the icon and space)
    device_name=$(echo "$chosen_option" | sed 's/^.[^ ]*  //')
    
    # Get the MAC address of the selected device
    device_mac=$(bluetoothctl devices | grep "$device_name" | awk '{print $2}')
    
    if [[ -z "$device_mac" ]]; then
        notify-send "Error" "Could not find device: $device_name"
        exit 1
    fi
    
    # Check if device is connected
    connected=$(bluetoothctl info "$device_mac" | grep "Connected:" | awk '{print $2}')
    
    if [[ "$connected" == "yes" ]]; then
        # Disconnect from device
        if bluetoothctl disconnect "$device_mac" >/dev/null 2>&1; then
            notify-send "󰂲  Bluetooth Disconnected" "Disconnected from $device_name"
        else
            notify-send "Connection Failed" "Failed to disconnect from $device_name"
        fi
    else
        # Try to connect to device
        if bluetoothctl connect "$device_mac" >/dev/null 2>&1; then
            notify-send "󰂱  Bluetooth Connected" "Connected to $device_name"
        else
            # If connection fails, try to pair first
            notify-send "󰂱  Bluetooth Pairing" "Attempting to pair with $device_name..."
            if bluetoothctl pair "$device_mac" >/dev/null 2>&1 && bluetoothctl connect "$device_mac" >/dev/null 2>&1; then
                notify-send "󰂱  Bluetooth Connected" "Paired and connected to $device_name"
            else
                notify-send "Connection Failed" "Failed to connect to $device_name"
            fi
        fi
    fi
fi

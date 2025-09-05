#!/usr/bin/env bash
# Get a list of available wifi connections and morph it into a nice-looking list
wifi_list=$(nmcli --fields "SECURITY,SSID" device wifi list | sed 1d | sed 's/  */ /g' | sed -E "s/WPA*.?\S/ /g" | sed "s/^--/ /g" | sed "s/  //g" | sed "/--/d")

# Add wifi icons to each network
wifi_list_with_icons=""
while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        wifi_list_with_icons+="󰤨  $line"$'\n'
    fi
done <<< "$wifi_list"

connected=$(nmcli -fields WIFI g)
if [[ "$connected" =~ "enabled" ]]; then
	toggle="󰖪  Disable Wi-Fi"
elif [[ "$connected" =~ "disabled" ]]; then
	toggle="󰖩  Enable Wi-Fi"
fi

# Add scan option
scan_option="󰑐  Refresh Networks"

# Use dmenu to select wifi network
chosen_network=$(echo -e "$toggle\n$scan_option\n$wifi_list_with_icons" | dmenu -i -p "󰤨 Wi-Fi Networks: ")

# Get name of connection
if [[ "$chosen_network" == "󰖪  Disable Wi-Fi" ]] || [[ "$chosen_network" == "󰖩  Enable Wi-Fi" ]]; then
    chosen_id="${chosen_network:3}"
elif [[ "$chosen_network" == "󰑐  Refresh Networks" ]]; then
    # Refresh and restart the script
    exec "$0"
elif [[ "$chosen_network" =~ ^󰤨 ]]; then
    # Remove the wifi icon and trim whitespace
    chosen_id=$(echo "${chosen_network:3}" | xargs)
else
    # Fallback for any other format
    chosen_id=$(echo "$chosen_network" | xargs)
fi

if [ "$chosen_network" = "" ]; then
	exit
elif [ "$chosen_network" = "󰖩  Enable Wi-Fi" ]; then
	nmcli radio wifi on
	notify-send "󰖩 WiFi Enabled" "WiFi has been turned on"
elif [ "$chosen_network" = "󰖪  Disable Wi-Fi" ]; then
	nmcli radio wifi off
	notify-send "󰖪 WiFi Disabled" "WiFi has been turned off"
else
	# Message to show when connection is activated successfully
  	success_message="You are now connected to the Wi-Fi network \"$chosen_id\"."
	# Get saved connections
	saved_connections=$(nmcli -g NAME connection)
	if [[ $(echo "$saved_connections" | grep -w "$chosen_id") = "$chosen_id" ]]; then
		if nmcli connection up id "$chosen_id" | grep "successfully"; then
			notify-send "󰤨  Connection Established" "$success_message"
		else
			notify-send "󰤳 Connection Failed" "Failed to connect to \"$chosen_id\"" 
		fi
	else
		if [[ "$chosen_network" =~ "" ]]; then
			wifi_password=$(dmenu -p "󰌾 Password for $chosen_id: " </dev/null)
		fi
		if nmcli device wifi connect "$chosen_id" password "$wifi_password" | grep "successfully"; then
			notify-send "󰤨  Connection Established" "$success_message"
		else
			notify-send "󰤳 Connection Failed" "Failed to connect to \"$chosen_id\". Check your password."
		fi
    fi
fi

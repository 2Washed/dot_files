#!/usr/bin/env bash

## Author: you, based on adi1090x style
## Applet: Network (WiFi)

dir="$HOME/.config/rofi/applets/"
theme="type-1/style-1.rasi"

## Icons (Nerd Font)
icon_wifi_hi="󰤨"
icon_wifi_mid="󰤥"
icon_wifi_low="󰤢"
icon_wifi_min="󰤟"
icon_off="󰤭"
icon_lock="󰌆"
icon_conn="󰖩"
icon_scan="󰑐"
icon_disc="󰖪"
icon_nm="󰮝"

## Get current connection info
iface=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi"{print $1; exit}')
ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2}')
state=$(nmcli -t -f DEVICE,STATE dev | awk -F: -v d="$iface" '$1==d{print $2}')
signal=$(nmcli -t -f active,signal dev wifi | awk -F: '$1=="yes"{print $2}')

## Status message shown in the prompt
if [[ "$state" == "connected" ]]; then
    prompt="$icon_conn  $ssid"
    msg="Signal: ${signal}%   Interface: $iface"
else
    prompt="$icon_off  Disconnected"
    msg="No active wifi connection"
fi

## Build network list (sorted by signal desc)
network_list=$(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list | \
    sort -t: -k2 -rn | \
    awk -F: '!seen[$1]++ && $1!="" {
        sig=$2+0
        if (sig>=75) icon="󰤨"
        else if (sig>=50) icon="󰤥"
        else if (sig>=25) icon="󰤢"
        else icon="󰤟"
        lock=($3!="--" ? "󰌆 " : "   ")
        printf "%s  %-32s %3s%%  %s\n", icon, $1, $2, lock
    }')

## Extra options
options="$network_list
$icon_scan  Scan / Refresh
$icon_disc  Disconnect
$icon_nm  Network Manager"

## Show rofi
chosen=$(echo -e "$options" | rofi -dmenu \
    -p "$prompt" \
    -mesg "$msg" \
    -theme "$dir/$theme" \
    -theme-str 'listview { lines: 10; }')

[ -z "$chosen" ] && exit 0

## Handle special options
case "$chosen" in
    *"Scan / Refresh"*)
        nmcli dev wifi rescan
        exec "$0"
        ;;
    *"Disconnect"*)
        nmcli dev disconnect "$iface"
        notify-send "WiFi" "Disconnected from $ssid"
        ;;
    *"Network Manager"*)
        nm-connection-editor
        ;;
    *)
        ## Extract SSID (2nd word, after icon)
        picked_ssid=$(echo "$chosen" | awk '{print $2}')
        saved=$(nmcli -t -f NAME con show | grep -Fx "$picked_ssid")

        if [ -n "$saved" ]; then
            nmcli con up "$picked_ssid" && \
                notify-send "WiFi" "Connected to $picked_ssid"
        else
            password=$(rofi -dmenu \
                -p "󰌆  Password" \
                -password \
                -theme "$dir/$theme" \
                -theme-str 'listview { lines: 0; } window { width: 400px; }' <<< "")
            [ -z "$password" ] && exit 0
            nmcli dev wifi connect "$picked_ssid" password "$password" && \
                notify-send "WiFi" "Connected to $picked_ssid"
        fi
        ;;
esac
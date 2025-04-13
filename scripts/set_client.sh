#!/bin/bash
echo "[+] Connecting wlan1 to upstream..."

ip link set wlan1 down
ip link set wlan1 up

wpa_cli -i wlan1 reconfigure
sleep 5
dhclient -r wlan1
dhclient wlan1

#!/bin/bash
echo "[+] Setting NAT forwarding from wlan0 to wlan1..."

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
iptables -A FORWARD -i wlan1 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o wlan1 -j ACCEPT

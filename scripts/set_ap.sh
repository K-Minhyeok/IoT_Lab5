#!/bin/bash

# set_ap.sh
# Usage: ./set_ap.sh RelayAP_2 192.168.51

ssid=$1
ip_base=$2

if [ -z "$ssid" ] || [ -z "$ip_base" ]; then
    echo "Usage: $0 <SSID_NAME> <IP_BASE (e.g., 192.168.51)>"
    exit 1
fi

# Stop services before setup
systemctl stop hostapd
systemctl stop dnsmasq

# Set static IP for wlan0
ip link set wlan0 down
ip addr flush dev wlan0
ip addr add $ip_base.1/24 dev wlan0
ip link set wlan0 up

# Configure hostapd
cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=$ssid
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=relay1234
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

# Point to hostapd.conf
sed -i 's|#DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Configure dnsmasq
cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=$ip_base.10,$ip_base.100,255.255.255.0,24h
EOF

# Start services
systemctl start dnsmasq
systemctl start hostapd

# Done
echo "[+] AP mode configured with SSID: $ssid and IP: $ip_base.1"

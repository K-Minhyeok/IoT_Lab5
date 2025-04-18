#!/bin/bash

# setup_relay_dynamic.sh
# 사용법: sudo ./setup_relay_dynamic.sh <내_AP_SSID> <내_IP_BASE> <상위_SSID> <상위_PSK>

SSID_MY_AP=$1
IP_BASE=$2
SSID_PARENT=$3
PSK_PARENT=$4

if [ -z "$SSID_MY_AP" ] || [ -z "$IP_BASE" ] || [ -z "$SSID_PARENT" ] || [ -z "$PSK_PARENT" ]; then
  echo "Usage: sudo $0 <내_AP_SSID> <내_IP_BASE> <상위_SSID> <상위_PSK>"
  exit 1
fi

# 1. 상위 AP 연결 (wlan1)
echo "[+] Connecting to upstream AP: $SSID_PARENT"
cat > /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=KR

network={
    ssid=\"$SSID_PARENT\"
    psk=\"$PSK_PARENT\"
}
EOF

sudo pkill wpa_supplicant
sudo ip link set wlan1 down
sudo ip link set wlan1 up
sudo wpa_supplicant -B -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant.conf -D nl80211
sleep 3
sudo dhclient -r wlan1
sudo dhclient wlan1

# 2. 내 AP 열기 (wlan0)
echo "[+] Setting up local AP: $SSID_MY_AP with IP $IP_BASE.1"
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
sudo ip addr add $IP_BASE.1/24 dev wlan0
sudo ip link set wlan0 up

cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=$SSID_MY_AP
channel=6
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=relay1234
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

sed -i 's|#DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

sudo systemctl stop hostapd
sudo hostapd /etc/hostapd/hostapd.conf &

# 3. DHCP 설정
cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=$IP_BASE.10,$IP_BASE.100,255.255.255.0,24h
EOF

sudo systemctl stop dnsmasq
sudo dnsmasq -C /etc/dnsmasq.conf

# 4. NAT 설정
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
sudo iptables -A FORWARD -i wlan1 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o wlan1 -j ACCEPT

echo "[✔] 릴레이 중계기 설정 완료"
echo "    상위 WiFi: $SSID_PARENT → 내 AP: $SSID_MY_AP"
echo "    IP 대역: $IP_BASE.0/24"
echo "    Test: Connect to $SSID_MY_AP and try ping google.com"

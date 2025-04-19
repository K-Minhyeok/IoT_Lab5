#!/bin/bash

# 사용법: sudo ./start_ap.sh <SSID> <SUBNET>
# 예시: sudo ./start_ap.sh MyRelayAP 192.168.50

SSID=$1
SUBNET=$2

if [ -z "$SSID" ] || [ -z "$SUBNET" ]; then
  echo "Usage: sudo $0 <SSID> <SUBNET (ex: 192.168.50)>"
  exit 1
fi

echo "[+] Starting AP: $SSID with subnet $SUBNET.0/24"

# 1. wlan0 초기화
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
sudo ip addr add $SUBNET.1/24 dev wlan0
sudo ip link set wlan0 up

# 2. hostapd 설정 파일 생성
cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=$SSID
channel=6
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=123456789a
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

# 3. DHCP 설정
cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=$SUBNET.10,$SUBNET.100,255.255.255.0,24h
EOF

# 4. AP 실행
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

sudo hostapd /etc/hostapd/hostapd.conf &
sudo dnsmasq -C /etc/dnsmasq.conf

echo "[✔] AP '$SSID' launched on wlan0"
echo "    IP: $SUBNET.1"
echo "    DHCP Range: $SUBNET.10 - $SUBNET.100"

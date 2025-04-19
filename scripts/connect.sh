#!/bin/bash

# 사용법: sudo ./connect_wifi.sh <SSID> <PSK>

SSID=$1
PSK=$2

if [ -z "$SSID" ] || [ -z "$PSK" ]; then
  echo "Usage: sudo $0 <SSID> <PSK>"
  exit 1
fi

echo "[+] Connecting wlan1 to SSID: $SSID"

# 1. 이전 설정 정리
sudo pkill wpa_supplicant
sudo rm -rf /var/run/wpa_supplicant
sudo mkdir -p /var/run/wpa_supplicant
sudo chown root:netdev /var/run/wpa_supplicant

# 2. wlan1 초기화
sudo ip link set wlan1 down
sudo ip addr flush dev wlan1
sudo ip link set wlan1 up

# 3. wpa_supplicant 설정파일 생성
cat > /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=KR

network={
    ssid="$SSID"
    psk="$PSK"
}
EOF

# 4. wpa_supplicant 실행
sudo wpa_supplicant -B -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant.conf -D nl80211

# 5. DHCP 요청
sleep 3
sudo dhclient -r wlan1
sudo dhclient wlan1

# 6. 결과 확인
echo "[*] 연결된 SSID:"
iwgetid wlan1 -r

echo "[*] 할당된 IP:"
ip a show wlan1 | grep inet

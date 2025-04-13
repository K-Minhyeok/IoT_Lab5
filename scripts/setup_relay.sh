#!/bin/bash

# setup_relay.sh
# 전체 릴레이 구성 자동화: AP 설정 + 상위 WiFi 연결 + NAT 포워딩
# 사용 예시: sudo ./setup_relay.sh RelayAP_2 192.168.51 RelayAP_1 relay1234

SSID_AP=$1         # 이 Pi가 열 AP 이름 (예: RelayAP_2)
IP_BASE=$2         # 이 Pi의 IP 대역 베이스 (예: 192.168.51)
SSID_PARENT=$3     # 상위 AP SSID (예: RelayAP_1)
PASSWORD_PARENT=$4 # 상위 AP 비밀번호

if [ -z "$SSID_AP" ] || [ -z "$IP_BASE" ] || [ -z "$SSID_PARENT" ] || [ -z "$PASSWORD_PARENT" ]; then
    echo "Usage: sudo $0 <MY_SSID> <MY_IP_BASE> <PARENT_SSID> <PARENT_PASSWORD>"
    exit 1
fi

# 1. 필수 패키지 설치
apt update
apt install -y hostapd dnsmasq iptables

# 2. wpa_supplicant 설정 (상위 AP 연결용)
echo "[+] Setting up wpa_supplicant for $SSID_PARENT"
wpa_passphrase "$SSID_PARENT" "$PASSWORD_PARENT" > /etc/wpa_supplicant/wpa_supplicant.conf
cat >> /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=KR
EOF

wpa_cli -i wlan1 reconfigure
sleep 5
dhclient -r wlan1
dhclient wlan1

# 3. AP 모드 설정
systemctl stop hostapd
systemctl stop dnsmasq

ip link set wlan0 down
ip addr flush dev wlan0
ip addr add $IP_BASE.1/24 dev wlan0
ip link set wlan0 up

cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=$SSID_AP
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

sed -i 's|#DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=$IP_BASE.10,$IP_BASE.100,255.255.255.0,24h
EOF

systemctl start dnsmasq
systemctl start hostapd

# 4. NAT 설정
sysctl -w net.ipv4.ip_forward=1

iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
iptables -A FORWARD -i wlan1 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o wlan1 -j ACCEPT

iptables-save > /etc/iptables.ipv4.nat

if ! grep -q 'iptables-restore < /etc/iptables.ipv4.nat' /etc/rc.local; then
    sed -i '/^exit 0/i iptables-restore < /etc/iptables.ipv4.nat' /etc/rc.local
fi

# 완료 메시지
echo "[✔] RelayPi 구성 완료: $SSID_AP 열고 $SSID_PARENT 중계 중"
echo "[ℹ] wlan0 IP: $IP_BASE.1"
hostname -I

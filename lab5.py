from flask import Flask, render_template, request, jsonify
import subprocess
import time
import os

app = Flask(__name__)

def get_status():
    ssid = subprocess.run(["iwgetid", "-r"], capture_output=True, text=True).stdout.strip()
    ip = subprocess.run(["hostname", "-I"], capture_output=True, text=True).stdout.strip()
    return ssid, ip

@app.route("/")
def index():
    ssid, ip = get_status()
    return render_template("index.html", ssid=ssid, ip=ip)

@app.route("/connect", methods=["POST"])
def connect():
    ssid = request.form["ssid"]
    password = request.form["password"]

    # wpa_supplicant.conf 생성
    result = subprocess.run(["wpa_passphrase", ssid, password], capture_output=True, text=True)
    with open("/etc/wpa_supplicant/wpa_supplicant.conf", "w") as f:
        f.write("ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\n")
        f.write("update_config=1\n")
        f.write(result.stdout)

    # 클라이언트로 전환
    subprocess.run(["bash", "scripts/set_client.sh"])
    time.sleep(5)

    # AP 모드 실행
    subprocess.run(["bash", "scripts/set_ap.sh"])
    subprocess.run(["bash", "scripts/iptables.sh"])

    return jsonify({"message": "Relay started."})

@app.route("/reboot")
def reboot():
    subprocess.run(["sudo", "reboot"])
    return "Rebooting..."

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)

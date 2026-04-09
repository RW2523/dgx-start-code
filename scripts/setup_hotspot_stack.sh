#!/bin/bash
set -e

WIFI_IFACE="wlP9s9"
SSID="DGX-Spark-AI"
WIFI_PASSWORD="12345678"
HOTSPOT_IP="10.10.0.1"
DHCP_START="10.10.0.10"
DHCP_END="10.10.0.100"

APP_USER="echomind"
APP_DIR="/home/echomind/dgx-local-app/backend"
APP_SERVICE="dgx-app"
# Uncommon dev port (avoid 3000/8000/8080/5173). Match systemd + nginx + DGX_APP_PORT in main.py default.
APP_PORT=28734
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Installing required packages..."
sudo apt update
sudo apt install -y hostapd dnsmasq nginx python3-venv python3-pip net-tools

echo "==> Writing /etc/hostapd/hostapd.conf ..."
sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=${WIFI_IFACE}
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=1
wmm_enabled=0
auth_algs=1
wpa=2
wpa_passphrase=${WIFI_PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

echo "==> Writing /etc/default/hostapd ..."
sudo tee /etc/default/hostapd > /dev/null <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

echo "==> Backing up and writing /etc/dnsmasq.conf ..."
if [ -f /etc/dnsmasq.conf ] && [ ! -f /etc/dnsmasq.conf.backup ]; then
  sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
fi

sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=${WIFI_IFACE}
bind-interfaces
dhcp-range=${DHCP_START},${DHCP_END},255.255.255.0,12h
EOF

echo "==> Creating hotspot IP script ..."
sudo tee /usr/local/bin/set-hotspot-ip.sh > /dev/null <<EOF
#!/bin/bash
sleep 1
ip addr flush dev ${WIFI_IFACE} || true
ip addr add ${HOTSPOT_IP}/24 dev ${WIFI_IFACE}
ip link set ${WIFI_IFACE} up
EOF

sudo chmod +x /usr/local/bin/set-hotspot-ip.sh

echo "==> Creating hotspot-ip service ..."
sudo tee /etc/systemd/system/hotspot-ip.service > /dev/null <<EOF
[Unit]
Description=Set Hotspot IP (after hostapd AP is up)
After=network.target hostapd.service
Wants=hostapd.service
Before=dnsmasq.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-hotspot-ip.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "==> Ordering dnsmasq after hotspot-ip (boot-safe) ..."
sudo mkdir -p /etc/systemd/system/dnsmasq.service.d
sudo tee /etc/systemd/system/dnsmasq.service.d/10-hotspot-order.conf > /dev/null <<EOF
[Unit]
After=hotspot-ip.service
EOF

echo "==> Creating dgx-app service ..."
sudo tee /etc/systemd/system/${APP_SERVICE}.service > /dev/null <<EOF
[Unit]
Description=DGX App
After=network.target NetworkManager.service
Wants=network.target

[Service]
User=${APP_USER}
WorkingDirectory=${APP_DIR}
Environment=DGX_APP_PORT=${APP_PORT}
ExecStart=${APP_DIR}/.venv/bin/uvicorn main:app --host 0.0.0.0 --port ${APP_PORT}
ExecStartPost=-/bin/sleep 5
ExecStartPost=-/bin/bash ${REPO_ROOT}/scripts/maybe_start_hotspot_stack.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "==> Updating NetworkManager config ..."
if ! sudo grep -q "unmanaged-devices=interface-name:${WIFI_IFACE}" /etc/NetworkManager/NetworkManager.conf 2>/dev/null; then
  sudo tee -a /etc/NetworkManager/NetworkManager.conf > /dev/null <<EOF

[keyfile]
unmanaged-devices=interface-name:${WIFI_IFACE}
EOF
fi

echo "==> Creating nginx site config ..."
sudo tee /etc/nginx/sites-available/app > /dev/null <<EOF
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        # Long docker / compose operations (if ever proxied synchronously)
        proxy_connect_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_read_timeout 3600s;
    }
}
EOF

if [ ! -L /etc/nginx/sites-enabled/app ]; then
  sudo ln -s /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
fi

if [ -f /etc/nginx/sites-enabled/default ]; then
  sudo rm -f /etc/nginx/sites-enabled/default
fi

echo "==> Reloading systemd ..."
sudo systemctl daemon-reload

echo "==> Enabling services ..."
sudo systemctl enable hotspot-ip
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable nginx
sudo systemctl enable ${APP_SERVICE}

echo "==> Restarting NetworkManager ..."
sudo systemctl restart NetworkManager

echo "==> Starting services ..."
sudo systemctl restart hostapd
sudo systemctl start hotspot-ip
sudo systemctl restart dnsmasq
sudo systemctl restart nginx
# Never stop/restart ${APP_SERVICE} from shell — uvicorn keeps running; hotspot_enable.sh uses this marker.
sudo mkdir -p /var/lib/dgx-hotspot
sudo touch /var/lib/dgx-hotspot/configured

echo
echo "Setup complete."
echo "Connect to Wi-Fi: ${SSID}"
echo "Open: http://${HOTSPOT_IP}"

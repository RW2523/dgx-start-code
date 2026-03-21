#!/bin/bash
# Apply hostapd → hotspot-ip → dnsmasq ordering on an existing install (no apt).
# Run: sudo ./apply_hotspot_order_fix.sh
set -e

WIFI_IFACE="wlP9s9"
HOTSPOT_IP="10.10.0.1"

echo "==> Updating /usr/local/bin/set-hotspot-ip.sh ..."
tee /usr/local/bin/set-hotspot-ip.sh > /dev/null <<EOF
#!/bin/bash
sleep 1
ip addr flush dev ${WIFI_IFACE} || true
ip addr add ${HOTSPOT_IP}/24 dev ${WIFI_IFACE}
ip link set ${WIFI_IFACE} up
EOF
chmod +x /usr/local/bin/set-hotspot-ip.sh

echo "==> Updating hotspot-ip.service ..."
tee /etc/systemd/system/hotspot-ip.service > /dev/null <<EOF
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

echo "==> dnsmasq ordering drop-in ..."
mkdir -p /etc/systemd/system/dnsmasq.service.d
tee /etc/systemd/system/dnsmasq.service.d/10-hotspot-order.conf > /dev/null <<EOF
[Unit]
After=hotspot-ip.service
EOF

systemctl daemon-reload

echo "==> Restarting stack in correct order ..."
systemctl start hostapd
systemctl start hotspot-ip
systemctl restart dnsmasq

echo "Done."

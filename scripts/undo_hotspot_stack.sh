#!/bin/bash
set -e

WIFI_IFACE="${WIFI_IFACE:-wlP9s9}"

echo "==> Stopping services (dgx-app not touched — app keeps running)..."
sudo systemctl stop hostapd || true
sudo systemctl stop dnsmasq || true
sudo systemctl stop hotspot-ip || true
sudo systemctl stop nginx || true

echo "==> Disabling hotspot-related units (not dgx-app)..."
sudo systemctl disable hostapd || true
sudo systemctl disable dnsmasq || true
sudo systemctl disable hotspot-ip || true
sudo systemctl disable nginx || true

echo "==> Removing hotspot IP..."
sudo ip addr flush dev ${WIFI_IFACE} || true

echo "==> Restoring NetworkManager control..."
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
  sudo sed -i "/unmanaged-devices=interface-name:${WIFI_IFACE}/d" /etc/NetworkManager/NetworkManager.conf
fi

echo "==> Removing hotspot netplan file..."
sudo rm -f /etc/netplan/90-hotspot.yaml || true

echo "==> Removing dnsmasq hotspot ordering drop-in..."
sudo rm -f /etc/systemd/system/dnsmasq.service.d/10-hotspot-order.conf || true
sudo systemctl daemon-reload || true

echo "==> Clearing hotspot configured marker (next enable will re-run setup if needed)..."
sudo rm -f /var/lib/dgx-hotspot/configured || true

echo "==> Applying netplan..."
sudo netplan apply || true

echo "==> Restarting networking..."
sudo systemctl restart NetworkManager
sudo systemctl restart wpa_supplicant || true

echo "==> Done. Current network devices:"
nmcli device status || true

#!/bin/bash
set -e

# hostapd first: AP mode can clear an IP set earlier; dnsmasq needs 10.10.0.1 on wlP9s9.
# Does not start/stop dgx-app — the FastAPI app stays running under systemd.
echo "==> Starting hotspot stack (hostapd → hotspot-ip → dnsmasq → nginx)..."
sudo systemctl start hostapd
sudo systemctl start hotspot-ip
sudo systemctl restart dnsmasq
sudo systemctl start nginx

echo "==> Status:"
sudo systemctl --no-pager --full status hotspot-ip || true
sudo systemctl --no-pager --full status hostapd || true
sudo systemctl --no-pager --full status dnsmasq || true
sudo systemctl --no-pager --full status nginx || true

echo
echo "Hotspot stack started."
rm -f /tmp/dgx-hotspot-skip-autostart
# Remove legacy file from older installs (no longer written).
sudo rm -f /var/lib/dgx-hotspot/autostart-suppressed 2>/dev/null || true

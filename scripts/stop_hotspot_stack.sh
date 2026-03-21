#!/bin/bash
set -e

echo "==> Stopping hotspot stack (hostapd, dnsmasq, hotspot-ip, nginx) — dgx-app left running..."
sudo systemctl stop hostapd || true
sudo systemctl stop dnsmasq || true
sudo systemctl stop hotspot-ip || true
sudo systemctl stop nginx || true

echo "Hotspot stack stopped (configs unchanged; use hotspot_disable.sh or undo_hotspot_stack.sh for full Wi‑Fi reset)."

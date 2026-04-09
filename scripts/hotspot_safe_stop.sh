#!/bin/bash
# Safety stop: block hotspot autostart (same skip file as Disable) and stop AP/DHCP/nginx
# only — does NOT run undo_hotspot_stack (no NetworkManager restart). Use when you want the
# radio off without a full client-Wi‑Fi reset, or as an extra guard against autostart loops.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_FLAG=/tmp/dgx-hotspot-skip-autostart
HOTSPOT_USER="${DG_HOTSPOT_USER:-echomind}"

echo "==> Safety: block hotspot autostart until Enable or reboot..."
touch "$SKIP_FLAG"
chown "${HOTSPOT_USER}:${HOTSPOT_USER}" "$SKIP_FLAG" 2>/dev/null || true

echo "==> stop_hotspot_stack.sh (no undo)..."
sudo bash "${SCRIPT_DIR}/stop_hotspot_stack.sh"

echo
echo "Safe stop complete. Dashboard keeps running. Use Disable for full Wi‑Fi restore, or Enable to turn the hotspot on again."

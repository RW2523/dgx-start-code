#!/bin/bash
# Combined "off" flow: stop hotspot services, then undo (restore NetworkManager / netplan / etc.).
# Never stops dgx-app / uvicorn — Wi‑Fi returns to normal client use while the API keeps running.
#
# Set skip-autostart FIRST so any dgx-app restart (e.g. after NetworkManager restart) does not
# immediately re-run hostapd/nginx via ExecStartPost. File lives in /tmp (echomind can remove it
# from start_hotspot_stack without extra sudo); cleared on reboot → hotspot on at boot again.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_FLAG=/tmp/dgx-hotspot-skip-autostart
HOTSPOT_USER="${DG_HOTSPOT_USER:-echomind}"

echo "==> Marking hotspot autostart suppressed (until successful Enable or reboot)..."
touch "$SKIP_FLAG"
chown "${HOTSPOT_USER}:${HOTSPOT_USER}" "$SKIP_FLAG" 2>/dev/null || true

echo "==> stop_hotspot_stack.sh ..."
sudo bash "${SCRIPT_DIR}/stop_hotspot_stack.sh"

echo "==> undo_hotspot_stack.sh ..."
sudo bash "${SCRIPT_DIR}/undo_hotspot_stack.sh"

echo
echo "Hotspot disable complete. dgx-app left running on :28734."

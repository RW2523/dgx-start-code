#!/bin/bash
# Combined "off" flow: stop hotspot services, then undo (restore NetworkManager / netplan / etc.).
# Never stops dgx-app / uvicorn — Wi‑Fi returns to normal client use while the API keeps running.
#
# Touch skip-autostart FIRST: undo removes the configured marker; if dgx-app restarts (Restart=always),
# ExecStartPost must not run hotspot_enable immediately. File is in /tmp → cleared on reboot.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_FLAG=/tmp/dgx-hotspot-skip-autostart
HOTSPOT_USER="${DG_HOTSPOT_USER:-echomind}"

echo "==> Suppressing hotspot autostart until Enable or reboot (survives dgx-app restart)..."
touch "$SKIP_FLAG"
chown "${HOTSPOT_USER}:${HOTSPOT_USER}" "$SKIP_FLAG" 2>/dev/null || true

echo "==> stop_hotspot_stack.sh ..."
sudo "${SCRIPT_DIR}/stop_hotspot_stack.sh"

echo "==> undo_hotspot_stack.sh ..."
sudo "${SCRIPT_DIR}/undo_hotspot_stack.sh"

echo
echo "Hotspot disable complete. dgx-app left running on :28734."

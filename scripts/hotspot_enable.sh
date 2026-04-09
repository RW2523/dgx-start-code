#!/bin/bash
# Combined "on" flow: first time runs setup (packages + configs), then always starts hotspot stack.
# Never stops or restarts dgx-app / uvicorn.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER=/var/lib/dgx-hotspot/configured

if [ ! -f "$MARKER" ]; then
  echo "==> No marker at $MARKER — first-time setup_hotspot_stack.sh ..."
  sudo bash "${SCRIPT_DIR}/setup_hotspot_stack.sh"
else
  echo "==> Hotspot already configured — skipping setup."
fi

echo "==> start_hotspot_stack.sh ..."
sudo bash "${SCRIPT_DIR}/start_hotspot_stack.sh"

echo
echo "Hotspot enable complete. dgx-app on :28734 was not stopped."

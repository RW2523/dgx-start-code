#!/bin/bash
# Combined "off" flow: stop hotspot services, then undo (restore NetworkManager / netplan / etc.).
# Never stops dgx-app / uvicorn — Wi‑Fi returns to normal client use while the API keeps running.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> stop_hotspot_stack.sh ..."
sudo bash "${SCRIPT_DIR}/stop_hotspot_stack.sh"

echo "==> undo_hotspot_stack.sh ..."
sudo bash "${SCRIPT_DIR}/undo_hotspot_stack.sh"

echo
echo "Hotspot disable complete. dgx-app left running on :8000."

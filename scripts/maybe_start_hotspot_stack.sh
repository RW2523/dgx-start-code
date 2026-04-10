#!/bin/bash
# Called from dgx-app.service ExecStartPost after uvicorn starts (every service start, including
# Restart=always). Disable/Safe stop create /tmp/dgx-hotspot-skip-autostart so a restart does NOT
# immediately run hotspot_enable (undo removes the configured marker — without this skip, the next
# dgx-app start would treat the box as "never configured" and turn the AP back on).
# /tmp is cleared on reboot → cold boot still runs enable/start as usual.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_FLAG=/tmp/dgx-hotspot-skip-autostart
MARKER=/var/lib/dgx-hotspot/configured

if [ -f "$SKIP_FLAG" ]; then
  echo "Skipping hotspot autostart ($SKIP_FLAG — use Enable in the dashboard; gone after reboot)."
  exit 0
fi

# Must use: sudo /path/script.sh (not bash script as normal user). Passwordless sudo is granted
# per script path in install_passwordless_sudo.sh; inner sudo systemctl calls expect this.
if [ ! -f "$MARKER" ]; then
  echo "==> Hotspot not configured — hotspot_enable.sh (setup + start) ..."
  exec sudo "${SCRIPT_DIR}/hotspot_enable.sh"
fi

exec sudo "${SCRIPT_DIR}/start_hotspot_stack.sh"

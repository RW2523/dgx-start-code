#!/bin/bash
# Called from dgx-app.service ExecStartPost only. Does NOT replace start_hotspot_stack.sh
# for explicit "Enable" / API — those invoke start_hotspot_stack.sh directly.
#
# If the user disabled the hotspot from the dashboard, this file exists (under /tmp, cleared
# on typical reboot) until a successful start_hotspot_stack removes it. Prevents a loop:
# disable → NetworkManager/dgx-app bounce → ExecStartPost must not turn AP back on.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_FLAG=/tmp/dgx-hotspot-skip-autostart

if [ -f "$SKIP_FLAG" ]; then
  echo "Skipping hotspot autostart ($SKIP_FLAG present — use Enable in the dashboard; reboot also clears this file)."
  exit 0
fi

exec bash "${SCRIPT_DIR}/start_hotspot_stack.sh"

#!/bin/bash
# Install sudo rules so dgx-app (or your user) can run hotspot scripts without a TTY/password.
# Web UIs and systemd services have no terminal — sudo needs NOPASSWD for these exact paths.
#
# Usage (once, from a real terminal with your password):
#   cd /home/echomind/dgx-local-app/scripts
#   chmod +x install_passwordless_sudo.sh
#   ./install_passwordless_sudo.sh
#
# It will ask for your password once to write /etc/sudoers.d/dgx-hotspot
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Override if dgx-app runs as another user: DG_HOTSPOT_SUDO_USER=foo ./install_passwordless_sudo.sh
TARGET_USER="${DG_HOTSPOT_SUDO_USER:-${SUDO_USER:-${USER:-echomind}}}"
SUDOERS_FILE="dgx-hotspot"
SUDOERS_PATH="/etc/sudoers.d/${SUDOERS_FILE}"

SCRIPTS=(
  "${REPO_ROOT}/scripts/hotspot_enable.sh"
  "${REPO_ROOT}/scripts/hotspot_disable.sh"
  "${REPO_ROOT}/scripts/setup_hotspot_stack.sh"
  "${REPO_ROOT}/scripts/start_hotspot_stack.sh"
  "${REPO_ROOT}/scripts/stop_hotspot_stack.sh"
  "${REPO_ROOT}/scripts/undo_hotspot_stack.sh"
  "${REPO_ROOT}/scripts/apply_hotspot_order_fix.sh"
)

for s in "${SCRIPTS[@]}"; do
  if [[ ! -f "$s" ]]; then
    echo "Missing script (create or fix path): $s" >&2
    exit 1
  fi
  if [[ ! -x "$s" ]]; then
    echo "Making executable: $s"
    chmod +x "$s" || true
  fi
done

TMP="$(mktemp)"
{
  echo "# Managed by dgx-local-app — passwordless sudo for hotspot UI + systemd ExecStartPost"
  echo "# systemd has no TTY; many distros use 'Defaults requiretty' — override per script:"
  for s in "${SCRIPTS[@]}"; do
    echo "Defaults!${s} !requiretty"
  done
  for s in "${SCRIPTS[@]}"; do
    echo "${TARGET_USER} ALL=(root) NOPASSWD: ${s}"
  done
} >"$TMP"

echo "==> Validating sudoers syntax..."
sudo visudo -cf "$TMP"

echo "==> Installing ${SUDOERS_PATH} ..."
sudo install -m 0440 "$TMP" "$SUDOERS_PATH"
rm -f "$TMP"

echo
echo "Done. User '${TARGET_USER}' may now run:"
for s in "${SCRIPTS[@]}"; do echo "  sudo $s"; done
echo "without a password. Restart dgx-app and try the web buttons again."

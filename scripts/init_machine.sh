#!/bin/bash
# One-shot after git clone: make shell scripts executable (required for sudoers exact paths).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
find "$REPO_ROOT/scripts" -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} \;
echo "==> Executable: scripts/*.sh under $REPO_ROOT"
echo "Next: follow setup.md (Python venv, sudoers, systemd)."

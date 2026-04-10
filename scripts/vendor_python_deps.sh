#!/bin/bash
# Run once while ONLINE to download FastAPI/uvicorn wheels + dependencies into the repo.
# Wheels are platform-specific (CPU/OS/Python version). Run this on the same kind of machine
# that will run offline, or use pip download --platform / --python-version for cross-vendor.
#
# Offline venv (from backend/):
#   python3 -m venv .venv && . .venv/bin/activate
#   pip install --no-index --find-links vendor/wheels -r requirements.txt
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQ="$ROOT/backend/requirements.txt"
OUT="$ROOT/backend/vendor/wheels"
mkdir -p "$OUT"
python3 -m pip download -r "$REQ" -d "$OUT"
echo "==> Downloaded wheels to $OUT"
echo "Offline install (from backend/):"
echo "  python3 -m venv .venv && . .venv/bin/activate"
echo "  pip install --no-index --find-links vendor/wheels -r requirements.txt"

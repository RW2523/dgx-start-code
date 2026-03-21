#!/bin/bash
# Build Personaplex client, free port 8998, start moshi.server in background.
# Run as the same user as dgx-app (echomind). No sudo.
#
# Override: PERSONAPLEX_ROOT, PERSONAPLEX_VENV, MOSHI_PORT
set -euo pipefail

ROOT="${PERSONAPLEX_ROOT:-${HOME}/Documents/plex/personaplex}"
CLIENT="${ROOT}/client"
VENV_ROOT="${PERSONAPLEX_VENV:-${HOME}/personaplex-venv}"
ACTIVATE="${VENV_ROOT}/bin/activate"
MOSHI_PORT="${MOSHI_PORT:-8998}"
LOG="${PERSONAPLEX_MOSHI_LOG:-/tmp/moshi-personaplex.log}"
PIDFILE="${PERSONAPLEX_MOSHI_PID:-/tmp/moshi-personaplex.pid}"

if [[ -s "${HOME}/.nvm/nvm.sh" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.nvm/nvm.sh"
fi

if [[ ! -f "${ACTIVATE}" ]]; then
  echo "ERROR: venv not found: ${ACTIVATE}" >&2
  exit 1
fi
if [[ ! -d "${CLIENT}" ]] || [[ ! -f "${CLIENT}/package.json" ]]; then
  echo "ERROR: client dir missing or no package.json: ${CLIENT}" >&2
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm not in PATH (install Node or add nvm to this user's profile)." >&2
  exit 1
fi

echo "==> npm run build (${CLIENT}) — last 20 lines printed; full log: /tmp/personaplex-npm-build.log"
cd "${CLIENT}"
set -o pipefail
npm run build 2>&1 | tee /tmp/personaplex-npm-build.log | tail -20

echo "==> Stop old moshi.server / vite / port ${MOSHI_PORT}"
pkill -f "moshi.server" 2>/dev/null || true
pkill -f "vite" 2>/dev/null || true
if command -v lsof >/dev/null 2>&1; then
  mapfile -t pids < <(lsof -ti:"${MOSHI_PORT}" -sTCP:LISTEN 2>/dev/null || true)
  if ((${#pids[@]})); then
    kill -9 "${pids[@]}" 2>/dev/null || true
  fi
fi
sleep 1

echo "==> Start moshi.server (background)"
cd "${ROOT}"
# shellcheck source=/dev/null
source "${ACTIVATE}"
SSL_DIR="$(mktemp -d)"
export SSL_DIR
: >"${LOG}"
# --host 0.0.0.0 so clients on the LAN / hotspot can reach port ${MOSHI_PORT} (default 8998).
nohup python -m moshi.server --host 0.0.0.0 --port "${MOSHI_PORT}" --fp8 --ssl "${SSL_DIR}" --static client/dist >>"${LOG}" 2>&1 &
echo $! >"${PIDFILE}"
sleep 2
if kill -0 "$(cat "${PIDFILE}")" 2>/dev/null; then
  echo "OK: moshi PID $(cat "${PIDFILE}")  log: ${LOG}  https://127.0.0.1:${MOSHI_PORT}/ (or this machine's IP)"
else
  echo "ERROR: moshi exited immediately. Last lines of ${LOG}:" >&2
  tail -40 "${LOG}" >&2
  exit 1
fi

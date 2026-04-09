#!/bin/bash
# Conversation button: ONLY what you run by hand — no npm build, no pkill, no port cleanup.
#   cd …/personaplex && source venv && SSL_DIR=$(mktemp -d) && python -m moshi.server …
# Runs moshi in the background so the web API can return (logs: /tmp/moshi-personaplex.log).
#
# Override: PERSONAPLEX_ROOT, PERSONAPLEX_VENV
set -euo pipefail

ROOT="${PERSONAPLEX_ROOT:-${HOME}/Documents/plex/personaplex}"
VENV_ROOT="${PERSONAPLEX_VENV:-${HOME}/personaplex-venv}"
ACTIVATE="${VENV_ROOT}/bin/activate"
LOG="${PERSONAPLEX_MOSHI_LOG:-/tmp/moshi-personaplex.log}"
PIDFILE="${PERSONAPLEX_MOSHI_PID:-/tmp/moshi-personaplex.pid}"

if [[ ! -f "${ACTIVATE}" ]]; then
  echo "ERROR: venv not found: ${ACTIVATE}" >&2
  exit 1
fi
if [[ ! -d "${ROOT}/client/dist" ]]; then
  echo "ERROR: client/dist missing at ${ROOT}/client/dist — build the client yourself first (npm run build)." >&2
  exit 1
fi

echo "==> cd ${ROOT} && source venv && mktemp SSL && moshi.server (background)"
cd "${ROOT}"
# shellcheck source=/dev/null
source "${ACTIVATE}"
SSL_DIR="$(mktemp -d)"
export SSL_DIR
: >"${LOG}"
nohup python -m moshi.server --fp8 --ssl "${SSL_DIR}" --static client/dist >>"${LOG}" 2>&1 &
echo $! >"${PIDFILE}"
sleep 2
if kill -0 "$(cat "${PIDFILE}")" 2>/dev/null; then
  echo "OK: moshi PID $(cat "${PIDFILE}")  log: ${LOG}"
else
  echo "ERROR: moshi exited immediately. Last lines of ${LOG}:" >&2
  tail -40 "${LOG}" >&2
  exit 1
fi

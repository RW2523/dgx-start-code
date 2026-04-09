#!/bin/bash
# Insert long proxy timeouts into nginx app site (avoids 60s cutoffs on slow API calls).
# Run: sudo ./patch_nginx_proxy_timeouts.sh
set -euo pipefail
SITE="${1:-/etc/nginx/sites-available/app}"
if [[ ! -f "$SITE" ]]; then
  echo "Missing $SITE" >&2
  exit 1
fi
if grep -q proxy_read_timeout "$SITE" 2>/dev/null; then
  echo "Already has proxy_read_timeout in $SITE"
  exit 0
fi
python3 <<PY
from pathlib import Path
p = Path("${SITE}")
text = p.read_text()
needle = "proxy_set_header X-Forwarded-Proto \$scheme;"
if needle not in text:
    raise SystemExit("Expected line not found; edit $SITE manually.")
if "proxy_read_timeout" in text:
    raise SystemExit("Already patched.")
block = """        proxy_connect_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_read_timeout 3600s;
"""
p.write_text(text.replace(needle, needle + "\n" + block, 1))
print("Updated", p)
PY
nginx -t
systemctl reload nginx
echo "nginx reloaded."

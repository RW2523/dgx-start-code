#!/bin/bash
# Re-fetch self-hosted dashboard fonts (Outfit + Source Sans 3) from Google Fonts.
# Run while online; writes backend/static/fonts/{fonts.css,*.woff2}. SIL OFL.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/backend/static/fonts"
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
URL='https://fonts.googleapis.com/css2?family=Outfit:wght@500;600;700&family=Source+Sans+3:ital,wght@0,400;0,600;1,400&display=swap'
mkdir -p "$OUT"
TMP="$(mktemp)"
curl -fsSL -A "$UA" "$URL" -o "$TMP"
grep -oE 'https://fonts\.gstatic\.com[^)]+' "$TMP" | sort -u | while read -r u; do
  curl -fsSL "$u" -o "$OUT/$(basename "$u")"
done
python3 - <<PY
import re, pathlib, sys
css = pathlib.Path("$TMP").read_text()
def sub(m):
    u = m.group(1)
    return "url(/static/fonts/" + u.rsplit("/", 1)[-1] + ")"
out = re.sub(r"url\((https://fonts\.gstatic\.com[^)]+)\)", sub, css)
pathlib.Path("$OUT/fonts.css").write_text(out)
PY
rm -f "$TMP"
echo "==> Fonts updated under $OUT"

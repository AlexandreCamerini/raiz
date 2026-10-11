#!/usr/bin/env bash
# radar_slug.sh — slug determinístico do tema: minúsculas, sem acento, hífens. Uso: radar_slug.sh "<tema>"
[ -n "$1" ] || { echo "FAIL: tema vazio" >&2; exit 1; }
command -v python3 >/dev/null || { echo "FAIL: python3 ausente" >&2; exit 1; }
python3 - "$1" <<'PY'
import re, sys, unicodedata
s = unicodedata.normalize("NFKD", sys.argv[1]).encode("ascii", "ignore").decode().lower()
s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
if not s: sys.exit("FAIL: tema sem caractere aproveitável")
print(s)
PY

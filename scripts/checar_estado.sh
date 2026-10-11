#!/usr/bin/env bash
# checar_estado.sh — .raiz/estado.json é JSON válido e toda bifurcação está bem formada
F="${1:-.raiz/estado.json}"
[ -f "$F" ] || { echo "FAIL: $F ausente"; exit 1; }
command -v jq >/dev/null || { echo "FAIL: jq ausente"; exit 1; }
jq empty "$F" 2>/dev/null || { echo "FAIL: $F não é JSON válido"; exit 1; }
rc=0
dp="$(jq -r 'if .decisao_pendente == null then "" else "x" end' "$F" 2>/dev/null)"
if [ -n "$dp" ]; then
  jq -e '.decisao_pendente.pergunta and .decisao_pendente.opcoes' "$F" >/dev/null 2>&1 \
    || { echo "FAIL: decisao_pendente sem pergunta ou opcoes"; rc=1; }
  n="$(jq '(.decisao_pendente.opcoes // []) | length' "$F" 2>/dev/null)"
  [ "${n:-0}" -ge 2 ] || { echo "FAIL: decisao_pendente com menos de 2 opções"; rc=1; }
fi
jq -e '(.historico_decisoes // []) | type=="array"' "$F" >/dev/null 2>&1 \
  || { echo "FAIL: historico_decisoes não é array"; rc=1; }
[ "$rc" = 0 ] && echo "checar_estado: ok"
exit "$rc"

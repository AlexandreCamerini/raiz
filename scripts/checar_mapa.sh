#!/usr/bin/env bash
# checar_mapa.sh — contrato mecânico do mapa do explorador
F="${1:-.raiz/auditoria/mapa.md}"
[ -f "$F" ] || { echo "FAIL: $F ausente"; exit 1; }
rc=0
if grep -nE '✓|✗|✔|✘|[Nn]ível de confiança|[Cc]onfiança:' "$F"; then
  echo "FAIL: marcações de veredito no mapa (linhas acima) — o explorador registra fatos, não julga"; rc=1
fi
for s in 'Invariantes lidos' 'Operação'; do
  grep -qE "^## ([0-9]+\.? )?$s" "$F" || { echo "FAIL: seção obrigatória ausente: ## $s"; rc=1; }
done
if grep -nE '^\| *Fato' "$F" | grep -v 'Saída'; then
  echo "FAIL: tabela sem a coluna 'Saída observada' (linhas acima)"; rc=1
fi
grep -qE '\.raiz-[0-9]' "$F" && { echo "FAIL: mapa referencia auditoria anterior — deve ser independente"; rc=1; }
[ "$rc" = 0 ] && echo "checar_mapa: ok"
exit "$rc"

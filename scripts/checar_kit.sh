#!/usr/bin/env bash
# checar_kit.sh — grep estrutural (mesmo espírito de checar_design.sh, não
# parser Swift completo): reprova cor/fonte solta fora do kit em qualquer
# .swift de App/Shared/, exceto Tokens.swift e TokensGerados.swift (onde o
# literal É o kit). Vira o comando do gate `kit` em .raiz/gates.json.
#
# Uso: checar_kit.sh [App/Shared]
set -uo pipefail
D="${1:-App/Shared}"

[ -d "$D" ] || { echo "FAIL: $D ausente"; exit 1; }

rc=0
n=0
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  [ "$base" = "Tokens.swift" ] && continue
  [ "$base" = "TokensGerados.swift" ] && continue

  while IFS=: read -r linha conteudo; do
    [ -n "$linha" ] || continue
    echo "FAIL: $f:$linha: cor de sistema solta fora do kit — ${conteudo#"${conteudo%%[![:space:]]*}"}"
    rc=1; n=$((n+1))
  done < <(grep -nE '\.(foregroundStyle|foregroundColor)\(\.[A-Za-z]' "$f")

  while IFS=: read -r linha conteudo; do
    [ -n "$linha" ] || continue
    echo "FAIL: $f:$linha: fonte de tamanho fixo fora do kit — ${conteudo#"${conteudo%%[![:space:]]*}"}"
    rc=1; n=$((n+1))
  done < <(grep -nE '\.font\(\.system\(size:' "$f")

  while IFS=: read -r linha conteudo; do
    [ -n "$linha" ] || continue
    echo "FAIL: $f:$linha: cor literal fora do kit — ${conteudo#"${conteudo%%[![:space:]]*}"}"
    rc=1; n=$((n+1))
  done < <(grep -nE 'Color\((red|hex):' "$f")
done < <(find "$D" -name '*.swift' -print0)

if [ "$rc" = 0 ]; then
  echo "checar_kit: ok"
else
  echo "checar_kit: $n ocorrência(s) fora do kit"
fi
exit "$rc"

#!/usr/bin/env bash
# Roda scripts/lint_modelos.sh contra as fixtures. Uso: bash evals/lint_modelos/rodar.sh
D="$(cd "$(dirname "$0")" && pwd)"
LINT="$D/../../scripts/lint_modelos.sh"
fail=0
# caso <dir> <rc esperado> <padrão grep esperado na saída ou "-">
caso() {
  local out rc
  out="$(bash "$LINT" "$D/$1" 2>&1)"; rc=$?
  if [ "$rc" = "$2" ] && { [ "$3" = "-" ] || printf '%s\n' "$out" | grep -q -- "$3"; }; then
    echo "PASS $1 (rc=$rc)"
  else
    echo "FAIL $1: esperado rc=$2 e saída ~ '$3'; obtido rc=$rc"; printf '%s\n' "$out" | sed 's/^/    | /'; fail=1
  fi
}
caso 1-effort-divergente 1 "FAIL alfa: matriz espera 'sonnet/medium', frontmatter tem 'sonnet/high'"
caso 2-alinhado          0 "lint_modelos: ok"
caso 3-matriz-ausente    1 "matriz ausente"
caso 4-agente-sem-entrada 0 "WARN gama: sem entrada"
caso 5-linha-malformada  1 "matriz.yaml:4: linha fora do formato"
[ "$fail" = 0 ] && echo "evals/lint_modelos: todos os casos ok" || echo "evals/lint_modelos: FALHOU"
exit "$fail"

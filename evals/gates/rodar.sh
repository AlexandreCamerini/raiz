#!/usr/bin/env bash
# Roda scripts/gates.sh contra evals/gates/casos/*.json. Uso: bash evals/gates/rodar.sh
D="$(cd "$(dirname "$0")" && pwd)"
GATES="$D/../../scripts/gates.sh"
export TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/raiz-evals-gates.XXXXXX")"
fail=0
# caso <arquivo> <rc esperado> <padrão que DEVE aparecer> <padrão que NÃO pode aparecer ou "-">
caso() {
  local f="$D/casos/$1" out rc ok=1
  out="$(bash "$GATES" "$f" 2>&1)"; rc=$?
  [ "$rc" = "$2" ] || ok=0
  printf '%s\n' "$out" | grep -q -- "$3" || ok=0
  if [ "$4" != "-" ] && printf '%s\n' "$out" | grep -q -- "$4"; then ok=0; fi
  if [ "$ok" = 1 ]; then echo "PASS $1 (rc=$rc)"
  else echo "FAIL $1: esperado rc=$2, contém '$3', não contém '$4'; obtido rc=$rc"; printf '%s\n' "$out" | sed 's/^/    | /'; fail=1; fi
}
# malformados: exit != 0 e NUNCA SKIP
for m in m1-array-de-string m2-gates-string m3-sem-id m4-comando-nao-string m5-bloqueante-string m6-gates-vazio m7-misto-valido-e-invalido m8-arquivo-vazio m9-id-com-barra m10-id-duplicado m12-id-quebra-de-linha; do
  caso "$m.json" 1 "FAIL" "SKIP"
done
caso m11-bloqueante-comando-so-espaco.json 1 "FAIL a: bloqueante sem comando" "PASS"
# regressão
caso r1-bem-formado-passa.json            0 "PASS ok" "FAIL"
caso r2-bloqueante-sem-comando.json       1 "FAIL a: bloqueante sem comando" "SKIP"
caso r3-nao-bloqueante-sem-comando.json   0 "SKIP a: não bloqueante e sem comando" "FAIL"
caso r4-bloqueante-falha.json             1 "FAIL a — d" "SKIP"
caso r5-nao-bloqueante-falha-warn.json    0 "WARN a — d" "FAIL"
caso inexistente.json                     1 "ausente" "SKIP"
rm -rf "$TMPDIR"
[ "$fail" = 0 ] && echo "evals/gates: todos os casos ok" || echo "evals/gates: FALHOU"
exit "$fail"

#!/usr/bin/env bash
# gates.sh — runner fail-closed. Lê .raiz/gates.json do projeto:
# { "gates": [ { "id": "build", "bloqueante": true, "comando": "xcodebuild ...", "dica": "..." } ] }
set -uo pipefail
F="${1:-.raiz/gates.json}"
LOG="${TMPDIR:-/tmp}/raiz-gates"; mkdir -p "$LOG"
command -v jq >/dev/null || { echo "FAIL: jq é obrigatório para os gates"; exit 1; }
[ -f "$F" ] || { echo "FAIL: $F ausente — sem gates declarados nada pode ser provado"; exit 1; }
# Validação de esquema ANTES do laço: gate malformado = FAIL, nunca SKIP (fail-closed).
errs="$(jq -rs '
  if length != 1 then "arquivo vazio ou com mais de um documento JSON"
  else .[0].gates as $g
  | if ($g | type) != "array" then ".gates não é array (tipo: \($g | type))"
    elif ($g | length) == 0 then "nenhum gate declarado"
    else ($g | map(select(type == "object") | .id)) as $ids
      | ($g | to_entries[] | .key as $i | .value as $x
      | if ($x | type) != "object" then "gates[\($i)]: não é objeto (tipo: \($x | type))"
        elif (($x.id | type) != "string") or ($x.id == "") then "gates[\($i)]: id ausente ou não é string não vazia"
        elif ($x.id | test("^[A-Za-z0-9_-][A-Za-z0-9._-]*$") | not) or ($x.id | test("^\\.+$")) then "gates[\($i)]: id inválido (use [A-Za-z0-9._-], sem / nem ..): \($x.id | @json)"
        elif ($x | has("bloqueante")) and (($x.bloqueante | type) != "boolean") then "gates[\($i)] (\($x.id)): bloqueante deve ser boolean ou ausente (tipo: \($x.bloqueante | type))"
        elif ($x | has("comando")) and (($x.comando | type) != "string") then "gates[\($i)] (\($x.id)): comando deve ser string ou ausente (tipo: \($x.comando | type))"
        elif ($x | has("dica")) and (($x.dica | type) != "string") then "gates[\($i)] (\($x.id)): dica deve ser string ou ausente (tipo: \($x.dica | type))"
        else empty end),
      (if ($ids | length) != ($ids | unique | length) then "ids duplicados" else empty end)
    end
  end' "$F" 2>&1)" || { echo "FAIL: $F inválido ou ilegível (jq: $errs)"; exit 1; }
if [ -n "$errs" ]; then
  printf '%s\n' "$errs" | while IFS= read -r l; do echo "FAIL $F: $l"; done
  exit 1
fi
n="$(jq '.gates | length' "$F")" || { echo "FAIL: $F inválido"; exit 1; }
rc=0; i=0
while [ "$i" -lt "$n" ]; do
  # qualquer erro de jq aqui = FAIL (nunca cair no ramo SKIP)
  id="$(jq -r ".gates[$i].id" "$F")" \
    && blk="$(jq -r "if .gates[$i].bloqueante == false then \"false\" else \"true\" end" "$F")" \
    && cmd="$(jq -r ".gates[$i].comando // empty" "$F")" \
    && dica="$(jq -r ".gates[$i].dica // empty" "$F")" \
    || { echo "FAIL gates[$i]: erro ao ler o gate com jq"; rc=1; i=$((i+1)); continue; }
  if [ -z "${cmd//[[:space:]]/}" ]; then  # só espaço conta como sem comando
    if [ "$blk" = "true" ]; then echo "FAIL $id: bloqueante sem comando"; rc=1
    else echo "SKIP $id: não bloqueante e sem comando"; fi
  elif bash -c "$cmd" >"$LOG/$id.log" 2>&1; then
    echo "PASS $id"
  elif [ "$blk" = "true" ]; then
    echo "FAIL $id — ${dica:-sem dica} (log: $LOG/$id.log)"; rc=1
  else
    echo "WARN $id — ${dica:-sem dica} (log: $LOG/$id.log)"
  fi
  i=$((i+1))
done
exit "$rc"

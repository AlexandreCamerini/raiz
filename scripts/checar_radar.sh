#!/usr/bin/env bash
# checar_radar.sh — contrato mecânico de uma rodada do radar (schemas/sinal.schema.json, via jq).
# Uso: checar_radar.sh <tema>/rodadas/<AAAAMMDD-HHMM>
# FAIL: nenhuma lente válida; campo obrigatório ausente; url/data fora do formato; id/lente/tipo/confiança
#       inválidos; auditoria ausente ou incompleta na profundidade completa.
# WARN: lente com <8 sinais; lente ausente ou descartada (lacuna); fronteira com sinal >18 meses.
R="${1:?uso: checar_radar.sh <rodada>}"
R="${R%/}"
[ -d "$R" ] || { echo "FAIL: rodada $R não existe"; exit 1; }
command -v jq >/dev/null || { echo "FAIL: jq ausente"; exit 1; }
rc=0

prof="completa"
if [ -f "$R/status.json" ]; then
  jq empty "$R/status.json" 2>/dev/null || { echo "FAIL: status.json não é JSON válido"; exit 1; }
  prof="$(jq -r '.profundidade // "completa"' "$R/status.json")"
  [ "$(jq -r '.estado // ""' "$R/status.json")" = "falhou" ] && { echo "FAIL: rodada marcada como falhou em status.json"; exit 1; }
else
  echo "WARN: status.json ausente — assumindo profundidade completa"
fi
case "$prof" in
  completa) lentes="consolidado fronteira adjacente ui-ux" ;;
  rapida)   lentes="fronteira consolidado" ;;
  *) echo "FAIL: profundidade '$prof' desconhecida (completa|rapida)"; exit 1 ;;
esac

abrev() { case "$1" in consolidado) echo CON;; fronteira) echo FRO;; adjacente) echo ADJ;; ui-ux) echo UIX;; esac; }

# Limite da lente fronteira: 18 meses antes do mês da rodada (nome AAAAMMDD-HHMM).
nome="$(basename "$R")"; limite=""
if printf '%s' "$nome" | grep -qE '^[0-9]{8}-[0-9]{4}$'; then
  t=$(( 10#${nome:0:4} * 12 + 10#${nome:4:2} - 1 - 18 ))
  limite="$(printf '%04d-%02d' $(( t / 12 )) $(( t % 12 + 1 )))"
else
  echo "WARN: nome da rodada '$nome' fora do formato AAAAMMDD-HHMM"
fi

VALIDA='
def req: ["id","lente","titulo","fato","por_que_sinal","url","data_publicacao","tipo","confianca"];
def str($k): (.[$k] | type) == "string" and (.[$k] | length) > 0;
if type != "array" then "não é um array de sinais"
else
  (to_entries[] | .key as $i | .value as $s | ($s.id? // "?") as $id |
    if ($s | type) != "object" then "item \($i): não é objeto"
    else
      (req[] as $k | select($s | str($k) | not) | "item \($i) (\($id)): campo obrigatório \($k) ausente ou vazio"),
      (select(($s | str("url")) and ($s.url | test("^https?://[^\\s]+$") | not)) | "item \($i) (\($id)): url fora do formato http/https"),
      (select(($s | str("data_publicacao")) and ($s.data_publicacao | test("^[0-9]{4}-(0[1-9]|1[0-2])(-(0[1-9]|[12][0-9]|3[01]))?$") | not)) | "item \($i) (\($id)): data_publicacao fora de AAAA-MM-DD ou AAAA-MM"),
      (select(($s | str("lente")) and $s.lente != $lente) | "item \($i) (\($id)): lente \($s.lente) no arquivo de \($lente)"),
      (select(($s | str("id")) and ($s.id | test("^" + $ab + "-[0-9]{2,}$") | not)) | "item \($i) (\($id)): id fora de \($ab)-<nn>"),
      (select(($s | str("tipo")) and ([$s.tipo] | inside(["produto","paper","tese","reclamacao","analogia","regulacao","padrao-ui"]) | not)) | "item \($i) (\($id)): tipo \($s.tipo) inválido"),
      (select(($s | str("confianca")) and ([$s.confianca] | inside(["alta","media","baixa"]) | not)) | "item \($i) (\($id)): confianca \($s.confianca) inválida")
    end),
  (map(.id? // empty) | group_by(.) | map(select(length > 1) | .[0])[] | "id duplicado: \(.)")
end'

validas=0; set --   # "$@" = lentes válidas
for l in $lentes; do
  f="$R/$l.json"; ab="$(abrev "$l")"
  if [ ! -f "$f" ]; then
    if [ -f "$f.descartado" ]; then echo "WARN: lente $l descartada (lacuna)"; else echo "WARN: lente $l ausente (lacuna)"; fi
    continue
  fi
  jq empty "$f" 2>/dev/null || { echo "FAIL: $l.json não é JSON válido"; rc=1; continue; }
  erros="$(jq -r --arg lente "$l" --arg ab "$ab" "$VALIDA" "$f")" || { echo "FAIL: $l.json: validação não executou"; rc=1; continue; }
  if [ -n "$erros" ]; then
    printf '%s\n' "$erros" | sed "s/^/FAIL: $l.json: /"; rc=1; continue
  fi
  n="$(jq length "$f")"
  if [ "$n" -lt 8 ]; then echo "WARN: lente $l com $n sinais (mínimo 8)"; else echo "lente $l: $n sinais"; fi
  if [ "$l" = "fronteira" ] && [ -n "$limite" ]; then
    jq -r --arg lim "$limite" '.[] | select(.data_publicacao[0:7] < $lim) | "WARN: fronteira \(.id) publicado em \(.data_publicacao), antes de \($lim) (>18 meses)"' "$f"
  fi
  set -- "$@" "$f"
  validas=$((validas + 1))
done
[ "$validas" -ge 1 ] || { echo "FAIL: nenhuma lente válida"; rc=1; }

if [ "$prof" = "completa" ] && [ "$validas" -ge 1 ]; then
  A="$R/auditoria.json"
  if [ ! -f "$A" ]; then echo "FAIL: auditoria.json ausente (profundidade completa)"; rc=1
  elif ! jq -e 'type == "array"' "$A" >/dev/null 2>&1; then echo "FAIL: auditoria.json não é um array"; rc=1
  else
    todos="$(jq -s 'add' "$@")" || { echo "FAIL: não leu os sinais das lentes válidas"; exit 1; }
    erros="$(jq -r --argjson s "$todos" '
      (to_entries[] | .key as $i | .value |
        (select((.id | type) != "string") | "item \($i): sem id"),
        (select([.status] | inside(["OK","WEAK","UNVERIFIED","SKIPPED"]) | not) | "\(.id // $i): status \(.status) inválido"),
        (select((.obs | type) != "string") | "\(.id // $i): obs ausente")),
      (map({(.id | tostring): .status}) | add // {}) as $st |
      ($s[] | select(.confianca == "alta") | select(($st[.id] // "SKIPPED") == "SKIPPED") | "\(.id): confiança alta sem verificação"),
      ([$s[] | select(.confianca != "alta")] as $d |
        ([$d[] | select(($st[.id] // "SKIPPED") != "SKIPPED")] | length) as $v |
        select($d | length > 0) | select($v * 2 < ($d | length)) |
        "verificados \($v) de \($d | length) sinais não-alta (mínimo 50%)")
    ' "$A")" || { echo "FAIL: auditoria.json: conferência não executou"; exit 1; }
    orfaos="$(jq -r --argjson s "$todos" '($s | map(.id)) as $ids | [.[] | select((.id | type) == "string" and ([.id] | inside($ids) | not)) | .id] | select(length > 0) | join(", ")' "$A")"
    [ -n "$orfaos" ] && echo "WARN: auditoria.json cita ids fora das lentes válidas (ignorados): $orfaos"
    if [ -n "$erros" ]; then printf '%s\n' "$erros" | sed 's/^/FAIL: auditoria.json: /'; rc=1
    else echo "auditoria: $(jq -r 'group_by(.status) | map("\(.[0].status)=\(length)") | join(" ")' "$A")"; fi
  fi
fi

[ "$rc" = 0 ] && echo "checar_radar: ok ($validas lente(s) válida(s), profundidade $prof)"
exit "$rc"

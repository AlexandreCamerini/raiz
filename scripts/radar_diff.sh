#!/usr/bin/env bash
# radar_diff.sh — incorpora a rodada mais recente de um tema ao acumulado e grava o diff contra a anterior.
# Uso: radar_diff.sh ~/.raiz/radar/<slug>
# Grava <rodada>/diff.md + <rodada>/diff.json e atualiza <tema>/sinais.jsonl (uma linha por URL normalizada).
# "Anterior" = a rodada incorporada mais recente (tem diff.md). Rodada com diff.md já foi incorporada.
# Fail-closed: rodada falhou, já incorporada, checar_radar falhou ou acumulado inconsistente → nada é gravado.
T="${1:?uso: radar_diff.sh <tema-dir>}"
T="${T%/}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
command -v jq >/dev/null || { echo "FAIL: jq ausente"; exit 1; }
[ -d "$T/rodadas" ] || { echo "FAIL: $T/rodadas não existe"; exit 1; }

atual=""; anterior=""
for d in $(ls -1 "$T/rodadas" | grep -E '^[0-9]{8}-[0-9]{4}$' | sort); do
  [ -d "$T/rodadas/$d" ] || continue
  [ -n "$atual" ] && [ -f "$T/rodadas/$atual/diff.md" ] && anterior="$atual"
  atual="$d"
done
[ -n "$atual" ] || { echo "FAIL: nenhuma rodada AAAAMMDD-HHMM em $T/rodadas"; exit 1; }
R="$T/rodadas/$atual"
[ -f "$R/diff.md" ] && { echo "FAIL: rodada $atual já incorporada (diff.md existe)"; exit 1; }
if [ -f "$R/status.json" ] && [ "$(jq -r '.estado // ""' "$R/status.json" 2>/dev/null)" = "falhou" ]; then
  echo "FAIL: rodada $atual marcada como falhou — acumulado e diff não atualizados"; exit 1
fi
bash "$AQUI/checar_radar.sh" "$R" || { echo "FAIL: checar_radar reprovou $atual — acumulado e diff não atualizados"; exit 1; }

ACC="$T/sinais.jsonl"
if [ -n "$anterior" ] && [ ! -s "$ACC" ]; then echo "FAIL: há rodada anterior ($anterior) mas $ACC está vazio ou ausente"; exit 1; fi
if [ -z "$anterior" ] && [ -s "$ACC" ]; then echo "FAIL: $ACC existe sem rodada incorporada — acumulado inconsistente"; exit 1; fi

prof="$(jq -r '.profundidade // "completa"' "$R/status.json" 2>/dev/null || echo completa)"
case "$prof" in rapida) lentes="consolidado fronteira" ;; *) lentes="consolidado fronteira adjacente ui-ux" ;; esac

tmp="$(mktemp -d "$T/.tmp.XXXXXX")" || { echo "FAIL: não criou diretório temporário em $T (gravável?)"; exit 1; }
trap 'rm -rf "$tmp"' EXIT
: > "$tmp/cur.jsonl"; : > "$tmp/lacunas.txt"
for l in $lentes; do
  if [ -f "$R/$l.json" ]; then jq -c '.[]' "$R/$l.json" >> "$tmp/cur.jsonl"
  elif [ -f "$R/$l.json.descartado" ]; then echo "lente $l descartada (falhou no checar_radar duas vezes)" >> "$tmp/lacunas.txt"
  else echo "lente $l ausente" >> "$tmp/lacunas.txt"; fi
done
[ -f "$R/status.json" ] && jq -r '(.lacunas // [])[] | tostring' "$R/status.json" >> "$tmp/lacunas.txt"
if [ -f "$R/auditoria.json" ]; then cp "$R/auditoria.json" "$tmp/aud.json"; else echo '[]' > "$tmp/aud.json"; fi
[ -f "$ACC" ] && cp "$ACC" "$tmp/acc.jsonl" || : > "$tmp/acc.jsonl"

jq -n \
  --slurpfile cur "$tmp/cur.jsonl" --slurpfile acc "$tmp/acc.jsonl" --slurpfile aud "$tmp/aud.json" \
  --arg atual "$atual" --arg anterior "$anterior" --rawfile lac "$tmp/lacunas.txt" '
def chave:
  sub("^[A-Za-z][A-Za-z0-9+.-]*://"; "") | sub("#.*$"; "")
  | (index("?")) as $q
  | (if $q then .[:$q] else . end) as $base
  | (if $q then .[$q + 1:] | split("&") | map(select(length > 0 and (ascii_downcase | startswith("utm_") | not))) | join("&") else "" end) as $qs
  | ($base | sub("^www\\."; ""; "i") | (index("/")) as $p
     | (if $p then (.[:$p] | ascii_downcase) + .[$p:] else ascii_downcase end) | sub("/+$"; "")) as $b
  | if $qs == "" then $b else $b + "?" + $qs end;
def dia($r): "\($r[0:4])-\($r[4:6])-\($r[6:8])";
(($aud[0] // []) | map({(.id | tostring): .status}) | add // {}) as $st
| ($aud[0] | length > 0) as $auditada
| ($cur | map(. + {chave: (.url | chave), auditoria: (if $auditada then ($st[.id] // "SKIPPED") else "sem auditoria" end)})) as $c0
| ($c0 | reduce .[] as $s ({vistos: {}, lista: []};
     if .vistos[$s.chave] then . else .vistos[$s.chave] = true | .lista += [$s] end) | .lista) as $c
| ($acc | map({(.chave): .}) | add // {}) as $A
| ($c | map({(.chave): true}) | add // {}) as $C
| (if $anterior == "" then "" else dia($anterior) end) as $d0
| [$c[] | select($A[.chave] | not)] as $novos
| {
    tema_rodada: $atual,
    anterior: (if $anterior == "" then null else $anterior end),
    linha_de_base: ($anterior == ""),
    novos_no_mundo: (if $anterior == "" then [] else
      [$novos[] | select(if (.data_publicacao | length) == 10 then .data_publicacao > $d0 else .data_publicacao > $d0[0:7] end)] end),
    novos_no_radar: (if $anterior == "" then [] else
      [$novos[] | select(if (.data_publicacao | length) == 10 then .data_publicacao <= $d0 else .data_publicacao <= $d0[0:7] end)] end),
    total_rodada: ($c | length),
    duplicados_na_rodada: (($c0 | length) - ($c | length)),
    por_lente: ($c | group_by(.lente) | map({(.[0].lente): length}) | add // {}),
    recorrentes: ([$c[] | select($A[.chave])] | length),
    atualizados: ([$c[] | select($A[.chave]) | select($A[.chave].data_publicacao != .data_publicacao)] | length),
    sumidos: (if $anterior == "" then 0 else ($c | map(.lente) | unique) as $rodaram
      | [$acc[] | select(.ultima_rodada == $anterior and ($C[.chave] | not) and ([.lente] | inside($rodaram)))] | length end),
    lacunas: ($lac | split("\n") | map(select(length > 0))),
    acumulado: (
      ($c | map({(.chave): .}) | add // {}) as $novo
      | [$acc[] | if $novo[.chave] then . + ($novo[.chave] | del(.chave)) + {ultima_rodada: $atual} else . end]
        + [$novos[] | . + {primeira_rodada: $atual, ultima_rodada: $atual}]
    )
  }
  | .novos_no_mundo |= map({id, lente, titulo, url, data_publicacao, tipo, confianca, auditoria})
  | .novos_no_radar |= map({id, lente, titulo, url, data_publicacao, tipo, confianca, auditoria})
' > "$tmp/res.json" || { echo "FAIL: cálculo do diff falhou — nada gravado"; exit 1; }

jq -c '.acumulado[]' "$tmp/res.json" > "$tmp/sinais.jsonl"
jq 'del(.acumulado)' "$tmp/res.json" > "$tmp/diff.json"
jq -r --arg tema "$(basename "$T")" '
def cel: tostring | gsub("\\|"; "\\|") | gsub("\n"; " ");
def tabela: if length == 0 then "_nenhum_" else
  (["| Título | URL | Publicado em | Lente | Auditoria |", "|---|---|---|---|---|"]
   + map("| \(.titulo | cel) | \(.url | cel) | \(.data_publicacao) | \(.lente) | \(if .auditoria == "UNVERIFIED" then "⚠ UNVERIFIED" else .auditoria end) |")) | join("\n") end;
"# Radar — \($tema) — rodada \(.tema_rodada)",
"",
(if .linha_de_base then
  "**Linha de base**: primeira rodada do tema; \(.total_rodada) sinais gravados no acumulado. Não há diff."
 else
  "Rodada anterior: \(.anterior)",
  "",
  "## Novos no mundo (\(.novos_no_mundo | length))",
  "Não estavam no acumulado e foram publicados depois da rodada anterior.",
  "",
  (.novos_no_mundo | tabela),
  "",
  "## Novos no radar (\(.novos_no_radar | length))",
  "Não estavam no acumulado, mas foram publicados antes da rodada anterior: ruído de busca, não novidade de mercado.",
  "",
  (.novos_no_radar | tabela)
 end),
"",
"## Contagens",
"- por lente: \(.por_lente | to_entries | map("\(.key)=\(.value)") | join(", "))",
"- recorrentes: \(.recorrentes) (com data alterada: \(.atualizados))",
"- sumidos: \(.sumidos)",
"- duplicados na rodada (mesma URL em mais de uma lente): \(.duplicados_na_rodada)",
"",
"## Lacunas",
(if (.lacunas | length) == 0 then "_nenhuma_" else (.lacunas | map("- " + .) | join("\n")) end)
' "$tmp/diff.json" > "$tmp/diff.md" || { echo "FAIL: geração do diff.md falhou — nada gravado"; exit 1; }

# Ordem: acumulado → diff.json → status → diff.md (marca de incorporada por último).
mv "$tmp/sinais.jsonl" "$ACC" || { echo "FAIL: não gravou $ACC"; exit 1; }
mv "$tmp/diff.json" "$R/diff.json"
agora="$(date +%Y-%m-%dT%H:%M:%S%z)"
if [ -f "$R/status.json" ]; then
  jq --arg t "$agora" '.estado = "incorporada" | .incorporada_em = $t' "$R/status.json" > "$tmp/st.json" && mv "$tmp/st.json" "$R/status.json"
else
  jq -n --arg t "$agora" '{estado: "incorporada", incorporada_em: $t}' > "$R/status.json"
fi
mv "$tmp/diff.md" "$R/diff.md"

jq -r '"radar_diff: ok — " + (if .linha_de_base then "linha de base, \(.total_rodada) sinais"
  else "\(.novos_no_mundo | length) novo(s) no mundo, \(.novos_no_radar | length) novo(s) no radar, \(.recorrentes) recorrente(s), \(.sumidos) sumido(s)" end)' "$R/diff.json"
echo "diff: $R/diff.md"

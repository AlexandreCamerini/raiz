#!/usr/bin/env bash
# lint_modelos.sh [raiz] — todo agente declara model; não-Haiku declara effort; Fable proibido em agentes;
# frontmatter de cada agente com entrada em hipoteses_iniciais (modelos/matriz.yaml) deve bater com a matriz.
# Agente sem entrada na matriz = WARN. Matriz ausente/ilegível/malformada = FAIL (fail-closed).
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
MATRIZ="$ROOT/modelos/matriz.yaml"
rc=0

# Matriz -> linhas "ok<TAB>agente<TAB>modelo[/effort]"; qualquer linha fora do formato vira "MAL<TAB>nº<TAB>texto".
if [ ! -r "$MATRIZ" ]; then
  echo "FAIL: matriz ausente ou ilegível: $MATRIZ"; exit 1
fi
hip="$(awk '
  /^hipoteses_iniciais:[ \t]*(#.*)?\r?$/ { sec=1; found=1; next }
  sec && /^[^ \t#\r]/ { sec=0 }
  sec {
    line=$0; sub(/\r$/,"",line)
    if (line ~ /^[ \t]*$/ || line ~ /^[ \t]*#/) next
    sub(/[ \t]+#.*$/,"",line)
    if (line ~ /^[ \t]+[a-z0-9][a-z0-9-]*: [a-z0-9][a-z0-9.-]*(\/[a-z]+)?[ \t]*$/) {
      gsub(/^[ \t]+|[ \t]+$/,"",line); i=index(line,": ")
      print "ok\t" substr(line,1,i-1) "\t" substr(line,i+2)
    } else print "MAL\t" NR "\t" $0
  }
  END { if (!found) print "SEM_SECAO\t0\thipoteses_iniciais" }
' "$MATRIZ")" || { echo "FAIL: não consegui ler $MATRIZ"; exit 1; }
if [ -z "$hip" ]; then echo "FAIL: hipoteses_iniciais vazia em $MATRIZ"; exit 1; fi
bad="$(printf '%s\n' "$hip" | awk -F'\t' '$1=="MAL"{print "FAIL matriz.yaml:" $2 ": linha fora do formato `agente: modelo[/effort]`: " $3} $1=="SEM_SECAO"{print "FAIL matriz.yaml: seção hipoteses_iniciais ausente"}')"
if [ -n "$bad" ]; then printf '%s\n' "$bad"; exit 1; fi
dup="$(printf '%s\n' "$hip" | awk -F'\t' '{c[$2]++} END{for(k in c) if(c[k]>1) print k}')"
if [ -n "$dup" ]; then printf 'FAIL matriz.yaml: agente duplicado em hipoteses_iniciais: %s\n' "$dup"; exit 1; fi

for f in "$ROOT"/agents/*.md; do
  [ -e "$f" ] || { echo "FAIL: nenhum agente em $ROOT/agents"; exit 1; }
  nome="$(basename "$f" .md)"
  fm="$(awk '/^---$/{n++; next} n==1' "$f")"
  m="$(printf '%s\n' "$fm" | awk -F': *' '/^model:/{print $2}' | tr -d '\r ')"
  e="$(printf '%s\n' "$fm" | awk -F': *' '/^effort:/{print $2}' | tr -d '\r ')"
  if [ -z "$m" ]; then echo "FAIL $(basename "$f"): sem model — herdaria o modelo da sessão"; rc=1
  elif [ "$m" = "inherit" ]; then echo "WARN $(basename "$f"): model: inherit"
  fi
  case "$m" in fable|best|claude-fable*) echo "FAIL $(basename "$f"): Fable em agente (pode cobrar créditos sem prompt em -p)"; rc=1;; esac
  case "$m" in haiku|claude-haiku*) : ;; *) [ -n "$e" ] || echo "WARN $(basename "$f"): sem effort";; esac

  # frontmatter × matriz
  esperado="$(printf '%s\n' "$hip" | awk -F'\t' -v a="$nome" '$2==a{print $3}')"
  encontrado="$m${e:+/$e}"
  if [ -z "$esperado" ]; then
    echo "WARN $nome: sem entrada em hipoteses_iniciais (hipótese não registrada na matriz)"
  elif [ "$esperado" != "$encontrado" ]; then
    echo "FAIL $nome: matriz espera '$esperado', frontmatter tem '$encontrado'"; rc=1
  fi
done
[ "$rc" = 0 ] && echo "lint_modelos: ok"
exit "$rc"

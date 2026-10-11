#!/usr/bin/env bash
# checar_publico.sh — higiene da árvore pública do plugin (fail-closed: qualquer erro interno = FAIL).
#
# Uso: checar_publico.sh [dir] [--exportacao --denylist <arq> --allowlist <arq> --arquivos <arq>]
#      checar_publico.sh --texto <arq> --denylist <arq>
#
# Modo genérico (CI), sobre [dir] (default "."):
#   - LICENSE presente e contendo "MIT License"
#   - .claude-plugin/plugin.json é JSON válido e declara "license"
#   - nenhum .DS_Store, *.log, .env*, *.pem, *.key, *.p12, settings.local.json
#     e nenhum diretório .raiz, .claude ou .planning
#   - nenhum componente de caminho chamado .git (diretório ou arquivo) em qualquer profundidade, e o conteúdo
#     de um .git aninhado é varrido mesmo assim. ÚNICA exceção, só neste modo: o .git da RAIZ de [dir] (o
#     checkout do CI e o clone de quem contribui sempre têm um) é ignorado, nem listado nem varrido
#   - nenhum caminho absoluto de usuário (macOS, Linux, volumes montados, Windows) nem caminho no diretório
#     pessoal (til ou HOME) que não seja .raiz ou .claude
#   - nenhum padrão de segredo (chave Anthropic/OpenAI/Google/AWS/Stripe de produção, chave sk- longa, JWT, token
#     GitHub/Slack, webhook Slack, chave PEM, chave pública SSH)
#   - nenhum endereço de e-mail (exceções: variável EMAIL_OK abaixo, por arquivo e endereço exatos)
#   - nenhum IPv4, salvo os blocos reservados para documentação (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24)
#     e os endereços 127.0.0.1 e 0.0.0.0
#   - nenhum CPF (formatado ou 11 dígitos soltos) nem telefone brasileiro (+55 ou DDD entre parênteses)
#   - nenhuma referência a caminhos que existem só no repositório privado de desenvolvimento
#   - nenhum link simbólico nem arquivo especial
#   - todo arquivo é texto UTF-8, sem byte NUL, e, em CONTEÚDO e em NOME de arquivo, sem caractere de formatação
#     (Cf: bidi, largura zero, tags, seletores, hífen condicional...), de controle (Cc, inclusive CR, ESC, DEL e
#     C1; só \n e \t são aceitos em conteúdo), combinante (M*), de uso privado (Co), substituto (Cs), não atribuído
#     (Cn), separador de linha/parágrafo/espaço não ASCII (Zl, Zp, Zs), dígito não ASCII (Nd), nem letra que não
#     seja latina (o nome Unicode precisa começar por LATIN; FULLWIDTH, HALFWIDTH, MATHEMATICAL e as letras i
#     sem ponto reprovam). Letras latinas fora de ASCII só são aceitas em U+00C0-U+017F (exceto U+0131 e
#     U+017F). ÚNICA exceção: U+00BA (indicador ordinal masculino), presente em um script do plugin
#   - tokens base64 (>=12 caracteres, em 4 alinhamentos para pegar prefixo/sufixo colado; linhas consecutivas
#     inteiras no charset, de >=8 caracteres, são juntadas antes) são decodificados (até 4 níveis); os trechos
#     ASCII imprimíveis (>=8 bytes) passam pelos mesmos padrões de segredo/PII e, em exportação, pela denylist
# Modo --exportacao (exige --denylist, --allowlist e --arquivos; arquivo ausente, ilegível ou sem regra = FAIL):
#   - denylist aplicada ao CONTEÚDO e ao NOME de cada arquivo/diretório
#   - todo arquivo fora da allowlist (diretórios/arquivos) = FAIL
#   - aprovação por CONTEÚDO: --arquivos é uma lista "<sha256>  <caminho>" (dois espaços entre eles). Caminho
#     fora da lista = FAIL "novo arquivo"; hash diferente = FAIL "arquivo alterado". Os dois pedem revisão humana
#     e exportar.sh --aprovar-novos (interativo)
#   - qualquer .git, inclusive o da raiz, = FAIL (exporte sem histórico)
# Modo --texto <arq> (usado por publicar.sh para a mensagem de commit e o nome do autor): aplica ao texto do
#   arquivo a denylist e todos os padrões de conteúdo acima; não faz checagem estrutural de árvore.
#
# Formato da denylist: uma regra por linha; "#" e linhas vazias ignoradas.
#   termo                  texto fixo, case-insensitive
#   termo => arq1 arq2     idem, mas permitido nos arquivos listados (exceção explícita, por arquivo)
#   re:REGEX [=> arqs]     expressão regular estendida, case-insensitive
# Formato da allowlist: um caminho por linha; terminado em "/" = prefixo de diretório, senão arquivo exato.
#
# Limites residuais (o que este gate NÃO pega): segredo ou termo proibido codificado em hex, percent-encoding,
# rot13, concatenação em várias linhas fora do charset base64, ou em mais de 4 níveis de base64; texto
# decodificado que não é ASCII; ofuscação por normalização Unicode (NFKC) de letras já aceitas; CNPJ, cartão e
# passaporte; telefones de outros países. A categoria Cn depende da versão do Unicode do python3 em uso (uma
# versão mais antiga pode reprovar caractere novo, nunca aceitar um proibido); Cs não pode aparecer em UTF-8
# válido e cai em "não é UTF-8 válido". A aprovação por conteúdo prova que o arquivo é o mesmo que um humano
# aprovou, não que a revisão foi boa.
#
# Os padrões abaixo usam um colchete no primeiro caractere para NÃO casarem com o texto deste próprio
# script (que vive dentro da árvore que ele varre); nenhum exemplo literal de dado proibido aparece nos
# comentários pelo mesmo motivo. Só grep/find/jq/python3 (stdlib, 3.8+) e POSIX shell (bash 3.2+).
# Saída: "FAIL: arquivo:linha: motivo" por violação; exit 0 só se tudo passou. Nunca imprime o segredo achado.

set -u
set -f   # sem expansão de glob em listas não aspeadas
export LC_ALL=C

NOME="checar_publico"
RC=0
NV=0
NF=0

# Exceções de e-mail: uma por linha, "caminho/relativo=endereço" exatos. NENHUMA hoje: a varredura da árvore
# exportada (revisão fixada) não achou e-mail legítimo. Se um dia houver (ex.: o endereço noreply de um
# trailer de commit num texto de contribuição), liste aqui o par arquivo=endereço, nunca um padrão.
EMAIL_OK=''

erro() { printf 'FAIL: %s\n' "$*"; exit 2; }
viola() { printf 'FAIL: %s\n' "$*"; RC=1; NV=$((NV+1)); }
uso() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

# ---------- argumentos ----------
DIR=""; EXPORT=0; DENY=""; ALLOW=""; ARQ=""; DENY_SET=0; ALLOW_SET=0; ARQ_SET=0; TEXTO=""; TEXTO_SET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --exportacao) EXPORT=1; shift ;;
    --denylist)   [ $# -ge 2 ] || erro "--denylist exige um arquivo"; DENY="$2"; DENY_SET=1; shift 2 ;;
    --allowlist)  [ $# -ge 2 ] || erro "--allowlist exige um arquivo"; ALLOW="$2"; ALLOW_SET=1; shift 2 ;;
    --arquivos)   [ $# -ge 2 ] || erro "--arquivos exige um arquivo"; ARQ="$2"; ARQ_SET=1; shift 2 ;;
    --texto)      [ $# -ge 2 ] || erro "--texto exige um arquivo"; TEXTO="$2"; TEXTO_SET=1; shift 2 ;;
    -h|--help)    uso; exit 0 ;;
    --*)          erro "opção desconhecida: $1" ;;
    *)            [ -z "$DIR" ] || erro "mais de um diretório informado ($DIR e $1)"; DIR="$1"; shift ;;
  esac
done
MODO_TEXTO=0
if [ "$TEXTO_SET" = 1 ]; then
  [ -z "$DIR" ] && [ "$EXPORT" = 0 ] && [ "$ALLOW_SET" = 0 ] && [ "$ARQ_SET" = 0 ] \
    || erro "--texto não combina com diretório, --exportacao, --allowlist nem --arquivos"
  [ "$DENY_SET" = 1 ] || erro "--texto exige --denylist <arquivo>"
  [ -f "$TEXTO" ] && [ -r "$TEXTO" ] || erro "arquivo de texto ausente ou ilegível: $TEXTO"
  MODO_TEXTO=1; EXPORT=1
fi
[ -n "$DIR" ] || DIR="."
if [ "$EXPORT" = 0 ] && { [ "$DENY_SET" = 1 ] || [ "$ALLOW_SET" = 1 ] || [ "$ARQ_SET" = 1 ]; }; then
  erro "--denylist/--allowlist/--arquivos só fazem sentido com --exportacao"
fi
if [ "$EXPORT" = 1 ] && [ "$MODO_TEXTO" = 0 ]; then
  [ "$DENY_SET" = 1 ]  || erro "modo exportação exige --denylist <arquivo>"
  [ "$ALLOW_SET" = 1 ] || erro "modo exportação exige --allowlist <arquivo>"
  [ "$ARQ_SET" = 1 ]   || erro "modo exportação exige --arquivos <arquivo> (lista de arquivos aprovados)"
fi

for c in jq grep find sed python3 cp; do command -v "$c" >/dev/null 2>&1 || erro "$c ausente (obrigatório)"; done

LISTA="$(mktemp "${TMPDIR:-/tmp}/${NOME}.XXXXXX")" || erro "mktemp falhou"
ERR="$(mktemp "${TMPDIR:-/tmp}/${NOME}.err.XXXXXX")" || erro "mktemp falhou"
NOMES="$(mktemp "${TMPDIR:-/tmp}/${NOME}.nomes.XXXXXX")" || erro "mktemp falhou"
OUTV="$(mktemp "${TMPDIR:-/tmp}/${NOME}.viol.XXXXXX")" || erro "mktemp falhou"
CONT="$(mktemp "${TMPDIR:-/tmp}/${NOME}.cont.XXXXXX")" || erro "mktemp falhou"
APRN="$(mktemp "${TMPDIR:-/tmp}/${NOME}.apr.XXXXXX")" || erro "mktemp falhou"
MIR="$(mktemp -d "${TMPDIR:-/tmp}/${NOME}.b64.XXXXXX")" || erro "mktemp falhou"
TXD=""
trap 'rm -rf "$LISTA" "$ERR" "$NOMES" "$OUTV" "$CONT" "$APRN" "$MIR" "$TXD"' EXIT
if [ "$MODO_TEXTO" = 1 ]; then
  TXD="$(mktemp -d "${TMPDIR:-/tmp}/${NOME}.txt.XXXXXX")" || erro "mktemp falhou"
  cp "$TEXTO" "$TXD/texto.txt" || erro "não consegui copiar $TEXTO"
  DIR="$TXD"
fi
[ -d "$DIR" ] || erro "diretório inexistente: $DIR"
case "$DIR" in /) ;; */) DIR="${DIR%/}" ;; esac

# Único caminho podado nas varreduras: o .git da RAIZ, e só no modo genérico (ver cabeçalho). No modo
# exportação o sentinela abaixo nunca casa com nada, então nada é escondido da varredura.
if [ "$EXPORT" = 1 ]; then PRUNE="/nonexistent/sem-poda"; else PRUNE="$DIR/.git"; fi

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

excecao() { # excecao <rel> <lista de exceções> — rc 0 se rel está na lista
  local rel="$1" e
  for e in $2; do [ "$e" = "$rel" ] && return 0; done
  return 1
}
email_ok() { # email_ok <rel> <endereço> — rc 0 se o par está em EMAIL_OK
  case $'\n'"$EMAIL_OK"$'\n' in *$'\n'"$1=$2"$'\n'*) return 0 ;; esac
  return 1
}

# varre <raiz> <rótulo> <padrão> <flags> [exceções] [tipo] — UM grep (via find -exec ... +) por regra sobre
# todos os arquivos regulares de <raiz>; viola por arquivo:linha. Stderr não vazio (arquivo ilegível, regex
# ruim, find com erro) = FAIL, nunca skip. tipo "email": exceções são pares arquivo=endereço (EMAIL_OK).
varre() {
  local raiz="$1" rot="$2" pat="$3" fl="$4" exc="${5:-}" tipo="${6:-}" out l p rel resto linha achado
  out="$(find "$raiz" -path "$PRUNE" -prune -o -type f -exec grep -a -n -H $fl -e "$pat" {} + 2>"$ERR")"
  if [ -s "$ERR" ]; then viola "erro interno ao aplicar '$rot': $(head -c 200 "$ERR" | tr '\n' ' ')"; return; fi
  [ -n "$out" ] || return 0
  while IFS= read -r l; do
    p="${l%%:*}"; rel="${p#"$raiz"/}"; resto="${l#*:}"; linha="${resto%%:*}"; achado="${resto#*:}"
    if [ -n "$exc" ] && excecao "$rel" "$exc"; then continue; fi
    if [ "$tipo" = email ] && email_ok "$rel" "$achado"; then continue; fi
    viola "$rel:$linha: $rot"
  done <<< "$out"
}

# ---------- regras de conteúdo (padrões; a denylist é acrescentada no modo exportação) ----------
# RT rótulo, RP padrão, RF flags do grep, RE exceções por arquivo, RK tipo
# (padrões que precisam de lookahead, validação numérica ou decodificação ficam no bloco python3 mais abaixo)
RN=0
regra() { RT[$RN]="$1"; RP[$RN]="$2"; RF[$RN]="$3"; RE[$RN]="${4:-}"; RK[$RN]="${5:-}"; RN=$((RN+1)); }
regra "caminho absoluto de usuário (macOS)"              '/[U]sers/' "-E"
regra "caminho absoluto de usuário (Linux)"              '/[h]ome/' "-E"
regra "caminho absoluto de volume montado"               '/[V]olumes/' "-E"
regra "caminho pessoal do autor (diretório pessoal, temporário do sistema ou unidade do Windows)" \
  '[~]/[d]ev/|[~]/[D]ocuments|[~]/[D]esktop|[$]HOME/(dev|Documents|Desktop)|/[p]rivate/var|C:\\[U]sers\\' "-E -i"
regra "padrão de segredo: chave de API Anthropic"         'sk-[a]nt-[A-Za-z0-9_-]{20,}' "-E"
regra "padrão de segredo: chave de API OpenAI (projeto)"  'sk-[p]roj-' "-E"
regra "padrão de segredo: chave de API Google"            '[A]Iza[0-9A-Za-z_-]{30,}' "-E"
regra "padrão de segredo: token GitHub"                   '[g]hp_' "-E"
regra "padrão de segredo: token GitHub (fine-grained)"    '[g]ithub_pat_[A-Za-z0-9_]{20,}' "-E"
regra "padrão de segredo: token GitHub (OAuth, servidor ou usuário)" '[g]h[osu]_[A-Za-z0-9]{20,}' "-E"
regra "padrão de segredo: chave de acesso AWS"            '[A]KIA' "-E"
regra "padrão de segredo: chave privada PEM"              'BEGIN .* PRIVATE [K]EY' "-E"
regra "padrão de segredo: token Slack"                    '[x]ox[bp]-' "-E"
regra "padrão de segredo: webhook Slack"                  '[h]ooks\.slack\.com/services/' "-E"
regra "e-mail (dado pessoal)"                             '[A-Za-z0-9._%+-]+[@][A-Za-z0-9.-]+\.[A-Za-z]{2,}' "-E -o" "" email
regra "referência a caminho que só existe no repositório privado" \
  'docs/[R]OTEIRO|[R]OTEIRO\.md|docs/[b]acklog|docs/[s]pecs|docs/[d]ecisoes|docs/[p]rogresso|ferramentas/[r]oteiro|evals/[a]uditoria-' "-E"

# ---------- listas do modo exportação ----------
DN=0; AN=0; ARQ_LIST=""; ARQ_N=0
if [ "$EXPORT" = 1 ]; then
  [ -f "$DENY" ]  && [ -r "$DENY" ]  || erro "denylist ausente ou ilegível: $DENY"
  if [ "$MODO_TEXTO" = 0 ]; then
    [ -f "$ALLOW" ] && [ -r "$ALLOW" ] || erro "allowlist ausente ou ilegível: $ALLOW"
    [ -f "$ARQ" ]   && [ -r "$ARQ" ]   || erro "lista de arquivos aprovados ausente ou ilegível: $ARQ"
  fi

  # denylist -> arrays paralelos: DT (rótulo), DP (padrão), DF (flags), DE (exceções)
  while IFS= read -r linha || [ -n "$linha" ]; do
    linha="${linha%$'\r'}"; linha="$(trim "$linha")"
    [ -n "$linha" ] || continue
    case "$linha" in \#*) continue ;; esac
    case "$linha" in
      *" => "*) termo="$(trim "${linha%% => *}")"; exc="$(trim "${linha#* => }")" ;;
      *)        termo="$linha"; exc="" ;;
    esac
    case "$termo" in
      re:*) pat="${termo#re:}"; fl="-E -i" ;;
      *)    pat="$termo"; fl="-F -i" ;;
    esac
    [ -n "$pat" ] || { viola "denylist: regra com padrão vazio ('$linha')"; continue; }
    if [ "$fl" = "-E -i" ]; then
      printf 'x\n' | grep -E -i -- "$pat" >/dev/null 2>&1
      [ "$?" -le 1 ] || { viola "denylist: expressão regular inválida ('$pat')"; continue; }
    fi
    DT[$DN]="$termo"; DP[$DN]="$pat"; DF[$DN]="$fl"; DE[$DN]="$exc"; DN=$((DN+1))
  done < "$DENY"
  [ "$DN" -gt 0 ] || viola "denylist sem nenhuma regra: $DENY"

  if [ "$MODO_TEXTO" = 0 ]; then
    while IFS= read -r linha || [ -n "$linha" ]; do
      linha="${linha%$'\r'}"; linha="$(trim "$linha")"
      [ -n "$linha" ] || continue
      case "$linha" in \#*) continue ;; esac
      case "$linha" in /*|*..*) viola "allowlist: entrada inválida ('$linha')"; continue ;; esac
      AL[$AN]="$linha"; AN=$((AN+1))
    done < "$ALLOW"
    [ "$AN" -gt 0 ] || viola "allowlist sem nenhuma entrada: $ALLOW"

    # arquivos aprovados: "<sha256>  <caminho>" por linha. Validados aqui; a lista normalizada vai para $APRN
    # e o python3 compara o hash do conteúdo de cada arquivo da árvore com ela.
    while IFS= read -r linha || [ -n "$linha" ]; do
      linha="${linha%$'\r'}"; linha="$(trim "$linha")"
      [ -n "$linha" ] || continue
      case "$linha" in \#*) continue ;; esac
      h="${linha%%  *}"; p="${linha#*  }"
      if [ "$h" = "$linha" ] || [ "${#h}" != 64 ] || [ -n "${h//[0-9a-f]/}" ]; then
        viola "arquivos aprovados: entrada inválida (esperado '<sha256>  <caminho>'; lista antiga só com caminhos? regenere com exportar.sh --aprovar-novos)"
        continue
      fi
      p="$(trim "$p")"
      case "$p" in ""|/*|*..*|*/) viola "arquivos aprovados: caminho inválido ('$p')"; continue ;; esac
      case $'\n'"$ARQ_LIST" in *$'\n'"$p"$'\n'*) viola "arquivos aprovados: caminho duplicado ('$p')"; continue ;; esac
      ARQ_LIST="$ARQ_LIST$p"$'\n'; ARQ_N=$((ARQ_N+1))
      printf '%s  %s\n' "$h" "$p" >> "$APRN"
    done < "$ARQ"
    [ "$ARQ_N" -gt 0 ] || viola "lista de arquivos aprovados sem nenhuma entrada: $ARQ"
  fi

  # a denylist entra no mesmo conjunto de regras (aplicada ao conteúdo, inclusive ao decodificado de base64)
  i=0
  while [ "$i" -lt "$DN" ]; do
    regra "denylist: '${DT[$i]}'" "${DP[$i]}" "${DF[$i]}" "${DE[$i]}"
    i=$((i+1))
  done
fi

permitido() {
  local rel="$1" e i=0
  while [ "$i" -lt "$AN" ]; do
    e="${AL[$i]}"; i=$((i+1))
    case "$e" in
      */) [ "${rel#"$e"}" != "$rel" ] && return 0 ;;
      *)  [ "$rel" = "$e" ] && return 0 ;;
    esac
  done
  return 1
}

# ---------- checagens estruturais ----------
if [ "$MODO_TEXTO" = 0 ]; then
  if [ ! -f "$DIR/LICENSE" ]; then
    viola "LICENSE: ausente"
  elif ! grep -q 'MIT License' "$DIR/LICENSE" 2>/dev/null; then
    viola "LICENSE: não contém 'MIT License'"
  fi

  PJ="$DIR/.claude-plugin/plugin.json"
  if [ ! -f "$PJ" ]; then
    viola ".claude-plugin/plugin.json: ausente"
  elif ! jq empty "$PJ" >/dev/null 2>&1; then
    viola ".claude-plugin/plugin.json: não é JSON válido"
  elif ! jq -e '(.license | type == "string") and (.license | length > 0)' "$PJ" >/dev/null 2>&1; then
    viola ".claude-plugin/plugin.json: campo license ausente ou vazio"
  fi
fi

# lista TODAS as entradas (menos o .git da raiz, só no modo genérico) em arquivo, separadas por NUL
find "$DIR" -path "$PRUNE" -prune -o -print0 > "$LISTA" 2>"$ERR" || erro "find falhou em $DIR"
[ ! -s "$ERR" ] || erro "find reportou erro em $DIR: $(head -c 200 "$ERR" | tr '\n' ' ')"

# estrutura: nomes proibidos, tipos, allowlist; acumula os nomes (um por linha) para a denylist de nomes
while IFS= read -r -d '' f; do
  [ "$f" = "$DIR" ] && continue
  rel="${f#"$DIR"/}"; base="${f##*/}"
  case "$rel" in *[[:cntrl:]]*) viola "$rel: nome com caractere de controle"; continue ;; esac
  printf '%s\n' "$rel" >> "$NOMES"
  case "$base" in
    .[Gg][Ii][Tt]) viola "$rel: repositório git (.git) dentro da árvore a publicar (exporte sem histórico; um .git aninhado é varrido mesmo assim)" ;;
  esac
  case "$base" in
    .DS_Store|*.log|.env*|*.pem|*.key|*.p12|settings.local.json) viola "$rel: arquivo proibido no repositório público" ;;
  esac
  if [ -L "$f" ]; then viola "$rel: link simbólico não é permitido"; continue; fi
  if [ -d "$f" ]; then
    case "$base" in .raiz|.claude|.planning) viola "$rel: diretório proibido no repositório público" ;; esac
    continue
  fi
  if [ ! -f "$f" ]; then viola "$rel: arquivo especial (nem regular nem diretório)"; continue; fi
  NF=$((NF+1))
  [ -r "$f" ] || viola "$rel: ilegível"
  if [ "$EXPORT" = 1 ] && [ "$MODO_TEXTO" = 0 ]; then
    permitido "$rel" || viola "$rel: fora da allowlist"
  fi
done < "$LISTA"

[ "$NF" -gt 0 ] || viola "árvore sem nenhum arquivo: $DIR"

# ---------- texto: binário, UTF-8, categorias Unicode, homóglifos, padrões e base64 (python3, stdlib) ----------
# Escreve as violações em $OUTV (rel US linha US motivo) e, para cada arquivo com base64 decodificável, um
# espelho em $MIR (mesmo caminho relativo, mesma linha) que depois passa pelas regras de conteúdo do grep
# (denylist, e-mail, caminhos). Os padrões do bloco abaixo são aplicados direto ao texto e ao decodificado.
# Só escapes \uXXXX no código: este script não pode conter os caracteres que ele proíbe.
if [ "$EXPORT" = 1 ] && [ "$MODO_TEXTO" = 0 ]; then CHECA_APR=1; else CHECA_APR=0; fi
python3 -I - "$DIR" "$LISTA" "$MIR" "$OUTV" "$CONT" "$CHECA_APR" "$APRN" >/dev/null 2>"$ERR" <<'PY'
import base64, binascii, hashlib, os, re, sys, unicodedata

dir_b = os.fsencode(sys.argv[1])
lista, espelho, saida, contagem = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
checa_aprovados = sys.argv[6] == "1"
arq_aprovados = sys.argv[7]
US = "\x1f"
MAX_POR_ARQUIVO = 30
ORCAMENTO_DECODIFICACOES = 20000
SUFIXO_B64 = " [texto decodificado de base64]"

# ---------- categorias Unicode ----------
LETRAS_EXCECAO = {0xBA}            # indicador ordinal masculino (presente em um script do plugin)
LATIN_EXTRA_PROIBIDAS = {0x131, 0x17F}   # i sem ponto e s longo: homóglifos de i e f

def motivo_char(c, conteudo):
    o = ord(c)
    if o < 0x80:
        if c in "\n\t":
            return None if conteudo else "caractere de controle (U+%04X)" % o
        if c == "\r":
            return "retorno de carro CR (U+000D)"
        if o < 0x20 or o == 0x7F:
            return "caractere de controle (U+%04X)" % o
        return None
    cat = unicodedata.category(c)
    nome = unicodedata.name(c, "")
    if cat == "Cf":
        return "caractere invisível/bidi (U+%04X)" % o
    if cat == "Cc":
        return "caractere de controle (U+%04X)" % o
    if cat == "Cn":
        return "caractere não atribuído no Unicode do python3 em uso (U+%04X)" % o
    if cat == "Co":
        return "caractere de uso privado (U+%04X)" % o
    if cat == "Cs":
        return "caractere substituto (U+%04X)" % o
    if cat[0] == "M":
        return "caractere combinante ou seletor, categoria %s (U+%04X)" % (cat, o)
    if cat in ("Zl", "Zp", "Zs"):
        return "separador/espaço não ASCII, categoria %s (U+%04X)" % (cat, o)
    if nome.startswith(("FULLWIDTH", "HALFWIDTH", "MATHEMATICAL")):
        return "caractere de largura total/matemático, possível homóglifo (U+%04X)" % o
    if "DOTLESS" in nome:
        return "letra sem ponto, possível homóglifo (U+%04X)" % o
    if cat[0] == "L":
        if o in LETRAS_EXCECAO:
            return None
        if nome.startswith(("CYRILLIC", "GREEK", "COPTIC")):
            return "letra cirílica/grega, possível homóglifo (U+%04X)" % o
        if not nome.startswith("LATIN"):
            return "letra não latina, possível homóglifo (U+%04X)" % o
        if not (0xC0 <= o <= 0x17F) or o in LATIN_EXTRA_PROIBIDAS:
            return "letra latina fora do conjunto esperado, possível homóglifo (U+%04X)" % o
        return None
    if cat == "Nd":
        return "dígito não ASCII, possível homóglifo (U+%04X)" % o
    return None

# ---------- padrões com lógica (texto e base64 decodificado) ----------
RESERVADOS_IP = ("192.0.2.", "198.51.100.", "203.0.113.")
IPS_OK = ("127.0.0.1", "0.0.0.0")

def ip_suspeito(m):
    s = m.group(0)
    if any(int(p) > 255 for p in s.split(".")):
        return False
    return not (s in IPS_OK or s.startswith(RESERVADOS_IP))

PADROES = [
    ("padrão de segredo: chave Stripe de produção", re.compile(r"sk_[l]ive_"), None),
    ("padrão de segredo: chave sk- de 40 ou mais caracteres", re.compile(r"s[k]-[A-Za-z0-9]{40,}"), None),
    ("padrão de segredo: JWT", re.compile(r"e[y]J[A-Za-z0-9_-]{4,}\.e[y]J[A-Za-z0-9_-]{4,}"), None),
    ("padrão de segredo: chave pública SSH", re.compile(r"ssh-[r]sa|ssh-[e]d25519|ecdsa-sha2-nist[p]"), None),
    ("endereço IPv4 fora dos blocos de documentação",
     re.compile(r"(?<![0-9])(?<![0-9]\.)(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?![0-9])(?!\.[0-9])"), ip_suspeito),
    ("CPF (formato com pontos e hífen)",
     re.compile(r"(?<![0-9])[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}(?![0-9])"), None),
    ("CPF (11 dígitos seguidos)", re.compile(r"(?<![0-9A-Za-z])[0-9]{11}(?![0-9A-Za-z])"), None),
    ("telefone brasileiro (código do país)",
     re.compile(r"(?<![0-9])\+55[\s.-]*\(?[0-9]{2}\)?[\s.-]*9?[0-9]{4}[\s.-]?[0-9]{4}(?![0-9])"), None),
    ("telefone brasileiro (DDD entre parênteses)",
     re.compile(r"\([0-9]{2}\)\s?9[0-9]{4}[\s.-]?[0-9]{4}"), None),
    ("caminho no diretório pessoal (til ou HOME) fora de .raiz e .claude",
     re.compile(r"(?:[~]|\$HOME|\$\{HOME\})/(?![.]raiz(?![A-Za-z0-9_])|[.]claude(?![A-Za-z0-9_]))(?=[A-Za-z0-9._<{$-])"), None),
]

def achados_padroes(texto):
    r = []
    for rotulo, rx, filtro in PADROES:
        for m in rx.finditer(texto):
            if filtro is None or filtro(m):
                r.append(rotulo)
                break
    return r

# ---------- base64 ----------
TOKEN = re.compile(r"[A-Za-z0-9+/_-]{12,}={0,2}")
LINHA_B64 = re.compile(r"[A-Za-z0-9+/_-]{8,}={0,2}")
IMPRIMIVEIS = re.compile(rb"[\x20-\x7e\t\n\r]{8,}")
MAX_TOKEN = 8192

class Excedeu(Exception):
    pass

orcamento = [ORCAMENTO_DECODIFICACOES]

def decodifica_janelas(tok):
    """Decodifica o token em 4 alinhamentos (prefixo colado de qualquer tamanho cai em um deles) e devolve os
    trechos ASCII imprimíveis de >=8 bytes (sufixo colado vira lixo no fim, que é descartado)."""
    out = []
    tok = tok[:MAX_TOKEN]
    for s in range(4):
        t = tok[s:].rstrip("=").replace("-", "+").replace("_", "/")
        if len(t) < 12:
            break
        if len(t) % 4 == 1:
            t = t[:-1]
        t += "=" * (-len(t) % 4)
        orcamento[0] -= 1
        if orcamento[0] < 0:
            raise Excedeu()
        try:
            raw = base64.b64decode(t, validate=True)
        except (binascii.Error, ValueError):
            continue
        for m in IMPRIMIVEIS.finditer(raw):
            out.append(m.group(0).decode("ascii"))
    return out

def expande(texto, nivel=1):
    res = []
    for m in TOKEN.finditer(texto):
        for d in decodifica_janelas(m.group(0)):
            res.append(d)
            if nivel < 4:
                res.extend(expande(d, nivel + 1))
    return res

def limpa_linha_b64(ln):
    s = re.sub(r"^(?:#|//|>)\s*", "", ln.strip())
    return s.strip(" \t\"'`\\,;+")

def limpa(s):
    return "".join(c if (c.isprintable() and c != US) else "?" for c in s)

viol = []
examinados = 0

def v(rel, linha, motivo):
    viol.append(limpa(rel) + US + str(linha) + US + motivo)

aprovados = {}
if checa_aprovados:
    with open(arq_aprovados, encoding="utf-8") as fh:
        for ln in fh:
            m = re.fullmatch(r"([0-9a-f]{64})  (.+)\n?", ln)
            if m:
                aprovados[m.group(2)] = m.group(1)

with open(lista, "rb") as fh:
    entradas = [e for e in fh.read().split(b"\0") if e]

for e in entradas:
    if e == dir_b or not e.startswith(dir_b + b"/"):
        continue
    relb = e[len(dir_b) + 1:]
    try:
        rel = relb.decode("utf-8")
    except UnicodeDecodeError:
        v(relb.decode("utf-8", "replace"), 0, "nome de arquivo não é UTF-8")
        rel = relb.decode("utf-8", "replace")
    vistos = set()
    for c in rel:
        m = motivo_char(c, False)
        if m and m not in vistos:
            vistos.add(m)
            v(rel, 0, "NOME de arquivo com " + m)
    if os.path.islink(e) or not os.path.isfile(e):
        continue
    examinados += 1
    try:
        with open(e, "rb") as fh:
            dados = fh.read()
    except OSError as ex:
        v(rel, 0, "ilegível para a varredura de texto (%s)" % ex.__class__.__name__)
        continue
    if checa_aprovados:
        esperado = aprovados.get(rel)
        if esperado is None:
            v(rel, 0, "arquivo fora de arquivos-aprovados — novo arquivo: revise o conteúdo e rode exportar.sh --aprovar-novos")
        elif esperado != hashlib.sha256(dados).hexdigest():
            v(rel, 0, "arquivo alterado: revise o diff e rode exportar.sh --aprovar-novos")
    if b"\0" in dados:
        v(rel, 0, "contém byte NUL (arquivo binário ou UTF-16)")
    try:
        texto = dados.decode("utf-8")
    except UnicodeDecodeError as ex:
        v(rel, 0, "não é UTF-8 válido (byte %d)" % ex.start)
        texto = dados.decode("utf-8", "replace")
    linhas = texto.split("\n")
    n = 0
    mir = [""] * len(linhas)
    achou_b64 = False
    orcamento[0] = ORCAMENTO_DECODIFICACOES
    suspeitos = {}
    for c in set(texto):
        m = motivo_char(c, True)
        if m:
            suspeitos[c] = m
    pend = []   # (linha, [decodificados]) deste arquivo
    try:
        bloco = []   # linhas consecutivas inteiras no charset base64: (número, texto limpo)
        for i, ln in enumerate(linhas, 1):
            if suspeitos and n < MAX_POR_ARQUIVO:
                for c in sorted(set(ln) & set(suspeitos)):
                    v(rel, i, suspeitos[c])
                    n += 1
            if n < MAX_POR_ARQUIVO:
                for rot in achados_padroes(ln):
                    v(rel, i, rot)
                    n += 1
            dec = expande(ln)
            if dec:
                pend.append((i, dec))
            lb = limpa_linha_b64(ln)
            if LINHA_B64.fullmatch(lb):
                bloco.append((i, lb))
            else:
                if len(bloco) >= 2:
                    jd = expande("".join(b[1] for b in bloco))
                    if jd:
                        pend.append((bloco[0][0], jd))
                bloco = []
        if len(bloco) >= 2:
            jd = expande("".join(b[1] for b in bloco))
            if jd:
                pend.append((bloco[0][0], jd))
    except Excedeu:
        v(rel, 0, "base64: orçamento de decodificação excedido; arquivo não totalmente verificado")
    for i, dec in pend:
        achou_b64 = True
        txt = " ".join(d.replace("\n", " ").replace("\r", " ") for d in dec)
        mir[i - 1] = (mir[i - 1] + " " + txt).strip()
        if n < MAX_POR_ARQUIVO:
            vistos = set()
            for d in dec:
                for rot in achados_padroes(d):
                    if rot not in vistos:
                        vistos.add(rot)
                        v(rel, i, rot + SUFIXO_B64)
                        n += 1
    if achou_b64:
        dest = os.path.join(os.fsencode(espelho), relb)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="ascii") as fo:
            fo.write("\n".join(mir))

with open(saida, "w", encoding="utf-8") as fo:
    for linha in viol:
        fo.write(linha + "\n")
with open(contagem, "w", encoding="ascii") as fo:
    fo.write(str(examinados) + "\n")
PY
PYRC=$?
if [ "$PYRC" != 0 ] || [ -s "$ERR" ]; then
  erro "varredura de texto (python3) falhou (exit $PYRC): $(head -c 300 "$ERR" | tr '\n' ' ')"
fi
# fail-closed: o python precisa ter examinado EXATAMENTE os arquivos regulares que a checagem estrutural contou
# (caminho relativo, ".", etc.); divergência = a varredura de texto ignorou arquivos
PYN="$(tr -dc '0-9' < "$CONT")"
[ "$PYN" = "$NF" ] || viola "varredura de texto examinou ${PYN:-nenhum} de $NF arquivo(s) regular(es): arquivos ficaram sem checagem de binário/UTF-8/invisíveis/base64"
while IFS="$(printf '\037')" read -r rel lin mot; do
  [ -n "$rel$lin$mot" ] || continue
  if [ "$lin" = 0 ]; then viola "$rel: $mot"; else viola "$rel:$lin: $mot"; fi
done < "$OUTV"

# ---------- varredura de conteúdo (um grep por regra; arquivos e depois o texto decodificado de base64) ----------
i=0
while [ "$i" -lt "$RN" ]; do
  varre "$DIR" "${RT[$i]}" "${RP[$i]}" "${RF[$i]}" "${RE[$i]}" "${RK[$i]}"
  varre "$MIR" "${RT[$i]} [texto decodificado de base64]" "${RP[$i]}" "${RF[$i]}" "${RE[$i]}" "${RK[$i]}"
  i=$((i+1))
done

# ---------- denylist (nomes) ----------
if [ "$EXPORT" = 1 ]; then
  i=0
  while [ "$i" -lt "$DN" ]; do
    # nomes de arquivos e diretórios: um grep sobre a lista de nomes (linha = um caminho relativo)
    out="$(grep -n ${DF[$i]} -e "${DP[$i]}" "$NOMES" 2>"$ERR")"; rc=$?
    if [ "$rc" -ge 2 ] || [ -s "$ERR" ]; then
      viola "erro interno ao aplicar a denylist '${DT[$i]}' aos nomes"
    elif [ "$rc" = 0 ]; then
      while IFS= read -r l; do
        rel="${l#*:}"
        if [ -n "${DE[$i]}" ] && excecao "$rel" "${DE[$i]}"; then continue; fi
        viola "$rel: NOME de arquivo contém termo da denylist '${DT[$i]}'"
      done <<< "$out"
    fi
    i=$((i+1))
  done
fi

if [ "$RC" = 0 ]; then
  if [ "$MODO_TEXTO" = 1 ]; then M="texto"; elif [ "$EXPORT" = 1 ]; then M="exportação"; else M="genérico"; fi
  echo "$NOME: ok ($NF arquivo(s), modo $M)"
  exit 0
fi
echo "$NOME: $NV violação(ões)"
exit 1

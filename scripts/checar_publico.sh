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
#   - nenhum padrão de segredo: chave Anthropic/OpenAI (inclusive sk- longa com hífen ou sublinhado, que cobre as de
#     projeto, conta de serviço e admin)/Google; AWS (permanente e temporária); Stripe (produção, restrita de produção
#     e de teste); token GitHub, GitLab, npm, Hugging Face e Slack; webhook Slack; chave de conta Azure; JWT e
#     cabeçalho Bearer com JWT; chave PEM com cabeçalho e CORPO de chave PEM sem cabeçalho (>=3 linhas só de base64,
#     de 64 a 76 caracteres cada, somando >=200; sequência só de hexadecimal não conta); chave pública SSH.
#     Não há regra para atribuição genérica (senha ou chave de API seguida de valor): daria falso positivo em
#     documentação
#   - nenhum endereço de e-mail (exceções: variável EMAIL_OK abaixo, por arquivo e endereço exatos)
#   - nenhum IPv4, salvo os blocos reservados para documentação (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24)
#     e os endereços 127.0.0.1 e 0.0.0.0. LIMITE CONHECIDO: número de versão com 4 partes tem a forma de IPv4 e
#     reprova; nenhuma palavra vizinha ("versão", "Xcode", "v") relaxa a regra, porque deixaria passar um IP real
#     escrito depois delas. Saídas: escrever a versão com 3 partes ou listar o par exato arquivo=endereço em IPV4_OK
#   - nenhum CPF (formatado ou 11 dígitos soltos) nem telefone brasileiro (+55 ou DDD entre parênteses)
#   - nenhuma referência a caminhos que existem só no repositório privado de desenvolvimento
#   - nenhum link simbólico nem arquivo especial
#   - todo arquivo é texto UTF-8, sem byte NUL, e, em CONTEÚDO e em NOME de arquivo, sem caractere de formatação
#     (Cf: bidi, largura zero, tags, seletores, hífen condicional...), de controle (Cc, inclusive CR, ESC, DEL e
#     C1; só \n e \t são aceitos em conteúdo), combinante (M*), de uso privado (Co), substituto (Cs), não atribuído
#     (Cn), separador de linha/parágrafo/espaço não ASCII (Zl, Zp, Zs), dígito não ASCII (Nd), nem letra que não
#     seja latina (o nome Unicode precisa começar por LATIN; FULLWIDTH, HALFWIDTH, MATHEMATICAL e as letras i
#     sem ponto reprovam). Letras latinas fora de ASCII só são aceitas em U+00C0-U+017F (exceto U+0131 e
#     U+017F). Reprova também todo caractere cuja decomposição Unicode é de compatibilidade (o NFKC o altera:
#     letras circuladas, algarismos romanos, quadrados, parentizados, largura total, expoentes, frações, ligaduras,
#     reticências, hífen sem quebra...) e os blocos braille (U+2800-28FF), U+FFFC, descrição ideográfica
#     (U+2FF0-2FFF), U+24B6-24E9, U+2160-217F, U+1F130-1F189 e U+249C-24B5. ÚNICA exceção, POR ARQUIVO e só em
#     conteúdo: U+00BA (indicador ordinal masculino) em scripts/lint_modelos.sh (tabela LETRAS_EXCECAO_ARQ); em
#     qualquer outro arquivo, e em qualquer NOME de arquivo, reprova. Os símbolos tipográficos que a árvore usa
#     (aspas, travessões, setas, ≤ ≥ ≠, × ÷, ·, estrela, aviso, marcas de verificação) não são de compatibilidade
#     e seguem aceitos: nenhuma exceção foi necessária para eles
#   - texto normalizado: além do texto original, o gate aplica a NFKC a cada linha e passa o resultado pela
#     denylist (exportação) e por todos os padrões (assim "b" de largura total, circulado ou ordinal vira "b" e
#     é achado, e o ordinal masculino permitido num arquivo não esconde um termo da denylist)
#   - entidades e escapes: &#NNN; &#xHH; (o ponto e vírgula é opcional), \uHHHH, \u{H..}, \UHHHHHHHH, \xHH e %HH
#     (só sequências de pelo menos 2 pares) são decodificados (até 4 camadas, normalizados em NFKC) e o texto
#     decodificado passa pelos mesmos testes
#   - tokens base64 (>=12 caracteres, em 4 alinhamentos para pegar prefixo/sufixo colado; linhas consecutivas
#     inteiras no charset, de >=4 caracteres contando o "=", são juntadas antes, com UMA linha curta de 1 a 3
#     caracteres absorvida em cada ponta) são decodificados (até 4 níveis); os trechos
#     ASCII imprimíveis (>=8 bytes) passam pelos mesmos padrões de segredo/PII e, em exportação, pela denylist.
#     Base64 CURTO: tokens de >=8 caracteres (contando o "=") dão trechos de >=4 bytes que passam SÓ pela denylist
#     e pelos padrões de caminho (o limite de 12 vale para o resto). Orçamento por arquivo (20000 decodificações
#     normais, 200000 curtas): estourar é FAIL, nunca passa calado
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
# Limites residuais (o que este gate NÃO pega): segredo ou termo proibido codificado em hex, rot13, concatenação em
# várias linhas fora do charset base64 (ou com 2+ linhas curtas seguidas na ponta de um base64 quebrado), entidades HTML nomeadas, %HH isolado, ou em mais de 4 níveis de base64 ou de
# escapes; padrão de segredo, e-mail, CPF ou IP dentro de base64 CURTO (<12 caracteres); base64 que decodifica para
# texto não ASCII; corpo de chave PEM com linhas de largura fora de 64-76; segredo com prefixo de provedor fora da
# lista acima; CNPJ, cartão e passaporte; telefones de outros países. Falsos positivos conhecidos: versão com 4 partes
# (ver IPv4) e palavra terminada em sk seguida de hífen e 40 ou mais caracteres de identificador (tem a forma de chave
# sk-); texto aleatório de base64 curto pode, com probabilidade desprezível, decodificar para um termo curto da
# denylist (o gate informa o arquivo e a linha). A categoria Cn depende da versão do Unicode do python3 em uso (uma
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

# Exceções de IPv4: uma por linha, "caminho/relativo=endereço" exatos (mesmo formato do EMAIL_OK). NENHUMA hoje.
# Existe por causa dos números de versão com 4 partes (ex.: uma versão do Xcode escrita com quatro números), que
# têm a forma de um IPv4 e reprovam. Não há regra por palavra vizinha ("versão", "Xcode", "v"): ela deixaria passar
# um IP real escrito depois dessas palavras. A saída é escrever a versão com 3 partes, ou listar aqui o par exato.
IPV4_OK=''

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
MIRA="$(mktemp -d "${TMPDIR:-/tmp}/${NOME}.esp.XXXXXX")" || erro "mktemp falhou"
TXD=""
trap 'rm -rf "$LISTA" "$ERR" "$NOMES" "$OUTV" "$CONT" "$APRN" "$MIRA" "$TXD"' EXIT
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

# varre <rótulo> <padrão> <flags> [exceções] [tipo] [curto] — UM grep (via find -exec ... +) por regra sobre todos os
# arquivos regulares de $DIR e, no mesmo find, dos espelhos de texto decodificado em $MIRA (ver abaixo); viola por
# arquivo:linha. Stderr não vazio (arquivo ilegível, regex ruim, find com erro) = FAIL, nunca skip. tipo "email":
# exceções são pares arquivo=endereço (EMAIL_OK). curto "1": inclui também o espelho de base64 curto (>=8 caracteres),
# que só as regras de denylist e de caminho consultam.
varre() {
  local rot="$1" pat="$2" fl="$3" exc="${4:-}" tipo="${5:-}" curto="${6:-}" out l p rel resto linha achado suf sub kind
  if [ "$curto" = 1 ]; then
    out="$(find "$DIR" "$MIRA" -path "$PRUNE" -prune -o -type f -exec grep -a -n -H $fl -e "$pat" {} + 2>"$ERR")"
  else
    out="$(find "$DIR" "$MIRA" -path "$PRUNE" -prune -o -path "$MIRA/curto" -prune -o -type f -exec grep -a -n -H $fl -e "$pat" {} + 2>"$ERR")"
  fi
  if [ -s "$ERR" ]; then viola "erro interno ao aplicar '$rot': $(head -c 200 "$ERR" | tr '\n' ' ')"; return; fi
  [ -n "$out" ] || return 0
  while IFS= read -r l; do
    p="${l%%:*}"; resto="${l#*:}"; linha="${resto%%:*}"; achado="${resto#*:}"
    case "$p" in
      "$MIRA"/*)
        sub="${p#"$MIRA"/}"; kind="${sub%%/*}"; rel="${sub#*/}"
        case "$kind" in
          b64)   suf=" [texto decodificado de base64]" ;;
          curto) suf=" [texto decodificado de base64 curto]" ;;
          nfkc)  suf=" [texto normalizado NFKC]" ;;
          esc)   suf=" [texto com entidades/escapes decodificados]" ;;
          *)     suf=" [espelho $kind]" ;;
        esac ;;
      *) rel="${p#"$DIR"/}"; suf="" ;;
    esac
    if [ -n "$exc" ] && excecao "$rel" "$exc"; then continue; fi
    if [ "$tipo" = email ] && email_ok "$rel" "$achado"; then continue; fi
    viola "$rel:$linha: $rot$suf"
  done <<< "$out"
}

# ---------- regras de conteúdo (padrões; a denylist é acrescentada no modo exportação) ----------
# RT rótulo, RP padrão, RF flags do grep, RE exceções por arquivo, RK tipo, RB "1" = também vale para o base64 CURTO
# (>=8 caracteres; só a denylist e os padrões de caminho)
# (padrões que precisam de lookahead, validação numérica ou decodificação ficam no bloco python3 mais abaixo)
RN=0
regra() { RT[$RN]="$1"; RP[$RN]="$2"; RF[$RN]="$3"; RE[$RN]="${4:-}"; RK[$RN]="${5:-}"; RB[$RN]="${6:-}"; RN=$((RN+1)); }
regra "caminho absoluto de usuário (macOS)"              '/[U]sers/' "-E" "" "" 1
regra "caminho absoluto de usuário (Linux)"              '/[h]ome/' "-E" "" "" 1
regra "caminho absoluto de volume montado"               '/[V]olumes/' "-E" "" "" 1
regra "caminho pessoal do autor (diretório pessoal, temporário do sistema ou unidade do Windows)" \
  '[~]/[d]ev/|[~]/[D]ocuments|[~]/[D]esktop|[$]HOME/(dev|Documents|Desktop)|/[p]rivate/var|C:\\[U]sers\\' "-E -i" "" "" 1
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
    regra "denylist: '${DT[$i]}'" "${DP[$i]}" "${DF[$i]}" "${DE[$i]}" "" 1
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
python3 -I - "$DIR" "$LISTA" "$MIRA/b64" "$OUTV" "$CONT" "$CHECA_APR" "$APRN" "$MIRA/nfkc" "$MIRA/esc" "$MIRA/curto" "$IPV4_OK" >/dev/null 2>"$ERR" <<'PY'
import base64, binascii, hashlib, os, re, sys, unicodedata

dir_b = os.fsencode(sys.argv[1])
lista, espelho, saida, contagem = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
checa_aprovados = sys.argv[6] == "1"
arq_aprovados = sys.argv[7]
espelho_n, espelho_e, espelho_c = sys.argv[8], sys.argv[9], sys.argv[10]
IPV4_OK = set()   # pares exatos (caminho, endereço) tolerados; vêm da variável IPV4_OK do shell
for _ln in sys.argv[11].split("\n"):
    _r, _s, _ip = _ln.partition("=")
    if _s and _r.strip() and _ip.strip():
        IPV4_OK.add((_r.strip(), _ip.strip()))
US = "\x1f"
MAX_POR_ARQUIVO = 30
ORCAMENTO_DECODIFICACOES = 20000
ORCAMENTO_CURTO = 200000
SUFIXO_B64 = " [texto decodificado de base64]"
SUFIXO_B64_CURTO = " [texto decodificado de base64 curto]"
SUFIXO_NFKC = " [texto normalizado NFKC]"
SUFIXO_ESC = " [texto com entidades/escapes decodificados]"

# ---------- categorias Unicode ----------
# Exceção de letra POR ARQUIVO (nunca global): {ponto de código: {caminhos relativos}}. U+00BA (indicador
# ordinal masculino) aparece em um comentário de um script do plugin; em qualquer outro arquivo reprova.
LETRAS_EXCECAO_ARQ = {0xBA: {"scripts/lint_modelos.sh"}}
LATIN_EXTRA_PROIBIDAS = {0x131, 0x17F}   # i sem ponto e s longo: homóglifos de i e f
# Blocos inteiros proibidos (símbolos que imitam letras/dígitos ou não têm uso legítimo no plugin).
BLOCOS_PROIBIDOS = (
    (0x2800, 0x28FF, "padrão braille"),
    (0xFFFC, 0xFFFC, "caractere de substituição de objeto"),
    (0x2FF0, 0x2FFF, "descrição ideográfica"),
    (0x24B6, 0x24E9, "letra circulada"),
    (0x2160, 0x217F, "algarismo romano"),
    (0x1F130, 0x1F189, "letra quadrada"),
    (0x249C, 0x24B5, "letra entre parênteses"),
)

def motivo_char(c, conteudo, rel=None):
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
    if rel is not None and rel in LETRAS_EXCECAO_ARQ.get(o, ()):
        return None
    for ini, fim, desc in BLOCOS_PROIBIDOS:
        if ini <= o <= fim:
            return "caractere de bloco proibido (%s), possível homóglifo ou ofuscação (U+%04X)" % (desc, o)
    if nome.startswith(("FULLWIDTH", "HALFWIDTH", "MATHEMATICAL")):
        return "caractere de largura total/matemático, possível homóglifo (U+%04X)" % o
    if "DOTLESS" in nome:
        return "letra sem ponto, possível homóglifo (U+%04X)" % o
    if unicodedata.decomposition(c).startswith("<"):
        return "caractere de compatibilidade Unicode (NFKC o altera), possível ofuscação (U+%04X)" % o
    if cat[0] == "L":
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

# ---------- padrões com lógica (texto, base64 decodificado, texto normalizado e escapes decodificados) ----------
RESERVADOS_IP = ("192.0.2.", "198.51.100.", "203.0.113.")
IPS_OK = ("127.0.0.1", "0.0.0.0")

def ip_suspeito(m, rel):
    s = m.group(0)
    if any(int(p) > 255 for p in s.split(".")):
        return False
    if (rel, s) in IPV4_OK:
        return False
    return not (s in IPS_OK or s.startswith(RESERVADOS_IP))

PADROES = [
    ("padrão de segredo: chave Stripe de produção", re.compile(r"sk_[l]ive_"), None),
    ("padrão de segredo: chave Stripe restrita de produção", re.compile(r"rk_[l]ive_"), None),
    ("padrão de segredo: chave Stripe de teste", re.compile(r"sk_[t]est_"), None),
    ("padrão de segredo: chave sk- de 40 ou mais caracteres", re.compile(r"s[k]-[A-Za-z0-9_-]{40,}"), None),
    ("padrão de segredo: chave de acesso temporária AWS", re.compile(r"[A]SIA[0-9A-Z]{16}"), None),
    ("padrão de segredo: token GitLab", re.compile(r"g[l]pat-[A-Za-z0-9_-]{20,}"), None),
    ("padrão de segredo: token npm", re.compile(r"n[p]m_[A-Za-z0-9]{36}"), None),
    ("padrão de segredo: token Hugging Face", re.compile(r"h[f]_[A-Za-z0-9]{30,}"), None),
    ("padrão de segredo: chave de conta Azure", re.compile(r"AccountK[e]y=[A-Za-z0-9+/=]{40,}"), None),
    ("padrão de segredo: cabeçalho Bearer com JWT", re.compile(r"[B]earer\s+e[y]J"), None),
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

def achados_padroes(texto, rel, so_caminho=False):
    r = []
    for rotulo, rx, filtro in PADROES:
        if so_caminho and not rotulo.startswith("caminho"):
            continue
        for m in rx.finditer(texto):
            if filtro is None or filtro(m, rel):
                r.append(rotulo)
                break
    return r

# Corpo de chave PEM sem o cabeçalho BEGIN: >=3 linhas consecutivas só de base64 com 64 a 76 caracteres (a última
# pode ser mais curta e ter "="), somando >=200 caracteres. Sequência só de hexadecimal (lista de sha256) não conta.
PEM_ROTULO = "padrão de segredo: corpo de chave PEM sem cabeçalho (bloco base64 em linhas de 64 a 76 caracteres)"
RX_PEM_CHEIA = re.compile(r"[A-Za-z0-9+/]{64,76}={0,2}")
RX_PEM_FIM = re.compile(r"[A-Za-z0-9+/]{1,76}={0,2}")
RX_SO_HEX = re.compile(r"[0-9a-fA-F]+")

def limpa_pem(ln):   # como limpa_linha_b64, mas sem tirar o "+" das pontas (faz parte do alfabeto)
    s = re.sub(r"^(?:#|//|>)\s*", "", ln.strip())
    return s.strip(" \t\"'`\\,;")

def pem_sem_cabecalho(linhas):
    """Devolve o índice (0-based) da primeira linha de um bloco suspeito, ou None."""
    i, n = 0, len(linhas)
    while i < n:
        j, total, cheias, partes = i, 0, 0, []
        while j < n:
            lb = limpa_pem(linhas[j])
            if not RX_PEM_CHEIA.fullmatch(lb):
                break
            total += len(lb); cheias += 1; partes.append(lb); j += 1
        if cheias >= 1 and j < n:
            lb = limpa_pem(linhas[j])
            if RX_PEM_FIM.fullmatch(lb):
                total += len(lb); partes.append(lb); j += 1
        if cheias >= 3 and total >= 200 and not RX_SO_HEX.fullmatch("".join(partes).replace("=", "")):
            return i
        i = max(j, i + 1)
    return None

# ---------- entidades e escapes ----------
RX_ESC = re.compile(
    r"&#[xX]([0-9A-Fa-f]{1,6});?"
    r"|&#([0-9]{1,7});?"
    r"|\\u\{([0-9A-Fa-f]{1,6})\}"
    r"|\\u([0-9A-Fa-f]{4})"
    r"|\\U([0-9A-Fa-f]{8})"
    r"|((?:\\x[0-9A-Fa-f]{2})+)"
    r"|((?:%[0-9A-Fa-f]{2}){2,})")
RX_HEX2 = re.compile(r"(?:\\x|%)([0-9A-Fa-f]{2})")

def _cp(n):
    try:
        return chr(n)
    except (ValueError, OverflowError):
        return "?"

def _sub_esc(m):
    g = m.groups()
    for k in (0, 2, 3, 4):
        if g[k] is not None:
            return _cp(int(g[k], 16))
    if g[1] is not None:
        return _cp(int(g[1]))
    raw = bytes(int(h, 16) for h in RX_HEX2.findall(g[5] if g[5] is not None else g[6]))
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("latin-1")

def decodifica_escapes(s):
    for _ in range(4):
        n = RX_ESC.sub(_sub_esc, s)
        if n == s:
            break
        s = n
    return s

def nfkc(s):
    return unicodedata.normalize("NFKC", s)

def plano(s):   # uma linha de espelho nunca vira duas
    return s.replace("\n", " ").replace("\r", " ")

# ---------- base64 ----------
TOKEN = re.compile(r"[A-Za-z0-9+/_-]{12,}={0,2}")
TOKEN_CURTO = re.compile(r"[A-Za-z0-9+/_-]{6,}={0,2}")
LINHA_B64 = re.compile(r"[A-Za-z0-9+/_-]+={0,2}")   # linha inteira no charset; o "=" conta para o tamanho
IMPRIMIVEIS = re.compile(rb"[\x20-\x7e\t\n\r]{8,}")
IMPRIMIVEIS_CURTO = re.compile(rb"[\x20-\x7e]{4,}")
MAX_TOKEN = 8192

class Excedeu(Exception):
    pass

orcamento = [ORCAMENTO_DECODIFICACOES]
orcamento_curto = [ORCAMENTO_CURTO]
_cache = {}

def decodifica_janelas(tok, curto=False):
    """Decodifica o token em 4 alinhamentos (prefixo colado de qualquer tamanho cai em um deles) e devolve os
    trechos ASCII imprimíveis (>=8 bytes; no modo curto, >=4 bytes não brancos). Sufixo colado vira lixo no fim,
    que é descartado."""
    chave = (tok, curto)
    if chave in _cache:
        return _cache[chave]
    out = []
    t0 = tok[:MAX_TOKEN]
    minimo = 6 if curto else 12
    rx = IMPRIMIVEIS_CURTO if curto else IMPRIMIVEIS
    cont = orcamento_curto if curto else orcamento
    for s in range(4):
        t = t0[s:].rstrip("=").replace("-", "+").replace("_", "/")
        if len(t) < minimo:
            break
        if len(t) % 4 == 1:
            t = t[:-1]
        t += "=" * (-len(t) % 4)
        cont[0] -= 1
        if cont[0] < 0:
            raise Excedeu()
        try:
            raw = base64.b64decode(t, validate=True)
        except (binascii.Error, ValueError):
            continue
        for m in rx.finditer(raw):
            seg = m.group(0).decode("ascii")
            if curto and len(seg.strip()) < 4:
                continue
            out.append(seg)
    _cache[chave] = out
    return out

def expande(texto, nivel=1):
    res = []
    for m in TOKEN.finditer(texto):
        for d in decodifica_janelas(m.group(0)):
            res.append(d)
            if nivel < 4:
                res.extend(expande(d, nivel + 1))
    return res

def expande_curto(texto, nivel=1):
    """Tokens base64 de >=8 caracteres (com o "="); trechos decodificados de >=4 bytes. Só a denylist e os padrões
    de caminho olham este resultado (o limite de 12 caracteres vale para todo o resto)."""
    res = []
    for m in TOKEN_CURTO.finditer(texto):
        tok = m.group(0)
        if len(tok) < 8:
            continue
        for d in decodifica_janelas(tok, True):
            res.append(d)
            if nivel < 4:
                res.extend(expande_curto(d, nivel + 1))
    return res

def limpa_linha_b64(ln):
    s = re.sub(r"^(?:#|//|>)\s*", "", ln.strip())
    return s.strip(" \t\"'`\\,;+")

def blocos_b64(lbs):
    """Linhas consecutivas inteiras no charset base64 são juntadas antes de decodificar. Membro "cheio": >=4
    caracteres (o "=" conta). Cada bloco de linhas cheias absorve UMA linha curta (1 a 3 caracteres, o "=" conta)
    imediatamente antes e UMA imediatamente depois (cabeça e cauda de um base64 quebrado em linhas). Precisa ter
    >=2 linhas. Devolve (número da primeira linha, texto junto). Limite: duas linhas curtas seguidas na ponta não
    são absorvidas."""
    n = len(lbs)
    cls = [(2 if len(lb) >= 4 else 1) if LINHA_B64.fullmatch(lb) else 0 for lb in lbs]
    res, i = [], 0
    while i < n:
        if cls[i] != 2:
            i += 1
            continue
        j = i
        while j < n and cls[j] == 2:
            j += 1
        a, b = i, j
        if a > 0 and cls[a - 1] == 1:
            a -= 1
        if b < n and cls[b] == 1:
            b += 1
        if b - a >= 2:
            res.append((a + 1, "".join(lbs[a:b])))
        i = j
    return res

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

def grava_espelho(base, relb, linhas_esp):
    if not any(linhas_esp):
        return
    dest = os.path.join(os.fsencode(base), relb)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "wb") as fo:
        fo.write("\n".join(linhas_esp).encode("utf-8", "replace"))

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
    mir = [""] * len(linhas)     # base64 decodificado (>=12 caracteres): todas as regras de conteúdo
    mirc = [""] * len(linhas)    # base64 curto (>=8 caracteres): só denylist e caminhos
    mirn = [""] * len(linhas)    # texto normalizado NFKC
    mire = [""] * len(linhas)    # entidades e escapes decodificados (e normalizados)
    orcamento[0] = ORCAMENTO_DECODIFICACOES
    orcamento_curto[0] = ORCAMENTO_CURTO
    suspeitos = {}
    for c in set(texto):
        m = motivo_char(c, True, rel)
        if m:
            suspeitos[c] = m
    pend = []     # (linha, [decodificados]) deste arquivo
    pend_c = []   # idem, modo curto
    try:
        lbs = []   # texto limpo de cada linha, para juntar linhas de base64 quebrado

        for i, ln in enumerate(linhas, 1):
            if suspeitos and n < MAX_POR_ARQUIVO:
                for c in sorted(set(ln) & set(suspeitos)):
                    v(rel, i, suspeitos[c])
                    n += 1
            if n < MAX_POR_ARQUIVO:
                for rot in achados_padroes(ln, rel):
                    v(rel, i, rot)
                    n += 1
            tn = nfkc(ln)
            if tn != ln:
                mirn[i - 1] = plano(tn)
                if n < MAX_POR_ARQUIVO:
                    for rot in achados_padroes(tn, rel):
                        v(rel, i, rot + SUFIXO_NFKC)
                        n += 1
            de = decodifica_escapes(ln)
            if de != ln:
                te = nfkc(de)
                mire[i - 1] = plano(te)
                if n < MAX_POR_ARQUIVO:
                    for rot in achados_padroes(te, rel):
                        v(rel, i, rot + SUFIXO_ESC)
                        n += 1
            dec = expande(ln)
            if dec:
                pend.append((i, dec))
            decc = expande_curto(ln)
            if decc:
                pend_c.append((i, decc))
            lbs.append(limpa_linha_b64(ln))
        for ini, junto in blocos_b64(lbs):
            jd = expande(junto)
            if jd:
                pend.append((ini, jd))
            jc = expande_curto(junto)
            if jc:
                pend_c.append((ini, jc))
    except Excedeu:
        v(rel, 0, "base64: orçamento de decodificação excedido; arquivo não totalmente verificado")
    ip = pem_sem_cabecalho(linhas)
    if ip is not None and n < MAX_POR_ARQUIVO:
        v(rel, ip + 1, PEM_ROTULO)
        n += 1
    achou_b64 = False
    for i, dec in pend:
        achou_b64 = True
        extras = []
        for d in dec:
            x = decodifica_escapes(d)
            if x != d:
                extras.append(nfkc(x))
        txt = " ".join(d.replace("\n", " ").replace("\r", " ") for d in dec + extras)
        mir[i - 1] = (mir[i - 1] + " " + txt).strip()
        if n < MAX_POR_ARQUIVO:
            vistos = set()
            for d in dec + extras:
                for rot in achados_padroes(d, rel):
                    if rot not in vistos:
                        vistos.add(rot)
                        v(rel, i, rot + SUFIXO_B64)
                        n += 1
                if "\n" in d and PEM_ROTULO not in vistos and pem_sem_cabecalho(d.split("\n")) is not None:
                    vistos.add(PEM_ROTULO)
                    v(rel, i, PEM_ROTULO + SUFIXO_B64)
                    n += 1
    for i, dec in pend_c:
        extras = []
        for d in dec:
            x = decodifica_escapes(d)
            if x != d:
                extras.append(nfkc(x))
        txt = " ".join(plano(d) for d in dec + extras)
        mirc[i - 1] = (mirc[i - 1] + " " + txt).strip()
        if n < MAX_POR_ARQUIVO:
            vistos = set()
            for d in dec + extras:
                for rot in achados_padroes(d, rel, True):
                    if rot not in vistos:
                        vistos.add(rot)
                        v(rel, i, rot + SUFIXO_B64_CURTO)
                        n += 1
    grava_espelho(espelho, relb, mir)
    grava_espelho(espelho_c, relb, mirc)
    grava_espelho(espelho_n, relb, mirn)
    grava_espelho(espelho_e, relb, mire)

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

# ---------- varredura de conteúdo (um grep por regra, sobre os arquivos e sobre os espelhos de texto decodificado) ----------
# Espelhos em $MIRA/<tipo>/<caminho relativo>, na mesma linha do original: b64 (base64 decodificado, >=12 caracteres),
# curto (base64 de >=8 caracteres; só denylist e caminhos), nfkc (texto normalizado) e esc (entidades e escapes
# decodificados e normalizados).
i=0
while [ "$i" -lt "$RN" ]; do
  varre "${RT[$i]}" "${RP[$i]}" "${RF[$i]}" "${RE[$i]}" "${RK[$i]}" "${RB[$i]}"
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

#!/usr/bin/env bash
# tokens.sh — gera App/Shared/Kit/TokensGerados.swift a partir do bloco json
# de tokens em .raiz/design/direcao.lock.md. Nunca editar a saída à mão.
#
# Uso: tokens.sh [direcao.lock.md] [saida.swift]
set -uo pipefail
LOCK="${1:-.raiz/design/direcao.lock.md}"
SAIDA="${2:-App/Shared/Kit/TokensGerados.swift}"

[ -f "$LOCK" ] || { echo "FAIL: $LOCK ausente — nada para gerar"; exit 1; }
command -v python3 >/dev/null || { echo "FAIL: python3 é obrigatório"; exit 1; }
mkdir -p "$(dirname "$SAIDA")" || { echo "FAIL: não foi possível criar $(dirname "$SAIDA")"; exit 1; }

python3 - "$LOCK" "$SAIDA" <<'PY'
import json, re, sys, datetime

lock_path, saida_path = sys.argv[1], sys.argv[2]
texto = open(lock_path, encoding="utf-8").read()

m = re.search(r'```json\s*\n(.*?)```', texto, re.S)
if not m:
    print(f"FAIL: {lock_path} sem bloco ```json``` de tokens")
    sys.exit(1)
try:
    tokens = json.loads(m.group(1))
except Exception as e:
    print(f"FAIL: bloco json de {lock_path} inválido ({e})")
    sys.exit(1)

cores = tokens.get("cores", {})
if not cores:
    print(f"FAIL: {lock_path} sem chave 'cores'")
    sys.exit(1)

HEX_RE = re.compile(r'^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$')

def hex_para_swift(valor, chave):
    mm = HEX_RE.match(valor)
    if not mm:
        print(f"FAIL: cores.{chave} não é hex válido: {valor!r}")
        sys.exit(1)
    h = mm.group(1)
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    return h.upper()

# Campos de raio que a decisão de 2026-09-24 mandou anexar ao `Raio` já
# existente (Tokens.swift), em vez de um tipo `RaioGerado` paralelo — único
# ponto de leitura de raio para o construtor.
CAMPOS_RAIO = {"raioBotao", "raioChip", "raioPill"}

espacamento = dict(tokens.get("espacamento", {}))
raio_extra = {k: v for k, v in espacamento.items() if k in CAMPOS_RAIO}
espacamento_resto = {k: v for k, v in espacamento.items() if k not in CAMPOS_RAIO}

def declaracao_swift(chave, v):
    """Retorna a linha completa 'static let <chave>: <tipo> = <valor>'."""
    if isinstance(v, bool):
        print(f"FAIL: valor booleano não suportado em espacamento: {v!r}")
        sys.exit(1)
    if isinstance(v, (int, float)):
        return f"static let {chave}: CGFloat = {v}"
    if isinstance(v, list):
        if not all(isinstance(x, (int, float)) and not isinstance(x, bool) for x in v):
            print(f"FAIL: lista de espacamento com item não numérico: {v!r}")
            sys.exit(1)
        itens = ", ".join(str(x) for x in v)
        return f"static let {chave}: [CGFloat] = [{itens}]"
    print(f"FAIL: tipo não suportado em espacamento: {v!r}")
    sys.exit(1)

agora = datetime.date.today().isoformat()

linhas = []
linhas.append("// GERADO — não editar. Fonte: .raiz/design/direcao.lock.md (bloco json de tokens).")
linhas.append(f"// Gerado por scripts/tokens.sh ({agora}). Regenerar: scripts/tokens.sh, nunca à mão.")
linhas.append("import SwiftUI")
linhas.append("")

if raio_extra:
    linhas.append("/// Estende o `Raio` de Tokens.swift com os raios da direção travada — nenhum")
    linhas.append("/// tipo paralelo, um único ponto de leitura pro construtor (decisão 2026-09-24).")
    linhas.append("extension Raio {")
    for chave in sorted(raio_extra):
        v = raio_extra[chave]
        linhas.append(f"    static let {chave}: CGFloat = {v}")
    linhas.append("}")
    linhas.append("")

linhas.append("/// Cores da direção travada. Nomes vêm do `direcao.lock.md`, não dos nomes")
linhas.append("/// semânticos de `Cor` (Tokens.swift) — evita colisão (`fundo`/`texto` já existem")
linhas.append("/// lá com outro valor). Mapear qual `CorGerada` substitui qual uso é decisão do")
linhas.append("/// construtor ao implementar a tela, não deste gerador.")
linhas.append("enum CorGerada {")
for chave in sorted(cores):
    hexval = hex_para_swift(cores[chave], chave)
    linhas.append(f"    static let {chave} = Color(hex: 0x{hexval})")
linhas.append("}")

if espacamento_resto:
    linhas.append("")
    linhas.append("/// Espaçamento/dimensão da direção travada. Contagens (ex.: máximo de chips)")
    linhas.append("/// também viram CGFloat por uniformidade — converta com Int(...) onde precisar")
    linhas.append("/// de um inteiro de verdade.")
    linhas.append("enum EspacoGerado {")
    for chave in sorted(espacamento_resto):
        linhas.append(f"    {declaracao_swift(chave, espacamento_resto[chave])}")
    linhas.append("}")

tipografia = tokens.get("tipografia", {})
if tipografia:
    linhas.append("")
    linhas.append("// Tipografia do lock é descrição de referência (ex.: \"15/20 semibold 650\"),")
    linhas.append("// não literal de Font. `Tipo` (Tokens.swift) já é 100% Dynamic Type — gerar")
    linhas.append("// Font de tamanho fixo aqui violaria essa regra do próprio kit. Mapear cada")
    linhas.append("// entrada abaixo para um caso de `Tipo` é decisão do construtor, registrada")
    linhas.append("// aqui só como referência, não como código:")
    for chave in sorted(tipografia):
        linhas.append(f"//   tipografia.{chave} = {tipografia[chave]!r}")

with open(saida_path, "w", encoding="utf-8") as f:
    f.write("\n".join(linhas) + "\n")

print(f"tokens: gerado {saida_path} ({len(cores)} cores, {len(raio_extra)} raio, {len(espacamento_resto)} espaçamento)")
PY

#!/usr/bin/env bash
# checar_tokens.sh — contrato mecânico do gerado de scripts/tokens.sh:
# nenhum hex do lock se perde na tradução, e o contraste recalculado a
# partir do .swift gerado ainda bate no mesmo limiar que checar_design.sh
# já validou (não recalcula do zero — cola o mesmo par declarado).
#
# Uso: checar_tokens.sh <TokensGerados.swift> [direcao.lock.md]
set -uo pipefail
SWIFT="${1:-}"
LOCK="${2:-.raiz/design/direcao.lock.md}"

[ -n "$SWIFT" ] || { echo "FAIL: uso: checar_tokens.sh <TokensGerados.swift> [direcao.lock.md]"; exit 1; }
[ -f "$SWIFT" ] || { echo "FAIL: $SWIFT ausente"; exit 1; }
[ -f "$LOCK" ]  || { echo "FAIL: $LOCK ausente"; exit 1; }
grep -q '^// GERADO' "$SWIFT" || echo "AVISO: $SWIFT sem cabeçalho '// GERADO' — confirme que não foi editado à mão"

python3 - "$SWIFT" "$LOCK" <<'PY'
import json, re, sys

swift_path, lock_path = sys.argv[1], sys.argv[2]
swift = open(swift_path, encoding="utf-8").read()
texto = open(lock_path, encoding="utf-8").read()

m = re.search(r'```json\s*\n(.*?)```', texto, re.S)
if not m:
    print(f"FAIL: {lock_path} sem bloco json de tokens")
    sys.exit(1)
tokens = json.loads(m.group(1))
cores = tokens.get("cores", {})
espacamento = tokens.get("espacamento", {})
pares = tokens.get("pares_contraste", [])

falhou = False

# 1) nenhum hex do lock se perde na tradução para o .swift gerado.
def norm_hex(v):
    h = v.lstrip('#')
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    return h.upper()

for chave, valor in cores.items():
    h = norm_hex(valor)
    if f"0X{h}" not in swift.upper():
        print(f"FAIL: cor '{chave}' ({valor}) não aparece em {swift_path}")
        falhou = True

# 2) campos de raio extraídos de espacamento (decisão 2026-09-24: extension
#    Raio, não um tipo paralelo) — se existem no lock, têm que existir dentro
#    de um bloco `extension Raio` no gerado, não em outro lugar.
CAMPOS_RAIO = {"raioBotao", "raioChip", "raioPill"}
raio_no_lock = {k: v for k, v in espacamento.items() if k in CAMPOS_RAIO}
if raio_no_lock:
    bloco = re.search(r'extension Raio\s*\{(.*?)\}', swift, re.S)
    if not bloco:
        print(f"FAIL: lock declara {sorted(raio_no_lock)} mas {swift_path} não tem 'extension Raio'")
        falhou = True
    else:
        for chave in raio_no_lock:
            if not re.search(rf'static let {re.escape(chave)}\b', bloco.group(1)):
                print(f"FAIL: 'extension Raio' em {swift_path} sem '{chave}'")
                falhou = True

# 3) contraste recalculado a partir dos hex do .swift gerado — mesma fórmula
#    e mesmo limiar (4.5) que checar_design.sh já usou na 0.2.
def lum(h):
    h = h.lstrip('#')
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def ratio(a, b):
    x, y = sorted([lum(a), lum(b)], reverse=True)
    return (x + 0.05) / (y + 0.05)

hex_no_swift = dict(re.findall(r'static let (\w+) = Color\(hex: 0x([0-9A-Fa-f]+)\)', swift))

if not pares:
    print(f"AVISO: {lock_path} sem 'pares_contraste' — contraste não reconferido")
else:
    def resolve(nome):
        if nome in hex_no_swift:
            return hex_no_swift[nome]
        if re.match(r'^#?[0-9A-Fa-f]{3,6}$', nome):
            return nome.lstrip('#')
        return None

    for a, b in pares:
        ha, hb = resolve(a), resolve(b)
        if not ha or not hb:
            print(f"FAIL: par {a}/{b} não resolvido no .swift gerado (chave ausente)")
            falhou = True
            continue
        r = ratio(ha, hb)
        if r < 4.5:
            print(f"FAIL: contraste recalculado {a}/{b} = {r:.2f} (< 4.5) a partir do .swift gerado")
            falhou = True

sys.exit(1 if falhou else 0)
PY
rc=$?
[ "$rc" = 0 ] && echo "checar_tokens: ok"
exit "$rc"

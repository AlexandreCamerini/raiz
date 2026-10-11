#!/usr/bin/env bash
# checar_design.sh — contrato mecânico das direções do designer
D="${1:-.raiz/design}"
rc=0
[ -f "$D/referencias.md" ] || { echo "FAIL: referencias.md ausente"; rc=1; }
[ -f "$D/fixture.json" ]   || { echo "FAIL: fixture.json ausente"; rc=1; }
if [ -f "$D/referencias.md" ]; then
  grep -q '^## Insumos internos lidos' "$D/referencias.md" || { echo "FAIL: referencias.md sem '## Insumos internos lidos'"; rc=1; }
  n="$(grep -cE '^\|.*(https?://|\.md|\.html|\.swift)' "$D/referencias.md")"
  [ "$n" -ge 6 ] || { echo "FAIL: referencias.md com $n referências (mínimo 6)"; rc=1; }
fi
for id in hig mercado aposta; do
  for ext in md html; do [ -f "$D/direcoes/$id.$ext" ] || { echo "FAIL: direcoes/$id.$ext ausente"; rc=1; }; done
  if [ -f "$D/direcoes/$id.html" ] && grep -nE '<(script|link|img|iframe)[^>]+(src|href)="https?://' "$D/direcoes/$id.html"; then
    echo "FAIL: $id.html carrega recurso externo"; rc=1
  fi
  if [ -f "$D/direcoes/$id.md" ]; then
    for s in 'Tese' 'Tokens' 'Telas' 'Invariantes respeitados' 'O que se perde'; do
      grep -qE "^## $s" "$D/direcoes/$id.md" || { echo "FAIL: $id.md sem '## $s'"; rc=1; }
    done
  fi
done
python3 - "$D" <<'PY' || rc=1
import json, re, sys, pathlib
d = pathlib.Path(sys.argv[1]); falhou = False
def lum(h):
    h = h.lstrip('#')
    if len(h) == 3: h = ''.join(c*2 for c in h)
    r, g, b = (int(h[i:i+2], 16)/255 for i in (0, 2, 4))
    f = lambda c: c/12.92 if c <= 0.03928 else ((c+0.055)/1.055)**2.4
    return 0.2126*f(r) + 0.7152*f(g) + 0.0722*f(b)
def ratio(a, b):
    x, y = sorted([lum(a), lum(b)], reverse=True); return (x+0.05)/(y+0.05)
paletas = {}
try:
    fx = json.loads((d/'fixture.json').read_text())
    nome = json.dumps(fx, ensure_ascii=False)
    nomes = re.findall(r'"nome"\s*:\s*"([^"]+)"', nome)
    ancora = nomes[0] if nomes else None
except Exception as e:
    print(f"FAIL: fixture.json ilegível ({e})"); falhou = True; ancora = None
for i in ("hig", "mercado", "aposta"):
    md = d/'direcoes'/f'{i}.md'; ht = d/'direcoes'/f'{i}.html'
    if not md.exists(): continue
    m = re.search(r'## Tokens.*?```json\s*\n(.*?)```', md.read_text(), re.S)
    if not m: print(f"FAIL: {i}.md sem bloco json em ## Tokens"); falhou = True; continue
    try: t = json.loads(m.group(1))
    except Exception as e: print(f"FAIL: {i}.md tokens json inválido ({e})"); falhou = True; continue
    cores = t.get('cores', {}); pares = t.get('pares_contraste', [])
    if not pares: print(f"FAIL: {i}.md sem pares_contraste"); falhou = True
    for a, b in pares:
        ca, cb = cores.get(a, a), cores.get(b, b)
        try: r = ratio(ca, cb)
        except Exception: print(f"FAIL: {i} par {a}/{b} não é hex"); falhou = True; continue
        if r < 4.5: print(f"FAIL: {i} contraste {a}/{b} = {r:.2f} (< 4.5)"); falhou = True
    paletas[i] = tuple(sorted(cores.values()))
    if ancora and ht.exists() and ancora not in ht.read_text():
        print(f"FAIL: {i}.html não usa o fixture (não contém '{ancora}')"); falhou = True
if len(paletas) == 3 and len(set(paletas.values())) < 3:
    print("FAIL: duas ou mais direções com a mesma paleta — não são distintas"); falhou = True
sys.exit(1 if falhou else 0)
PY
[ "$rc" = 0 ] && echo "checar_design: ok"
exit "$rc"

#!/usr/bin/env bash
# checar_briefing.sh — valida .raiz/briefing.json contra schemas/briefing.schema.json
# de verdade (carrega o schema e interpreta os campos, não reimplementa as
# regras à mão). Resolve o achado "schemas decorativos": este era o único dos 3
# schemas do plugin que não tinha gate nenhum.
#
# Uso: checar_briefing.sh [briefing.json] [schema.json]
# FAIL: JSON inválido; campo obrigatório ausente; tipo errado; string mais
#       curta que minLength; array com menos itens que minItems; item de
#       array com tipo errado; número fora de minimum/maximum.
# WARN: completude < 0.8 — o schema não exige um valor mínimo pra completude
#       (é number entre 0 e 1); 0.8 é o critério de commands/novo.md pra
#       apresentar aprovação, não de validade do JSON em si.
set -uo pipefail
DOC="${1:-.raiz/briefing.json}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
SCHEMA="${2:-$AQUI/../schemas/briefing.schema.json}"

[ -f "$DOC" ]    || { echo "FAIL: $DOC ausente"; exit 1; }
[ -f "$SCHEMA" ] || { echo "FAIL: $SCHEMA ausente"; exit 1; }
command -v jq >/dev/null || { echo "FAIL: jq ausente"; exit 1; }
jq empty "$DOC" 2>/dev/null    || { echo "FAIL: $DOC não é JSON válido"; exit 1; }
jq empty "$SCHEMA" 2>/dev/null || { echo "FAIL: $SCHEMA não é JSON válido"; exit 1; }

python3 - "$DOC" "$SCHEMA" <<'PY'
import json, sys

doc_path, schema_path = sys.argv[1], sys.argv[2]
doc = json.load(open(doc_path, encoding="utf-8"))
schema = json.load(open(schema_path, encoding="utf-8"))

falhou = False
JSON_TIPO = {str: "string", int: "number", float: "number", bool: "boolean", list: "array", dict: "object"}

def tipo_de(v):
    if isinstance(v, bool):
        return "boolean"
    return JSON_TIPO.get(type(v), "desconhecido")

def checa_valor(campo, spec, v):
    """Verifica um valor contra as palavras-chave do schema que este plugin usa
    (type, minLength, maxLength, minItems, maxItems, minimum, maximum, items.type).
    Não é um validador de JSON Schema genérico -- cobre só o que
    schemas/briefing.schema.json de fato declara."""
    global falhou
    t = spec.get("type")
    if t and tipo_de(v) != t:
        print(f"FAIL: {campo}: esperado tipo '{t}', veio '{tipo_de(v)}' ({v!r})")
        falhou = True
        return
    if t == "string":
        if "minLength" in spec and len(v) < spec["minLength"]:
            print(f"FAIL: {campo}: string com {len(v)} caractere(s), mínimo {spec['minLength']}")
            falhou = True
        if "maxLength" in spec and len(v) > spec["maxLength"]:
            print(f"FAIL: {campo}: string com {len(v)} caractere(s), máximo {spec['maxLength']}")
            falhou = True
    elif t == "number":
        if "minimum" in spec and v < spec["minimum"]:
            print(f"FAIL: {campo}: {v} abaixo do mínimo {spec['minimum']}")
            falhou = True
        if "maximum" in spec and v > spec["maximum"]:
            print(f"FAIL: {campo}: {v} acima do máximo {spec['maximum']}")
            falhou = True
    elif t == "array":
        if "minItems" in spec and len(v) < spec["minItems"]:
            print(f"FAIL: {campo}: array com {len(v)} item(ns), mínimo {spec['minItems']}")
            falhou = True
        if "maxItems" in spec and len(v) > spec["maxItems"]:
            print(f"FAIL: {campo}: array com {len(v)} item(ns), máximo {spec['maxItems']}")
            falhou = True
        item_tipo = (spec.get("items") or {}).get("type")
        if item_tipo:
            for i, item in enumerate(v):
                if tipo_de(item) != item_tipo:
                    print(f"FAIL: {campo}[{i}]: esperado tipo '{item_tipo}', veio '{tipo_de(item)}'")
                    falhou = True

for campo in schema.get("required", []):
    if campo not in doc:
        print(f"FAIL: campo obrigatório '{campo}' ausente")
        falhou = True

propriedades = schema.get("properties", {})
for campo, spec in propriedades.items():
    if campo in doc:
        checa_valor(campo, spec, doc[campo])

completude = doc.get("completude")
if isinstance(completude, (int, float)) and completude < 0.8:
    print(f"WARN: completude {completude} — abaixo de 0.8, ainda não é hora de pedir aprovação (commands/novo.md)")

sys.exit(1 if falhou else 0)
PY
rc=$?
[ "$rc" = 0 ] && echo "checar_briefing: ok"
exit "$rc"

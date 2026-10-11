#!/usr/bin/env bash
# SessionStart: informa versão do Raiz, caminho dos recursos e estado do projeto.
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
V="$(grep -m1 '"version"' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null | tr -dc '0-9.')"
echo "Raiz v${V:-?} ativo. Recursos do plugin em: $ROOT (scripts/, schemas/, ecossistema/, cicatrizes/, contratos/, modelos/)."
if [ -f .raiz/estado.json ]; then
  if command -v jq >/dev/null; then
    echo "Projeto Raiz: modo=$(jq -r '.modo // "?"' .raiz/estado.json) etapa=$(jq -r '.etapa // "?"' .raiz/estado.json)"
  else echo "Projeto Raiz: .raiz/estado.json presente"; fi
fi
echo "Ajuda a qualquer momento, sem alterar o projeto: /raiz:consultor \"<sua pergunta>\""
exit 0

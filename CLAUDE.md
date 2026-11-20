# Raiz — plugin do Claude Code

Plugin (comandos `/raiz:*`, agentes, scripts bash). Sem build: é markdown + YAML/JSON + bash. Docs e prompts em PT-BR.

## Verificação (todas exit 0 antes de commitar; são os passos do CI)
```bash
bash scripts/lint_modelos.sh       # frontmatter de agents/*.md × modelos/matriz.yaml
bash evals/lint_modelos/rodar.sh   # fixtures do lint
bash evals/gates/rodar.sh          # fixtures do gates.sh
bash scripts/checar_publico.sh .   # higiene: segredos, caminhos absolutos, termos proibidos
```
Teste manual: `claude --plugin-dir "$PWD"`; manifesto: `claude plugin validate "$PWD"`. Deps: bash, git, jq, python3.

## Estrutura
- `commands/` → `/raiz:<nome>`; `agents/` → subagentes; `scripts/` → verificações fail-closed chamadas pelos comandos
- `modelos/matriz.yaml` → fonte de verdade de model/effort por agente (`hipoteses_iniciais`) + `medicoes`
- `cicatrizes/registro.yaml` → incidente → regra → verificação; `contratos/bifurcacao.md` → formato de toda decisão com >1 caminho
- `schemas/` → JSON Schemas de `.raiz/*.json`; `hooks/hooks.json` → SessionStart roda `scripts/sessao.sh`

## Regras
- Agente novo/alterado: declara `model` (+ `effort` se não-Haiku) e bate com `hipoteses_iniciais`; atualize também a tabela do README (o lint não cobre).
- Fable (`fable`/`best`/`claude-fable*`) é proibido em agente (o lint reprova: cobra créditos sem prompt em subagente/`-p`). A linha `fable` em `modelos:` da matriz é só documentação; esforço alto = `opus/high`.
- Gate bloqueante sem comando ou malformado = falha, nunca skip.
- Mudou um script → crie/ajuste o caso em `evals/<nome>/`.
- Model/effort só muda com medição em `medicoes` e doc oficial reverificada (atualize `verificado_em`).
- Nada de dado pessoal/privado em fixtures, exemplos ou cicatrizes (sem caminho absoluto, e-mail, nome de projeto de terceiro).

## Gotchas
- Haiku 5.5 aceita effort, mas o lint ainda isenta Haiku: `explorador` e `radar-auditor` rodam no default (`medium`) sem declarar. Fixar effort neles exige medição.
- Toda release sobe `version` em `.claude-plugin/plugin.json`: o cache do plugin só renova quando a versão muda.
- Versão sempre com 3 partes; 4 partes reprova no `checar_publico.sh` (lida como IP).
- CHANGELOG em ordem crescente: entrada nova no FIM.
- Comandos citam scripts como `<scripts do plugin>/x.sh` (caminho vem do `sessao.sh`); hooks usam `${CLAUDE_PLUGIN_ROOT}`. Não hardcode caminho.
- Restrições de escrita nos comandos são instrução de prompt, não sandbox; nenhum comando declara `allowed-tools`.
- `.raiz/` é estado local de projeto-alvo: gitignored, nunca versionar.

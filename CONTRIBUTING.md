# Contribuindo

Obrigado por querer contribuir. Regras que mantêm o plugin consistente:

## Regras

1. **Todo agente declara `model`**; os que não são Haiku declaram também `effort`. Frontmatter de
   `agents/*.md` e `hipoteses_iniciais` em `modelos/matriz.yaml` precisam bater.
   `bash scripts/lint_modelos.sh` precisa passar.
2. **Gates são fail-closed:** gate bloqueante sem comando é falha, nunca skip. Gate malformado também.
3. **Desempenho só vira regra com medição.** Não afirme que um modelo/effort é melhor sem registrar a
   medição em `modelos/matriz.yaml` (seção `medicoes`). Ao mudar modelo ou parâmetro, confira antes a
   documentação oficial do Claude Code/Anthropic e registre a data de verificação.
4. **Incidente real → regra → gate.** Uma nova cicatriz em `cicatrizes/registro.yaml` traz a regra e a
   verificação mecânica que a cobre. Descreva o incidente de forma genérica, sem nome de cliente ou projeto privado.
5. **Sem dado pessoal ou privado** em exemplos, fixtures e evals: nada de caminhos absolutos da sua máquina,
   chaves, e-mails ou nomes de projetos de terceiros. `bash scripts/checar_publico.sh .` verifica o básico.
6. Mudou um script? Adicione ou ajuste o caso correspondente nas fixtures de `evals/`.

## Rodando as verificações

Na raiz do repositório:

```
bash scripts/lint_modelos.sh          # agentes × matriz de modelos
bash evals/lint_modelos/rodar.sh      # fixtures do lint_modelos
bash evals/gates/rodar.sh             # fixtures do gates.sh (casos malformados e de regressão)
bash scripts/checar_publico.sh .      # higiene da árvore (licença, segredos, caminhos absolutos)
```

Todos devem terminar com exit 0 antes de abrir um pull request. Descreva no PR o que mudou e como
você verificou. Para testar o plugin localmente: `claude --plugin-dir /caminho/para/raiz`.

## Licença

Ao contribuir, você concorda que sua contribuição é licenciada sob a [MIT](LICENSE).

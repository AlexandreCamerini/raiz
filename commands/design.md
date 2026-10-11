---
description: Direção visual — referências reais, 3 direções comparáveis, veredito do juiz e trava (subcomandos travar/rever)
---
Argumentos: `$ARGUMENTS`

## Regras
- Escreva apenas em `.raiz/design/` e `.raiz/vereditos/`. Não altere código do projeto.
- Proibida rede para serviços do próprio projeto. Web pública só para referências.
- Ao delegar, não passe o parâmetro de modelo.

## Sem argumentos — gerar direções
1. Leia os insumos: `CLAUDE.md`, ADRs de UX, `docs/pesquisa-*`, explorações anteriores (ex.: um diretório de exploração de design) e `.raiz/auditoria/scorecard.md` se existir.
2. Delegue ao **explorador**: (a) `.raiz/design/fixture.json` com ~10 registros fictícios cobrindo os tipos reais do modelo do app e ao menos 1 com textos longos; (b) levantamento bruto de referências de apps reais (nome, tela, URL, o que mostra) → `.raiz/design/referencias-brutas.md`.
3. Delegue ao **designer** as saídas do agente (referencias.md, 3 direções .md + .html, comparativo.md).
4. Rode `bash <scripts do plugin>/checar_design.sh .raiz/design`. Se falhar, devolva ao designer uma vez com a saída. Se falhar de novo, registre como defeito no veredito.
5. Delegue ao **juiz** (uma vez): por direção, critérios booleanos com evidência — tarefas críticas atendidas, invariantes de UX respeitados, legibilidade em Dynamic Type grande (pelo desenho), distinção real entre as três; red team da `aposta`. → `.raiz/vereditos/<data>-direcoes.md`.
6. Atualize `.raiz/estado.json` (`etapa: "direcoes"`). Conforme `contratos/bifurcacao.md`: apresente a tese de cada direção em uma linha, o comando `open .raiz/design/direcoes/*.html`, uma tabela prós/contras das três, sua recomendação justificada, grave a pergunta em `decisao_pendente` e pergunte qual travar (★). **Não trave sem resposta.**

## `travar <id> <motivo>`
Crie `.raiz/design/direcao.lock.md` com: direção escolhida, motivo nas palavras do usuário, data, tokens finais (copiados), invariantes respeitados, direções descartadas e por quê, e um texto de ADR sugerido para o projeto (o usuário decide registrar). `estado.json` → `etapa: "direcao-travada"`.

## `rever <motivo>`
Só com motivo explícito. Renomeie o lock atual para `direcao.lock.<data>.md` e volte ao fluxo sem argumentos.

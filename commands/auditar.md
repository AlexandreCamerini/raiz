---
description: App existente — mapa do projeto e scorecard por lente, somente leitura e sempre completa
---
Regra zero: **não altere nenhum arquivo do projeto**. Escreva apenas em `.raiz/`.
Regra um: **toda auditoria é completa e independente.** Não leia auditorias anteriores (`.raiz-*`) nem reduza o escopo com base nelas.

1. Delegue ao **explorador** o mapa completo → `.raiz/auditoria/mapa.md`, com as seções obrigatórias do agente.
2. Rode `bash <scripts do plugin>/checar_mapa.sh .raiz/auditoria/mapa.md` (caminho do início da sessão). Se falhar, devolva ao explorador uma vez com a saída. Se falhar de novo, siga em frente e registre a falha no scorecard.
3. Delegue ao **juiz**, uma única vez e com todas as lentes: arquitetura, código, UX, custo e operação, mais `cicatrizes/registro.yaml` do plugin (só as aplicáveis) → `.raiz/auditoria/scorecard.md`. Abre com "Fora do alcance desta avaliação" e "Invariantes lidos"; invariante violado é achado de severidade alta; projeto sem remote entra no top 5.
4. Atualize `.raiz/estado.json` com `modo: "auditoria"` e `etapa: "scorecard"`.
5. Apresente os 5 achados de maior impacto e, conforme `contratos/bifurcacao.md`, as três saídas:
   - **Só relatório** — a auditoria termina no scorecard.
   - **Plano de melhoria** — correções dentro da arquitetura e da direção de produto atuais, em etapas com critério de aceite.
   - **Redesign** — nova direção de experiência (UX, visual, fluxo) partindo do app atual; segue para o designer. Achado de UX ou direção visual sem decisão registrada é gatilho de redesign.
   Grave a pergunta em `decisao_pendente` até a resposta; ao receber, grave em `historico_decisoes`.

## Fronteiras de execução
- Proibida qualquer requisição de rede a serviços do próprio projeto (produção, staging, workers, APIs publicadas), mesmo GET.
- Permitido rodar a suíte local de testes já existente, sem instalar dependências. Ao final, `git status --short` só pode mostrar `.raiz/`.
- Ao delegar, não passe o parâmetro de modelo: os agentes já declaram o próprio.

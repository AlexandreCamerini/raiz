---
description: Inventor — hipóteses de produto divergentes ancoradas em evidência do radar, criticadas e sintetizadas em apostas com teste de 1 dia e critério de morte
---
Argumentos: `$ARGUMENTS` (tema em texto livre).

## Regras
- Escreva **só** em `~/.raiz/inventor/<slug>/`. Leitura do radar (`~/.raiz/radar/`) e do projeto atual
  permitida; escrita neles, não.
- Proibida rede para serviços do próprio projeto. Web pública só para o prior art do contraditor.
- Ao delegar, não passe o parâmetro de modelo. Passe **caminhos**, nunca conteúdo colado.
- `<scripts do plugin>` = caminho absoluto informado no início desta sessão (echo do `sessao.sh`) + `/scripts`.
- O inventor não depende de projeto: funciona sem `.raiz/estado.json` (o campo de prova típico é uma ideia
  nova, ainda sem projeto).

## 1. Tema
- Tema nos argumentos → use-o.
- Sem tema, com `.raiz/estado.json` ou `CLAUDE.md` no diretório → proponha um tema derivado deles e confirme.
- Sem tema e sem contexto → uma pergunta: "Qual tema ou ideia?".

## 2. Radar do tema
1. `SLUG=$(bash '<scripts do plugin>/radar_slug.sh' "<tema>")`.
2. Se `~/.raiz/radar/$SLUG/sinais.jsonl` existir: use-o direto como evidência.
3. Se não existir: ofereça, conforme `contratos/bifurcacao.md` — **rodar `/raiz:radar` primeiro**
   (recomendado, ancora as hipóteses em evidência real) ou **seguir sem radar** (hipóteses citam
   `CONTEXTO`). Não bloqueia quem quer só o inventor.
4. Teste de escrita em `~/.raiz/inventor/`: `mkdir -p ~/.raiz/inventor/$SLUG/rodadas && touch ~/.raiz/inventor/$SLUG/.gravavel && rm ~/.raiz/inventor/$SLUG/.gravavel`.
   Falhou → **pare** e diga: "`~/.raiz/inventor/` não é gravável nesta sessão (sandbox); libere esse caminho
   em `/sandbox` e rode de novo." Não grave em outro lugar.

## 3. Perguntas guiadas (até 2, AskUserQuestion)
- `n` de hipóteses (default 8).
- `restricoes_de_kill`, só se existir rodada anterior no mesmo tema com apostas descartadas.

## 4. Rodada
1. `RODADA=~/.raiz/inventor/$SLUG/rodadas/$(date +%Y%m%d-%H%M)`; `mkdir -p "$RODADA/apostas"`.
2. Dispare o **inventor**: tema, `n`, caminho de `sinais.jsonl` (se existir), `restricoes_de_kill`,
   saída `$RODADA/hipoteses.md`.
   - Schema incompleto ou distribuição errada (menos de 2 radicais ou 3 adjacentes) → devolva **uma vez**
     citando o defeito.
3. Dispare o **contraditor**: `$RODADA/hipoteses.md`, saída `$RODADA/critica.md`.
   - Alguma hipótese sem veredito, score ou teste ≤1 dia → devolva **uma vez** citando o defeito.
   - `≥80%` das hipóteses `KILL` → rode o **inventor** de novo com `restricoes_de_kill` extraídas da crítica,
     antes de seguir para o sintetizador.
4. Dispare o **sintetizador**: `$RODADA/hipoteses.md`, `$RODADA/critica.md`, saída `$RODADA/`.
   - Confere que ao menos 1 `apostas/APOSTA-*.md` tem `Critério de sucesso` e `Critério de morte`
     preenchidos e não genéricos. Se não, devolva ao sintetizador uma vez.
5. **Gate humano:** mostre o top 5 do ranking no chat (≤25 linhas) e pergunte, via `AskUserQuestion`
   multi-select: "quais apostas seguem?". Não decide sozinho, não executa nenhuma aposta.
6. Registre em `status.json` da rodada: modelo de cada agente, chamadas, início e fim. Peça `/usage`
   antes/depois se o usuário quiser o delta — registrar em `modelos/matriz.yaml` é feito no repositório do
   Raiz, não por este comando.

## 5. Resumo no chat (até 15 linhas)
Quantas hipóteses por tipo; veredito do contraditor (KEEP/REFRAME/KILL); as apostas escolhidas no gate
humano, cada uma com o critério de morte em 1 linha; caminho de `INOVACAO.md`.

## Degradação
| Situação | Comportamento |
|---|---|
| Sem `sinais.jsonl` do tema | Segue com evidência `CONTEXTO`, avisa no resumo |
| Inventor ou contraditor falha 2x no mesmo defeito | Pare e reporte o defeito ao usuário — não force um resultado ruim adiante |
| `~/.raiz/inventor/` não gravável (sandbox) | Para e diz qual caminho liberar; não grava em outro lugar |
| Nenhuma hipótese sobra após o contraditor (100% KILL) | Reporta o motivo do conjunto morrer; não sintetiza aposta fictícia |

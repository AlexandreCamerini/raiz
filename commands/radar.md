---
description: Radar — sinais de mercado e de fronteira sobre um tema, acumulados em ~/.raiz/radar/ entre projetos, com diff a cada rodada (flags --rapida, --foco=<x>)
---
Argumentos: `$ARGUMENTS` (tema em texto livre; flags `--rapida`, `--foco=<x>`).

## Regras
- Escreva **só** em `~/.raiz/radar/<slug>/`. Leitura do projeto atual permitida; escrita nele, não (nem `.raiz/`).
- Proibida rede para serviços do próprio projeto. Web pública só para as buscas das lentes e do auditor.
- Ao delegar, não passe o parâmetro de modelo. Passe **caminhos**, nunca conteúdo colado.
- `<scripts do plugin>` = caminho absoluto informado no início desta sessão (echo do `sessao.sh`) + `/scripts`.
- O radar não depende de projeto: funciona sem `.raiz/estado.json`.

## 1. Tema
- Tema nos argumentos → use-o.
- Sem tema, com `.raiz/estado.json` ou `CLAUDE.md` no diretório → proponha um tema derivado deles e confirme.
- Sem tema e sem contexto → uma pergunta: "Qual tema?".

## 2. Slug e pasta
1. `SLUG=$(bash '<scripts do plugin>/radar_slug.sh' "<tema>")`.
2. `ls ~/.raiz/radar/ 2>/dev/null`. Se existir slug diferente mas parecido (mesmas palavras-chave, plural/singular,
   ordem trocada), pergunte se é o mesmo tema antes de criar outro. Sendo o mesmo, use o slug existente.
3. Teste de escrita: `mkdir -p ~/.raiz/radar/$SLUG/rodadas && touch ~/.raiz/radar/$SLUG/.gravavel && rm ~/.raiz/radar/$SLUG/.gravavel`.
   Falhou → **pare** e diga: "`~/.raiz/radar/` não é gravável nesta sessão (sandbox); libere esse caminho em
   `/sandbox` e rode de novo." Não grave em outro lugar.

## 3. Perguntas guiadas (até 2, AskUserQuestion; pule as que as flags já responderam)
- Profundidade: `completa` = 4 lentes (`consolidado`, `fronteira`, `adjacente`, `ui-ux`) + `radar-auditor` (recomendada);
  `rapida` = `fronteira` + `consolidado`, sem auditor. `--rapida` responde esta.
- Foco opcional (recorte do tema). `--foco=<x>` responde esta.

## 4. Rodada
1. `RODADA=~/.raiz/radar/$SLUG/rodadas/$(date +%Y%m%d-%H%M)`; `mkdir -p "$RODADA"`.
2. Grave `$RODADA/status.json`:
   `{"tema","slug","profundidade":"completa|rapida","foco","iniciada_em","estado":"em_andamento","lentes":{},"lacunas":[],"medicao":{}}`.
3. Dispare o agente **radar**, uma instância por lente, **todas numa mesma mensagem** (paralelo). Cada uma recebe:
   tema, lente, foco, data da rodada, caminho de `~/.raiz/radar/$SLUG/sinais.jsonl` e `$RODADA/<lente>.json` como saída.
4. Lente que não gravou arquivo ou devolveu erro → `status.json`: `lentes.<lente> = "falhou"` e item em `lacunas`
   com o motivo. Nas demais, `lentes.<lente> = "ok"`.
5. **Todas as lentes falharam** (ex.: sem web) → `estado: "falhou"` e pare aqui: **não** rode auditor, checar nem diff;
   `sinais.jsonl` fica intacto. Diga o motivo em uma linha.
6. Profundidade `completa`: dispare o **radar-auditor** com `$RODADA/` e saída `$RODADA/auditoria.json`.
   Não gravou `auditoria.json` ou devolveu erro → dispare-o de novo **uma vez**. Falhou de novo → `estado: "falhou"`,
   item em `lacunas` ("auditoria") e pare: sem auditoria a rodada completa não passa no checar e não é incorporada.
   Diga que `--rapida` roda sem auditor.
7. `bash '<scripts do plugin>/checar_radar.sh' "$RODADA"`.
   - Falhou por uma lente → devolva ao **radar** daquela lente **uma vez**, com a saída do checar. Refaça o auditor
     só se a lente corrigida tiver ids novos sem auditoria.
   - Falhou de novo → `mv "$RODADA/<lente>.json" "$RODADA/<lente>.json.descartado"`, `lentes.<lente> = "descartada"`,
     item em `lacunas`, e rode o checar outra vez.
   - Falha sem lente válida restante → `estado: "falhou"` e pare (como no passo 5).
8. `bash '<scripts do plugin>/radar_diff.sh' ~/.raiz/radar/$SLUG`. Ele grava `diff.md`, `diff.json`, atualiza
   `sinais.jsonl` e marca `estado: "incorporada"`. Falhou → mostre a saída e pare; não edite o acumulado à mão.
9. Grave em `status.json` → `medicao`: modelo de cada agente, chamadas por lente, início e fim (tempo de parede).
   Peça ao usuário o `/usage` antes/depois se ele quiser registrar o delta — o registro em `modelos/matriz.yaml`
   é feito no repositório do Raiz, não por este comando.

## 5. Resumo no chat (até 10 linhas)
Contagem por lente; **novos no mundo** com título, URL e data (UNVERIFIED marcado); quantos novos no radar,
recorrentes e sumidos; lacunas; caminho do `diff.md`. Na primeira rodada do tema: "linha de base — N sinais".

## Degradação
| Situação | Comportamento |
|---|---|
| Sem web ou todas as lentes falham | `status.json` → `estado: "falhou"`; acumulado e diff **não** são atualizados |
| 1–2 lentes falham | Segue com as restantes; lacuna registrada no `status.json` e no diff |
| `radar-auditor` falha duas vezes (completa) | `estado: "falhou"`; acumulado e diff **não** são atualizados; sugere `--rapida` |
| `checar_radar.sh` falha | Devolve a lente ao radar uma vez com a saída; falhou de novo → lente descartada e registrada |
| `~/.raiz/` não gravável (sandbox) | Para e diz qual caminho liberar; não grava em outro lugar |

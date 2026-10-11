---
description: Porta única do Raiz — mostra onde o projeto está, reapresenta decisão em aberto, ou propõe o próximo passo
---
0. Se o pedido falar em mercado, concorrência, concorrentes, tendência, inovação ou "o que existe por aí", ofereça
   `/raiz:radar [tema]` (sinais de fora, acumulados em `~/.raiz/radar/`) — não o explorador, que olha código e projeto.
   Se falar em ideia de produto nova, aposta, hipótese, "o que o app poderia ser", ofereça `/raiz:inventar [tema]`
   (hipóteses ancoradas no radar, criticadas e sintetizadas em apostas com teste de 1 dia). Se falar em prototipar,
   protótipo clicável, testar uma aposta, ofereça `/raiz:prototipar <aposta-id>`. Se falar em custo de modelo,
   qual modelo usar, otimizar gasto de agente, ofereça `/raiz:pulso` (introspecção do próprio Raiz, não do
   projeto atual). Nenhum dos quatro depende de projeto. Sem `.raiz/estado.json`, não faça a pergunta do
   passo 2 nesses casos.
1. Leia `.raiz/estado.json` no diretório atual.
2. Se não existir: pergunte se é projeto **novo** (sugira `/raiz:novo`) ou **existente** (sugira `/raiz:auditar`). Uma pergunta só.
3. Se `decisao_pendente` não for nulo: **reapresente o menu completo**, conforme `contratos/bifurcacao.md`
   (caminho do plugin do início da sessão) — mesmo que o usuário não tenha perguntado sobre isso. Não prossiga sem resposta.
4. Caso contrário: informe modo, etapa e status dos gates em até 5 linhas.
   - Só um caminho sensato daqui → diga-o direto.
   - Dois ou mais caminhos válidos → apresente como bifurcação, mesmo contrato.
5. Lembre, em uma linha, que `/raiz:consultor "<pergunta>"` está disponível a qualquer momento, sem alterar nada.
6. Se a etapa pedida ainda não existe nesta versão do Raiz, diga isso claramente em vez de improvisar.

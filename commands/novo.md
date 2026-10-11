---
description: Projeto novo — descoberta adaptativa até um briefing completo em .raiz/briefing.json
---
Objetivo: produzir `.raiz/briefing.json` válido contra `schemas/briefing.schema.json` do plugin.

1. Crie `.raiz/` se não existir e inicialize `.raiz/estado.json` com `modo: "novo"`, `etapa: "descobrir"`.
2. Entrevista adaptativa: pergunte apenas o que falta para completar problema, usuário, tarefas críticas, restrições e critérios de sucesso. No máximo 3 perguntas por rodada; aceite respostas curtas.
3. Aplique as restrições do `ecossistema/manifesto.yaml` do plugin sem perguntar o que ele já responde (hospedagem, plataforma-alvo, etc.). Campo com o valor `"<definir>"` (ou ausente) não está respondido: pergunte ao usuário e confirme a resposta antes de aplicá-la; nunca assuma um padrão.
4. Calcule `completude` (0–1) = campos obrigatórios preenchidos com conteúdo verificável ÷ total.
5. Rode `bash '<scripts do plugin>/checar_briefing.sh' .raiz/briefing.json`. Falhou → corrija o campo
   apontado antes de seguir; não peça aprovação com o gate reprovado.
6. Com completude ≥ 0.8 (e `checar_briefing.sh` ok), mostre o briefing resumido e peça aprovação (★). Só
   então marque a etapa como concluída.
7. Nesta versão a próxima etapa (explorar/decidir) ainda não está implementada — diga isso ao final.

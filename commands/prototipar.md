---
description: Protótipo — transforma uma aposta do inventor num HTML navegável + roteiro de teste, apoio ao experimento de 1 dia, não substituto
---
Argumentos: `$ARGUMENTS` (id da aposta, ex. `H-01`, ou caminho completo de `APOSTA-<id>.md`).

## Regras
- Escreva **só** em `<diretório da rodada do inventor>/prototipos/<id>/` — ao lado da aposta, não em
  `~/.raiz/` separado.
- Protótipo é descartável por definição: sem gate, sem schema formal.

## 1. Localizar a aposta
- Argumento é um id (`H-0n`) → procure `APOSTA-<id>.md` nas rodadas de `~/.raiz/inventor/*/rodadas/*/apostas/`.
  Mais de um resultado → pergunte qual rodada.
- Argumento é caminho completo → use direto.
- Sem argumento → se houver exatamente uma rodada recente do inventor com apostas, proponha a de maior score
  e confirme. Mais de uma, ou nenhuma → pergunte qual aposta.

## 2. Rodada
1. `RODADA=<diretório da rodada que contém a aposta>`; `mkdir -p "$RODADA/prototipos/<id>"`.
2. Dispare o **prototipador**: caminho da aposta, saída `$RODADA/prototipos/<id>/`.
3. Confira que `index.html` existe e não referencia rede/CDN (`grep -E "https?://" ` no arquivo deve achar,
   no máximo, texto descritivo, não `<script src=` nem `<link href=` externos). Achar → devolva ao
   prototipador uma vez.

## 3. Resumo no chat (até 10 linhas)
Qual pergunta o protótipo torna navegável; quantos cenários no passeio guiado; caminho de `index.html` e de
`roteiro-de-teste.md`; lembrete de que o protótipo apoia o experimento real, não o substitui.

---
description: Conselheiro sob demanda — a qualquer momento, dado um briefing seu, recomenda estratégias com prós e contras, sem alterar o projeto
---
Argumento: `$ARGUMENTS` (o briefing ou pergunta; se vazio, pergunte).

## Regras
- Não altera `.raiz/estado.json`, gates, design ou qualquer arquivo do projeto. Escreve só em `.raiz/consultas/<data>-<slug>.md`.
- Proibida rede para serviços do próprio projeto.
- Chamável a qualquer momento, independente da etapa atual — não exige `.raiz/` nem projeto em andamento.

1. Leia o contexto disponível: `.raiz/estado.json` e `.raiz/briefing.json` (se existirem), ADRs do projeto,
   `ecossistema/manifesto.yaml` e `cicatrizes/registro.yaml` do plugin (caminhos do início da sessão), e `$ARGUMENTS`.
2. Delegue ao **arquiteto**, em modo consulta: 2 a 4 estratégias reais (nunca uma única "certa"), cada uma com
   prós, contras e quando faz sentido, no formato de `contratos/bifurcacao.md`.
3. Recomende uma, com o motivo.
4. Grave em `.raiz/consultas/` e apresente. Não é uma etapa da jornada — se o usuário responder escolhendo,
   registre em `historico_decisoes` como o contrato descreve; senão, a consulta fica só como registro.

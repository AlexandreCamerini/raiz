# Contrato de bifurcação — como apresentar uma decisão (★)

Use sempre que a jornada chegar a um ponto em que mais de um caminho é válido:
fim de etapa, escolha de direção, decisão de arquitetura, ir ou não adiante.
Não decida por conta própria quando houver mais de um caminho válido.

## Formato obrigatório
1. Resuma em até 3 linhas o que foi concluído e onde estamos.
2. Apresente as opções como tabela: `Opção | O que significa | Prós | Contras | Quando escolher`.
3. Recomende uma opção, com o motivo em uma frase — a decisão continua sendo do usuário.
4. Termine com "Qual você escolhe? (★)", de preferência como pergunta interativa quando a ferramenta existir.
5. **Não execute nenhuma opção antes da resposta.**
6. Grave em `.raiz/estado.json`: enquanto espera, `decisao_pendente: {pergunta, opcoes:[{id,resumo}, ...]}`;
   ao receber a resposta, `decisao_pendente: null` e um item novo em `historico_decisoes`
   (`data`, `pergunta`, `escolha`, `motivo` nas palavras do usuário quando ele der um).

## Quando NÃO usar
- Só existe um caminho sensato daqui (ex.: gate falhou, a única ação é corrigir): diga o próximo passo direto.
- Dúvida sobre o próprio pedido: isso é esclarecimento, não bifurcação.

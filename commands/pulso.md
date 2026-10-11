---
description: Pulso — analisa as medições acumuladas em modelos/matriz.yaml e recomenda troca de modelo/effort por nó quando o dado sustenta
---
Sem argumentos. Roda sobre `modelos/matriz.yaml` do repositório do Raiz — não é por tema nem por projeto,
é introspecção do próprio plugin.

## Regras
- Escreva **só** em `modelos/pulso/`. Não altere `hipoteses_iniciais` sem aprovação explícita (passo 3).
- Ao delegar, não passe o parâmetro de modelo.

## 1. Rodada
1. `DATA=$(date +%Y-%m-%d)`; `mkdir -p modelos/pulso`.
2. Dispare o **pulso**: caminho de `modelos/matriz.yaml`, saída `modelos/pulso/$DATA.md`.

## 2. Resumo no chat (até 15 linhas)
Quantos agentes analisados; achados de arquitetura (I/O serial) separados de trocas recomendadas; cada
troca com a medição exata que a sustenta.

## 3. Aplicar (conforme `contratos/bifurcacao.md`)
Se houver ≥1 troca recomendada: apresente como bifurcação (opção por troca: aplicar agora, ou manter e só
registrar como candidato) e pergunte. **Não aplique sozinho.**
- Aceita → atualize `hipoteses_iniciais` em `modelos/matriz.yaml` pro(s) agente(s) aprovado(s).
- Nenhuma troca recomendada, ou recusada → relatório fica registrado, `hipoteses_iniciais` inalterado.

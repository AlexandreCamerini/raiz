# Protocolo de medição ponta a ponta

Responde três perguntas que `modelos/matriz.yaml` ainda não responde: **quanto custa, quanto atrito dá e se o resultado é aceito**, comparado a usar o Claude Code puro.

## Por que existe
- As medições atuais registram tokens de subagentes e tempo de parede, mas **não** o orquestrador (thread principal), o aceite do resultado, o retrabalho nem os pedidos de permissão.
- A `metrica_principal` da matriz é "custo relativo por tarefa aceita", e nenhuma medição registra aceite.
- Duas rodadas idênticas do radar variaram ~30% em tokens sem mudar nada: uma amostra única não sustenta decisão.

## Desenho
1. **Uma tarefa real por fluxo** que você quer avaliar (`auditar`, `novo` → `design`, `radar`, `inventar`; `construir` só se o projeto for SwiftUI/iOS).
2. **Dois braços por tarefa**, em sessões novas e mesmo modelo de sessão:
   - **A (Raiz):** o comando do Raiz.
   - **B (controle):** Claude Code puro, com o mesmo objetivo escrito em um parágrafo, sem o plugin.
3. **Critérios de aceite escritos antes de rodar**: 3 a 6, booleanos (passa/não passa), por tarefa. Avalie o resultado sem olhar de qual braço veio, se possível.
4. **Limiar de decisão escrito antes de rodar** (campo `limiar` do registro). Sem limiar prévio, qualquer resultado vira justificativa.
5. **Repetir 3 vezes** cada braço quando o custo permitir; registrar a variação, não só a média.

## O que registrar por rodada
| Campo | Como obter |
|---|---|
| `orquestrador.modelo`, `orquestrador.effort` | `/model` e `/effort` da sessão |
| `tokens.orquestrador`, `tokens.subagentes` | `claude -p --output-format json` (`modelUsage`) ou `/usage` antes e depois |
| `parede_min` | início e fim da rodada |
| `prompts_de_permissao` | contagem manual de quantas vezes o Claude Code pediu aprovação |
| `aceite` | quantos critérios passaram do total |
| `retrabalho` | número de correções humanas até aceitar (mensagem de ajuste conta 1) |
| `custo_estimado_usd` | estimativa local; use só como comparação relativa entre braços |

## Como decidir
- Compare por **custo por tarefa aceita**, não por custo bruto.
- Fluxo em que A não bate B em aceite **ou** gasta mais que o `limiar` por aceite é candidato a ser cortado, colapsado em uma passada ou separado do plugin.
- Só depois da decisão mexa em model/effort, e registre a medição em `modelos/matriz.yaml` (`medicoes`) conforme o CONTRIBUTING.

## Onde registrar
Copie `modelo-registro.yaml`, preencha uma entrada por rodada e, quando a decisão for tomada, leve o resumo para `medicoes` da matriz. Não coloque caminhos da sua máquina, nomes de clientes nem trechos privados do projeto avaliado.

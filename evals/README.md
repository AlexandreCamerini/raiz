# Evals

Cada eval fica em `evals/<nome>/`, com tarefas ou fixtures representativas e critérios de aceite booleanos.
Hoje há dois, ambos executáveis com `bash evals/<nome>/rodar.sh`:

- `evals/gates/` — casos de `scripts/gates.sh` (malformados e de regressão); gate malformado nunca pode virar SKIP.
- `evals/lint_modelos/` — fixtures de `scripts/lint_modelos.sh` (agentes × `modelos/matriz.yaml`).

Execução comparável de evals com agentes: `claude -p --output-format json` sobre as mesmas tarefas; registrar aceite, tentativas, correções humanas e `modelUsage`.
O valor em dólar é estimativa local — use só como comparação relativa entre variantes. Na assinatura, o impacto real é o % do limite em `/usage`.

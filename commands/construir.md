---
description: Constrói a fatia da direção travada — tokens gerados, kit sem literal solto, gates do projeto
---
Pré-requisito: `.raiz/design/direcao.lock.md` precisa existir (rode e trave `/raiz:design` antes). Sem lock, pare e diga isso.

## Regras
- Escreve só em `App/Shared/`, `project.yml`, `Makefile`, `.raiz/`. **Nunca** em `.raiz/design/direcao.lock.md` — contrato já travado, só leitura.
- Proibida rede para serviços do próprio projeto.
- Ao delegar, não passe o parâmetro de modelo: os agentes já declaram o próprio.
- **Nenhum nome de projeto, bundle id, scheme ou nome de view é fixo aqui.** Derive de `.raiz/estado.json` (campo do projeto, ou nome do diretório do repo) e do que o `direcao.lock.md`/`briefing.json` realmente pedem. Se não der pra derivar com segurança, pare e pergunte — não adivinhe um nome de app.

## Passos

### 0. Descobrir o projeto (sempre primeiro)
- `NOME_PROJETO` = nome do diretório do repo (`basename "$(git rev-parse --show-toplevel)"`), a menos que `.raiz/estado.json` ou `.raiz/briefing.json` declarem um nome de produto explícito — nesse caso, use o nome declarado.
- `NOME_APP_IOS` = `NOME_PROJETO` em PascalCase, sem espaço/acento (ex.: `meuapp` → `Meuapp`).
- `BUNDLE_ID` = `com.<owner>.<nome_projeto_lowercase>` — `<owner>` vem do `git config user.email`/remote, ou pergunte se não der pra inferir. Nunca use um bundle id de outro projeto.
- Telas a construir: leia `.raiz/design/direcao.lock.md` (tokens + invariantes) e os `.md`/`.html` de `.raiz/design/direcoes/<travada>.*` (nomes de tela na seção `## Telas`) — são os nomes reais de `View`/`ViewModel` a criar, não os de nenhum outro projeto.

### 1. Bootstrap do projeto Xcode — idempotente, roda uma vez
Pule qualquer item que já exista.

**a. Projeto Xcode via `xcodegen`, se `project.yml` não existir.** Gere um `project.yml` mínimo:
```yaml
name: ${NOME_APP_IOS}
options:
  bundleIdPrefix: ${BUNDLE_ID%.*}
targets:
  ${NOME_APP_IOS}-iOS:
    type: application
    platform: iOS
    deploymentTarget: "18.0"
    sources:
      - path: App/Shared
      - path: App/iOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ${BUNDLE_ID}
        CODE_SIGN_STYLE: Automatic
        SWIFT_VERSION: "6"
```
Rode `xcodegen generate` (ou `make gerar` se o `Makefile` já tiver o alvo) e confirme que
`xcodebuild -list` mostra o alvo antes de seguir. Erro de xcodegen aqui é bloqueante.

**b. `.raiz/gates.json`** (se não existir). Kit é bloqueante desde o início — é mecânico e barato.
Build é bloqueante assim que houver um alvo Xcode. a11y/UI Test só entram como gate quando a fatia
desta rodada realmente tiver uma `View` interativa pra testar (nem toda construção precisa; decida
por rodada, não copie de outro projeto):
```json
{
  "gates": [
    { "id": "kit", "bloqueante": true,
      "comando": "bash '<scripts do plugin>/checar_kit.sh' App/Shared",
      "dica": "cor/fonte solta fora de Tokens.swift/TokensGerados.swift — mova para o kit" },
    { "id": "build", "bloqueante": true,
      "comando": "xcodebuild -project ${NOME_APP_IOS}.xcodeproj -scheme ${NOME_APP_IOS}-iOS -destination 'generic/platform=iOS Simulator' build",
      "dica": "corrija o erro de build antes de qualquer outro gate" }
  ]
}
```
Substitua `<scripts do plugin>` pelo caminho absoluto informado no início desta sessão (echo do `sessao.sh`).

**c. `Makefile`** (se não existir ou não tiver alvo `provar`) — pelo menos:
```makefile
gerar:
	xcodegen generate

provar:
	bash '<scripts do plugin>/gates.sh' .raiz/gates.json
```

### 2. Tokens
`bash '<scripts do plugin>/tokens.sh' .raiz/design/direcao.lock.md App/Shared/Kit/TokensGerados.swift`,
depois `bash '<scripts do plugin>/checar_tokens.sh' App/Shared/Kit/TokensGerados.swift`. Falhou → pare
aqui — não delega ao construtor com tokens inválidos, não edite `TokensGerados.swift` à mão.

### 3. Construção
Delegue ao **construtor** a fatia: implementar as telas nomeadas em `## Telas` da direção travada,
usando **só** o kit (`TokensGerados.swift` + qualquer `Kit/Componentes.swift` já existente), com dado
do `.raiz/design/fixture.json` desta rodada. Nomeie `View`/`ViewModel` a partir do domínio real do
projeto (ex.: para "resumo do pedido", algo como `ResumoView`/`ResumoViewModel` — nunca
copie um nome de tela de outro projeto Raiz).

- **Escopo desta rodada**: registre explicitamente, na entrega, quais telas da direção travada
  entraram na fatia e quais ficaram de fora — não assuma que "tudo" é o padrão; combine com quem
  pediu se não estiver óbvio pelo `briefing.json`.
- **Componentes do kit**: qualquer componente reaproveitável vai em `Kit/Componentes.swift`, sem
  literal solto — `checar_kit.sh` só isenta `Tokens.swift`/`TokensGerados.swift`.
- **Contratos que não podem regredir**: os do veredito do juiz **deste projeto**
  (`.raiz/vereditos/*-direcoes.md`) — não herde contratos de outro projeto Raiz.

### 4. Gate de kit e build
`bash '<scripts do plugin>/gates.sh' .raiz/gates.json`. Kit ou build falhou → devolve ao construtor
uma vez com a saída. Gate **bloqueante** (kit e build são) falhou de novo → **pare**: registre o defeito e a
saída do gate no veredito, reporte ao usuário e não avance para o passo 5 nem declare a fatia construída. Gate
não bloqueante que falha de novo → registra defeito no veredito e segue (a política de `checar_design.sh` em
`commands/design.md:4` continua sendo "registra e segue", porque aquele script não é gate bloqueante).

### 5. a11y e UI Test (opcional por rodada)
Só bootstrap isso se a fatia desta rodada tiver uma `View` interativa que valha testar via
`XCUITest`/`performAccessibilityAudit()`. Quando fizer sentido: alvo de UI Test em `project.yml`
seguindo o mesmo padrão do passo 1a (`dependencies: - target: ${NOME_APP_IOS}-iOS`), Dynamic Type em
`accessibilityExtraExtraExtraLarge`, teste negativo (`.lineLimit(1)` numa label longa de propósito,
que precisa reprovar o audit — senão o teste não testa nada). Registre a decisão de incluir ou não no
veredito desta rodada, com o motivo.

### 6. Juiz visual (se houver UI Test rodando)
Delegue ao **juiz** (uma vez), só se o passo 5 tiver rodado: `xcrun simctl io booted screenshot` por
estado relevante do fixture, comparado ao `.html` da direção travada. Critérios booleanos com
evidência = caminho do PNG + citação do HTML comparado. Registre modelo, chamadas e tempo de parede
(medição pra `modelos/matriz.yaml` do Raiz, se quem estiver rodando quiser levar pra lá depois).
→ `.raiz/vereditos/<data>-construcao.md`.

### 7. Fechamento
Atualize `.raiz/estado.json`. Conforme `contratos/bifurcacao.md`: resuma o veredito em até 3 linhas,
apresente os achados de maior impacto, e pergunte (★) se aprova ou volta ao construtor com o ajuste
nomeado. **Não conclui sozinho.**

## Fronteiras de execução
- `git status --short` ao final só pode mostrar `App/Shared/`, `App/iOS/` (se criado), `project.yml`,
  `Makefile`, `.raiz/`.
- Telas fora do escopo desta rodada ficam registradas como pendência, não implementadas por
  suposição.

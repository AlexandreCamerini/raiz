# Raiz

Plugin do Claude Code que leva um projeto do briefing à fundação provada (contratos, arquitetura,
kit de design, gates). Também audita apps existentes: não altera o código do projeto, mas grava em `.raiz/`
e roda a suíte de testes local do projeto, o que pode gerar artefatos (veja
[Onde o Raiz grava, o que lê e o que executa](#onde-o-raiz-grava-o-que-lê-e-o-que-executa)).

O Raiz é um conjunto de comandos (`/raiz:*`), agentes especializados e scripts de verificação.

**Maturidade:** o fluxo vai do briefing à fundação provada e para aí; não publica nem entrega o app. A construção
(`/raiz:construir`) cobre só SwiftUI/iOS. Modelo e effort dos agentes são hipóteses ainda não medidas, e a
documentação está só em português (PT-BR).
Nada nele roda sozinho fora de uma sessão do Claude Code, com uma exceção: o hook `SessionStart`
executa `scripts/sessao.sh` (só imprime versão e estado do projeto).

## Requisitos

- Claude Code (CLI).
- `bash`, `git`, `jq` e `python3`. O `python3` é obrigatório para `scripts/checar_publico.sh` e para 5 scripts
  (`checar_briefing`, `checar_design`, `checar_tokens`, `tokens` e `radar_slug`); os gates usam `jq`.
- Vários agentes usam busca na web (`WebSearch`/`WebFetch` do Claude Code); veja
  [Onde o Raiz grava, o que lê e o que executa](#onde-o-raiz-grava-o-que-lê-e-o-que-executa).
- `/raiz:construir` gera hoje apenas projetos SwiftUI/iOS e exige macOS com Xcode e `xcodegen`.
  Os demais comandos não dependem disso.

## Instalação

```
git clone https://github.com/AlexandreCamerini/raiz raiz
claude --plugin-dir /caminho/para/raiz
```

`--plugin-dir <path>` está documentada em `claude --help` (testado com Claude Code 2.1.x; confirme a flag na
sua versão): carrega o plugin de um diretório só para aquela sessão. Para checar o manifesto antes: `claude plugin validate /caminho/para/raiz`.

Dentro da sessão, os comandos aparecem com o prefixo do plugin: `/raiz:raiz`, `/raiz:novo`, etc.

## Comandos

| Comando | O que faz |
|---|---|
| `/raiz:raiz` | Porta única — diz onde o projeto está, reapresenta decisão em aberto ou propõe o próximo passo |
| `/raiz:novo` | Projeto novo: descoberta → `.raiz/briefing.json` |
| `/raiz:auditar` | App existente: mapa + scorecard, sempre completa e independente. Não altera o código do projeto; grava em `.raiz/` e roda a suíte local de testes do projeto |
| `/raiz:design` | Referências reais, 3 direções distintas, trava (`/raiz:design travar <id> <motivo>`) |
| `/raiz:radar [tema]` | Sinais de mercado e fronteira por tema, acumulados em `~/.raiz/radar/` com diff a cada rodada (`--rapida`, `--foco=<x>`) |
| `/raiz:inventar [tema]` | Hipóteses de produto ancoradas no radar, criticadas (prior art, modos de falha) e sintetizadas em apostas com teste de 1 dia e critério de morte |
| `/raiz:prototipar <aposta-id>` | Protótipo HTML navegável + roteiro de teste a partir de uma aposta do inventor — apoia o experimento de 1 dia, não substitui |
| `/raiz:construir` | Constrói a fatia da direção travada — tokens gerados, kit sem literal solto, gates do projeto |
| `/raiz:pulso` | Analisa as medições acumuladas em `modelos/matriz.yaml` e recomenda troca de modelo/effort por nó só quando o dado sustenta |
| `/raiz:consultor "<pergunta>"` | Conselheiro sob demanda, a qualquer momento; não altera o código do projeto (grava a consulta e, se você escolher uma opção, a decisão em `.raiz/estado.json`) |
| `/raiz:provar` | Roda os gates do projeto (fail-closed) |

Toda decisão com mais de um caminho válido segue `contratos/bifurcacao.md`: resumo, opções com
prós/contras, recomendação, e espera a resposta antes de agir.

## Agentes

| Agente | Modelo / effort | Papel |
|---|---|---|
| explorador | haiku | Coleta evidência delimitada (mapa de codebase, histórico git, referências) |
| arquiteto | opus / high | Decide arquitetura, escopo e contratos técnicos |
| designer | opus / high | Direção de arte e padrões de interface a partir de referências reais |
| juiz | sonnet / high | Verifica de forma independente: gates, critérios booleanos, red team |
| construtor | sonnet / high | Implementa fatias dentro dos contratos aprovados |
| radar | sonnet / medium | Levanta sinais de mercado e fronteira sob uma lente |
| radar-auditor | haiku | Audita as fontes de uma rodada do radar |
| inventor | opus / high | Gera hipóteses de produto divergentes ancoradas em evidência |
| contraditor | opus / high | Ataca premissas das hipóteses e define o teste de falsificação |
| sintetizador | sonnet / medium | Consolida hipóteses e crítica em relatório e apostas |
| prototipador | sonnet / high | Protótipo HTML descartável + roteiro de teste |
| pulso | sonnet / high | Analisa medições e recomenda trocas de modelo/effort |

**O modelo e o effort de cada agente são hipóteses iniciais**, não resultado de benchmark. Só viram regra
com medição registrada em `modelos/matriz.yaml` (seção `medicoes`); hoje essa amostra é pequena. Não tome a
tabela acima como recomendação de custo-benefício comprovada.

## Onde o Raiz grava, o que lê e o que executa

Levantado do código do plugin (comandos, agentes e scripts). Atenção: as regras de escrita dos comandos
("escreva só em ...") são **instruções de prompt para o modelo, não um sandbox**. Quem impõe limites de verdade
é o sistema de permissões do Claude Code (e o `/sandbox`, se você o ativar). Em ambiente com sandbox, os
caminhos fora do projeto listados abaixo precisam ser liberados para escrita.

### Grava no projeto em que você roda

| Quem | O que grava |
|---|---|
| `/raiz:novo` | `.raiz/estado.json`, `.raiz/briefing.json` |
| `/raiz:auditar` | `.raiz/auditoria/mapa.md`, `.raiz/auditoria/scorecard.md`, `.raiz/estado.json`; o comando não escreve no resto do projeto, mas a suíte local de testes que ele roda pode (caches, relatórios de cobertura, artefatos de build — o comando manda conferir `git status --short` ao final) |
| `/raiz:design` | `.raiz/design/` (dados fictícios, referências, direções em `.md` e `.html`, comparativo, `direcao.lock.md`), `.raiz/vereditos/`, `.raiz/estado.json` |
| `/raiz:construir` | `.raiz/gates.json`, `.raiz/vereditos/`, `.raiz/estado.json` e, fora de `.raiz/`: `App/Shared/` (inclui `Kit/TokensGerados.swift`, `Kit/Componentes.swift` e as telas), `App/iOS/` (se criado), `project.yml` e `Makefile` |
| `/raiz:consultor` | `.raiz/consultas/<data>-<slug>.md` e, quando você responde escolhendo uma das opções, uma entrada em `historico_decisoes` de `.raiz/estado.json` (o texto do comando declara que não altera o estado e, no último passo, manda registrar a escolha: vale o registro) |
| `/raiz:provar` | nada; se `.raiz/gates.json` não existir, propõe os gates e só grava com a sua aprovação |
| agente `arquiteto` | `.raiz/decisoes/ADR-NNN-<slug>.md` |

`/raiz:construir` gera hoje só SwiftUI/iOS. As ferramentas que ele dispara (`xcodegen generate`,
`xcodebuild`) criam o projeto Xcode e artefatos de build e podem resolver pacotes pela rede (por exemplo
dependências do Swift Package Manager): isso é comportamento delas, não do texto do plugin. No passo
opcional do juiz visual, `xcrun simctl io booted screenshot` grava capturas de tela (PNG) do simulador.

### Grava em `~/.raiz/` (acumulado entre projetos)

| Quem | O que grava |
|---|---|
| `/raiz:radar` | `~/.raiz/radar/<tema>/`: `sinais.jsonl` e `rodadas/<data>/` (`status.json`, um JSON por lente, `auditoria.json`, `diff.md`, `diff.json`) |
| `/raiz:inventar` | `~/.raiz/inventor/<tema>/rodadas/<data>/`: `hipoteses.md`, `critica.md`, `INOVACAO.md`, `apostas/`, `status.json` |
| `/raiz:prototipar` | `prototipos/<id>/` (`index.html` e o roteiro de teste) dentro da rodada do inventor |

Também cria e apaga arquivos temporários nesses diretórios: `.gravavel` (teste de escrita) e `.tmp.*` (usado
por `scripts/radar_diff.sh`).

### Grava fora do projeto e de `~/.raiz/`

- `/raiz:pulso`: `modelos/pulso/<data>.md` e, só com a sua aprovação, edita `modelos/matriz.yaml`. Os dois
  caminhos são relativos ao diretório onde o comando roda; ele foi pensado para rodar dentro de um clone do
  próprio Raiz, não de um projeto seu.
- `scripts/gates.sh`: o log de cada gate em `${TMPDIR:-/tmp}/raiz-gates/<id>.log`.

### O que lê

- No projeto: `.raiz/`, o código, `CLAUDE.md`, ADRs, o histórico e a configuração do git (`/raiz:auditar` e o
  explorador). `/raiz:construir` também lê o seu e-mail (`git config user.email`) e o remote: veja
  [Dado pessoal](#dado-pessoal-o-e-mail-do-git-e-o-bundle-id).
- No plugin: `schemas/`, `cicatrizes/`, `ecossistema/manifesto.yaml`, `contratos/` e `modelos/matriz.yaml`.
- `~/.raiz/radar/`, lido por `/raiz:inventar`.

### O que executa

- Hook `SessionStart`: `scripts/sessao.sh`, que só imprime versão e estado do projeto.
- `scripts/gates.sh` (via `/raiz:provar` e `/raiz:construir`): roda com `bash -c` o campo `comando` de cada gate
  do `.raiz/gates.json` do projeto. Esse arquivo é código executável; revise-o antes de rodar os gates num
  projeto que você não escreveu.
- `/raiz:auditar`: roda a suíte local de testes que o projeto já tem, sem instalar dependências. Isso executa
  código do projeto auditado e pode gerar artefatos (caches, relatórios, builds); só audite projetos em que você
  confia o suficiente para rodar os testes.
- `/raiz:construir`: `xcodegen`, `xcodebuild`, `make` e `xcrun simctl` (macOS com Xcode).
- Agentes com `Bash`: `explorador` e `juiz` (gates e comandos de verificação). O `explorador` declara também a
  ferramenta `Write` no frontmatter: ele é só leitura por **instrução** de prompt, não por restrição de
  ferramenta. O `construtor` não declara `tools` e herda todas as ferramentas da sessão, inclusive `Bash`,
  escrita e web.
- **Nenhum comando declara `allowed-tools`**: os comandos `/raiz:*` rodam no thread principal, com as
  ferramentas e as permissões da sua sessão. Só os agentes declaram `tools`.

### Dado pessoal: o e-mail do git e o bundle id

`/raiz:construir` deriva o `<owner>` do bundle id (`com.<owner>.<projeto>`) lendo o seu `git config user.email`
e o remote do projeto; se não conseguir inferir, pergunta. O resultado é **escrito** no `project.yml` do app
(`bundleIdPrefix` e `PRODUCT_BUNDLE_IDENTIFIER`), que costuma ir para o seu repositório, e o bundle id de um
app publicado é público. Ou seja: um pedaço derivado do seu e-mail pode virar texto versionado. O comando só
pergunta quando não consegue inferir; revise o `project.yml` antes de commitar e corrija o `<owner>` se não
quiser expor essa parte do e-mail. Nenhum script do plugin envia esse dado a lugar nenhum; ele fica nos
arquivos do projeto e, como qualquer saída de comando, no contexto da sessão com o modelo.

### Manifesto do ecossistema (`ecossistema/manifesto.yaml`)

Guarda regras e ativos compartilhados entre os seus projetos. É lido como contexto pelo `arquiteto`, por
`/raiz:consultor` e por `/raiz:novo`. Quase todos os campos vêm como `"<definir>"` (em branco): você os preenche
editando o arquivo **na cópia do plugin que a sessão está usando** (o caminho é informado no início da
sessão). Atenção: atualizar o plugin **sobrescreve** a cópia instalada e apaga a sua edição. Por isso a
recomendação é não depender dela: quando um campo está `"<definir>"`, o `/raiz:novo` pergunta, e você informa as
escolhas nas respostas da entrevista (valem para aquele projeto; o plugin não as grava de volta no manifesto).
Se mesmo assim editar o arquivo, guarde uma cópia fora do plugin. Os três valores já preenchidos em
`governanca` (`commits_automaticos: false`, `rollback_first: true`, `escritor_unico: claude_code`) são premissas
de operação do próprio Raiz, não preferências suas; os agentes os leem como contexto e nenhum script os aplica.

### Rede

Nenhum script do plugin faz requisição de rede (as ferramentas que `/raiz:construir` dispara, como `xcodebuild`, podem;
veja acima). Nos agentes, a rede vem das ferramentas `WebSearch` e `WebFetch`:

| Agente | Ferramentas de web | Usado em |
|---|---|---|
| `radar` | WebSearch, WebFetch | `/raiz:radar` |
| `radar-auditor` | WebFetch | `/raiz:radar` (profundidade completa) |
| `contraditor` | WebSearch | `/raiz:inventar` (prior art) |
| `explorador` | WebSearch, WebFetch | `/raiz:design`, `/raiz:auditar` |
| `designer` | WebSearch, WebFetch | `/raiz:design` |
| `arquiteto` | WebSearch, WebFetch | decisões e `/raiz:consultor` |
| `construtor` | herda as da sessão | `/raiz:construir` |

Os agentes com `Bash` (`explorador`, `juiz` e o `construtor`, que herda a ferramenta) também podem fazer
requisição de rede por comando de shell, como `curl`. Os comandos instruem a não acessar serviços do próprio
projeto (produção, staging, APIs publicadas), mas isso é só uma instrução de prompt: nada no plugin bloqueia.
Se isso importa para você, restrinja rede e comandos com as permissões e o `/sandbox` do Claude Code.

**Conteúdo não confiável (prompt injection).** Páginas lidas com `WebFetch`/`WebSearch` e o código de um projeto
auditado são texto que o modelo lê, e texto hostil pode tentar induzir ações (executar comandos, gravar arquivos,
enviar dados). Isso vale sobretudo para os agentes que combinam leitura externa com `Bash` ou `Write`
(`explorador`, `construtor`). Nada no plugin filtra esse conteúdo. Audite só projetos em que você confia, revise
o que os agentes propõem executar e prefira rodar com o `/sandbox` e permissões restritas.

Veja também [SECURITY.md](SECURITY.md).

## Contribuindo

Veja [CONTRIBUTING.md](CONTRIBUTING.md). Em resumo: todo agente declara `model` (e `effort`, se não for
Haiku), `bash scripts/lint_modelos.sh` precisa passar, e gates são fail-closed.

## Licença

[MIT](LICENSE).

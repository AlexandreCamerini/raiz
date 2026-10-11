# Política de segurança

## Como reportar uma vulnerabilidade

Use o relato privado de vulnerabilidades do GitHub: na página do repositório, aba **Security** →
**Report a vulnerability** (`https://github.com/AlexandreCamerini/raiz/security/advisories/new`).

Não abra issue pública para uma vulnerabilidade e não inclua credenciais ou dados pessoais no relato.
Inclua: versão do plugin (`.claude-plugin/plugin.json`), passos para reproduzir e impacto esperado.

## Superfície relevante

O Raiz é um plugin do Claude Code: prompts de agentes, comandos e scripts shell executados na sua máquina.
A lista completa do que ele grava, lê, executa e acessa na rede está em
[Onde o Raiz grava, o que lê e o que executa](README.md#onde-o-raiz-grava-o-que-lê-e-o-que-executa).
Vale relatar em especial:

- scripts em `scripts/` que executem comando arbitrário a partir de entrada não confiável. Hoje
  `scripts/gates.sh` executa, com `bash -c`, o `comando` de cada gate declarado em `.raiz/gates.json` do
  projeto, e `/raiz:construir` gera esse arquivo e roda `xcodegen`, `xcodebuild` e `make`. `/raiz:auditar` roda a
  suíte local de testes do projeto auditado (código do projeto, não do plugin), o que pode gerar artefatos;
- dado pessoal: `/raiz:construir` lê `git config user.email` e o remote para derivar o `<owner>` do bundle id e o
  grava no `project.yml` do projeto (veja o README, seção "Dado pessoal");
- o hook `SessionStart` (`hooks/hooks.json` → `scripts/sessao.sh`), que deve apenas imprimir;
- instruções em agentes/comandos que levem a escrever fora do que o README documenta (`.raiz/`,
  `App/Shared/`, `App/iOS/`, `project.yml`, `Makefile`, `~/.raiz/radar/`, `~/.raiz/inventor/`,
  `modelos/pulso/` e `${TMPDIR:-/tmp}/raiz-gates/`), ou a fazer requisição de rede a serviços do próprio projeto.

Limites que você deve conhecer: as restrições de escrita dos comandos são instruções de prompt, não um
sandbox. Nenhum comando `/raiz:*` declara `allowed-tools`: eles rodam no thread principal com as ferramentas da
sua sessão. Os agentes `explorador` e `juiz` declaram `Bash`; o `explorador` declara também `Write` e é só
leitura por instrução, não por ferramenta; o `construtor` não declara `tools` e herda as da sessão; os agentes
de pesquisa usam `WebSearch`/`WebFetch`. O que de fato limita o plugin é o sistema de permissões do Claude Code.

## Versões suportadas

Apenas a última versão publicada recebe correções.

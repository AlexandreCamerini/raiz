# Changelog

## 0.1.0
- Esqueleto andante greenfield.

## 0.1.1
- explorador sem vereditos; juiz sem PASSA herdado e com escopo declarado; auditar lê invariantes e avalia operação (remote/backup).

## 0.1.2
- explorador com modelo de saída (Fato | Fonte | Comando) e seções obrigatórias; auditoria sempre completa e independente; checar_mapa.sh verifica o contrato do mapa.

## 0.1.3
- auditoria proibida de tocar a rede do projeto; testes locais permitidos com git status limpo; explorador registra a saída observada de cada comando.

## 0.2.0-rc.1
- designer: referências reais, 3 direções, trava; bifurcação e consultor; checar_design/checar_estado

## 0.2.0
- 0.2 aceita: direção visual de um app real travada no campo de prova

## 0.3.0-rc.1
- /raiz:construir; tokens.sh gera TokensGerados.swift do direcao.lock.md; gates checar_tokens.sh e checar_kit.sh

## 0.3.0-rc.2
- construir: Kit/Componentes.swift entra na fatia do construtor

## 0.3.0
- 0.3 aceita

## 0.4.0-rc.1
- radar: agente radar + radar-auditor, checar_radar/radar_diff/radar_slug, schema do sinal, roteamento e matriz de modelos

## 0.4.0
- 0.4 aceita: radar provado em 2 rodadas (tema agentes de IA e orquestração multi-agente)

## 0.5.0-rc.1
- inventor: hipóteses ancoradas no radar, crítica com prior art, apostas com teste de 1 dia e critério de morte

## 0.5.0
- 0.5 aceita: inventor provado (2 apostas com teste de 1 dia e critério de morte, tema agentes de IA e orquestração multi-agente)

## 0.6.0-rc.1
- prototipador: protótipo HTML descartável (lógica) a partir de aposta do inventor, roteiro de teste que apoia o experimento de 1 dia

## 0.6.0
- 0.6 aceita: o protótipo é navegável de verdade, testado clicando no navegador (não só lido): trocar de cenário atualiza veredito e regra corretamente nos 3 casos pré-carregados, e o passeio guiado avança por 3 passos. O roteiro de validação adapta o Experimento da aposta em passo a passo executável sem redefinir critério de sucesso/morte. Nenhum dado observado foi fabricado: todo campo 'observado' está marcado explicitamente 'a preencher', consistente com a regra do agente prototipador.

## 0.7.0-rc.1
- pulso: analisa medições acumuladas, recomenda troca de modelo/effort só quando o dado sustenta

## 0.7.0
- 0.7 aceita: o sintetizador passou de sonnet/high para sonnet/medium como HIPÓTESE (2026-09-26), sem medição em medium -- o registro em modelos/matriz.yaml diz isso. A única medição existente é do sintetizador em sonnet/high (399519ms/8 tool_uses = 49,9s/chamada, no mesmo patamar do inventor opus/high): ela sugere que o papel é de compilação, não de criação, mas não mede o efeito da troca. Já aplicada em hipoteses_iniciais; segue como hipótese até haver medição em medium. radar-auditor NÃO virou troca de modelo (é I/O serial, registrado como achado de arquitetura, não força troca onde a medição não sustenta).

## 1.0.0
- Raiz 1.0 — ciclo fechado num projeto novo

## 1.0.1
- construir: quando um gate bloqueante (kit ou build) falha duas vezes, o comando para e reporta, em vez de registrar a falha e seguir.
- `.gitignore` passa a ignorar `.raiz/` (estado local do Raiz num projeto: auditorias, decisões, estado.json), para não ser versionado por engano.
- gate de publicação (`scripts/checar_publico.sh`) mais rigoroso: reprova letras e símbolos que imitam outras letras (circuladas, romanas, de largura total, braille e afins) mesmo quando formam um termo proibido depois da normalização Unicode; reprova termos proibidos e caminhos pessoais escondidos em base64 curto (8 caracteres ou mais; segredos e e-mails em base64 só são detectados a partir de 12) e texto escondido em entidades HTML e escapes (`&#NN;`, `\uHHHH`, `\xHH`, `%HH`); reconhece mais formatos de chave e token (sk- longas, Stripe restrita e de teste, AWS temporária, GitLab, npm, Hugging Face, Azure, Bearer com JWT) e corpo de chave PEM sem cabeçalho. Limitações conhecidas: número de versão com quatro partes é tratado como endereço IP e reprova (escreva a versão com três partes); o gate é uma rede de proteção, não garantia: letras latinas acentuadas parecidas, base64 muito longo ou quebrado de formas incomuns e provedores de token fora da lista ainda podem passar, então revise o diff antes de publicar.
- a versão sobe para o cache do plugin renovar (o cache só atualiza quando a versão muda).

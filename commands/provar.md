---
description: Roda os gates do projeto (fail-closed) e reporta o resultado real
---
1. Execute `bash <scripts do plugin>/gates.sh` no diretório do projeto (caminho dos scripts informado no início da sessão).
2. Se `.raiz/gates.json` não existir, o script falha de propósito: proponha os gates adequados à stack detectada, cada um com comando real, e peça aprovação antes de gravar.
3. Reporte PASS/FAIL por gate, sem reinterpretar. Nunca declare sucesso se o script retornou erro.

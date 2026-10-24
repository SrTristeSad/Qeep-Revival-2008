# Base técnica verificável — Qeep Java ME

**Referências locais analisadas:** `qeep-94724.jar` e `qeep_client_ui.zip` fornecidos pelo mantenedor. Os binários e os gráficos originais não estão redistribuídos neste repositório público.

- MIDlet: `joca.Joca` (Qeep 1.29, Blue Lion mobile); MIDP 2.0 / CLDC 1.0.
- Registro: `build.timestamp=200801211543` (formato interpretado como 21/01/2008, não necessariamente data de lançamento).
- SHA-256 do JAR: `fd24b6191fbef801f3b7791def8c9c13e30485c9152fe073799f46c383e5e6b3`.
- 35 arquivos `.class`, três PNGs incorporados (`icon_15x15.png`, `logo.png`, `kui/symbols.png`).
- Cores verificadas no `registry.ini`: `#EBFFB9`, `#CDFF3C`, `#A0B419`, `#7D147D`.
- A classe `w` serializa requisições com: 1 byte de tipo, Java `writeUTF` do caminho, inteiro big-endian de parâmetros, pares de strings e um anexo precedido de inteiro. No transporte por socket, existe um prefixo de comprimento `int32`.
- A leitura de respostas sem XOR começa por 1 byte de tipo, seguida por caminho e parâmetros no mesmo estilo; o fluxo real de mensagens ainda precisa ser testado.
- `h` interpreta estrutura de interface remota (elementos como `form`, `layout`, `button`, `input`, `img`). As páginas originais do servidor **não estão todas no JAR**.
- Foram observados endpoints históricos `/navigation/init/` e `/navigation/structure` e referência a porta 5190, mas **nunca conectamos ao serviço histórico**.
- Recurso `animation.png` e classe `handler.Mplayer` referenciados, porém ausentes no JAR analisado.

## Distinção obrigatória

**Confirmado:** estrutura estática do JAR, configuração, formato principal de solicitação e componentes locais. **Experimental:** servidor de laboratório `/revival/ping`, codec Lua de teste, tela inicial provisória. **Não confirmado:** respostas históricas reais, conteúdos completos das páginas, login, funcionalidades sociais e compatibilidade 1:1.

## Segurança e direitos

O servidor de laboratório usa porta local e não processa senhas. Evite publicar JAR e artes proprietárias sem autorização. O projeto precisa de documentação de proveniência antes de integrar arquivos históricos. Apenas o código novo está sob MIT.

# Fase 15 — evidências visuais do Qeep 1.29

## Objetivo

Distinguir o que o arquivo Java ME **comprova** do que o laboratório Lua
apenas **aproxima**. Nenhuma captura de versões posteriores é tomada como
prova do visual do JAR de janeiro de 2008.

## Referências verificadas

O script `python3 tools/audit_visual_jar.py /caminho/qeep-94724.jar` examina
`registry.ini` e cabeçalhos/hashes dos três PNGs sem executá-los ou publicá-los.
A saída reprodutível está em [`visual-evidence-fase15.json`](visual-evidence-fase15.json).

* `registry.ini`: `qeep_en-1.29`, `back.cmd=Back`, `kui.cmd.select=Select`,
  `kui.cmd.cancel=Cancel`, `kui.cmd.options=Options`, `ok.cmd=OK`.
* Cores verificadas: `s0.bg=ebffb9`, `s2.bg=cdff3c`, `s7.cbg=a0b419`,
  `s10.bg=a1b617` e `s11.tc=3c143c`.
* PNGs verificados por SHA-256 e dimensões: `logo.png` **128×42**,
  `icon_15x15.png` **15×15**, `kui/symbols.png` **12×180**.
* O recorte em células **12×6** do atlas `symbols.png` e o uso dos
  quadros **14–17** pelo cliente estão documentados na Fase 7.

## Mudanças na interface

* A nova opção **Recursos originais (JAR)** exibe logo, ícone, oito cores
  e quatro quadros do atlas, quando o usuário já importou seus próprios
  arquivos de referência com `tools/import_jar_assets.py`.
* O desenho da tela de referência é **novo** e serve para comparação;
  NÃO é uma tela que tenha sido recuperada do servidor do Qeep.
* O canvas lógico continua **240×320**. Agora o cliente prioriza zoom
  inteiro com letras e pixels sem escalonamento fracionário; janelas
  menores que 240×320 usam redução proporcional. As bordas vazias
  permanecem fora da área interativa e o toque é convertido para as
  coordenadas corretas da interface.
* Menus e controles sociais de laboratório continuam com a aparência
  explicitamente provisória, preservando as fases anteriores.

## Reprodução

```bash
python3 tools/audit_visual_jar.py /caminho/qeep-94724.jar
python3 tools/import_jar_assets.py /caminho/qeep-94724.jar
love client
# No menu, abra "Recursos originais (JAR)"
```

Os originais não são armazenados na branch pública. A versão `.love`
local pode incluí-los **somente** quando produzida a partir do JAR que o
usuário forneceu. A cópia de código-fonte não os inclui.

## Lacunas explícitas

Ainda não foi obtida uma execução visual do `qeep-94724.jar` em emulador
Java ME com telas do servidor original. Não há referência pixel a pixel
da navegação social de 2008. Não confundimos interfaces publicadas em
anos posteriores com esta build 1.29. Capturas da GPU/Android também
não foram verificadas. O avanço desta fase é uma base de evidências
reproduzível, não uma afirmação de aparência histórica 1:1.

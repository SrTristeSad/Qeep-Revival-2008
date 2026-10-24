# Fase 3 — revisão estática do layout e renderização JCL (24/10/2026)

## Evidência rastreável (JAR original)

No `qeep-94724.jar` de 2008, a desassemblagem `javap -c -p h.class` do parser de tags (`h.a(m,j)`) indica:

- Nas tags `a`, `p`, `button`, `li`, `img` e `hr`, lê `href` e o atributo numérico `align`, armazenado em `ac.k`.
- Para `a` sem `label`/`clabel`, o fallback de rótulo é `>` (instruções em torno de 450–469 do método). Para `li`, fallback é `*` (em torno de 426–447).
- Para `hr`, inicializa `ac.G = 90` (em torno de 524–536), depois substitui com o inteiro `w` quando presente (em torno de 540–559).
- Também lê `style`, `focus`, `focused` (em torno de 114–207) e `flags`; a mera leitura não prova a semântica completa do layout histórico.

O arquivo `registry.ini` do JAR documenta as cores e estilos `s0`, `s1`, `s2`, `s4`, `s5`, `s7`, `s8`, `s10`, `s11`, `s12` e `s13`. **São valores de configuração autênticos, não imagens de telas antigas.**

## Implementação

- `client/lib/jcl_style.lua` interpreta exclusivamente identificadores numéricos conhecidos, impedindo URLs/expressões arbitrárias no estilo. Usa `cbg`/`bg` como preenchimento proposto, `tc` como texto e `fr` como contorno. A cor `xc` é usada no estado de foco quando disponível. **O vínculo exato entre os campos do registro e os pixels do renderizador original ainda precisa de validação em emulador.**
- `client/lib/jcl.lua` retém `align` como número para estudo posterior; não presume que valores numéricos sejam equivalentes às constantes do LÖVE. Também guarda `hr.width`, marcadores de `a`/`li`, preserva a ordem de texto misturado a elementos filhos, e rejeita entidades XML malformadas.
- `client/lib/jcl_layout.lua` calcula largura de separadores, mantém alturas e posições coerentes com rolagem, sem afirmar que a centralização é a mesma usada no Java ME.
- `client/main.lua` aplica cores resolvidas e desenha as linhas com largura explícita. Continua sendo um protótipo com resolução lógica de 240×320.
- `client/fixtures/lab.xml` inclui o formulário `styles`, inteiramente sintético e rotulado como laboratório. Não se trata de uma tela extraída do servidor original.

## Testes e limitações

`tests/test_jcl_styles.lua` verifica o fallback de marcadores, a largura de separadores, a ordem do texto, a leitura do alinhamento, a identificação de estilos, a rejeição de entidades incompletas e a resistência a valores de estilo desconhecidos. O teste de interface simulada inclui navegação ao formulário de demonstração.

Sem capturas de emulador ou pacotes autênticos do servidor antigo, não há base para prometer reprodução visual 1:1, login/chat reais, layout de todas as tags ou aparência final do Qeep. Não redistribuímos os PNGs do JAR no repositório.

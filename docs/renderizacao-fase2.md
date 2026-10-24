# Fase 2 — fluxo visual JCL, rolagem e correção Unicode (24/10/2026)

## Evidências estáticas (cliente original)

A análise foi feita exclusivamente sobre o `qeep-94724.jar` fornecido para o projeto. O `registry.ini` inclui 11 estilos (s0, s1, s2, s4, s5, s7, s8, s10, s11, s12 e s13). Cores comprovadas: fundo `EBFFB9`, destaque `CDFF3C`, oliva `A0B419`, roxo `7D147D`, texto `000000`, roxo-escuro `501E50` e `3C143C`. A tabela foi transcrita em `client/lib/legacy_palette.lua` para que futuras revisões não precisem adivinhar códigos de cores.

No bytecode:

- `aa.paint(Graphics)` encaminha desenho ao formulário `j.b(Graphics)` e possui desenho próprio de transições/indicadores. `aa` também implementa `keyPressed`, `keyReleased`, `keyRepeated`, `pointerPressed`, `pointerDragged` e `pointerReleased`.
- `j` possui métodos de renderização (`b`, `c`, `a`, `d` com `Graphics`), controle de foco (`e()` retorna o widget atual) e gerenciamento de comando (`commandAction`).
- `ac` é a base de widgets com desenho abstrato `a(Graphics,int,int)` e medidas/layout de controles.

Os nomes ofuscados e a falta de respostas do antigo servidor **impedem concluir dimensões e estilos exatos de cada tela** só com essa evidência. O desenho desta fase é uma **interpretação funcional** do sistema, não uma reprodução histórica 1:1.

## Alterações implementadas

1. `jcl_layout.lua`: organiza linhas por altura calculada a partir de medição de fonte, quebra de texto, área útil e tipo de controle. É uma biblioteca puramente Lua, com testes sem LÖVE.
2. Foco e scroll: o item selecionado é mantido visível quando se navega pelo teclado; rolagem manual por wheel/PgUp/PgDn e gesto vertical com toque, sempre limitada ao comprimento real da página.
3. Seleção e toque: hit-testing só considera controles visíveis dentro da área de conteúdo. As barras de comando esquerda e direita permanecem disponíveis.
4. `utf8_edit.lua`: edição respeita limites por caractere Unicode, não por bytes; `backspace` não corta caracteres acentuados ou emoji no meio.
5. Paleta de evidências: cores extraídas de `registry.ini`; não são redistribuídas imagens ou fontes do JAR.
6. `tests/test_client_smoke.lua`: percorre menu, abertura do JCL, troca de formulário, seleção, edição e rolagem num LÖVE simulado. **Não é teste de dispositivo nem de renderização real**.

## Limites / próximos passos

- A largura lógica **240 × 320** é uma escolha do protótipo, não uma resolução universal demonstrada para todos os dispositivos Java ME.
- O cálculo de comprimento Unicode usa pontos de código, enquanto partes do Java ME podem ter contado unidades UTF-16. Isso será verificado quando extrairmos mais regras do bytecode para campos.
- Não há suporte a imagens remotas, submissão histórica de formulários, máscaras/decoração precisa do estilo `s11` em gradiente, fontes do dispositivo original ou layout de todas as tags JCL.
- Nenhuma tela sintética representa login, cadastro ou chat históricos. Para a etapa seguinte: teste visual do JAR em emulador Java ME, coleta de capturas verificáveis e mapeamento dos estilos usados por cada elemento.

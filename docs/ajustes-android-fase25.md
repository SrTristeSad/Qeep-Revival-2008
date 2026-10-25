# Fase 25 — Ajustes visuais Android após a primeira captura real

## Evidência

Execução GitHub Actions [40241042226](https://github.com/SrTristeSad/Qeep-Revival-2008/actions/runs/40241042226), Android 34, APK da Fase 24. O `result.json` confirmou instalação/abertura e processo ativo; a captura real em 1080 × 1920 mostrou a UI em área central reduzida, com espaços vazios laterais e instruções `Enter`/`Esc` inadequadas para toque. O registro de Android `hidapi` relativo ao broadcast receiver foi observado, mas não houve encerramento fatal. Esse aviso de biblioteca ainda pode exigir revisão futura.

## Alterações fundamentadas

- `legacy_viewport.fit` aceita opção `fractional=true`, preservando escala inteira por padrão, e amplia proporcionalmente ao maior tamanho que cabe na janela.
- O cliente ativa essa opção **somente em Android/iOS**; a tela lógica permanece 240 × 320, a proporção é preservada e coordenadas de toque, scissor, teclado e renderização usam a mesma transformação.
- Rodapé do menu no móvel: **Abrir** (atua no item selecionado) e **Sair**. Configuração de IP: **Salvar** e **Cancelar** acionados por toque.
- Em outras telas de informação, rodapé usa **Voltar**; não exibe comandos Enter/Esc em Android. Telas JCL continuam com os comandos contextuais da própria página.
- A galeria dos recursos originais permanece um laboratório; estas mudanças não afirmam fidelidade visual histórica 1:1.

## Limitações

O emulador aprovou a inicialização **da versão anterior**. A nova renderização móvel ainda precisa de novo smoke de emulador e teste em aparelho físico. A escala fracionária pode distribuir pixels de forma não uniforme em alguns tamanhos; o Windows mantém escala inteira para evitar isso. Não foi testado login/chat completo dentro do emulador.

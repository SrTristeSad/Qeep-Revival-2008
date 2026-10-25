# Fase 26 — Navegação Android real e comparação entre execuções

## Evidência existente (Android 34, emulador real)

- Fase 24: [startup no emulador, execução 40241042226](https://github.com/SrTristeSad/Qeep-Revival-2008/actions/runs/40241042226). Imagem `emulator.png` produzida pelo adb; a interface ocupava aproximadamente 58,4% da largura da captura 1080×1920.
- Fase 25: [startup no emulador, execução 40242854541](https://github.com/SrTristeSad/Qeep-Revival-2008/actions/runs/40242854541). Outra imagem autêntica produzida pelo adb; a barra superior agora mede toda a largura de 1080px e o rodapé contém `Abrir` e `Sair`.
- A ampliação é uma adequação Android do laboratório. Não é reconstrução 1:1 do layout original do Java ME.

## Fase 26 — novo teste funcional de toque

`tools/android_navigation.py` é executado **depois** do smoke de instalação. Sem rede externa nem login:

1. Captura `01-menu.png` real pelo adb e detecta barras superior/rodapé na paleta original da aplicação.
2. Rejeita uma interface que permaneça horizontalmente reduzida abaixo de 96% da largura do emulador.
3. Toca na opção **Sobre o projeto** e salva `02-about.png`, exigindo uma mudança visual real na área do aplicativo.
4. Toca no rodapé **Voltar**, captura `03-menu-return.png` e exige outra transição visual.
5. Toca em **Abrir JCL (offline)**, salva `04-offline-jcl.png` e exige mudança verificável.
6. Confirma que o processo ainda está ativo e coleta `logcat.txt` e `result.json`.

As comparações usam diferenças de pixels da área interna do aplicativo (sem relógio nem barra do Android); não usam OCR nem alegam equivalência visual com telas Java ME. A execução é realizada pelo mesmo `android-emulator-smoke.yml` usado na Fase 24, agora com artefato adicional de navegação.

## Limitações

- A inicialização real **da Fase 25** já passou. Os novos testes de toques da Fase 26 só podem ser declarados aprovados após uma execução bem-sucedida do workflow.
- Não há aparelho físico conectado; ausência de crash no emulador não comprova o funcionamento de todos os aparelhos.
- Não são testados login, chat TCP, câmera nem distribuição pública do APK.
- A comparação histórica com as telas originais Java ME ainda exige uma captura autêntica do JAR.

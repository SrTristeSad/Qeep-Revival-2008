# Fase 17 — Captura controlada do Qeep Java ME

## Situação verificada

O MicroEmulator 2.0.4 é um emulador Java ME publicado no SourceForge. **Neste ambiente não há arquivo do emulador disponível** e as conexões necessárias para baixá-lo falharam. A tentativa de `unshare -n true` também devolveu `Operation not permitted`. **Não obtivemos uma captura de execução do Qeep** e não declaramos fidelidade 1:1.

## Como obter uma captura verificável em Linux

1. Obter o MicroEmulator 2.0.4 na página oficial do SourceForge e extrair `microemulator.jar` (em algumas distribuições o nome é `microemulator-2.0.4.jar`). Não colocar o emulador nem o JAR original no repositório público.
2. Instalar Java, Python 3, Pillow e Xvfb. Habilitar um namespace de rede independente (`unshare -n true` deve encerrar com código 0, possivelmente com privilégios apropriados). **Não executar o original com acesso à Internet**.
3. Rodar da raiz do projeto, substituindo os caminhos:

```bash
python3 tools/j2me_capture.py /caminho/qeep-94724.jar --emulator /caminho/microemulator.jar
python3 tools/j2me_capture.py /caminho/qeep-94724.jar --emulator /caminho/microemulator.jar --run-isolated --delay 12 --out-dir visual-results/emulator
```

O primeiro comando **não executa nada**: só valida os arquivos e mostra o comando proposto. O segundo inicia uma tela Xvfb exclusiva e o JAR dentro de `unshare -n`. Se o isolamento não funcionar, o processo original não será iniciado. O processo é encerrado após a captura.

### Saídas

- `emulator-window.png`: captura integral da janela emulada, inclusive moldura ou tela de erro, caso apareçam. **Não afirmar que é uma tela real do Qeep sem inspeção visual.**
- `capture-provenance.json`: hash SHA-256 do JAR original, do emulador e da captura, horário relativo, comando, estado do processo e o indicador obrigatório `specific_historic_screen_verified: false`.
- `emulator.log`: log local, útil para diagnosticar ausência de APIs e outros erros. Antes de compartilhar, revisar qualquer dado sensível.

Após conseguir uma captura, pressione `F12` no cliente LÖVE para obter a imagem correspondente e compare-as:

```bash
python3 tools/compare_visual.py visual-results/emulator/emulator-window.png /caminho/captura-love.png \
  --crop-reference X Y LARGURA ALTURA --scale-reference 1 \
  --crop-candidate X Y LARGURA ALTURA --scale-candidate 1 \
  --out-dir visual-results/comparacao
```

Escolher os recortes **a partir da tela real**, e não pressupor que a área útil Java ME tenha 240×320. Arquivos em `visual-results/` são ignorados pelo Git. Evitar comparar a tela sintética do laboratório com páginas originais que eram enviadas exclusivamente pelo servidor antigo.

## Limitações

A captura não comprova que o JAR recebeu telas legítimas do servidor original. O emulador pode mostrar apenas o splash, o menu do próprio emulador, uma mensagem de erro ou uma tela incompleta. O relatório exige revisão manual para identificar o conteúdo e a versão real exibidos. No Windows, onde o isolamento Linux não está disponível, **não executar o cliente antigo conectado à rede**; executar em VM sem placa de rede ou usar um ambiente Linux isolado.
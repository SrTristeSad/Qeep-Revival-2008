# Fase 16 — execução isolada e comparação verificável

## O que temos (e o que ainda não temos)

- Fonte: `qeep-94724.jar`, Qeep 1.29, MIDP 2.0 / CLDC 1.0. O hash SHA-256 do arquivo usado na auditoria local é `fd24b6191fbef801f3b7791def8c9c13e30485c9152fe073799f46c383e5e6b3`.
- **Não existe captura histórica validada nesta fase.** Não foi possível obter e executar um emulador no ambiente de desenvolvimento. As três imagens PNG extraídas do JAR são recursos, não capturas de telas.
- O código de comparação não comprova a origem histórica das imagens recebidas: a evidência deve ser registrada pelo operador.
- O aplicativo original contém referências a servidores antigos. **Nunca o execute com acesso à Internet**, nem introduza credenciais antigas. Não houve tentativa de conexão à rede original.

## 1. Preparar o emulador (somente offline)

Emuladores possíveis: FreeJ2ME-Plus (AWT) e MicroEmulator 2.0.4. Obtenha-os de seus repositórios oficiais, sem incluí-los no projeto. Recomendamos uma máquina virtual com rede desativada para capturar a tela inicial. Algumas funções do Qeep dependem de respostas de um servidor indisponível e podem não surgir offline.

Verificar o JAR **sem executá-lo**:

```bash
python3 tools/j2me_preflight.py /caminho/qeep-94724.jar --report output/preflight.json
```

Se houver um `freej2me.jar` instalado, preparar a linha de comando sem iniciar o MIDlet:

```bash
python3 tools/j2me_preflight.py /caminho/qeep-94724.jar --backend freej2me --emulator /caminho/freej2me.jar
```

Somente no Linux, o comando abaixo tenta criar um namespace de rede completamente desconectado. **Se o isolamento não estiver autorizado, termina antes de iniciar o emulador**. A inicialização Java ME pode falhar devido a dependências ausentes no JAR.

```bash
python3 tools/j2me_preflight.py /caminho/qeep-94724.jar --emulator /caminho/freej2me.jar --run-isolated
```

No Windows, utilize uma **VM sem adaptador de rede** e inicie o emulador manualmente. Não oferecemos uma opção de execução insegura pelo script. Capture a janela no tamanho do LCD; anote largura/altura, emulador usado, versão, hora e qualquer mensagem de erro.

## 2. Capturar a versão Lua

No cliente LÖVE Windows, pressione **F12**. A captura PNG é salva no diretório de gravação da aplicação (no Windows, normalmente `%APPDATA%\\LOVE\\qeep-revival-2008`). É uma captura **local** e somente ocorre por ação do operador; não é enviada para rede nem para GitHub. Se a janela LÖVE estiver ampliada, a captura incluirá as margens/espaços da janela. Use o recorte explícito no comparador.

**Atenção:** não capture campos com códigos de acesso ou informações pessoais; imagens podem conter esses dados em texto legível.

## 3. Comparar as duas imagens

Instale Pillow (`python -m pip install Pillow`) e execute:

```bash
python3 tools/compare_visual.py original.png revival.png --out-dir visual-results
```

A saída contém `reference-normalized.png`, `candidate-normalized.png`, `differences.png` (pixels distintos em vermelho), `overlay.png` e `report.json` (porcentagem de diferenças e MAE RGB).

Para uma captura original de 240×320 a 2x e outra janela LÖVE com bordas, **especifique** escalas e recortes, por exemplo:

```bash
python3 tools/compare_visual.py original.png revival.png \
    --scale-reference 2 --crop-candidate 40 20 480 640 --scale-candidate 2 \
    --out-dir visual-results
```

Não usamos interpolação: escala inteira é reduzida com nearest-neighbor. Use `--mask X Y W H` somente para áreas dinâmicas conhecidas (horário, dados pessoais), documentando quais foram mascaradas. Se as dimensões lógicas diferirem, a ferramenta recusa a comparação: não tenta forçar uma falsa fidelidade.

## Próxima validação

1. Conseguir uma captura autêntica e documentada do primeiro quadro renderizado pelo MIDlet.
2. Confirmar se o JAR chega ao menu antes de requerer servidor ou classes não incluídas.
3. Capturar a mesma tela (ou estado comprovadamente equivalente) no cliente Lua, sem confundir o laboratório atual com uma tela histórica.
4. Comparar margens, fontes, cores, recortes do atlas e softkeys; registrar ajustes com provas e testes.

**Não houve comparação 1:1 nesta fase**: somente a infraestrutura para fazê-la de forma verificável foi criada.

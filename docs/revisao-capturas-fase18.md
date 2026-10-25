# Fase 18 — Revisão auditável das capturas

## Situação

Não existe ainda uma captura autêntica da versão Java ME no projeto. A tentativa realizada neste ambiente confirmou o hash do JAR original, mas `unshare -n true` falhou com **Operation not permitted** e o emulador não pôde ser baixado. Nenhuma tela foi reconstruída por aproximação a partir dessa tentativa.

A Fase 18 adiciona uma etapa obrigatória de **revisão humana** entre a captura Linux isolada (Fase 17) e o comparador de pixels (Fase 16). Esta etapa protege contra o erro de confundir a janela do próprio emulador, uma tela vazia ou um erro Java com uma tela do Qeep.

## Capturar com o Qeep original

Use o procedimento descrito em `docs/captura-autentica-fase17.md` numa máquina Linux com `unshare -n`, Xvfb, Java, Pillow e um emulador Java ME confiável instalado. O cliente antigo deve continuar **sem acesso à rede externa**. A captura gera `emulator-window.png` e `capture-provenance.json`.

## Classificar e selecionar a tela

Inspecione visualmente a captura e escolha um retângulo correspondente **somente à área útil do MIDlet** — as coordenadas devem ser medidas na captura real e podem diferir de 240×320. Se a captura mostrar uma tela do Qeep, registre uma descrição específica e marque sua confirmação explícita:

```bash
python3 tools/visual_evidence.py review \
  visual-results/emulator/emulator-window.png \
  visual-results/emulator/capture-provenance.json \
  --classification qeep-splash \
  --note "Confirmei visualmente logotipo e tela inicial do MIDlet, sem elementos do emulador no recorte" \
  --confirm-visible-app \
  --crop X Y LARGURA ALTURA \
  --out-dir visual-results/review
```

Se a imagem só mostrar o lançador do emulador, use `--classification emulator-ui` e **não** use `--confirm-visible-app`. `unknown` também é uma classificação válida, mas essas duas classificações não podem servir como referência na ferramenta de comparação.

As categorias `qeep-client`, `qeep-splash` e `qeep-error` identificam estados percebidos por uma pessoa, **não** comprovam que uma tela foi entregue pelo servidor de 2008.

## Comparar com o cliente LÖVE

Obtenha a tela visualmente correspondente no cliente LÖVE pressionando `F12`. Execute:

```bash
python3 tools/visual_evidence.py compare \
  visual-results/review/reference-review.json \
  /caminho/captura-do-cliente-love.png \
  --candidate-crop X Y LARGURA ALTURA \
  --candidate-scale 1 \
  --out-dir visual-results/review-comparison
```

A ferramenta só compara imagens de **tamanhos lógicos iguais**. Use `--candidate-scale 2` se a captura LÖVE representar cada pixel lógico por um quadrado 2×2, e escolha manualmente o recorte apropriado. Não aplique escala suavizada nem ajuste as imagens até que elas pareçam iguais artificialmente.

Saídas: `reference-review.json`, `reference-reviewed.png`, `report.json`, `reference.png`, `candidate.png`, `overlay.png` e `differences.png`. O relatório indica a fração de pixels diferentes e o erro médio por canal RGB; ele **não** verifica automaticamente se as duas imagens mostram a mesma tela histórica.

## Garantias e limitações

- Confere o SHA-256 do JAR original e a integridade do PNG em relação ao relatório de captura, além de conferir a declaração de isolamento do executor.
- **Não** é prova criptográfica de que o emulador executou o Qeep. O JSON de proveniência é um relato gerado localmente e pode ser falsificado; a revisão humana também não equivale a documentação oficial histórica.
- Impede comparar automaticamente uma janela de emulador ou uma imagem sem revisão com uma tela apresentada como Qeep.
- O recorte e o relatório ficam em `visual-results/`, ignorado pelo Git. **Não** publique capturas contendo dados de conta, mensagens ou credenciais.
- A interface JCL do servidor antigo continua não recuperada. Comparações só fazem sentido entre estados correspondentes realmente observados.

# Fase 7 — símbolos e imagens do JAR original

## Evidência observada

* `aa.class`, método estático de desenho de sprites: recebe a imagem, posição, quadro, número de colunas e linhas; calcula a região usando divisões inteiras e recorte gráfico.
* `aa.class`, inicializador: carrega `kui/symbols.png`, cujo PNG mede **12 × 180** pixels.
* `j.class`, método de desenho: solicita os quadros **15 ou 17** e **14 ou 16** com **1 coluna e 30 linhas**. Cada recorte fica com **12 × 6** pixels. Usa flags para escolher os pares.
* `ac.class` desenha recursos de imagem após estabelecer uma região de clipping. Os atributos `src` do JCL são conhecidos, mas os recursos das páginas originais enviadas remotamente não foram recuperados.

## Implementação

`client/lib/legacy_symbols.lua` calcula os recortes correspondentes sem redimensionamento; também desenha esses quadros quando o PNG for importado localmente. O indicador foi colocado no rodapé de laboratório. A posição e associação entre flags e rolagem **são aproximações**, e não a prova de posicionamento original.

`client/lib/legacy_assets.lua` permite carregar **somente** três recursos presentes no JAR recebido: `logo.png`, `icon_15x15.png` e `kui/symbols.png`. A lista é estática e bloqueia URLs, caminhos absolutos e travessia `../`. O carregador valida as dimensões, preserva o filtro `nearest` e mantém cache.

`client/lib/jcl_layout.lua` dimensiona localmente elementos `<img>` usando a altura conhecida, e `client/main.lua` os renderiza, se importados. A página `#styles` mostra `logo.png` e `icon_15x15.png` como **demonstração sintética**, nunca como captura histórica.

Recursos originais não são enviados ao GitHub. Para importar seus PNGs de um JAR já obtido, use:

```bash
python3 tools/import_jar_assets.py /caminho/para/qeep-94724.jar
```

Sem esses arquivos, a interface continua executando e mostra texto substituto. Não fazemos chamadas externas ao servidor original.

## Limitações verificáveis

* Ainda não há captura pixel a pixel de um emulador Java ME nem telas remotas originais.
* O recorte do atlas corresponde ao bytecode, mas a posição do indicador no laboratório não é 1:1.
* A implementação de imagens não substitui o carregador de mídias remotas e não fornece imagens para conteúdo criado por usuários.

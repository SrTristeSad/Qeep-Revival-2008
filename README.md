# Qeep Revival 2008

Reconstrução **independente** e orientada por evidências do cliente clássico Qeep para **Android e Windows**, com **Lua + LÖVE (Love2D)** e servidor próprio em Lua. Projeto de preservação e estudo; não é afiliado ao serviço original.

## Estado atual: fase 6 — navegação JCL com histórico e assets opcionais (protótipo)

- Cliente LÖVE inicial com controles por teclado, mouse e toque, renderização lógica em **240 × 320**, paleta extraída de `registry.ini` e tela **explicitamente provisória**.
- Servidor Lua de diagnóstico na porta **5190**, apenas para teste em rede local.
- Codec de mensagens sintéticas deduzido do bytecode do cliente Java ME e testes sem rede.
- Interpretador local de subconjunto JCL identificado no bytecode: formulários, textos, links, botões, campos, seleção e teclas de ação, com uma **página de demonstração sintética** (offline ou enviada pelo servidor de laboratório).
- Renderização em lista com alturas dinâmicas, quebra de linhas e rolagem limitada ao conteúdo, mantendo o foco visível por teclado e gestos de toque. Edição de texto UTF-8 preserva caracteres acentuados e emoji.
- Paleta e tabela de estilos transcritas de `registry.ini` (somente informação técnica, sem copiar recursos protegidos). O cliente interpreta `style="11"`/`style="s11"` quando o identificador consta dessa tabela. A **interpretação de preenchimento e contorno é experimental**, não uma tela original recuperada.
- O parser preserva texto misto na ordem original; links e listas sem rótulo recebem marcadores `>` e `*`; separadores respeitam `w` (90 por padrão), conforme o bytecode `h.class`. Uma quarta tela de laboratório demonstra esses detalhes.
- **Fase 4:** o cliente pode carregar via TCP um formulário **sintético** do servidor de laboratório, preencher `input`/`textarea`/`select`, enviar tipo `P` e abrir a resposta JCL. O servidor não salva dados. Esse tipo de envio foi inspirado na classe original `handler.Submit` e na coleta da classe `n`, mas o endpoint e o conteúdo de resposta são nossos, não históricos.
- **Fase 5:** histórico limitado de navegação preserva formulário, foco e rolagem para voltar com Esc/Backspace/0; erros de comunicação não descartam o documento atual. A tecla numérica 2/8/5/4/6 facilita testes com controle de telefone antigo. Um importador valida os três PNGs do JAR por hash e permite usar o logotipo original localmente, sem publicá-lo no GitHub.
- **Fase 6:** seleção JCL (`select`) distingue os tipos 1 (única), 2 (múltipla), 3 (única) e 4 (compacta). Os padrões por quantidade de opções e a concatenação de valores múltiplos por vírgulas foram verificados nas classes `h` e `s` do JAR. O layout e os controles são uma aproximação própria, não uma captura pixel a pixel do Qeep. Veja `docs/selecoes-fase6.md`.
- Não existem ainda login, contas, chat, contatos, jogos ou telas históricas reconstruídos. A interface de demonstração **não deve ser confundida com uma tela original do Qeep**.

## Executar

**Cliente Windows / desktop:** instale [LÖVE 11.x](https://love2d.org/), abra a pasta `client` com LÖVE ou, no terminal, use `love client` a partir da raiz do repositório.

**Servidor de testes:** instale Lua e LuaSocket (`luarocks install luasocket`), depois execute `lua server/main.lua` a partir da raiz. Ele responde a `/revival/ping`, `/revival/page/lab`, `/revival/page/submit` e `/revival/submit/echo` e aceita apenas conexões em `127.0.0.1:5190` por padrão. Para receber conexões de um telefone na mesma rede, execute `lua server/main.lua 0.0.0.0 5190`, configure um IPv4 privado do computador no cliente (endereços públicos são rejeitados) e permita a porta no firewall **somente na rede confiável**. O teste de rede não implementa autenticação.

**Recursos gráficos originais opcionais:** com o JAR de referência em mãos, execute `python tools/import_jar_assets.py qeep-94724.jar` na raiz. Ele valida os hashes antes de extrair os três PNGs para `client/assets/original/` (ignorados no Git). O logotipo passa a aparecer na tela inicial de laboratório. Para mais informações, veja `docs/navegacao-e-assets-fase5.md`.

**Android:** a base cliente está escrita para LÖVE Android, mas **ainda não há APK compilado nem testes em dispositivo**. Será preciso embalar `client/` com a distribuição LÖVE Android compatível e verificar LuaSocket no pacote final.

**Testes independentes:** execute os testes `tests/test_protocol.lua`, `test_jcl.lua`, `test_jcl_layout.lua`, `test_jcl_styles.lua`, `test_client_smoke.lua`, `test_submit.lua`, `test_lab_host.lua` , `test_lab_client.lua`, `test_jcl_history.lua`, `test_client_history.lua`, `test_original_logo.lua`, `test_jcl_choices.lua` e `test_client_choices.lua` com `lua` (ou `texlua`) na raiz. Os testes de interface simulados não exercitam GPU real. Com o servidor executando e LuaSocket instalado, execute também `lua tests/test_socket_roundtrip.lua` para o teste TCP real.

## Evidências e limites

A análise inicial foi feita sobre `qeep-94724.jar`, Java ME 1.29, e `qeep_client_ui.zip`, fornecidos para estudo. O JAR usa um motor de UI dinâmica; não inclui todas as telas enviadas pelo servidor. Consulte `docs/engenharia-reversa.md`.

**Não conectar aos domínios originais.** Nenhuma conta, senha ou dado pessoal é enviado ao serviço antigo. Apenas implementações originais deste repositório recebem licença MIT; arquivos e marcas de terceiros não recebem licença por associação.

## Organização

```text
client/                   Aplicativo LÖVE (Android / Windows)
client/lib/protocol.lua   Codec offline e loopback experimental
client/lib/jcl.lua        Interpretador parcial de JCL
client/lib/jcl_view.lua   Estado e navegação dos formulários JCL
client/lib/jcl_layout.lua Layout e hit-testing, sem dependência de GPU
client/lib/jcl_style.lua  Resolver de estilos do registry.ini (sem código remoto)
client/lib/utf8_edit.lua  Edição de caracteres Unicode em LuaJIT
client/lib/jcl_choices.lua Tipos e serialização de seleções JCL
client/lib/jcl_history.lua Histórico de formulários/documentos com rolagem/foco
client/lib/jcl_submit.lua Coleta segura de valores do formulário do laboratório
client/lib/lab_host.lua  Validação de host local/rede privada
client/lib/legacy_palette.lua Cores verificadas em registry.ini
client/fixtures/         Telas sintéticas exclusivamente de teste
server/                   Servidor Lua de diagnóstico
tests/                    Testes do codec
tools/import_jar_assets.py Importação local verificada dos três PNGs históricos
docs/                     Documentação e evidências (fases 1–6)
```

## Próximos marcos

1. **Em andamento:** validar o renderizador JCL com capturas reais do JAR em emulador e mapear o restante do estilo/foco de `j`, `aa`, `ac`. O subconjunto de `h` incluído na fase 3 ainda não comprova a aparência histórica.
2. Substituir as telas sintéticas por telas reproduzidas a partir de referências verificáveis.
3. Evoluir do laboratório de formulários sintéticos (Fase 4) para fluxos comprovados no JAR; construir serviços reais somente após mapear o funcionamento de cada recurso.
4. Empacotar e testar versões Windows e Android, preservando a mesma base Lua.


### Fase 7 — atlas e imagens locais

O cliente pode desenhar recortes reais do atlas `kui/symbols.png` (12×180, células 12×6 usadas em `j.class`) e imagens locais por `<img src>` para os três PNGs conhecidos do JAR. Os originais continuam ignorados pelo Git; importe-os com `python3 tools/import_jar_assets.py <caminho-do-JAR>`. As posições atuais são experimentais: consulte [`docs/simbolos-e-imagens-fase7.md`](docs/simbolos-e-imagens-fase7.md).

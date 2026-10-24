# Qeep Revival 2008

Reconstrução **independente** e orientada por evidências do cliente clássico Qeep para **Android e Windows**, com **Lua + LÖVE (Love2D)** e servidor próprio em Lua. Projeto de preservação e estudo; não é afiliado ao serviço original.

## Estado atual: fase 3 — atributos e paleta do JCL (protótipo)

- Cliente LÖVE inicial com controles por teclado, mouse e toque, renderização lógica em **240 × 320**, paleta extraída de `registry.ini` e tela **explicitamente provisória**.
- Servidor Lua de diagnóstico na porta **5190**, apenas para teste em rede local.
- Codec de mensagens sintéticas deduzido do bytecode do cliente Java ME e testes sem rede.
- Interpretador local de subconjunto JCL identificado no bytecode: formulários, textos, links, botões, campos, seleção e teclas de ação, com uma **página de demonstração sintética** (offline ou enviada pelo servidor de laboratório).
- Renderização em lista com alturas dinâmicas, quebra de linhas e rolagem limitada ao conteúdo, mantendo o foco visível por teclado e gestos de toque. Edição de texto UTF-8 preserva caracteres acentuados e emoji.
- Paleta e tabela de estilos transcritas de `registry.ini` (somente informação técnica, sem copiar recursos protegidos). O cliente interpreta `style="11"`/`style="s11"` quando o identificador consta dessa tabela. A **interpretação de preenchimento e contorno é experimental**, não uma tela original recuperada.
- O parser preserva texto misto na ordem original; links e listas sem rótulo recebem marcadores `>` e `*`; separadores respeitam `w` (90 por padrão), conforme o bytecode `h.class`. Uma quarta tela de laboratório demonstra esses detalhes.
- Não existem ainda login, contas, chat, contatos, jogos ou telas históricas reconstruídos. A interface de demonstração **não deve ser confundida com uma tela original do Qeep**.

## Executar

**Cliente Windows / desktop:** instale [LÖVE 11.x](https://love2d.org/), abra a pasta `client` com LÖVE ou, no terminal, use `love client` a partir da raiz do repositório.

**Servidor de testes:** instale Lua e LuaSocket (`luarocks install luasocket`), depois execute `lua server/main.lua` a partir da raiz. Ele responde a `/revival/ping` e `/revival/page/lab` e aceita apenas conexões em `127.0.0.1:5190` por padrão. Para receber conexões de um telefone na mesma rede, execute `lua server/main.lua 0.0.0.0 5190`, configure o IP privado do computador no cliente e permita a porta no firewall **somente na rede confiável**. O teste de rede não implementa autenticação.

**Android:** a base cliente está escrita para LÖVE Android, mas **ainda não há APK compilado nem testes em dispositivo**. Será preciso embalar `client/` com a distribuição LÖVE Android compatível e verificar LuaSocket no pacote final.

**Testes independentes:** execute `lua tests/test_protocol.lua`, `lua tests/test_jcl.lua`, `lua tests/test_jcl_layout.lua`, `lua tests/test_jcl_styles.lua` e `lua tests/test_client_smoke.lua` (ou `texlua`; na raiz). O último usa um LÖVE simulado, não testa a GPU.

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
client/lib/legacy_palette.lua Cores verificadas em registry.ini
client/fixtures/         Telas sintéticas exclusivamente de teste
server/                   Servidor Lua de diagnóstico
tests/                    Testes do codec
docs/                     Documentação e evidências (`jcl-fase1.md`, `renderizacao-fase2.md`, `estilos-fase3.md`)
```

## Próximos marcos

1. **Em andamento:** validar o renderizador JCL com capturas reais do JAR em emulador e mapear o restante do estilo/foco de `j`, `aa`, `ac`. O subconjunto de `h` incluído na fase 3 ainda não comprova a aparência histórica.
2. Substituir as telas sintéticas por telas reproduzidas a partir de referências verificáveis.
3. Construir um servidor compatível e testar o protocolo usando capturas sintéticas ou históricas autorizadas.
4. Empacotar e testar versões Windows e Android, preservando a mesma base Lua.

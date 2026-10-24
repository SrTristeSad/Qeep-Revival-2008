# Qeep Revival 2008

Reconstrução **independente** e orientada por evidências do cliente clássico Qeep para **Android e Windows**, com **Lua + LÖVE (Love2D)** e servidor próprio em Lua. Projeto de preservação e estudo; não é afiliado ao serviço original.

## Estado atual: fase 0 — infraestrutura executável

- Cliente LÖVE inicial com controles por teclado, mouse e toque, renderização lógica em **240 × 320**, paleta extraída de `registry.ini` e tela **explicitamente provisória**.
- Servidor Lua de diagnóstico na porta **5190**, apenas para teste em rede local.
- Codec de mensagens sintéticas deduzido do bytecode do cliente Java ME e testes sem rede.
- Não existem ainda login, contas, chat, contatos, jogos ou telas históricas reconstruídos. A interface atual **não deve ser confundida com uma tela original do Qeep**.

## Executar

**Cliente Windows / desktop:** instale [LÖVE 11.x](https://love2d.org/), abra a pasta `client` com LÖVE ou, no terminal, use `love client` a partir da raiz do repositório.

**Servidor de testes:** instale Lua e LuaSocket (`luarocks install luasocket`), depois execute `lua server/main.lua` a partir da raiz. Ele aceita apenas conexões em `127.0.0.1:5190` por padrão. Para receber conexões de um telefone na mesma rede, execute `lua server/main.lua 0.0.0.0 5190`, configure o IP privado do computador no cliente e permita a porta no firewall **somente na rede confiável**. O teste de rede não implementa autenticação.

**Android:** a base cliente está escrita para LÖVE Android, mas **ainda não há APK compilado nem testes em dispositivo**. Será preciso embalar `client/` com a distribuição LÖVE Android compatível e verificar LuaSocket no pacote final.

**Testes independentes:** `lua tests/test_protocol.lua` ou `texlua tests/test_protocol.lua` (executando na raiz).

## Evidências e limites

A análise inicial foi feita sobre `qeep-94724.jar`, Java ME 1.29, e `qeep_client_ui.zip`, fornecidos para estudo. O JAR usa um motor de UI dinâmica; não inclui todas as telas enviadas pelo servidor. Consulte `docs/engenharia-reversa.md`.

**Não conectar aos domínios originais.** Nenhuma conta, senha ou dado pessoal é enviado ao serviço antigo. Apenas implementações originais deste repositório recebem licença MIT; arquivos e marcas de terceiros não recebem licença por associação.

## Organização

```text
client/                   Aplicativo LÖVE (Android / Windows)
client/lib/protocol.lua   Codec offline e loopback experimental
server/                   Servidor Lua de diagnóstico
tests/                    Testes do codec
docs/                     Documentação e evidências
```

## Próximos marcos

1. Mapear gramática e renderização do motor JCL (`h`, `j`, `aa`) e coletar imagens reais em emulador.
2. Substituir o menu provisório por telas reproduzidas a partir de referências verificáveis.
3. Construir um servidor compatível e testar o protocolo usando capturas sintéticas ou históricas autorizadas.
4. Empacotar e testar versões Windows e Android, preservando a mesma base Lua.

# Fase 28 — Android conectado ao servidor Lua isolado

A execução 40253532329 confirmou sete testes de toque no Android 34, inclusive formulário JCL secundário e retorno à tela anterior.

O novo teste inicia o servidor real com `QEEP_ROUTE_TRACE=android-server-routes.log lua5.4 server/main.lua 127.0.0.1 5190`, usa `adb reverse tcp:5190 tcp:5190` e tenta configurar o próprio APK pela tela de IP/porta. A rotina testa ping e entrada na área social por toque.

A confirmação de rede depende de dois caminhos recebidos pelo servidor: `/revival/ping` e `/revival/social/start`. O log opt-in contém apenas **nomes de rotas**, jamais credenciais ou conteúdo de mensagens. A instrumentação só funciona quando o servidor está escutando no endereço loopback.

Capturas, logcat e relatórios ficam arquivados no workflow. O teste ainda não realiza registro, login, amizade ou envio de mensagens entre contas; não prova interoperabilidade histórica 1:1. Até o novo workflow terminar, esta integração é pendente de validação.
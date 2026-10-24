# Fase 11 — chat assíncrono e servidor cooperativo

**Escopo:** somente o laboratório social **sintético** do Qeep Revival 2008. Nenhuma destas rotas representa protocolo ou interface histórica confirmada do serviço Qeep.

## Cliente

- `client/lib/social_send.lua`: envio `P` da rota `/revival/social/send/<peer>` por LuaSocket não bloqueante. Faz progresso durante `love.update`, aceita escrita/resposta fragmentada e limita tempo (7s) e tamanho da resposta (1 MiB).
- A interface mostra *Enviando mensagem...* enquanto aguarda confirmação, bloqueia envio duplicado e operações que mudariam a conversa enquanto a mensagem está pendente.
- Uma resposta válida e positiva abre a nova página JCL; até lá, o rascunho não é descartado. Erros e timeouts preservam o texto.
- **Não há repetição automática** após erro: uma perda da confirmação não comprova que a mensagem falhou no servidor. Um reenvio manual pode causar duplicação, pois ainda não implementamos chaves de idempotência persistentes.
- A consulta de novas mensagens por revisão continua ativa quando não há envio pendente. Ao enviar, uma consulta em andamento é cancelada.

## Servidor

- `server/lib/tcp_loop.lua` separa a máquina de estados do servidor: aceita novas conexões, recebe tamanho + frame, despacha uma requisição e envia a resposta em partes, em `socket.select`, sem `settimeout` bloqueante em clientes.
- Até **64** conexões TCP em andamento (não é limite de contas ou capacidade de produção). Acesso por `127.0.0.1` inicialmente; opcionalmente IP da LAN confiável.
- O loop descarta frames malformados, exige máximo de 1 MiB de corpo, encerra clientes sem progresso por 8s e lida com escrita e leitura parciais.
- **Não** possui TLS, autenticação segura, bancos de dados, proteção contra abusos distribuídos, garantias de entrega ou desempenho dimensionado para produção. Não publicar na internet.

## Verificações

- `tests/test_social_send.lua`: envio fragmentado, confirmação, timeout e ausência de reenvio automático.
- `tests/test_tcp_loop.lua`: dois clientes concorrentes, um cliente lento, limite de conexão, desconexão por inatividade e frame inválido.
- `tests/test_client_social.lua` e `tests/test_client_poll.lua`: callbacks simulados adaptados à resposta assíncrona, inclusive preservação do rascunho e retorno.
- `tests/test_socket_concurrent.lua`: teste TCP **real** no GitHub Actions; um cliente envia só dois bytes e o segundo deve receber uma resposta completa antes que o primeiro termine o frame.

Os testes de interface simulam eventos do LÖVE e não substituem execução gráfica real, build do APK ou EXE no Windows.

# Fase 10 — atualização automática do chat de laboratório

Esta funcionalidade é **nova**, criada para testar a reconstrução Lua. Não se trata de um recurso histórico comprovado do Qeep 2008.

## Comportamento

- Enquanto uma página de chat estiver aberta, o cliente verifica a conversa a cada **3 segundos** pela rota sintética `/revival/social/poll/<id>`.
- O pedido `O` inclui a sessão do visitante e a revisão `since` obtida na página JCL atual (`chatRevision`).
- Se não surgiram mensagens, a resposta contém `unchanged=true` e payload vazio: nenhuma tela é recriada.
- Quando há mensagens novas, o servidor retorna JCL com a nova revisão. O cliente atualiza **sem alterar o histórico Voltar**, preservando rascunho, foco e rolagem.
- Se a pessoa estiver editando, a atualização visual espera a interação terminar. O rascunho permanece intacto.
- Consultas automáticas usam **LuaSocket não bloqueante** em `love.update`, com limite de tamanho e timeout de 5 segundos.
- Falhas não fecham a conversa; o cliente tenta novamente. A consulta manual continua disponível.
- A revisão é um número de sequência em memória, não um ID persistente de mensagem. Ela zera ao reiniciar o servidor.

## Limitações

- Não há push ou WebSocket; a latência normal pode chegar a aproximadamente 3 segundos, sem garantia de entrega em tempo real ou persistência.
- O envio manual ainda usa TCP síncrono da Fase 9. Esta fase torna **apenas o recebimento automático** não bloqueante.
- O servidor continua serial, de diagnóstico e limitado a 24 visitantes, sem contas seguras nem criptografia. **Não o exponha à internet.**
- Depende de LuaSocket no cliente LÖVE. O APK Android ainda não foi compilado nem testado em dispositivo.

## Testes

- `tests/test_social_poll.lua`: rotas, revisões, respostas fragmentadas, timeout e cancelamento.
- `tests/test_client_poll.lua`: cliente simulado com dois visitantes, atualização automática, rascunho preservado e histórico.
- Os testes anteriores continuam no GitHub Actions, incluindo o teste TCP localhost.

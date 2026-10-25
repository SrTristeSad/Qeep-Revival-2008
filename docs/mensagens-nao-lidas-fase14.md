# Fase 14 — Conversas e mensagens não lidas (Revival experimental)

O servidor Lua passa a manter, por conta e contato, um **cursor de leitura persistente**.
A lista de contatos prioriza as conversas com atividade mais recente e exibe o número de mensagens recebidas ainda não lidas. A página inicial também mostra o total.

## Semântica

- Apenas mensagens **recebidas** após o último cursor de leitura contam como não lidas. Respostas enviadas não limpam o contador.
- Abrir uma conversa autenticada marca as mensagens recebidas que estão no armazenamento como lidas. Atualizar por polling uma conversa aberta faz o mesmo. Não há confirmações de leitura mostradas ao remetente.
- Os cursores são por **par de conta e contato**, persistem após reiniciar o servidor e não são manipuláveis através de parâmetros fornecidos pelo cliente.
- Contatos são listados da conversa mais recente para a menos recente; em caso de empate, por nome. A página de contatos oferece **Atualizar** para reconsultar a lista.
- O limite anterior de 1.500 mensagens armazenadas permanece. Como mensagens antigas podem sair dessa janela, o contador representa mensagens **ainda armazenadas** e não lidas, não um número histórico absoluto.

## Compatibilidade do banco

O arquivo `server/data/social.db` agora é gravado no formato `QEEP_REVIVAL_SOCIAL_2`. Um arquivo válido no formato `_1` é carregado sem remover contatos ou mensagens, e migra para `_2` na próxima gravação. Na migração, mensagens recebidas ainda presentes são consideradas não lidas até que a conversa seja aberta, pois a versão antiga não registrava leituras.

O servidor mantém a gravação por arquivo temporário + renomeação. Os bancos são privados e continuam fora do Git. Não há criptografia em disco nem TLS; uso recomendado apenas em ambiente local de teste.

**Importante:** estas funcionalidades pertencem ao backend experimental do Revival, não foram demonstradas como comportamento exato do serviço Qeep de 2008.

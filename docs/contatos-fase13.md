# Fase 13 — Contatos e mensagens persistentes (laboratório)

Esta é uma funcionalidade **inventada para o servidor independente do Qeep Revival**. Não é prova de que o Qeep 2008 tivesse exatamente esses fluxos ou essas telas.

## Funcionamento

1. Cadastre duas contas locais na interface social e guarde os códigos de acesso.
2. Uma conta abre **Meus contatos e mensagens salvas**, informa o nome da outra conta e envia a solicitação.
3. A outra conta entra em **Contatos**, aceita ou recusa a solicitação.
4. Depois do aceite, as contas podem conversar mesmo que o outro usuário esteja offline. O histórico é salvo em `server/data/social.db`.
5. Após reiniciar o servidor, basta entrar novamente com o código de acesso para reencontrar contatos e mensagens. As sessões anteriores expiram no reinício; o login não é permanente.

As páginas continuam sendo JCL sintético, renderizado pelo cliente Lua. O cliente utiliza os mesmos mecanismos de envio não bloqueante e atualização a cada três segundos da conversa da Fase 11, agora também para nomes de contas. O modo visitante e o chat temporário entre visitantes continuam disponíveis separadamente.

## Persistência e limites

- `server/data/accounts.db` é o armazenamento de cadastro da Fase 12; `server/data/social.db` mantém convites, contatos aprovados e mensagens. Ambos ficam fora do Git.
- O arquivo social tem versão explícita, registros validados, escrita em arquivo temporário e substituição por renomeação. Falhas de gravação não confirmam a operação e um arquivo corrompido não é zerado silenciosamente.
- Até 100 contatos por conta, 100 solicitações por conta e 1.500 mensagens retidas **no total do servidor**. As conversas exibem as 12 mensagens retidas mais recentes por par de contas. Mensagens mais antigas podem ser eliminadas quando a capacidade global é alcançada.
- Mensagens limitadas a 240 caracteres Unicode válidos e 960 bytes UTF-8. Dados são escapados antes de gerar XML.
- Somente uma instância do servidor deve operar os arquivos. Não existe controle de acesso concorrente entre múltiplos processos, banco SQL, replicação ou migração automática.

## Segurança

**Não publique essa implementação na Internet.** O transporte TCP é sem TLS, o código de acesso da Fase 12 atravessa a rede em texto claro no login, e as mensagens persistidas **não têm criptografia em repouso**. Teste exclusivamente em `127.0.0.1` ou rede privada confiável, com contas e textos fictícios. Não compartilhe dados pessoais.

Contatos requerem aprovação explícita e mensagens privadas só são entregues quando há vínculo aprovado. Ainda não há exclusão de conta, exclusão de mensagens, bloqueio, recuperação de código, ferramentas administrativas, política de retenção configurável nem persistência das sessões.

## Como validar

No Linux, com Lua 5.4 e LuaSocket instalados, execute `lua5.4 server/main.lua` na raiz do repositório e abra duas instâncias do cliente com LÖVE 11.x. Teste o convite, o aceite, o envio e o reinício do servidor. Também existem testes isolados de armazenamento, autorização, conversas e navegação no cliente.

Este passo não substitui a pesquisa visual do JAR original nem produz um APK Android ou EXE independente.

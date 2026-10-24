# Fase 9 — laboratório social em rede local

Esta é uma **implementação nova**, e **não** uma recuperação das telas ou serviços originais do Qeep 2008. Ela valida de ponta a ponta os componentes JCL, a navegação e a troca de mensagens usando o servidor Lua do projeto.

## Como experimentar

1. Inicie `lua server/main.lua` na raiz do projeto (LuaSocket necessário).
2. Execute dois clientes LÖVE a partir de `client/`. Em uma mesma máquina, cada processo usa uma sessão em memória própria.
3. Entre em **Social local (prototipo)**, escolha apelidos diferentes, visite **Pessoas conectadas**, selecione alguém e envie uma mensagem.
4. Atualize a conversa pelo link **Atualizar conversa**. As mensagens não chegam por push: o destinatário precisa atualizar a página.

Para testar em Android e Windows na mesma LAN, ligue o servidor a `0.0.0.0` **somente na rede confiável**, use o IPv4 privado do servidor na configuração do cliente e bloqueie acesso pela internet no firewall. Um servidor iniciado em `127.0.0.1` aceita apenas conexões locais.

## Rotas sintéticas

| Verbo | Caminho | Função |
| --- | --- | --- |
| O | `/revival/social/start` | Entrada de visitantes |
| P | `/revival/social/join` | Criação de sessão temporária com apelido |
| O | `/revival/social/home` | Início de uma sessão |
| O | `/revival/social/people` | Lista de visitantes ativos |
| O | `/revival/social/chat/<id>` | Histórico temporário de conversa |
| P | `/revival/social/send/<id>` | Envio temporário de mensagem |

O servidor mantém no máximo 24 visitantes simultâneos, até 160 mensagens em memória e apresenta as últimas 12 mensagens de cada conversa. Sessões ficam inativas depois de uma hora. Não há contas permanentes, senhas, convites, contatos persistentes ou sincronização instantânea. Tudo se perde ao reiniciar o servidor.

## Limites de segurança

- **Não é um sistema de autenticação seguro**, nem é destinado à internet pública: o identificador da sessão é um token de demonstração transmitido em texto claro por TCP, sem TLS.
- Não envie senhas, dados pessoais reais ou conteúdos privados nesse laboratório.
- O servidor valida caminho, tipo de requisição, campos esperados, comprimento, UTF-8 e caracteres de controle, e converte `&`, `<`, `>`, aspas e apóstrofos ao produzir JCL.
- Quando há `/dev/urandom`, tokens usam bytes do sistema operacional. A implementação alternativa para Windows não é criptograficamente segura. Isso **não substitui** autenticação, TLS, controle de acesso e armazenamento de uma rede social de verdade.
- A reconstrução histórica do Qeep 2008 permanece um trabalho separado e não pode ser inferida dessas telas.

## Testes

- `tests/test_social_routes.lua`: fluxo com dois visitantes, isolamento, escape de XML, rotas inválidas e limites.
- `tests/test_client_social.lua`: simulação de teclado/renderização LÖVE e requisições via socket simulado.
- `tests/test_socket_social.lua`: dois visitantes e entrega de mensagem por um servidor TCP real (requer LuaSocket).

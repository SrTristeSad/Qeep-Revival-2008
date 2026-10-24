# Fase 12 — Contas persistentes locais (protótipo)

Esta é uma **implementação nova** e independente; não é o sistema de autenticação do Qeep de 2008.

## Fluxo

No cliente LÖVE, abra **Social local (protótipo)**. O menu agora oferece **Criar conta local**, **Entrar com código de acesso** e **Entrar como visitante**. O usuário criado deve ter de 3 a 24 caracteres em minúsculas (`a-z`, `0-9`, `_`), começando por letra. O servidor emite um código de **192 bits** representado por 48 caracteres hexadecimais, mostrado **somente após o cadastro**. É a credencial para logins posteriores e deve ser copiada e guardada pelo usuário. Não existe recuperação de códigos nesta fase.

O servidor grava `server/data/accounts.db`. Somente nome do usuário, salt aleatório e SHA-256 do código de acesso são persistidos; nunca o código em texto claro. Para contas, cadastro/login e geração de sessões falham caso `/dev/urandom` não esteja disponível. O banco é escrito por arquivo temporário e renomeado após conclusão.

**Não é um sistema de senhas:** a propriedade de segurança decorre da entropia do código gerado aleatoriamente. Não use esse digest simples para senhas escolhidas por pessoas; essas exigem Argon2id ou equivalente, salt e limites de tentativa. Nenhuma conta real deve depender do laboratório.

## Limitações de segurança

- O protocolo TCP do laboratório **não usa TLS**. Os códigos de acesso passam pela rede em texto claro. Use estritamente **localhost ou rede privada de testes confiável**; nunca publique a porta 5190 na Internet.
- O banco não tem criptografia em repouso, mecanismo de recuperação, proteção contra várias instâncias gravando ao mesmo tempo, perfis completos ou autorização de produção.
- Linux/POSIX com `/dev/urandom` é necessário para a geração segura atual de códigos. O cliente continua multiplataforma (Android/Windows), mas esta implementação do **servidor** não está pronta para Windows nativo.
- A conta sobrevive ao reinício do servidor. **Sessões, visitantes, lista de pessoas online e mensagens não sobrevivem.**
- Mantenha o `server/data/accounts.db` fora do GitHub. O `.gitignore` protege esse arquivo. Para reiniciar as contas do laboratório, com o servidor **desligado**, remova o banco com cuidado; isso elimina todas as contas de teste.

## Testes

- `lua5.4 tests/test_account_store.lua`: vetores SHA-256, formato e privacidade do arquivo, persistência após reabertura e rejeição de base corrompida.
- `lua5.4 tests/test_social_accounts.lua`: cadastro, login, logout, restrições de campos, sessão de conta e convivência com visitantes.
- `lua5.4 tests/test_socket_accounts.lua`: integração real pela porta TCP de laboratório, com o servidor iniciado.

## Próximos passos

O login definitivo precisará de TLS, armazenamento confiável (como SQLite/PostgreSQL), política de autenticação adequada, recuperação de acesso, proteção contra abuso e migração do laboratório de visitantes. A aparência das telas ainda é provisória, não historicamente verificada.

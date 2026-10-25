# Dados locais de laboratório

Esta pasta é utilizada somente pelo servidor experimental. `accounts.db` guarda os nomes de usuário, salts e hashes dos códigos aleatórios de acesso. Não publique nem faça commit desse arquivo. Mensagens de chat não são armazenadas aqui.

Não compartilhe o banco ou os códigos de acesso com outras pessoas. Não exponha o servidor na Internet: o protocolo de laboratório não usa TLS.

Fase 13: `social.db` armazena convites, contatos confirmados e histórico de chat para contas locais. É armazenado em texto simples no disco e deve permanecer privado. O Git ignora `*.db`/`*.db.tmp`. Uma única instância do servidor deve usar o arquivo; faça backup com o servidor parado.

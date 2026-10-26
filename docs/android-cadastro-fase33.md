# Fase 33 — cadastro no Android com evidência sem segredos

O teste da Fase 32 (workflow 40331591906) passou com `/revival/ping`, `/revival/social/start` e `/revival/social/join` recebidos pelo servidor Lua.

Neste teste o emulador Android reinicia o cliente, abre a seção Social, acessa `Criar conta local`, toca no campo de usuário, digita `f33androidlab` e confirma pelo botão. O servidor de teste em **127.0.0.1** registra `/revival/social/register/submit:ok` somente quando sua rota devolve `ok=true`.

**Privacidade:** após submeter o cadastro o código de acesso de 48 caracteres aparece na tela; nenhuma captura dessa tela é permitida. O log de rotas não armazena usuários, tokens, códigos ou conteúdo de mensagens.

A validação em emulador desta fase aguarda execução bem-sucedida do CI. Login pelo Android e equivalência visual ao Qeep histórico continuam pendentes.

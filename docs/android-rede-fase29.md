# Fase 29 — servidor de teste Android com ciclo de vida confiável

As execuções de emulador **40257370401** e **40257502151** falharam após a navegação JCL. O erro reproduzível era `argument --server-pid: invalid int value: ''`: o action runner executa linhas de `script` em shells separados. A variável `SERVER_PID=$!` era perdida.

O workflow agora usa um único comando `python3 tools/android_server_smoke.py --start-local-server`. O Python inicia `lua5.4 server/main.lua 127.0.0.1 5190` com `QEEP_ROUTE_TRACE` e supervisiona o subprocesso até o fim da verificação Android. Usa `finally` para encerrar o processo em caso de sucesso, falha ou timeout. O arquivo de rotas é eliminado antes da inicialização, impedindo evidências herdadas de outro teste.

O servidor é restrito a **127.0.0.1**; o emulador acessa via `adb reverse tcp:5190 tcp:5190`. Os relatórios registram rotas, não credenciais nem mensagens. A execução será considerada aprovada somente quando as rotas **/revival/ping** e **/revival/social/start** forem observadas pelo servidor. Cadastro, login e chat ainda não fazem parte deste teste. A correção de automação não prova, por si, funcionamento de rede.

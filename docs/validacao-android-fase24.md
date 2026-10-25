# Fase 24 — Validação de inicialização Android

O APK compilado pela Fase 23 é um pacote, não uma confirmação de inicialização.
O workflow de smoke test executa o APK em Android 34 após a compilação, registra
a saída do comando de abertura, verifica o PID duas vezes, captura PNG do emulador
e preserva logcat e result.json mesmo quando o teste falha.

Uma screenshot válida não comprova que o Qeep foi renderizado corretamente:
inspecione a imagem e os registros. O teste não substitui um celular real nem
comprova fidelidade 1:1 em relação ao aplicativo Java ME original.

Em Android, perder foco cancela consultas automáticas; o campo de texto em edição
restaura o teclado ao retornar ao aplicativo, sem salvar credenciais nos logs.

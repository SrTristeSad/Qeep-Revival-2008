# Fase 35 — cadastro aprovado, revisão de cabeçalho e próximo login Android

## Evidência da Fase 34
GitHub Actions 40356584485 (Android 34): 12 checks aprovados, `/revival/social/register` e `/revival/social/register/submit:ok` confirmados em `android-server-routes.log`. O retorno inclui um código bearer de 48 caracteres; o sistema de testes não capturou a tela de confirmação.

## Cabeçalho JCL
A captura `18-registration-form.png` mostrava o título de cadastro invadindo a linha divisória. O módulo `client/lib/jcl_heading.lua` usa o próprio mecanismo de medida de fontes para manter título e divisor acima do início da região rolável (y=65). Cabeçalhos longos são desenhados em duas linhas (y=26), com separador y=62; até três linhas em fonte menor quando necessário e truncamento por codepoint UTF-8 no limite.

## Próximo marco
Automatizar login na interface Android usando uma conta de teste criada no servidor em loopback, com segredo efêmero recebido diretamente pelo script de testes em memória. Nunca gravar código de acesso em log, relatório ou captura de tela. Login pelo Android ainda não é considerado verificado.

## Tentativa automatizada de login na Fase 35
A nova ferramenta `tools/android_login_smoke.py` cria por TCP (127.0.0.1) uma segunda conta descartável, recebe o código de acesso em memória, reinicia o Android, abre o formulário de login pela interface (eventos DPAD e IME), preenche usuário e código e aciona Entrar. Só conta como sucesso se o servidor registrar `/revival/social/login/submit:ok`. O `server/main.lua` registra somente o nome da rota e seu sucesso/erro, exclusivamente sob `QEEP_ROUTE_TRACE` no loopback.

O código de 48 caracteres não é salvo nem inserido em resultados JSON, capturas ou logs. O sistema interrompe capturas antes da entrada do segredo e redige sequências hexadecimais de 48 caracteres no logcat do teste. Um erro no comando que recebe o segredo é sanitizado, sem exibir a linha de comando.

Os testes Python de segurança e fluxo local validam a automação, mas **o login pelo emulador permanece pendente até terminar GitHub Actions**. O uso de eventos de D-pad neste teste comprova navegação pela interface Android, não usabilidade de todos os toques; essa validação pode ser ampliada depois.

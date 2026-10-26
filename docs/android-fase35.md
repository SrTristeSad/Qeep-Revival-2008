# Fase 35 — cadastro aprovado, revisão de cabeçalho e próximo login Android

## Evidência da Fase 34
GitHub Actions 40356584485 (Android 34): 12 checks aprovados, `/revival/social/register` e `/revival/social/register/submit:ok` confirmados em `android-server-routes.log`. O retorno inclui um código bearer de 48 caracteres; o sistema de testes não capturou a tela de confirmação.

## Cabeçalho JCL
A captura `18-registration-form.png` mostrava o título de cadastro invadindo a linha divisória. O módulo `client/lib/jcl_heading.lua` usa o próprio mecanismo de medida de fontes para manter título e divisor acima do início da região rolável (y=65). Cabeçalhos longos são desenhados em duas linhas (y=26), com separador y=62; até três linhas em fonte menor quando necessário e truncamento por codepoint UTF-8 no limite.

## Próximo marco
Automatizar login na interface Android usando uma conta de teste criada no servidor em loopback, com segredo efêmero recebido diretamente pelo script de testes em memória. Nunca gravar código de acesso em log, relatório ou captura de tela. Login pelo Android ainda não é considerado verificado.

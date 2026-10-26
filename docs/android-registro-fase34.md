# Fase 34 — primeira tela após reinício Android e link de cadastro

## Diagnóstico comprovado

O workflow Android da Fase 33, execução **40342050149**, falhou antes do formulário de cadastro. O arquivo `android-server-results/16-menu-for-registration.png` é inteiramente preto (1080×1920), e a mensagem do relatório foi `ValueError: expected 2 Qeep purple bands, found []`. A entrada de visitante, o ping e o social haviam passado. O problema é o teste capturar o primeiro frame antes da renderização após `am force-stop` + `am start`.

## Correção

1. Repetir a captura de menu até a tela clássica renderizar, em vez de usar tempo fixo de 2 segundos; limitar tentativas e falhar explicitamente caso a interface não apareça.
2. Corrigir o toque no link `Criar conta local (laboratório)`: ele aparece perto de y=274, dentro da área JCL. A coordenada antiga y=281 pertence ao limite inferior (excluído da área clicável).
3. Só avançar para o formulário após o próprio servidor Lua registrar `/revival/social/register`. Não aceitar mera mudança de pixels como confirmação.
4. Preservar o bloqueio de screenshots após o envio do cadastro, pois a resposta mostra o código de acesso de 48 caracteres.

Os testes unitários cobrem quadros pretos, tentativas limitadas, toques dentro de y<281 e comprovação de rota. Essas mudanças não validam login nem envio de mensagens pela interface móvel.

## Referência

Evidências do workflow: https://github.com/SrTristeSad/Qeep-Revival-2008/actions/runs/40342050149

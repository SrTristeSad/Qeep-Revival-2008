# Fase 31 — entrada de visitante no Android

As capturas reais da execução 40261539359 mostram que a tela social abriu, mas a primeira captura do campo de apelido ainda não exibia o teclado. A imagem seguinte mostrava o IME aberto e o campo vazio. O teste tentou inserir o apelido antes de adquirir foco, e reutilizou a geometria antiga ao tocar para enviar.

A automação agora aguarda o teclado abrir, digita o nickname descartável f31guest, encerra a edição, aguarda o IME fechar, recalcula o viewport e toca em Entrar como visitante. Só aprova quando o log do servidor Lua contém a rota exata /revival/social/join. Capturas intermediárias permitem investigar falhas. Três novos testes locais verificam detecção de IME e ausência de digitação prematura.

O encaminhamento usa somente adb reverse em 127.0.0.1:5190. Nenhum servidor histórico Qeep é acessado. A aprovação do teste Android na nova revisão ainda está pendente; teste TCP com duas contas não substitui login pelo aplicativo.

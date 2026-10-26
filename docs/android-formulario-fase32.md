# Fase 32 — Entrada do visitante no Android

A captura real de `40272603749` revelou o erro da fase anterior: toques em `y=175–185` selecionavam um parágrafo. O campo está em `y=208–226`, com bordas oliva (`#A0B419`), e o botão de entrada em `y=234–259`, inicialmente destacado (`#CDFF3C`). O detector compara pixels nas duas bordas do campo na área lógica `240×320`, rejeita ausência/ambiguidade e recalcula a geometria após fechar o teclado.

Teste local: `python3 -m unittest discover -s tests -p test_android_server_smoke.py -v`. Conferência do detector realizada contra captura do emulador Android 34 da Fase 31. Isso não aprova ainda o fluxo ponta a ponta: a requisição exata `/revival/social/join` precisa aparecer no relatório do próximo GitHub Actions. O antigo serviço Qeep não é acessado.

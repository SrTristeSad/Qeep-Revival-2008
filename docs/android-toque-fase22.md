# Fase 22 — Toque e teclado no Android

## O que mudou

- O primeiro dedo ativo controla o gesto; um segundo toque não ativa botões nem altera a rolagem.
- Um toque só ativa a opção quando o movimento fica abaixo do limiar proporcional à escala da tela.
- A rolagem por arrasto somente começa quando o dedo encosta inicialmente na área de conteúdo JCL (entre `TOP=65` e `BOTTOM=281` no canvas lógico). Um arrasto iniciado no rodapé não movimenta a conversa nem dispara softkeys.
- A posição/área do campo de edição é passada para `love.keyboard.setTextInput(true,x,y,w,h)`, para melhorar a integração com o teclado virtual quando o runtime oferece suporte a esse recurso.
- Uma perda de foco cancela o gesto, evitando cliques involuntários ao voltar ao aplicativo.

## Verificação

- `lua5.4 tests/test_mobile_touch.lua`: comportamento do módulo de gestos em pixels de janela.
- `lua5.4 tests/test_client_mobile.lua`: eventos LÖVE simulados, com teclado, toque e gestos.
- A suíte anterior de navegação/JCL continua incluída no GitHub Actions.

## Limites

Testes automatizados **não** são execução em aparelho Android. A versão de depuração foi compilada no GitHub Actions (workflow da Fase 21), mas ainda é necessário testar em um celular real: abertura, teclado virtual, toque, gestos, rotação/orientação, conexão LAN e retorno ao aplicativo após alternar de janela. O conteúdo social é de laboratório, e o servidor não deve ser exposto à Internet. O protocolo original de 2008 e a aparência histórica continuam incompletos.

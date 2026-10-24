# Fase 5 — Histórico de navegação e recursos originais opcionais

## Escopo

O JAR de 2008 continua sendo a fonte primária. **O histórico implementado nesta fase é uma solução funcional experimental, não uma reprodução byte a byte da navegação antiga.** As telas do laboratório permanecem sintéticas.

### Navegação JCL

- Links `#id` só criam entradas no histórico quando o formulário de destino existe e é diferente do atual.
- Links remotos do laboratório e respostas de envio de formulário entram no mesmo histórico, **apenas depois** de um JCL válido ser recebido e interpretado.
- `Esc`, `Backspace` (fora da edição), `0` e `kp0` retornam à tela anterior com formulário, item selecionado e posição da rolagem restaurados. A ação `lsk` sem destino explícito também retorna à tela anterior.
- Teclas numéricas opcionais `2/8/5/4/6` emulam cima/baixo/selecionar/tecla esquerda/tecla direita. Essa correspondência é uma conveniência para simular um telefone Java ME, não uma alegação de correspondência exata com o Qeep 1.29.
- O histórico mantém até 16 snapshots, referenciando o documento em memória para conservar textos digitados. Isso evita copiar o JCL completo em cada navegação.
- Se o servidor do laboratório falhar, a mensagem de erro pode ser descartada e o formulário anterior permanece acessível; não se perde a entrada digitada.

### Imagens do JAR

O arquivo fornecido `qeep-94724.jar` contém `logo.png` (128×42), `icon_15x15.png` (15×15) e `kui/symbols.png` (12×180). Os três recursos foram identificados por **SHA-256 e dimensões verificadas**, sem modificar os PNGs.

O script Python `tools/import_jar_assets.py` importa **apenas** esses recursos de um JAR correspondente à amostra verificada, para `client/assets/original/`, pasta ignorada pelo Git. A importação rejeita versões ou conteúdos desconhecidos e só grava arquivos depois de validar todos os recursos. Exemplo na raiz do repositório:

```bash
python tools/import_jar_assets.py qeep-94724.jar
```

Quando `client/assets/original/logo.png` estiver presente, o cliente desenha o logotipo histórico **na tela inicial de laboratório**. Sem ele, utiliza título textual. Isso não converte a tela inicial em uma tela fiel: a distribuição, os comandos e o resto do design ainda são de teste.

Nenhum PNG histórico é acrescentado ao GitHub. A implantação Windows/Android precisa copiar os assets importados para dentro do pacote do cliente, caso o usuário queira vê-los.

## Testes

- `tests/test_jcl_history.lua` valida capacidade máxima, restauração de seleção/rolagem e limpeza do histórico.
- `tests/test_client_history.lua` simula teclado, navegação entre documentos, envio de formulário e recuperação após erro remoto.
- `tests/test_import_jar_assets.py` verifica que material adulterado não é aceito nem escrito parcialmente.
- Os testes existentes de protocolo, formulário, estilos e round-trip continuam na automação.

## Ainda falta

Validar capturas reais do Qeep 1.29 em um emulador Java ME, decodificar posições e widgets de `j`, `aa` e `ac`, recuperar estrutura e dados históricos fornecidos pelo servidor, implementar serviços sociais e empacotar Windows/Android. Nenhuma compatibilidade 1:1 deve ser anunciada neste estágio.

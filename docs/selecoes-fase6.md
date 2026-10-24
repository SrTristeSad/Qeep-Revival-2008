# Fase 6 — Grupos de seleção JCL

## Evidências do JAR original

O bytecode de `h.class` constrói `s` para `<select>` e `<option>`. Sem atributo `type`, define o tipo pelo número de opções: **1 opção → tipo 2; 2 opções → tipo 1; outros números → tipo 4**. As opções podem carregar `selected="true"` e `value`. O método `s.h()` devolve um único valor para tipos diferentes de 2; para **tipo 2**, concatena os valores marcados, separados por vírgulas. Em `s.b(int)` são tratados códigos distintos para navegação e marcação; `s.a(Graphics,...)` desenha símbolos de escolha extraídos de sprite.

## Implementação própria

- `client/lib/jcl_choices.lua` isola inicialização, tipos, alternância e valores do widget.
- Tipos 1 e 3: opções exclusivas, com marcador de rádio representado em texto; tipo 2: múltiplas opções, com caixa de seleção textual; tipo 4: seletor compacto com escolha cíclica.
- O renderizador distribui espaço individual para as opções expandidas, com foco, rolagem e seleção por teclado/toque.
- `jcl_submit.collect()` gera `val1,val2` para seleções múltiplas, mantendo o comportamento prévio para seleções compactas.
- O servidor de testes usa `type="4"` explicitamente para preservar o fluxo demonstrativo anterior. O novo formulário `#choices` é **sintético**, destinado a verificar as modalidades.

## Limitações

Os controles e o desenho não são uma réplica visual 1:1 de `s.class`, `aa.class` ou dos sprites históricos. Não há simulação de servidor legado. A seleção múltipla de laboratório não introduz persistência nem dados pessoais. Recursos gráficos proprietários continuam fora do repositório.

## Testar

Executar `lua tests/test_jcl_choices.lua` e `lua tests/test_client_choices.lua` no diretório raiz. No cliente LÖVE: **Abrir JCL (offline) → Tipos de seleção (JAR)**. Usar setas e Enter para marcar, seta direita/tecla Voltar para concluir.

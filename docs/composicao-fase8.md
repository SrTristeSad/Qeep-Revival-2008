# Fase 8 — composição de formulários JCL e comandos Java ME

## Evidências confirmadas pelo `qeep-94724.jar`

- `j.class`, construtor `j(String)`: a flag booleana `B` começa como verdadeira.
- `j.class`, rotina de layout/desenho: quando a tela começa no primeiro item e `B` está verdadeira, calcula o espaço não ocupado pelo conteúdo e divide a sobra por dois (`(altura disponível - altura do conteúdo) / 2`) para posicionamento vertical.
- `h.class`, interpretação de `<form valign="top">`: altera `j.B` para falso, desabilitando essa centralização.
- `h.class`, interpretação de `<lsk>` e `<rsk>`: o atributo `cancel` usa `true` como código de comando Java ME **2** (`Command.CANCEL`) e `false` como código **4** (`Command.ITEM`). Na ausência do atributo, `lsk` assume `true` e `rsk` assume `false`.

## Implementação desta fase

- `client/lib/jcl_layout.lua`: `place(layout, altura, valign)` centraliza páginas curtas por padrão e deixa páginas longas alinhadas ao topo, sem mexer no conteúdo ou nas coordenadas de toque fora do viewport. Chamadas repetidas não acumulam deslocamento.
- `client/lib/jcl.lua`: preserva o tipo de ação/cancelamento de softkeys no modelo JCL.
- `client/lib/jcl_screen.lua`: apresenta comandos de rodapé com metadados `label`, `href`, `cancel` e `commandType`; os nomes e a posição física dos dois botões são uma adaptação LÖVE.
- `client/main.lua`: usa os comandos do modelo; uma tecla direita sem `<rsk>` explícito ativa o componente em foco, e uma tecla esquerda sem `<lsk>` volta à tela anterior. Toques nos dois lados do rodapé seguem as mesmas rotas.
- `client/fixtures/composition.xml`: quatro telas **sintéticas** para inspecionar alinhamento padrão, `valign="top"`, rolagem e comandos. O laboratório está disponível no menu principal sem substituir as telas da Fase 7.

## Limitações

Não há prova de que a posição, o desenho ou o mapeamento físico dos softkeys corresponda pixel a pixel ao Qeep de 2008. O comportamento estrutural descrito acima é ancorado no bytecode, mas o layout de referência continua uma simulação de resolução 240×320. O JAR não contém as páginas sociais históricas enviadas remotamente. Não há login ou chat nesta fase.

## Testes

- `tests/test_jcl_screen.lua`: estrutura JCL, comandos (incluindo `cancel` explícito), centralização, topo, listas longas e idempotência do posicionamento.
- `tests/test_client_composition.lua`: eventos simulados do cliente, abertura de telas, posicionamento de conteúdo, interação com comandos e rolagem.
- Suíte anterior preservada, incluindo testes do laboratório TCP na automação do GitHub.

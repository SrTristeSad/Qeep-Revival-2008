# Fase 1 — interpretador parcial de JCL (24/10/2026)

## Evidências diretas do JAR

A classe `h` recebe uma sequência de bytes de página e usa a classe `m` (parser XML) para exigir um nó `jcl`. Atributos inspecionados no topo: `base`, `branding`, `cas`, `timeout`, `followup`, `kampagne`. No nível superior, encontra `form` e `prop` (com `n`, `v`, `t`), além de um caminho para objetos especializados.

No método `h.a(m,j)` verificamos os nós `a`, `p`, `button`, `li`, `img`, `hr`, `select`, `option`, `input`, `textarea`, `gauge`, `lsk`, `rsk`, `calc` e a leitura de atributos como `href`, `label`, `clabel`, `focused`, `flags`, `focus`, `style`, `layout`. O `select` agrega opções com `value` e `selected`; `input` lê `type`, `len`, `value` e `mode`. Foram observados comprimentos padrão de 30 para `input` e 2.000 para `textarea` (quando `len` não foi definido). Isso é **comportamento verificado do interpretador**, não evidência de que todas essas opções apareciam simultaneamente nas telas do serviço antigo.

## Implementado agora

- Leitura offline de XML sem bibliotecas de terceiros, com limites de tamanho, profundidade e número de nós. XML com `DOCTYPE`/entidades externas é recusado deliberadamente.
- Conversão de documentos `jcl` em formulários e controles tipados, decodificando entidades XML e referências numéricas Unicode.
- Navegação por teclado e por toque/mouse entre formulários de demonstração, edição de `input`/`textarea`, mudança de `select`, exibição de `gauge` e comandos simulados `lsk`/`rsk`.
- Cliente em 240×320 lógico, com cores extraídas de `registry.ini` e dimensionamento para janela atual, sem WebView.
- Fixture **sintética** `client/fixtures/lab.xml`, que pode ser aberta sem rede ou buscada por socket local com `/revival/page/lab`.
- Nenhuma conexão a endereço legado; o cliente só faz chamadas ao servidor configurado pelo usuário e apenas para os endpoints de laboratório.

## Lacunas explícitas

A hierarquia e o estilo visual completos do renderer Java ME (`j`, `aa`, widgets `ac`) **não foram reproduzidos 1:1**. Atualmente `layout`, `focus` e `style` são lidos, mas sua semântica visual ainda é parcial. `calc`, imagens remotas e a submissão real de formulários não estão implementados. Tampouco há imagens/capturas ou respostas de servidor histórico para comparar. Recursos originais do JAR e suas marcas não são redistribuídos no repositório.

## Testes

Na raiz do repositório:

```sh
lua tests/test_protocol.lua
lua tests/test_jcl.lua
```

`tests/test_jcl.lua` cobre formulários, textos com entidades, navegação, edição, `select` e rejeição de XML malformado, DTD, duplicação de atributos e limites de profundidade/tamanho. Não substitui teste de renderização Android/Windows nem o teste real de servidor.

## Próxima etapa

Mapear decisões de layout/desenho e ações do `j`/`aa`/`ac` por método de bytecode; coletar frames autênticos em emulador J2ME; implementar semântica de focos e submit condicionada a essa evidência; testar cliente empacotado com LÖVE para Android e Windows.

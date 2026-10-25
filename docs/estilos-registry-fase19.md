# Fase 19 — Inspetor fiel dos estilos codificados no JAR

A execução do Qeep no MicroEmulator continua sem captura validada neste ambiente: `unshare -n -- true` retorna `Operation not permitted`; não se executou o JAR sem isolamento.

Alternativa fundamentada: os onze registros `sN` do arquivo `registry.ini` do JAR fornecido foram extraídos automaticamente e salvos em `docs/registry-tokens-fase19.json` e `client/lib/registry_tokens.lua`. São dados, **não telas originais**.

No LÖVE: **Recursos originais (JAR)**, depois **Tab** (ou setas esquerda/direita) para alternar entre galeria existente e tabela de estilos. A tabela mostra as cores planas codificadas por `32,HEX`, mas não inventa fundo para estilos sem `bg` e **não** converte o gradiente `64,...` do registro `s11` em cor plana. A UI ilustrativa (posições, fontes, bordas) não foi validada contra execução do JAR.

Validação: `python3 tests/test_registry_tokens.py`. Se o JAR original estiver presente localmente: `QEEP_ORIGINAL_JAR=/caminho/qeep-94724.jar python3 tests/test_registry_tokens.py`. Os arquivos originais e dados de usuário permanecem fora do GitHub.

Próxima etapa: obter captura Java ME real em ambiente isolado e comparar estados correspondentes; enquanto isso, priorizar diferenças comprovadas no bytecode.

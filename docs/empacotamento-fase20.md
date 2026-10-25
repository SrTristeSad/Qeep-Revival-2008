# Fase 20 — distribuição do cliente Windows x64

A versão Lua/LÖVE do projeto pode ser empacotada em um `.exe` Windows **sem exigir a instalação de LÖVE**. O servidor Lua é uma aplicação separada e não é incluído neste cliente.

## Geração automática no GitHub

O workflow `.github/workflows/windows-build.yml` é executado em `main`, em pull requests e manualmente. Ele baixa **somente** o pacote oficial `love-11.5-win64.zip` do release 11.5 do projeto LÖVE, verifica rigorosamente o SHA-256 `ba6e56be2685e53c817749c4a5007f51137136fe5a3ab64920508babc2e74369`, executa os testes do empacotador e produz um artefato com:

- `Qeep-Revival-2008-Windows-x64.zip`: `QeepRevival2008.exe`, DLLs e licença do LÖVE, com instruções de execução.
- `Qeep-Revival-2008.love`: cliente LÖVE compatível com o **LÖVE Loader para Android 11.5**. **Não é um APK**; exige o LÖVE Android instalado. Não foi verificada a execução em telefone real.

O empacotador insere a aplicação `.love` no final do `love.exe` oficial e preserva suas DLLs e o `license.txt`, conforme o método de distribuição documentado pelo LÖVE. A aplicação mantém suporte a LuaSocket oferecido pelo próprio runtime LÖVE.

## Empacotamento local

Faça download de `love-11.5-win64.zip` no repositório oficial do LÖVE e rode, na raiz do projeto:

```sh
python3 -m unittest discover -s tests -p 'test_package_windows.py' -v
python3 tools/package_windows.py --runtime-zip love-11.5-win64.zip
```

Arquivos resultantes: `dist/Qeep-Revival-2008-Windows-x64.zip` e `dist/Qeep-Revival-2008.love`.

O runtime deve corresponder à assinatura SHA-256 fixa por padrão. O empacotador recusa SHA incorreto, DLLs essenciais ausentes, caminhos ZIP perigosos, links simbólicos no cliente e ausência de licença. O pacote é reprodutível a partir das mesmas entradas.

## Recursos originais, segurança e limitações

Os recursos `client/assets/original/`, extraídos do JAR proprietário fornecido pelo usuário, são **excluídos por padrão** das distribuições públicas. A flag `--include-original-assets` existe apenas para pacotes **locais e pessoais**, não para publicações no GitHub.

O cliente e seu laboratório social continuam experimentais. A interface ainda não foi validada visualmente contra uma captura real do Qeep Java ME. O servidor não usa TLS e não pode ser disponibilizado publicamente com segurança.

**Estado dos testes:** os testes Python verificam estruturalmente o pacote, mas **não executam a aplicação na interface gráfica do Windows**, nem constroem ou testam APK. Antes de distribuir ao público, testar o `.exe` em Windows x64 real e o arquivo `.love` no LÖVE Android, inclusive conexão a um servidor LAN próprio.

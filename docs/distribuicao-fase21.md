# Fase 21 — Auditoria Windows e APK Android de depuração

Esta etapa não altera os componentes JCL, os dados sociais nem o servidor. Introduz mecanismos de validação e empacotamento, **sem alegar fidelidade visual 1:1 ao Qeep de 2008**.

## Windows x64

`tools/verify_windows_bundle.py` verifica o ZIP público gerado na Fase 20: assinatura PE/AMD64 do `.exe`, DLLs e licença, presença de `main.lua` dentro do jogo fundido e exclusão dos PNGs originais. Execute:

```sh
python3 tools/verify_windows_bundle.py dist/Qeep-Revival-2008-Windows-x64.zip
```

O teste é **estático**. Ele NÃO comprova a abertura da interface em uma sessão Windows real. A verificação foi incluída no workflow `windows-build.yml`.

## Android — APK de teste independente do LÖVE Loader

O código-fonte Android vem do projeto oficial `love2d/love-android`, fixado no commit `55feb38fa144f4734c26742389f279fb07d955c0` (tag **11.5a**). Este commit utiliza Java 17, SDK 34 e NDK `25.2.9519653`. O workflow `android-build.yml` instala as dependências e executa a variante Gradle `assembleEmbedNoRecordDebug`.

`tools/package_android.py` cria `app/src/embed/assets/game.love` no checkout upstream e atualiza as configurações do aplicativo:

- Nome: Qeep Revival 2008
- Identificador: `com.srtristesad.qeeprevival2008`
- Orientação inicial: retrato
- Versão experimental: `0.21.0-test` / código 21
- Permissões: INTERNET, necessária ao laboratório em rede local (sem microfone ou Bluetooth)
- Backup Android desativado, para reduzir a exposição acidental de dados
- Sem imagens originais do Qeep, nem JAR original, nem arquivo `accounts.db` ou `social.db`

Em uma máquina configurada para compilar Android:

```sh
git clone --depth 1 --branch 11.5a --recurse-submodules https://github.com/love2d/love-android.git ./love-android
python3 tools/package_android.py --client client --love-android ./love-android
cd love-android
./gradlew assembleEmbedNoRecordDebug
```

O workflow publica o arquivo **Qeep-Revival-2008-Android-debug.apk** como artefato de build. É um APK de depuração assinado com chave de desenvolvimento, **não um release pronto para a Play Store**. A execução real em um aparelho Android continua necessitando de teste manual; a presença de LuaSocket dentro da distribuição Android deve ser confirmada em dispositivo. O servidor Lua não fica dentro do APK: é necessário executar o servidor em outro dispositivo da mesma rede privada.

**Segurança:** o serviço social utiliza conexões locais sem TLS; não deve ser exposto à Internet ou usado com senhas pessoais. O código de acesso do laboratório não representa um sistema de autenticação pronto para produção.

## O que os testes comprovam

- A estrutura do ZIP Windows e as características do executável são válidas; não testam GPU/janela real.
- O empacotador Android gera um `game.love` reproduzível e livre de recursos proprietários originais.
- A pipeline Android compila um APK de depuração e verifica sua assinatura e presença de código Lua **quando a ação no GitHub termina com sucesso**.
- Sem captura de tela do JAR rodando em emulador; ainda não há equivalência visual histórica comprovada.

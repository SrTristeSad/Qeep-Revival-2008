# Qeep Revival 2008

**Fase 32:** a execução Android 34 da Fase 31 (`40272603749`) abriu o APK e confirmou TCP para `/revival/ping` e `/revival/social/start`, mas o teste tocava em parágrafos em `y=175–185`, não no campo de apelido (`y≈208–226`). Agora o teste identifica as bordas oliva do campo e o botão destacado diretamente na captura real, sem OCR, e exige `/revival/social/join`. A entrada Android permanece pendente de nova execução no CI. Veja `docs/android-formulario-fase32.md`.


**Fase 31:** o teste Android da Fase 30 (run 40261539359) abriu o social e enviou ping/start, mas não entrou como visitante. Capturas mostram que o teclado abriu tarde e a automação utilizou coordenadas desatualizadas. Corrigido o teste para aguardar foco no IME, digitar, dispensar o teclado, recalibrar o viewport e exigir a rota real /revival/social/join no servidor. A execução Android desta correção ainda depende do CI. Veja docs/android-conexao-fase31.md.


**Fase 30:** a comunicação Android ↔ Lua foi comprovada na execução `40259673092` (rotas de ping e abertura social). O novo smoke passa a tocar no campo de apelido e no botão de entrada como visitante, verificando a rota real `/revival/social/join`. A automação também executa testes de cadastro/login de conta e mensagens entre visitantes usando TCP no host, no mesmo servidor local; isso **não** é login pela interface Android. A autenticação completa no celular ainda depende de validação.


**Fase 29:** corrigido o teste de rede Android. O workflow isolava cada linha de shell, tornando `SERVER_PID=$!` inacessível na linha seguinte; a ferramenta agora gerencia o ciclo de vida do servidor Lua na mesma execução Python, eliminando logs antigos antes do teste. A comunicação real permanece pendente até a validação em emulador. Leia [`docs/android-rede-fase29.md`](docs/android-rede-fase29.md).

**Fase 28:** confirmadas sete verificações de navegação no emulador Android 34, incluindo formulário JCL secundário e retorno por toque. Acrescentado teste Android↔servidor Lua real com `adb reverse`, loopback `127.0.0.1:5190` e confirmação no servidor das rotas de ping/social (somente nomes das rotas, sem conteúdo privado). A execução completa desta nova integração depende da próxima rodada Android no GitHub Actions. Leia `docs/android-rede-fase28.md`.

**Fase 27:** a validação da Fase 26 terminou aprovada no Android 34, com quatro capturas reais (menu, Sobre, retorno, JCL) e largura útil de 99,96%. Corrigidas as instruções de teclado ainda visíveis nas páginas JCL Android e a sobreposição do subtítulo em Sobre. O teste seguinte passa a verificar também navegação entre formulários JCL por toque. Veja [`docs/android-usabilidade-fase27.md`](docs/android-usabilidade-fase27.md).

**Fase 26:** validação automatizada de toque concluída no emulador Android 34 (Sobre, voltar, JCL offline). A execução 40244607071 passou e disponibiliza evidências verificáveis. Veja [`docs/android-navegacao-fase26.md`](docs/android-navegacao-fase26.md).

Reconstrução **independente** e orientada por evidências do cliente clássico Qeep para **Android e Windows**, com **Lua + LÖVE (Love2D)** e servidor próprio em Lua. Projeto de preservação e estudo; não é afiliado ao serviço original.

## Estado atual: fase 28 — navegação Android testada no emulador; interface histórica ainda pendente

- **Fase 25:** APK abriu no emulador Android 34 (execução do GitHub Actions 40241042226). Captura real confirmou muita margem vazia e rodapé com atalhos de desktop. Android agora usa ampliação proporcional fracionária para ocupar a largura disponível e botões de rodapé por toque (Abrir/Sair, Salvar/Cancelar); Windows mantém escala inteira. Testes em aparelho físico continuam pendentes. Veja [Fase 25](docs/ajustes-android-fase25.md).

- **Fase 24:** teste de abertura do APK Android em emulador no GitHub Actions, com screenshot, logcat e relatório, mais tratamento de pausa e retomada no Android. Veja [validação Android](docs/validacao-android-fase24.md).

- **Fase 23:** IP/porta privados configuráveis (`192.168.1.50:5190`), configuração persistente por aplicativo, migração de `host.txt`, Android sem `127.0.0.1` como padrão inicial e teclado reposicionado após redimensionamento. A compilação do APK da Fase 22 foi aprovada; **inicialização em dispositivo real ainda não verificada**. Veja [configuração de rede da Fase 23](docs/android-rede-fase23.md).

- **Fase 22:** gestos em tela sensível ao toque com limiar escalonado, rolagem limitada à área JCL e posicionamento do teclado virtual nos campos de entrada; testes de eventos simulados em Lua. A compilação de APK debug da Fase 21 foi concluída no GitHub Actions, mas a execução em aparelho físico continua pendente. Veja [toque Android](docs/android-toque-fase22.md).

- **Fase 20:** workflow automatizado para gerar ZIP com EXE Windows x64 e DLLs do LÖVE 11.5, validando o runtime por SHA-256. O mesmo workflow gera `.love` utilizável no LÖVE Loader Android. A execução gráfica Windows e Android **ainda depende de testes em dispositivo**. Veja [distribuição da Fase 20](docs/empacotamento-fase20.md).

- **Fase 19:** inspetor de 11 estilos `sN` extraídos do `registry.ini` original; mostra somente tokens existentes e não interpreta valores de gradiente como cores planas. No laboratório **Recursos originais (JAR)**, use **Tab** para alternar o painel. Os módulos e testes foram gerados a partir do JAR de referência; a captura autêntica da tela Java ME **continua pendente**. Veja `docs/estilos-registry-fase19.md`.

- **Fase 18:** ferramenta `tools/visual_evidence.py` para revisar capturas reais (hashes, classificação manual e recorte), rejeitar telas só do emulador e comparar pixels com um screenshot do LÖVE. **Nenhuma tela autêntica do Qeep foi obtida neste ambiente**. Ver [`docs/revisao-capturas-fase18.md`](docs/revisao-capturas-fase18.md).

- **Fase 16:** ferramenta de pré-verificação e execução isolada do JAR Java ME, comparação de capturas PNG e captura local do cliente LÖVE via tecla `F12`. **Ainda não foi obtida captura autenticada do emulador**; não existe equivalência visual 1:1 comprovada. Leia [procedimento seguro e reprodutível](docs/fidelidade-capturas-fase16.md).

- **Fase 15:** menu **Recursos originais (JAR)** para comparação de logotipo, ícone, atlas e cores verificadas do JAR 1.29; janela com zoom de pixels inteiros e área de toque ajustada. Não é uma reprodução de tela histórica. [Evidências e limites](docs/fidelidade-visual-fase15.md).

- **Fase 14:** contatos ordenados pela atividade recente e contadores de mensagens não lidas persistidos por usuário/conversa, com leitura registrada ao abrir chat e migração automática do banco social `_1` para `_2`. [Detalhes](docs/mensagens-nao-lidas-fase14.md).

- **Fase 13:** contatos vinculados a contas: convite, aceite/recusa, chat direto com histórico local salvo em `server/data/social.db` e polling de novas mensagens. Visitantes continuam com mensagens temporárias. O contato deve aprovar a solicitação antes que o chat seja liberado. Dados em texto simples no disco; teste somente em máquina/rede privada, sem TLS. Veja [Fase 13](docs/contatos-fase13.md).
- **Fase 12:** contas persistentes locais, entrada por código aleatório de 192 bits, login/logout e visitantes preservados. O servidor grava `server/data/accounts.db` (ignorado pelo Git). Não há TLS nem recuperação de código; somente laboratório privado Linux/POSIX. Veja [documentação da Fase 12](docs/contas-fase12.md).


- Cliente LÖVE inicial com controles por teclado, mouse e toque, renderização lógica em **240 × 320**, paleta extraída de `registry.ini` e tela **explicitamente provisória**.
- Servidor Lua de diagnóstico na porta **5190**, apenas para teste em rede local.
- Codec de mensagens sintéticas deduzido do bytecode do cliente Java ME e testes sem rede.
- Interpretador local de subconjunto JCL identificado no bytecode: formulários, textos, links, botões, campos, seleção e teclas de ação, com uma **página de demonstração sintética** (offline ou enviada pelo servidor de laboratório).
- Renderização em lista com alturas dinâmicas, quebra de linhas e rolagem limitada ao conteúdo, mantendo o foco visível por teclado e gestos de toque. Edição de texto UTF-8 preserva caracteres acentuados e emoji.
- Paleta e tabela de estilos transcritas de `registry.ini` (somente informação técnica, sem copiar recursos protegidos). O cliente interpreta `style="11"`/`style="s11"` quando o identificador consta dessa tabela. A **interpretação de preenchimento e contorno é experimental**, não uma tela original recuperada.
- O parser preserva texto misto na ordem original; links e listas sem rótulo recebem marcadores `>` e `*`; separadores respeitam `w` (90 por padrão), conforme o bytecode `h.class`. Uma quarta tela de laboratório demonstra esses detalhes.
- **Fase 4:** o cliente pode carregar via TCP um formulário **sintético** do servidor de laboratório, preencher `input`/`textarea`/`select`, enviar tipo `P` e abrir a resposta JCL. O servidor não salva dados. Esse tipo de envio foi inspirado na classe original `handler.Submit` e na coleta da classe `n`, mas o endpoint e o conteúdo de resposta são nossos, não históricos.
- **Fase 5:** histórico limitado de navegação preserva formulário, foco e rolagem para voltar com Esc/Backspace/0; erros de comunicação não descartam o documento atual. A tecla numérica 2/8/5/4/6 facilita testes com controle de telefone antigo. Um importador valida os três PNGs do JAR por hash e permite usar o logotipo original localmente, sem publicá-lo no GitHub.
- **Fase 6:** seleção JCL (`select`) distingue os tipos 1 (única), 2 (múltipla), 3 (única) e 4 (compacta). Os padrões por quantidade de opções e a concatenação de valores múltiplos por vírgulas foram verificados nas classes `h` e `s` do JAR. O layout e os controles são uma aproximação própria, não uma captura pixel a pixel do Qeep. Veja `docs/selecoes-fase6.md`.
- **Fase 8:** formulários curtos são centralizados verticalmente por padrão e `valign="top"` os alinha ao topo, como indicado por `j.class` e `h.class`. Comandos `lsk/rsk` preservam `cancel` e o modelo de tecla direita sem comando explícito ativa o foco. O menu contém **Composicao JCL (laboratorio)**, quatro telas sintéticas de comparação. Consulte `docs/composicao-fase8.md`.
- **Fase 9:** laboratório social **novo e temporário**, com apelidos de visitantes, lista de pessoas conectadas e mensagens entre clientes na mesma rede local usando JCL. Não há login real, contatos, histórico permanente ou telas históricas recuperadas. Veja `docs/social-fase9.md`.
- **Fase 11:** o envio de mensagens é não bloqueante e confirma a nova tela somente após resposta válida. Em falhas, o rascunho é mantido e **não há reenvio automático**, pois uma entrega pode ter ocorrido sem confirmação. O servidor de laboratório usa um laço TCP cooperativo para até 64 conexões simultâneas, com limites de tamanho e tempo por cliente. Veja `docs/chat-assincrono-fase11.md`.
- **Fase 10:** conversas de laboratório verificam novas mensagens a cada 3 segundos com LuaSocket não bloqueante. A resposta por revisão evita redesenhar a página sem mudanças. O rascunho, a seleção e o histórico Voltar são preservados; a atualização visual espera o fim da edição. Consulte `docs/atualizacao-social-fase10.md`.
- Contas, contatos e mensagens persistentes estão disponíveis somente no **laboratório local experimental**. Ainda não existem jogos, interface social histórica recuperada nem autenticação adequada para uso público. As demonstrações **não devem ser confundidas com as telas originais do Qeep**.

## Executar

**Cliente Windows / desktop:** baixe o artefato Windows x64 do GitHub Actions na `main` e abra o `.exe` com as DLLs lado a lado (LÖVE não precisa ser instalado). Para desenvolvimento, ainda é possível instalar [LÖVE 11.x](https://love2d.org/) e usar `love client`. Consulte `docs/empacotamento-fase20.md`.

**Servidor de testes:** instale Lua e LuaSocket (`luarocks install luasocket`), depois execute `lua server/main.lua` a partir da raiz. Ele responde ao laboratório de protocolo e às rotas sintéticas `/revival/social/...` (descritas em `docs/social-fase9.md`) e aceita apenas conexões em `127.0.0.1:5190` por padrão. Para receber conexões de um telefone na mesma rede, execute `lua server/main.lua 0.0.0.0 5190`, configure um IPv4 privado do computador no cliente (endereços públicos são rejeitados) e permita a porta no firewall **somente na rede confiável**. O laboratório possui armazenamento persistente para contas e conversas entre contatos, mas **não possui TLS nem autenticação segura para a Internet**. Os dados do chat não são criptografados no disco. Não exponha na internet.

**Referências visuais do JAR:** execute `python3 tools/audit_visual_jar.py qeep-94724.jar` para confirmar a identidade e as cores da build. Após importar os PNGs, abra **Recursos originais (JAR)** no menu. A tela mostra apenas material confirmado pelo arquivo, não uma composição histórica.

**Recursos gráficos originais opcionais:** com o JAR de referência em mãos, execute `python tools/import_jar_assets.py qeep-94724.jar` na raiz. Ele valida os hashes antes de extrair os três PNGs para `client/assets/original/` (ignorados no Git). O logotipo passa a aparecer na tela inicial de laboratório. Para mais informações, veja `docs/navegacao-e-assets-fase5.md`.

**Android:** o workflow `android-build.yml` compila um APK de depuração independente do LÖVE Loader, disponível nos artefatos do GitHub Actions (o primeiro build foi aprovado em 25/10/2026). Para uso inicial, instale manualmente o APK de debug no telefone. **Ainda falta testar a inicialização, o teclado virtual e as conexões LAN em aparelho real.** O servidor não deve ser exposto à Internet.

**Testes independentes:** execute os testes `tests/test_protocol.lua`, `test_jcl.lua`, `test_jcl_layout.lua`, `test_jcl_styles.lua`, `test_client_smoke.lua`, `test_submit.lua`, `test_lab_host.lua` , `test_lab_client.lua`, `test_jcl_history.lua`, `test_client_history.lua`, `test_original_logo.lua`, `test_jcl_choices.lua` e `test_client_choices.lua` com `lua` (ou `texlua`) na raiz. Os testes de interface simulados não exercitam GPU real. Com o servidor executando e LuaSocket instalado, execute também `lua tests/test_socket_roundtrip.lua` para o teste TCP real.

## Evidências e limites

A análise inicial foi feita sobre `qeep-94724.jar`, Java ME 1.29, e `qeep_client_ui.zip`, fornecidos para estudo. O JAR usa um motor de UI dinâmica; não inclui todas as telas enviadas pelo servidor. Consulte `docs/engenharia-reversa.md`.

**Não conectar aos domínios originais.** Nenhuma conta, senha ou dado pessoal é enviado ao serviço antigo. Apenas implementações originais deste repositório recebem licença MIT; arquivos e marcas de terceiros não recebem licença por associação.

## Organização

```text
client/                   Aplicativo LÖVE (Android / Windows)
client/lib/protocol.lua   Codec offline e loopback experimental
client/lib/jcl.lua        Interpretador parcial de JCL
client/lib/jcl_view.lua   Estado e navegação dos formulários JCL
client/lib/jcl_layout.lua Layout e hit-testing, sem dependência de GPU
client/lib/jcl_style.lua  Resolver de estilos do registry.ini (sem código remoto)
client/lib/utf8_edit.lua  Edição de caracteres Unicode em LuaJIT
client/lib/jcl_choices.lua Tipos e serialização de seleções JCL
client/lib/jcl_history.lua Histórico de formulários/documentos com rolagem/foco
client/lib/jcl_screen.lua Comandos Java ME e estado visual de softkeys
client/lib/jcl_submit.lua Coleta segura de valores do formulário do laboratório
client/lib/lab_host.lua  Validação de host local/rede privada
client/lib/social_poll.lua Transporte não bloqueante da consulta social de laboratório
client/lib/social_send.lua Envio de mensagens de demonstração, não bloqueante e sem retry automático
client/lib/legacy_palette.lua Cores verificadas em registry.ini
client/lib/legacy_reference.lua Evidências de comandos, cores e imagens da Fase 15
client/lib/legacy_viewport.lua Escala inteira e transformação de toque
client/fixtures/         Telas sintéticas exclusivamente de teste
server/                   Servidor Lua cooperativo: visitantes temporários e contas persistentes
server/lib/tcp_loop.lua  Atendimento simultâneo e limitado de sockets
server/lib/account_store.lua Cadastro local e códigos de acesso (Fase 12)
server/lib/social_store.lua Contatos e histórico persistente (Fase 13)
tests/                    Testes do codec
tools/import_jar_assets.py Importação local verificada dos três PNGs históricos
tools/audit_visual_jar.py Auditoria reproduzível dos recursos do JAR sem extrair PNGs
docs/                     Documentação e evidências (fases 1–15)
```

## Próximos marcos

1. **Em andamento:** obter capturas reais autenticadas do JAR em emulador (infraestrutura de comparação preparada na Fase 16), depois validar o renderizador JCL e mapear o restante do estilo/foco de `j`, `aa`, `ac`. O subconjunto de `h` incluído na fase 3 ainda não comprova a aparência histórica.
2. Substituir as telas sintéticas por telas reproduzidas a partir de referências verificáveis.
3. Evoluir do laboratório de formulários sintéticos (Fase 4) para fluxos comprovados no JAR; construir serviços reais somente após mapear o funcionamento de cada recurso.
4. Empacotar e testar versões Windows e Android, preservando a mesma base Lua.


### Fase 7 — atlas e imagens locais

O cliente pode desenhar recortes reais do atlas `kui/symbols.png` (12×180, células 12×6 usadas em `j.class`) e imagens locais por `<img src>` para os três PNGs conhecidos do JAR. Os originais continuam ignorados pelo Git; importe-os com `python3 tools/import_jar_assets.py <caminho-do-JAR>`. As posições atuais são experimentais: consulte [`docs/simbolos-e-imagens-fase7.md`](docs/simbolos-e-imagens-fase7.md).

### Fase 8 — composição de telas

`client/fixtures/composition.xml` contém quatro telas sintéticas para testar centralização vertical, `valign="top"`, listas longas e comandos com `cancel`. Abra **Composicao JCL (laboratorio)** no menu inicial. Veja [`docs/composicao-fase8.md`](docs/composicao-fase8.md).

### Fase 9 — protótipo social local

O menu **Social local (prototipo)** inicia um fluxo de páginas JCL geradas pelo servidor Lua, com entrada de visitantes, pessoas online e mensagens temporárias entre instâncias do cliente. Este recurso **não é uma reprodução histórica** nem possui sistema de contas. [Detalhes e limites de segurança](docs/social-fase9.md).

### Fase 10 — atualização social não bloqueante

O chat local pode receber novas mensagens automaticamente enquanto está aberto (consulta a cada 3 segundos). O servidor transmite uma nova página apenas quando houver mudanças; o rascunho não é perdido ao receber respostas. [Documentação e testes](docs/atualizacao-social-fase10.md). O recurso não é uma reconstrução histórica e não está pronto para uso público.

### Fase 11 — envio assíncrono e conexões concorrentes

O envio de mensagens deixou de esperar pela rede dentro do callback de clique. O servidor processa várias conexões sem deixar uma transmissão lenta bloquear as demais. [Detalhes, limites e testes](docs/chat-assincrono-fase11.md). Continua sendo um laboratório LAN sem autenticação real ou persistência.

### Fase 13 — contatos e mensagens persistentes

Usuários cadastrados podem enviar convites, aprovar ou recusar contatos e conversar após aprovação, com mensagens mantidas no servidor local mesmo depois de reiniciá-lo. O modo visitante permanece temporário. Os limites, o arquivo `social.db` e os riscos de privacidade estão descritos em [docs/contatos-fase13.md](docs/contatos-fase13.md).

### Fase 15 — laboratório de fidelidade visual

O menu **Recursos originais (JAR)** reúne cores e imagens verificadas da versão 1.29, sem atribuir à tela sintética a condição de imagem histórica. O canvas de 240×320 prioriza escala inteira para manter pixels nítidos. [Evidências, hashes e limites](docs/fidelidade-visual-fase15.md).

### Fase 16 — capturas e comparações de evidências

`python3 tools/j2me_preflight.py qeep-94724.jar` identifica o JAR sem executar o programa; `--run-isolated` só executa com isolamento Linux de rede comprovado. O cliente LÖVE salva uma captura local com `F12`, e `tools/compare_visual.py` compara capturas explicitamente fornecidas, com máscaras, escalas inteiras e relatório de diferenças. Não foram obtidas telas reais do Qeep no emulador nesta fase. Veja [procedimento e limitações](docs/fidelidade-capturas-fase16.md).

### Fase 17 — captura original em sandbox Linux

`tools/j2me_capture.py` acrescenta execução do JAR em tela virtual isolada, exigindo `unshare -n` e recusando-se a iniciar caso o isolamento falhe. Salva o screenshot com SHA-256 e relatório de proveniência, mas exige revisão manual para reconhecer uma tela histórica. **Ainda não foi possível executar o JAR no ambiente de desenvolvimento atual.** Consulte [o procedimento](docs/captura-autentica-fase17.md).

### Fase 20 — distribuição Windows e Android Loader

O workflow `windows-build.yml` gera um ZIP Windows x64 contendo `.exe` e DLLs do runtime verificado, e um `.love` importável no LÖVE Loader para Android (não é APK). Os pacotes públicos omitem os PNGs históricos e o servidor, que permanece separado. Veja [`docs/empacotamento-fase20.md`](docs/empacotamento-fase20.md).


### Fase 21 — APK Android independente para teste

O workflow `android-build.yml` prepara o código Lua com o upstream oficial LÖVE Android 11.5a e tenta gerar um **APK de depuração embutido**, sem exigir LÖVE Loader no aparelho. O teste do pacote Windows verifica a integridade da distribuição, mas não inicia a interface gráfica no Windows. O APK Android requer validação manual no dispositivo; dados e conexões continuam experimentais e restritos à rede local. Veja [docs/distribuicao-fase21.md](docs/distribuicao-fase21.md).

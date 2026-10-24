# Fase 4 — coleta de formulários e ida/volta ao servidor de laboratório

## Evidência de engenharia reversa

Foi inspecionado o bytecode de `handler.Submit.class` e `n.class` presentes no `qeep-94724.jar` recebido para estudo:

- `handler.Submit.run()` transmite usando `w.a('P', path, hashtable, anexo)`, com o byte 80 (`P`) visível em `javap -c -p handler.Submit`.
- `n.b()` percorre os objetos de campo, recolhendo valores com seus identificadores para um `java.util.Hashtable`, incluindo referências condicionais a indicadores `flags-*`.
- O comando de envio pode acrescentar parâmetros auxiliares como `iasRequestId` e `submitId`. **Os detalhes reais do servidor e dos flags ainda não foram reconstruídos**.

A Fase 4 implementa **somente** uma aproximação de coleta de campos (`input`, `textarea`, `select` + `submitId`) e um envio do tipo `P` no protocolo sintético que já existia no projeto. **Não há compatibilidade de login ou formulários históricos demonstrada.**

## Funcionalidade testável

1. Iniciar `lua server/main.lua` na raiz. Por padrão escuta somente em `127.0.0.1:5190`.
2. Iniciar `love client` e escolher `Abrir JCL (offline)`.
3. Entrar em `Formulário remoto - laboratório` dentro da página sintética, editar campos e usar o botão de envio ou a tecla virtual direita.
4. O cliente requisita `/revival/page/submit` com tipo `O` e envia `/revival/submit/echo` com tipo `P`.
5. O servidor devolve outro documento JCL incluindo os valores escapados. Nada é salvo e o servidor não pede credenciais.

O cliente rejeita links externos e só aceita as rotas de laboratório explícitas. A configuração do servidor no cliente aceita apenas `localhost`, `127.0.0.1` e endereços privados IPv4 RFC1918 (`10/8`, `172.16/12`, `192.168/16`). O servidor pode ser disponibilizado na LAN usando `0.0.0.0` **somente em uma rede confiável**. Não exponha este servidor à internet: não possui autenticação ou TLS.

## Verificação

- `tests/test_submit.lua`: coleta de campos, preservação UTF-8, XML escapado, validação de propriedades, retorno JCL e rejeição de valores indevidos.
- `tests/test_lab_client.lua`: simulação de eventos LÖVE e de respostas TCP (não há renderização GPU real).
- `tests/test_lab_host.lua`: endereços locais aceitos e domínios/IPs públicos rejeitados.
- `tests/test_socket_roundtrip.lua`: cliente/servidor reais via loopback TCP com LuaSocket, validando navegação, envio, retorno e rejeição de uma rota histórica.

Os testes não demonstram comportamento histórico 1:1, desempenho em rede móvel, APK instalado nem visual idêntico ao original.

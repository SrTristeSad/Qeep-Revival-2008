# Fase 23 — configuração de conexão em Android e Windows

O cliente aceita um IPv4 privado e porta, por exemplo 192.168.1.50:5190. Caso omita a porta, o padrão é 5190. Não aceita servidores públicos nem domínios do Qeep antigo.

O endereço é salvo em endpoint.txt no diretório de dados LÖVE. O antigo host.txt é lido quando endpoint.txt não está presente. No Android, o endereço inicial fica vazio para não confundir o celular com o computador. No Windows, localhost é usado inicialmente.

Para testar: descubra o IPv4 privado do computador, por exemplo 192.168.1.50. Inicie o servidor nesse IPv4: lua5.4 server/main.lua 192.168.1.50 5190. PC e celular devem estar na mesma rede Wi-Fi sem isolamento de clientes; no firewall, permita a porta TCP somente na LAN. No aplicativo, configure 192.168.1.50:5190 e use Testar servidor local.

Enter salva uma configuração válida, Escape cancela, tocar no campo reabre o teclado e redimensionar/rotacionar reposiciona o teclado virtual. A rotação foi testada apenas com eventos simulados. Android Fase 22 compilou no GitHub Actions, mas não houve instalação, abertura ou conexão verificadas em dispositivo físico.

Segurança: não encaminhe a porta no roteador. Este é um laboratório privado sem TLS ou banco criptografado, não pronto para Internet pública.

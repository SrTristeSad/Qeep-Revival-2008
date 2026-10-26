# Fase 27 — legibilidade Android e navegação JCL por toque

## Evidência concluída

O workflow Android da Fase 26, execução GitHub Actions **40244607071**, passou. Evidências: `Qeep-Android-emulator-navigation-evidence`, contendo `01-menu.png`, `02-about.png`, `03-menu-return.png`, `04-offline-jcl.png` e `result.json`. O emulador Android 34 usou uma tela 1080×1920, com 99,96% de ocupação horizontal da área lógica de 240×320 (sem esticar a proporção). Esses dados não provam fidelidade visual ao Java ME original.

## Mudanças da Fase 27

- O JCL no Android apresenta ajuda de toque em vez de instruções como Enter/setas. O Windows preserva o teclado.
- O título e subtítulo de Sobre foram reorganizados para que o texto não invada a linha divisória na área lógica y=83.
- O teste no emulador passa a tocar no link local `#fields`, verificar a mudança visual e retornar por softkey esquerdo, salvando mais duas capturas e o relatório.
- A comparação não usa OCR nem simula as imagens: são capturas do `adb screencap`. Os limiares de diferenças de pixels verificam transições, mas não substituem conferência humana de cada tela.

## Validação e limitações

Executar `texlua tests/test_client_mobile_copy.lua` e `python3 -m unittest discover -s tests -p test_android_navigation.py -v` localmente. A validação de instalação, abertura e toques efetivos depende de uma execução completa do workflow Android. Não considerar a nova trajetória de formulários aprovada até essa execução ocorrer. O servidor social não foi modificado.

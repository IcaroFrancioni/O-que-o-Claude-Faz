# Returing para macOS

Esta branch (`returing-para-mac`) é o projeto integrado, pronto para exportar para macOS.
Fluxo do jogo: cutscene da história -> logo -> tutorial -> Fase 1 -> cutscene 2 -> resto -> cutscene final.

## Como gerar o app
1. Godot 4.7.2 com os templates de exportação instalados (veja `EXPORTAR.md`).
2. **Projeto > Exportar > "macOS (PC, universal)"**. Gera `build/macos/Returing.zip` com o `Returing.app`.
   O app é universal: roda em Mac com chip Apple (macOS 11+) e em Mac Intel (macOS 10.12+).
   Dá para exportar no Windows e no Linux; o zip preserva a permissão de execução do app.

## Abrir o app
O app não é assinado nem notarizado pela Apple. Na primeira vez:
1. Descompacte o zip e clique com o **botão direito** no `Returing.app` > Abrir > Abrir.
2. Se o Mac disser que o app está "danificado": `xattr -cr Returing.app` no Terminal.
3. Se ainda não abrir: `codesign --force --deep -s - Returing.app`.

Para distribuir sem esses avisos é preciso assinar e notarizar com uma conta Apple Developer
(`codesign` e `notarization` no preset).

## Controles
Teclado e mouse (sem controles de toque). O modo comando abre com **Ctrl** e a sequência é digitada com as
setas do teclado. O Mac não tem acelerômetro.

# Returing para iOS (iPhone e iPad)

Esta branch (`returing-para-ios`) é o projeto integrado, pronto para exportar para iOS.
Fluxo do jogo: cutscene da história -> logo -> tutorial -> Fase 1 -> cutscene 2 -> resto -> cutscene final.

## Como gerar o app
O app de iPhone só pode ser compilado e assinado num **Mac com Xcode**. Não existe `.ipa` pronto
para instalar direto, como existe `.apk` no Android.

1. Godot 4.7.2 com os templates de exportação instalados (veja `EXPORTAR.md`).
2. **Projeto > Exportar > "iOS (iPhone e iPad)"**: preencher o *App Store Team ID* e conferir o
   *Bundle Identifier* (`com.returing.game`, troque por um seu se o Xcode reclamar). Exportar para
   `build/ios/Returing.xcodeproj`.
   (Exportar o projeto Xcode funciona também no Windows; compilar e assinar exige o Mac.)
3. Abrir o `.xcodeproj` no Xcode > *Signing & Capabilities* > escolher o **Team** > conectar o iPhone > Run.
4. Para gerar o `.ipa`: Product > Archive > Distribute App.

## Celular
- Roda na horizontal e liga os controles de toque sozinho.
- O acelerômetro (modo comando por inclinação) funciona no app nativo; o mapeamento de eixos do iOS está
  em `mobile/tilt_logic.gd` e coberto por `testes/t_tilt_logico.gd` e `testes/t_tilt_input.gd`.
- Vida do Turing no celular: 100 (`Platform.MOBILE_PLAYER_HP`).

## Versão Web no iPhone
O preset "Web (iPhone, Android e navegador)" roda no Safari, mas a versão Web **não lê o acelerômetro**;
o modo comando usa o D-pad na tela.

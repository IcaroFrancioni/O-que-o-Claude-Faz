# Decisões técnicas (modo multiplataforma)

Formato: **decisão** — motivo — alternativa descartada.

## Plataforma e projeto
1. **`Platform` virou a única fonte da verdade, com `is_mobile()`, `is_desktop()`, `platform_name()`, `is_real_device()`, `can_quit()`.**
   Motivo: o pedido era centralizar a detecção e não espalhar `OS.has_feature`; os poucos usos soltos (área segura, botão "Sair") passaram a perguntar à `Platform`.
   Descartado: manter a variável pública `is_mobile` (obrigava cada script a conhecer a regra).
2. **Modo celular = Android/iOS (feature) ou `--mobile`; notebook Windows com tela de toque continua em modo computador.** Motivo: requisito explícito. Descartado: `DisplayServer.is_touchscreen_available()` no desktop (liga touch em notebook com touch).
3. **Flags de teste/depuração por argumento de usuário** (`--mobile`, `--platform=ios`, `--landscape-reverse`, `--debug-tilt`, `--mobile-config=`) em vez de `ProjectSettings` ou variáveis de ambiente: funcionam igual no editor, no PC e na CI sem mexer no projeto.
4. **Stretch `canvas_items` + aspect `expand` e paisagem com sensor já estavam no projeto** (`window/handheld/orientation=4`); só conferi. A área segura vem de `DisplayServer.get_display_safe_area()` (só em aparelho real) e todo controle é preso dentro dela.

## Layout dos controles
5. **Posição em proporção da tela + escala por controle (`MobileLayout`)**, com os padrões medidos no print (1464x648 lógicos). Motivo: fica igual em qualquer proporção (celular e tablet) e o editor só guarda dois números por controle. Descartado: nós `TouchScreenButton` por cena (cada tela teria o seu layout e o editor teria que reescrever cenas).
6. **Os controles continuam desenhados por um único `Control` (`MobileControls`)**, agora com as texturas geradas, em vez de um nó por botão. Motivo: o sistema de multitouch já existia e estava testado; trocar tudo por `TouchScreenButton` arriscaria regressões de mira/tiro. Os eventos viram as mesmas ações do InputMap.
7. **Joysticks fixos** (o de movimento era "flutuante"). Motivo: o print e o editor de HUD pedem posição fixa; a zona de toque é 1,9× o raio, então não exige precisão.
8. **O joystick direito começa no TIRO** (`weapon_ranged=true`); o botão de espada sempre golpeia; "trocar arma" muda o que o joystick direito faz (tiro <-> espada). Motivo: o pedido descreve "joystick de mira/tiro" e três botões separados; o tutorial (tiro → trocar arma → espada) só faz sentido assim.
9. **Botão de pausa em camada própria (110) acima do menu de pausa (100)** e visível mesmo com o jogo pausado. Motivo: "sempre visível, por cima de qualquer painel".
10. **Zoom/escala de sprites do celular (câmera 2x, sprites 1,5x) mantidos** como o projeto já tinha (`Platform.MOBILE_*`); o print de referência mostra o mundo menor, mas ele só define o layout dos controles. Ajustável em um lugar.
11. **Barras de status e quadro de comandos seguem o layout** (`MobileControls._adapt_hud` e `CommandBoard.apply_layout`), então o editor de HUD move as barras REAIS (não proxies) e o jogo reage ao vivo.
12. **Editor de HUD trabalha direto no layout vivo** e "Voltar" recarrega do disco (descarta). Alternativa descartada: um rascunho separado (dobraria o código de refresh).
13. **Preferências em `user://mobile_hud.cfg` (ConfigFile)**, seções `layout` e `tilt`. Valores inválidos viram o padrão (testado).

## Modo comando por inclinação
14. **Inclinação = diferença de ÂNGULOS (roll/pitch) entre a pose atual e a pose neutra**, não de componentes do vetor. Motivo: descoberto em teste — a diferença de componentes perde sensibilidade com o celular quase em pé (o seno satura). Com ângulos a resposta é a mesma em qualquer pose.
15. **Convenção "bolinha numa bandeja"**: direita = borda direita desce; cima = borda de cima desce (longe do jogador). O indicador do quadro mostra exatamente isso.
16. **Vetor normalizado** antes de tudo: Android entrega m/s² e iOS também (Godot converte g → m/s²), mas assim a unidade não importa.
17. **Mapeamento por plataforma e orientação (`TiltLogic.to_screen_gravity`)** com dois sistemas de eixos. Verifiquei no código-fonte do Godot 4.4 (`GodotInputHandler` + `InputEventRunnable` no Android; `godot_view.mm` no iOS) que o Godot JÁ gira o sensor para a tela e entrega a gravidade com o mesmo sinal nas duas plataformas (`Frame.SCREEN`). Por segurança (versão futura/aparelho estranho) existe `Frame.RAW` com a tabela por plataforma e paisagem/invertida, e `Frame.AUTO` detecta pela calibração (gravidade toda no eixo x = bruto). Tudo coberto por teste (4 direções × 2 plataformas × 2 paisagens × 2 sistemas).
18. **Calibração automática ao abrir o modo comando** + botão "Calibrar" nas configurações (recalibra na hora, com indicador ao vivo).
19. **Histerese + cooldown + zona morta + filtro passa-baixa** no `TiltInput`; tempo medido em relógio real (`delta / time_scale`) porque o modo comando liga a câmera lenta.
20. **Sensor ausente = leituras exatamente zero por 1 s** → aviso no quadro e D-pad de fallback (toque). No PC com `--mobile` as teclas I/J/K/L simulam a inclinação.
21. **Setas disparam a habilidade ao completar a sequência** (o `AbilityComponent` já tinha o "modo de toque": sem Enter). Reaproveitei em vez de criar outro.
22. **`AbilityComponent.practice`** (modo treino) só para o tutorial: abre o modo comando sem habilidades, sem câmera lenta, e as setas só emitem `arrow_input`.
23. **iOS:** o acelerômetro (CoreMotion) não exige `NSMotionUsageDescription`; mesmo assim o preset inclui o texto em `application/additional_plist_content`.

## Tutorial, cutscenes e menus
24. **O tutorial reaproveita o `TutorialUi` e as lições existentes**; no celular só trocam os ícones (`MobileGuideIcon`) e os textos, e entram duas lições (trocar arma e modo comando). O controle da vez é destacado (anel dourado que pisca) no HUD real E no painel.
25. **"Mover" exige as quatro direções** (igual ao WASD do computador, com um check por direção); **"Incline o celular" exige as quatro inclinações**.
26. **Aba "Melhorias" do tutorial**: no celular não há seta, então tocar na carta "Saída" faz o papel da seta para a direita.
27. **Botão "Avançar cutscene"** é um `PixelButton` do tema do jogo (caixa marrom e fonte do jogo), aparece no `Dialogue` e na cutscene 2; no computador nada muda ("segure TAB/ESC"). No tutorial, "Pular tutorial" continua (a dica "segure TAB" some no celular).
28. **Painel do tutorial e botão "Pular tutorial" no celular** foram reposicionados para não cobrir joysticks, botões, pausa nem o quadro de comandos.

## Assets
29. **Assets gerados por `tools/gerar_assets.py` (Pillow, determinístico)**. Botões/joysticks seguem o estilo do print (cinza translúcido, traço branco, suavizado); molduras, setas, celular e ícones do app são pixel art com a paleta do projeto (`tools/paleta.txt`). A moldura do quadro é derivada de `ui/theme/panel_gold.png`. Texturas com filtro nearest já eram o padrão do projeto (`default_texture_filter=0`).
30. **Caixa marrom e fonte do botão de cutscene vêm do tema** (`Palette.load_theme()`), não de textura nova: é literalmente o mesmo estilo.

## Testes e processo
31. **Cada teste roda num processo novo** (`executor.tscn` + `rodar_todos.gd`): o modo celular é lido no `_ready` de vários scripts, então ligar/desligar em runtime não é confiável. Também isola vazamentos.
32. **Capturas precisam de renderizador** (não funcionam em `--headless`): `capturar_todas.gd` roda os mesmos testes com janela (no Linux: xvfb).
33. **Uma flag de ruído conhecido** (vazamentos de saída do áudio do menu e do renderizador dummy) é ignorada pelo runner; qualquer outro `ERROR:`/`WARNING:`/`SCRIPT ERROR` reprova o teste.
34. **Os testes antigos de celular (`tests/mobile_*`) foram removidos**: dependiam do layout/API antigos (`_rest_aim`, analógico flutuante). Foram substituídos pela suíte `testes/`; o `soak_test` e o `qa/` continuam e foram ajustados.
35. **Push com `-c credential.helper=manager`** (Git Credential Manager): a máquina não tinha helper configurado no `~/.gitconfig`; não alterei a configuração global.

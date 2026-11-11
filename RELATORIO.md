# Relatório — Returing multiplataforma (Windows, Linux, macOS, Android e iOS)

- **Branch:** `turing-apk` — <https://github.com/IcaroFrancioni/O-que-o-Claude-Faz/tree/turing-apk>
- **Godot:** 4.7.2 stable (Windows, console). Templates oficiais 4.7.2 instalados (SHA-512 conferido).
- **Último commit:** ver `git log -1` da branch (o hash final vai na mensagem de entrega).

## 1. O que foi feito, por seção do pedido

| Seção | Resumo |
|---|---|
| Regra geral | Autoload `Platform` (`is_mobile()`, `is_desktop()`, `platform_name()`, `is_real_device()`, `can_quit()`); `--mobile` força o modo celular no PC; notebook com touch fica em modo computador; só `user://`/`res://`; teste de caminhos com maiúsculas/minúsculas exatas; stretch `canvas_items`, aspect `expand`, paisagem com sensor, área segura. |
| 1. Layout mobile | `MobileControls` + `MobileLayout`: joysticks fixos, botões de espada, dash, trocar arma, modo comando e pausa (sempre por cima), HUD de status, quadro de comandos na região do print, multitouch. Mesmas ações do InputMap. |
| 2. Pular cutscene | `SkipCutsceneButton` ("Avançar cutscene", caixa marrom e fonte do jogo) no `Dialogue` e na cutscene 2; computador inalterado. |
| 3. Editor de HUD | `MobileHudEditor` no menu de pausa: arrastar, pinça/slider, limites, restaurar padrão, salvar (`user://mobile_hud.cfg`). Configurações: sensibilidade, zona morta, intervalo e "Calibrar". |
| 4. Acelerômetro | `TiltLogic` (função pura) + `TiltInput` (autoload): mapeamento por plataforma/orientação, zona morta, low-pass, histerese, cooldown, sensor ausente → D-pad, overlay `--debug-tilt`, simulação por teclas I/J/K/L. iOS: texto de movimento no preset. |
| 5. Tutorial mobile | 6 passos (mover, dash, tiro, trocar arma, espada, modo comando + inclinar) com ilustrações animadas e controle da vez piscando; computador igual. |
| 6. Exportação | `export_presets.cfg` (Windows, Linux x86_64/arm64, macOS universal, Android APK/AAB arm64, iOS, Web), `exportar.sh`/`exportar.bat`, `EXPORTAR.md`. |
| 7. Testes | `testes/` (runner `rodar_todos.gd`, capturas `capturar_todas.gd`), veja a seção 2. |
| 8. Git | Commits pequenos em português na `turing-apk`, sem `--force`, sem segredos. |
| 11. Assets | `tools/gerar_assets.py` + `tools/paleta.txt` → `assets/gerados/`. |

## 2. Testes (versão do Godot: 4.7.2)

Rodar: `godot --headless --path . --script res://testes/rodar_todos.gd` (código de saída ≠ 0 se algo falhar; também reprova qualquer
`SCRIPT ERROR`/`ERROR:`/`WARNING:` que não seja o ruído conhecido de saída do Godot).

Última execução completa, a partir de estado limpo (`.godot/` apagado e reimportado), **13 testes, 427 verificações, 0 falhas**:

| Teste | Verificações | O que prova |
|---|---|---|
| `t_carga.gd` (PC e `--mobile`) | 23 + 23 | todos os 298 scripts/cenas carregam; assets gerados existem; caminhos `res://` com maiúsculas exatas; sem caminho absoluto |
| `t_tilt_logico.gd` | 46 | função pura: 4 direções × Android/iOS × 2 paisagens × 2 sistemas de eixos, zona morta, sensibilidade, diagonal, unidade, sensor zero |
| `t_tilt_input.gd` | 48 | `TiltInput` com `Input.set_accelerometer`: direções, histerese, cooldown, calibração, sensor ausente |
| `t_pc.gd` | 32 | **regressão no computador:** sem controles de toque, teclado/mouse/Ctrl/ESC como antes, barras no lugar original |
| `t_tutorial_pc.gd` | 14 | **regressão do tutorial no computador** (WASD, ESPAÇO, mouse; sem lições do celular) |
| `t_controles.gd` | 61 | posições do print, quadro sem sobreposição, joysticks, tiro, multitouch, dash, espada, trocar arma, pausa por cima do menu |
| `t_comando_mobile.gd` | 30 | botão de comando, quadro, inclinação → setas → habilidade certa, erro, histerese, D-pad sem sensor, fechar |
| `t_layout.gd` + `t_layout_reinicio.gd` | 34 + 23 | editor: arrastar, pinça, slider, limites, barras reais e quadro, restaurar padrão, salvar; **após reiniciar o processo** o layout é restaurado |
| `t_config.gd` | 14 | página do acelerômetro, sliders, Calibrar, gravação em `user://` |
| `t_cutscene.gd` | 14 | botão "Avançar cutscene" (tema, posição, tamanho) pula o diálogo e a cutscene 2 |
| `t_tutorial_mobile.gd` | 65 | tutorial inteiro com toques e inclinação simulada: cada passo só avança com a ação certa, destaque pisca, termina e pede a Fase 1 |

Nenhum erro/warning de script no console (o runner reprova qualquer `SCRIPT ERROR`/`ERROR:`/`WARNING:`, exceto os vazamentos de saída do áudio do menu que já existiam).

Capturas (`testes/capturas/`, geradas com janela 1500x664): `01_jogo`, `20_comando_aberto`, `21_comando_seta_cima`,
`22_comando_sem_sensor`, `30_editor_hud`, `41…47_tutorial_*` (um por passo), `48_tutorial_melhorias`, `50_botao_avancar_cutscene`.
Conferidas contra `referencias/mobile_layout.png`: controles nas mesmas posições. Diferença conhecida: o mundo aparece maior
(zoom 2x e sprites 1,5x do projeto), veja `DECISOES.md` item 10.

**Emulador Android:** não executado — a máquina não tem JDK nem Android SDK (e instalar SDK + imagem de sistema do emulador não cabia
no ambiente). Plano alternativo aplicado: suíte headless + capturas + exportação desktop/web. O CI (`.github/workflows/testes.yml`)
tenta gerar o APK debug no GitHub Actions.

## 3. Exportações (neste computador, Windows)

| Plataforma | Resultado |
|---|---|
| Windows x86_64 | OK — `build/windows/Returing.exe` (159 MB); abre e sai sem erro em headless |
| Linux x86_64 | OK — `build/linux/Returing.x86_64` |
| Linux arm64 | OK — `build/linux-arm64/Returing.arm64` |
| macOS universal | OK — `build/macos/Returing.zip` (**não assinado/notarizado**: só em Mac) |
| Web | OK — `build/web/index.html` |
| Android APK/AAB | **Não gerado aqui:** sem JDK 17 e Android SDK. Preset e script prontos; CI tenta. |
| iOS | **Não gerado aqui:** só em macOS com Xcode e conta Apple. Preset pronto (`com.returing.game`, iPhone+iPad, ícones, splash). |

## 4. Assets gerados (`assets/gerados/`, regenerar com `python3 tools/gerar_assets.py`)

Botões e joysticks: `btn_base*.png`, `ic_sword/shot/dash/swap/command/pause/interact.png`, `stick_base.png`, `stick_thumb*.png`.
Quadro de comandos: `board_frame.png` (derivada da moldura dourada), `arrow_{up,down,left,right}[_lit|_off].png`, `dpad_base.png`,
`tilt_ring.png`, `tilt_dot.png`. Tutorial: `phone_{neutral,up,down,left,right}.png`, `joy_demo_0..3.png`, `glow_0/1.png`.
App: `icone_app_1024/512.png`, `icone_android_192.png`, `adaptive_fg/bg_432.png`, `icone_ios_1024.png`, `icone_win.ico`, `icone_mac.icns`, `splash_ios.png`.
O botão "Avançar cutscene" e a caixa do tutorial usam o **tema do jogo** (não há PNG novo para eles).
Botões/joysticks seguem o estilo suave do print; o resto é pixel art com a paleta de `tools/paleta.txt`.

## 5. Problemas conhecidos e o que você precisa fazer

1. **Testar o acelerômetro num celular real** (Android e iPhone). Tudo foi verificado por simulação (`Input.set_accelerometer`) e pelo código-fonte do Godot 4.4 (que gira o sensor para a tela nas duas plataformas). Se algum aparelho vier com eixos trocados, use `--debug-tilt` (overlay) e o modo `Frame.RAW` em `TiltInput.frame`.
2. **Android:** instalar JDK 17 + Android SDK e rodar `./exportar.sh debug android` (ou usar o APK do CI). Keystore de release é seu.
3. **iOS:** exportar e assinar num Mac (Team ID no preset).
4. **macOS:** assinar/notarizar num Mac.
5. O zoom da câmera no celular (2x) é maior que o do print; ajuste em `Platform.MOBILE_CAMERA_ZOOM` se preferir.
6. Ao sair, o Godot imprime vazamentos de objetos causados pela música do menu principal (já existiam antes deste trabalho); o runner ignora só essas linhas.
7. O push no Windows exigiu `git -c credential.helper=manager push` (o `~/.gitconfig` não tinha helper).

## 6. Auditoria: requisito → implementação → teste → status

| Requisito | Como foi implementado | Teste que prova | Status |
|---|---|---|---|
| `Platform` único (`is_mobile`, `is_desktop`, nome) | `autoload/platform.gd` | `t_pc`, `t_controles`, `t_carga` | OK |
| Flag para forçar mobile no editor; touch de notebook = computador | `--mobile`; `is_real_device()` só Android/iOS | `t_controles` (mobile), `t_pc` (desktop) | OK |
| Só `user://`/`res://`, maiúsculas exatas | sem caminhos absolutos | `t_carga` (verifica todos os `res://`) | OK |
| Paisagem, `canvas_items`, `expand`, área segura | `project.godot`, `MobileControls._compute_safe_margins` | `t_controles` (janela 1500x664 → 1464x648); área segura só em aparelho real | OK (área segura só verificável em aparelho) |
| Layout igual ao print, proporcional | `MobileLayout.DEFS` em proporção | `t_controles` (posições ±0,02 do print) + captura `01_jogo` | OK |
| HUD de status, pausa, joysticks, espada, dash | `MobileControls`, texturas geradas | `t_controles`, captura | OK |
| Botão de trocar arma e de modo comando sem sobreposição | posições do print | `t_controles` (nenhuma sobreposição) | OK |
| Quadro de comandos na região azul, sem cobrir controles | `CommandBoard` + `MobileLayout.BOARD` | `t_controles`, `t_comando_mobile`, captura `20_*` | OK |
| Conteúdo do quadro: setas, indicador de inclinação, habilidades | `CommandBoard._draw` | `t_comando_mobile` + capturas `20`, `21` | OK |
| Multitouch, mesmas ações do InputMap | `MobileControls` | `t_controles` (mover+atirar) | OK |
| Botão "Avançar cutscene" (só mobile) | `SkipCutsceneButton` | `t_cutscene`, `t_pc` (ausente no PC) | OK |
| Editor de HUD (texto, arrastar, pinça/slider, limites, restaurar, salvar, persistir) | `MobileHudEditor`, `MobileLayout`, `MobileSettings` | `t_layout`, `t_layout_reinicio` | OK |
| Sensibilidade do acelerômetro e Calibrar nas configurações | `SettingsPanel` (página Acelerômetro) | `t_config` | OK |
| Modo comando por acelerômetro, mapeamento por plataforma/orientação | `TiltLogic`, `TiltInput` | `t_tilt_logico`, `t_tilt_input`, `t_comando_mobile` | OK em simulação; **aparelho real pendente** |
| Zona morta, low-pass, histerese, cooldown | `TiltInput.step` | `t_tilt_input` | OK |
| iOS: descrição de uso de sensores | `application/additional_plist_content` no preset | n/a (não há Mac) | OK (não exigido pela Apple para acelerômetro; incluído) |
| Sem sensor: aviso + D-pad | `CommandBoard`, `MobileControls.dpad_*` | `t_comando_mobile` + captura `22_*` | OK |
| Função pura testável; simulação com teclas; overlay de debug; `@export` | `TiltLogic.detect`, `I/J/K/L`, `--debug-tilt`, exports do `TiltInput` | `t_tilt_logico`, `t_tilt_input` (teclas); overlay sem teste automático | OK (overlay só visual) |
| Tutorial mobile (6 passos, pisca/anima, só avança com a ação) | `tutorial.gd`, `MobileGuideIcon` | `t_tutorial_mobile` + capturas `41`–`48` | OK |
| Tutorial de computador igual | ramos `Platform.is_mobile()` | `t_tutorial_pc` | OK |
| Presets das 5 plataformas, scripts e `EXPORTAR.md` | `export_presets.cfg`, `exportar.sh/.bat` | exportação real: Windows, Linux x64/arm64, macOS, Web OK | OK; Android/iOS **não gerados aqui** (sem JDK/SDK/Mac) |
| Ícones, nome, orientação, versão consistentes | presets + `config/icon` | exportação desktop/web | OK |
| Testes headless com runner e código de saída | `testes/rodar_todos.gd` | execução limpa: 13/13 | OK |
| Capturas em `testes/capturas/` | `capturar_todas.gd` | 15 capturas conferidas | OK |
| Emulador Android | — | — | **Não resolvido:** sem Android SDK/JDK nesta máquina; CI tenta o APK |
| CI | `.github/workflows/testes.yml` | não executado (precisa do GitHub) | OK (best effort, não verificado) |
| Git: branch `turing-apk`, commits pequenos, sem force/segredos | histórico | `git log` | OK |
| Assets gerados no estilo do projeto | `tools/gerar_assets.py`, `tools/paleta.txt` | conferência visual nas capturas | OK |
| Regressão no computador | `t_pc`, `t_tutorial_pc` | 46 verificações | OK |

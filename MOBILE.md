# Returing no celular (Android, iPhone e iPad) e em outras plataformas

O mesmo projeto roda em **Windows, Linux, macOS, Android, iOS/iPadOS e navegador**.
Passo a passo de exportação: [EXPORTAR.md](EXPORTAR.md). Decisões técnicas: [DECISOES.md](DECISOES.md). Resultado dos testes e
pendências: [RELATORIO.md](RELATORIO.md).

* **Computador:** teclado e mouse, nada muda (nenhum controle de toque aparece).
* **Celular/tablet:** controles de toque no layout de `referencias/mobile_layout.png`.

## Testar no PC como se fosse celular
```
godot --path . -- --mobile                  # o mouse vira o dedo (botão esquerdo); I/J/K/L inclinam o "celular"
godot --path . -- --mobile --debug-tilt     # overlay com os valores do acelerômetro
godot --path . -- --mobile --platform=ios --landscape-reverse
```

## Controles do celular
| Controle | Função |
|---|---|
| Joystick esquerdo | mover |
| Joystick direito | mirar e atirar (segure para carregar, solte para disparar); um toque rápido mira no inimigo mais próximo |
| Botão de espada | golpeia (sempre) |
| Botão de dash (>>) | dash |
| Botão de trocar arma | alterna o joystick direito entre tiro e espada |
| Botão de modo comando | abre/fecha o modo comando e o **quadro de comandos** (canto superior direito) |
| Botão de pausa | pausa; fica visível por cima de qualquer painel |
| Botão E | aparece perto dos terminais da Fase 2 |

### Modo comando por inclinação
1. Toque no botão de modo comando: o quadro de comandos aparece e o celular é calibrado na posição atual.
2. **Incline o celular** para cima, baixo, esquerda ou direita: cada inclinação vira uma seta da sequência (como o teclado no PC). Volte ao centro entre uma seta e a próxima.
3. Ao completar a sequência de uma habilidade ela dispara.
* Sem acelerômetro, o quadro avisa e mostra um **D-pad** para tocar.
* **Configurações > Acelerômetro:** sensibilidade, zona morta, intervalo entre setas e **Calibrar**.

### Editor de HUD
**Pausa > Editar controles:** arraste cada controle (inclusive as barras de status e o quadro de comandos), amplie/reduza com a
**pinça** ou o slider, **Restaurar padrão** (layout do print) e **Salvar** (grava em `user://mobile_hud.cfg`).

## Ajustes rápidos
* `autoload/platform.gd`: `MOBILE_SPRITE_SCALE` (1.5), `MOBILE_CAMERA_ZOOM` (2.0), `MOBILE_MIN_SHOT_CHARGE` (0.2).
* `mobile/mobile_layout.gd`: posições/tamanhos padrão dos controles (em proporção da tela).
* `mobile/tilt_input.gd`: `sensitivity`, `deadzone`, `cooldown`, `smoothing_rate` (também nas configurações).
* `autoload/mobile_controls.gd`: `MELEE_ON_RELEASE`, zonas de toque dos joysticks.
* Mira assistida do tiro: constantes `ASSIST_*` em `characters/turing/player_projectile.gd`.

## Assets
Gerados por `python3 tools/gerar_assets.py` em `assets/gerados/` (paleta em `tools/paleta.txt`). Para usar arte feita à mão, troque os PNGs
mantendo o nome e o tamanho.

## Testes
```
godot --headless --path . --script res://testes/rodar_todos.gd            # suíte completa
godot --headless --path . --script res://testes/rodar_todos.gd -- --filtro=tutorial
godot --path . --script res://testes/capturar_todas.gd                     # capturas em testes/capturas/ (precisa de janela)
```

## iPhone pelo Safari (versão Web)
1. `./exportar.sh debug web` e hospede `build/web/` (HTTPS).
2. No Safari: Compartilhar > **Adicionar à Tela de Início**. Gire para paisagem: o jogo liga os controles de toque sozinho.
3. O acelerômetro no Safari exige permissão do usuário (iOS 13+) e só vale no app nativo; no navegador o modo comando usa o D-pad.

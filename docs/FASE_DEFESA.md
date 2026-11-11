# Transição do cristal + Fase de defesa

Fluxo: `Fase 1 -> Labirinto -> SalaNova (cristal) -> [transição] -> Defesa.tscn -> Fase2.tscn (quiz) -> Fase 3`

## Visual (tudo em PNG, nada desenhado por código)

Os PNGs ficam em `assets/defesa/` e são gerados por `python tools/gerar_arte_defesa.py` (+ `tools/arte_defesa_arena.py`), com a paleta e a resolução de pixel do projeto (`tileset_sf.png`, `gerar_arte_fase2.py`):

| PNG | Uso |
|---|---|
| `arena_defesa.png` (1152 x 656) | Arena **nova**, desenhada do zero (nenhum sprite de outra arena é reaproveitado): racks no topo, piso de placas, trilhas de circuito, 8 escotilhas de nascimento, plataforma e poço do portal. |
| `portal.png` (6 x 2 quadros de 48 x 80) | Portal: linha 0 carregando, linha 1 pronto. |
| `barra_*.png` | Moldura e preenchimentos das barras da HUD (`TextureProgressBar`). |

Inimigos: **só os originais** (`DroneEnemy`, `RoboEnemy` = Atirador, `TankEnemy`), com as cenas, scripts e sprites do jogo.

## Como os inimigos originais atacam o portal (sem duplicar lógica)

- O portal tem um corpo `Corpo` (grupo `enemy_target`, camada do jogador) e uma `Hurtbox` (camada das hurtboxes do jogador).
- Os sensores de alcance do Drone e do Atirador agora usam `CombatUtils.is_enemy_target(body)` (jogador **ou** alvo do grupo `enemy_target`) em vez de `is_player`. É a única mudança nos scripts dos inimigos.
- Golpes, tiros e ondas de choque já acertam `Hurtbox`: o portal perde `HIT_DAMAGE` (10) por golpe aceito, qualquer que seja o inimigo.
- `DefenseLevel` define `enemy.target` (portal, ou o jogador se estiver a menos de 150 px) por Timer.

## Waves (`wave_table.tres`, recurso `DefenseWaveTable`)

| Wave | Conteúdo |
|---|---|
| 1 | só Drones |
| 2 | Drones + Atiradores |
| 3+ | Drones + Atiradores + Tanks, crescendo (`growth_per_wave`; fração acumula) |

Quantidades e limite de inimigos vivos (`max_active`) ficam no `.tres`. Fluxo: pausa -> aviso "WAVE n" (HUD) -> nascimento escalonado -> luta; a próxima wave só vem quando **todos** morrem. Nascimento: ponto sorteado entre os `Marker2D` das escotilhas, a pelo menos 280 px do jogador e dentro do piso (sem parede); a ordem dos tipos também é sorteada.

## Portal

100 de vida, carrega em 30 s e cresce 0,5 %/s (Tweens). READY **não** encerra a fase: o jogador entra no portal para sair (sugado -> distorção -> diálogo -> quiz). Derrota (portal a 0 ou jogador morto) = game over com "Tentar de novo".

## Cutscenes e diálogo (`Dialogue`, `ScreenGlitch`, `CrystalTransition`)

Copiam o que o jogo já tem: a **voz do tutorial** (VT323 44 px, #d8ecff com brilho azul, no alto da tela) em **todas** as falas da transição do cristal ("Você conseguiu!" e as falas da armadilha), em sequência sobre a tela preta, sem trocar para uma cutscene. A **caixa da cutscene** (Panel do `main_theme`, nome em dourado, botão "Avançar", ilustração `Lab-Turing.png`) continua só na saída do portal da Defesa. Glitch com aberração RGB e fatias, chiado procedural e distorção de teletransporte (shaders). **Segurar ESC** pula a sequência.

## Testes

```
godot --headless --path . res://qa/defesa_test.tscn      # lógica
godot --path . res://qa/defesa_shot.tscn -- <pasta>       # capturas (precisa de janela)
```

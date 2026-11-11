# Fase 2 — Labirinto

Nova fase entre a Fase 1 e o quiz do terminal (`Scenes/Fase2/Fase2.tscn`, que não foi alterado).

```
Fase 1 -> Labirinto.tscn -> SalaNova.tscn -> Defesa.tscn -> Fase2.tscn (quiz) -> Fase 3
```

(O cristal da `SalaNova` agora dispara a transição e a fase de defesa: ver [FASE_DEFESA.md](FASE_DEFESA.md).)

Abra `Scenes/Fase2/Labirinto.tscn` e rode com **F6**. Na primeira abertura o editor importa os PNG novos de `assets/arena/`.

## Como se joga

| Elemento | Regra |
|---|---|
| Visão | `CanvasModulate` quase preto + `PointLight2D` no Player (160 px, cintilação leve). Paredes têm oclusores. |
| Fogo | 3 trechos (`Fogo1..3`). Dano de 34 por tick. O dash dá invulnerabilidade, então só se cruza sem dano **em dash**. |
| Dash | 560 px/s x 0,30 s = 168 px, recarga de 1 s, invulnerável durante todo o dash (ajustado na instância do Player). |
| Chave | No canto sudeste, atrás do `Fogo1`. Ao coletar: ícone no inventário (canto sup. direito) + aviso. |
| Porta | Parede leste da linha de cima, atrás do `Fogo2`. **[E]** com a chave a destranca (sinal `key_used`). |
| Puzzle | 3 painéis (triângulo, quadrado, círculo) ligados com **[E]** na ordem mostrada pela projeção no chão perto do início (`puzzle_solved`). Ordem errada reinicia. |
| Sala nova | Só abre quando `key_used` **e** `puzzle_solved` (uma única checagem, `Labirinto._try_unlock`). Depois, o vestíbulo leva à `SalaNova.tscn`. |
| Drones | 3 `DroneEnemy.tscn` do projeto, cada um numa rota de `Marker2D` (`Rotas/Rota1..3`). Perseguem e atacam com o código original quando veem o jogador; atrás de parede seguem os corredores (`Grafo` + `drone_maze_chase_state.gd`), em vez de empurrar contra ela. |
| F3 | Alterna a depuração: contornos (colisão verde, oclusor ciano, fogo vermelho, rotas magenta, alcance da luz branco) -> contornos + luz ambiente alta -> desligado. |

## Onde mexer

- **Alcance da luz / cintilação:** nó `Player/Luz` (`player_light.gd`): `light_range`, `flicker_*`.
- **Dash e vida:** nó `Player` da cena (grupos *Dash* e *Status* do `player.gd`): `dash_speed`, `dash_duration`, `dash_cooldown`, `iframes_duration`, `hp_maximo`, `hp`.
- **Dano do fogo:** `fire_hazard.gd` (`damage`, `tick_interval`, `retry_delay`).
- **Ordem do puzzle:** `PuzzleController.solution` (precisa bater com a dica desenhada: `tools/fase2_layout.py` -> `SOLUTION`).
- **Cena seguinte:** `Labirinto.sala_nova_scene`, `SalaNova.next_scene`.

## A arte e as colisões não são geradas no jogo

- Piso e paredes são **PNGs prontos** (`assets/arena/arena_piso.png`, `arena_paredes.png`), pintados em pixel art por `tools/gerar_arte_fase2.py` (1 px de arte = 2 px de tela, escala 2, filtro Nearest).
- Colisões (`Colisoes/Parede..`), oclusores (`Oclusores/Oclusor..`), fogo, chave, porta, painéis e waypoints são **nós estáticos** em `Labirinto.tscn`, alinhados à arte pelos mesmos números da planta (`tools/fase2_layout.py`).
- Não há TileMap, TileSet, arquivo de mapa nem geração em tempo de execução.

## Ferramentas (`tools/`)

```
python tools/gerar_arte_fase2.py    # repinta os PNG de assets/arena/ (precisa de Pillow)
python tools/gerar_cena_fase2.py    # regrava Labirinto.tscn e SalaNova.tscn (sobrescreve edições manuais!)
python tools/validar_fase2.py       # valida caminhos, vazamento de luz, alinhamento, fogo x dash, drones e .tscn
```

Se editar a cena à mão no editor, **não rode** `gerar_cena_fase2.py` depois (ele recria o arquivo).

## Drones no labirinto

O desvio por raycast do `DroneEnemy` não acha caminho em labirinto e o drone travava na parede entre ele e o jogador (a detecção atravessa paredes). Sem alterar nenhum arquivo do drone, as 3 instâncias trocam os scripts dos estados `Patrol` e `Chase` por subclasses (`drone_route_patrol_state.gd`, `drone_maze_chase_state.gd`) que usam o nó `Grafo` (`maze_graph.gd`, passagens gravadas no `.tscn`). Com linha de visão livre (3 raios) vale o comportamento original, inclusive o ataque; sem ela o drone vai de centro de célula em centro de célula.

```
python tools/simular_drones_fase2.py                                    # simula perseguição e patrulha contra as paredes reais
godot --headless --path . res://qa/labirinto_drone_test.tscn            # teste dentro do Godot (não rodado por quem escreveu)
```

## Limitações conhecidas

- Andar através do fogo não é bloqueado: custa 34 de vida por travessia (3 travessias a pé matam com 100 de vida).
- A detecção do drone (190 px) ainda atravessa parede: ele pode começar a perseguir quem está do outro lado e contorna pelos corredores até perder o jogador de vista a mais de 190 px.

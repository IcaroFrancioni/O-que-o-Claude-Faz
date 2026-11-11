# Fase 5 — Câmara de Provas ("Linha de Tiro")

```
Fase 1 -> Labirinto -> SalaNova (cristal) -> Defesa (teleporte) -> Fase2 (quiz) -> Camara -> Fase 3
```

Só dois pontos mudaram: `Fase2.tscn` (quiz) agora tem `next_scene = Camara.tscn` e `Camara.next_scene = fase_3.tscn`.
A `SalaNova` e a `Defesa` continuam como no projeto original.

**Abertura:** ao entrar, tela preta com a voz do homem misterioso do tutorial (`Dialogue.Style.VOICE`: texto azul, sem caixa
nem ilustração, não é cutscene; segurar ESC pula). Falas em `Camara.falas_abertura`. O Player fica parado e nada dispara até acabar.

Abra `Scenes/Fase5/Camara.tscn` e rode com **F6**. F3 liga a depuração.

## Como se joga

- **Máquinas** nas paredes disparam uma LINHA de 10 px que varre a faixa delas (a faixa está marcada no chão).
  Ciclo fixo: aviso 1,0 s (a máquina pisca, tracejado vermelho) -> clarão 0,4 s -> varredura 2,0 s -> pausa 1,6 s.
- Só o **DASH** atravessa a linha (iframes). Só o **tiro carregado** (dano >= 40, carga >= 52 %, ~0,62 s) destrói a
  máquina; tiro fraco é rebatido (faísca) e a espada não a enxerga. Carregar (1,2 s, anda a 40 %) é cancelado pelo dash.
- **Sala 1 "Passagem"**: corredor com 2 raios (máquinas indestrutíveis nas pontas, ciclo de 10 s) e 1 trecho de fogo.
- **Sala 2 "Calibração"**: 1 máquina, ciclo de 5 s. Destruí-la abre a porta.
- **Sala 3 "Câmara Principal"**: 10 máquinas (6 em cima/baixo, 4 nas laterais), em sequência fixa, uma de cada vez, a cada
  2,4 s (`Sala3.intervalo_disparos`). 2 são reforçadas (B3 e LL: 2 tiros). O número no chão é a vaga de cada uma.
  HUD "Máquinas X/10"; o contador na porta mostra as restantes. Destruir as 10 abre a porta final -> quiz.

## Onde mexer (tudo `@export`)

| O quê | Onde |
|---|---|
| Aviso, clarão, varredura, pausa | `CamaraMaquina`: `tempo_aviso`, `tempo_clarao`, `tempo_varredura`, `tempo_pausa` |
| Intervalo entre disparos | `CamaraSequenciador.intervalo_disparos` (nós `Sala1/2/3`); `atraso_inicial` |
| Dano mínimo da máquina | `CamaraMaquina.dano_minimo` (40) |
| Vida normal / reforçada | `CamaraMaquina.vida_normal` (1) / `vida_reforcada` (2) |
| Dano do raio | `CamaraMaquina.dano_raio` (120) e `intervalo_dano` |
| Próxima cena | `Camara.next_scene` |
| Ordem de disparo | ordem dos filhos de `Sala3` (e `ORDEM_SALA3` em `tools/camara_layout.py`) |

Atenção: se mudar o intervalo ou a ordem, rode `python tools/validar_camara.py` — com 10 máquinas o intervalo tem um
mínimo (~2,3 s) para manter 2,6 s entre chegadas de raios em qualquer ponto.

## Arquitetura

- Arte pronta (`assets/camara/*.png`, gerada por `tools/gerar_arte_camara.py`) e nós estáticos no `.tscn`
  (`tools/gerar_cena_camara.py`), tudo a partir da planta `tools/camara_layout.py`. Sem TileMap, sem mapa, sem geração em runtime.
- `camara.gd` (fase), `camara_sequenciador.gd` (cronograma), `camara_maquina.gd` (ciclo, dano), `camara_porta.gd`,
  `camara_hud.gd`, `camara_debug*.gd` (F3).
- Reuso do projeto: `Hitbox` (feixe, máscara 8 = hurtboxes do player), `Hurtbox` + `HealthComponent` (máquina),
  `FireHazard`, `Player` (só propriedades da instância), `EventBus`.
- **Camadas**: a Hurtbox da máquina fica na camada 1 (Mundo), não na 5. O tiro (máscara 17) a enxerga; a espada (máscara 16,
  dano 50 >= 40) não — é assim que "espada ignorada" vale sem editar `player.gd`.

## Validação

- `python tools/validar_camara.py [--motor]` — cronograma (folga >= 2,6 s, janela de carga >= 1,4 s), dash, linha de tiro,
  caminho, jogador-robô, integridade dos arquivos; `--motor` roda também o Godot.
- `godot --headless --path . res://qa/camara_test.tscn` — 64 verificações no motor (raio fere no instante previsto,
  iframes, dano mínimo, espada, sequência, portas, saída).
- `godot --path . --windowed res://qa/camara_shot.tscn -- <pasta>` — capturas.

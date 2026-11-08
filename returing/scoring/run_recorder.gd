class_name RunRecorder
extends Node
## Filho do Player: conta o tempo de jogo e registra os números brutos da run em `RunStats`.
## Fica pausável (`process_mode` padrão): pause, menus de escolha/build e quiz pausam a árvore
## e, por isso, não contam. Cutscene e tutorial são cenas sem Player, então também não contam.

## Corte de travadas (arrastar a janela): um frame maior que isso é limitado a este valor.
const MAX_DELTA_S: float = 0.25
## Piso do time_scale para a divisão nunca estourar.
const MIN_TIME_SCALE: float = 0.001

## True depois que a fase terminou: o intervalo até a próxima cena não conta.
var _fase_concluida: bool = false
var _config: ScoreConfig = null
## Quiz da fase (só existe na Fase 2).
var _quiz: QuizScreen = null


func _init() -> void:
	name = &"RunRecorder"  # nome estável (nó criado por código)


func _enter_tree() -> void:
	_config = ScoreConfig.carregar()
	CombatUtils.connect_once(EventBus.level_completed, _on_level_completed)
	CombatUtils.connect_once(EventBus.enemy_died, _on_enemy_died)
	CombatUtils.connect_once(EventBus.enemy_damaged, _on_enemy_damaged)
	CombatUtils.connect_once(EventBus.player_damaged, _on_player_damaged)


func _ready() -> void:
	_ligar_quiz.call_deferred()


func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.level_completed, _on_level_completed)
	CombatUtils.disconnect_if_connected(EventBus.enemy_died, _on_enemy_died)
	CombatUtils.disconnect_if_connected(EventBus.enemy_damaged, _on_enemy_damaged)
	CombatUtils.disconnect_if_connected(EventBus.player_damaged, _on_player_damaged)
	if CombatUtils.is_valid(_quiz):
		CombatUtils.disconnect_if_connected(_quiz.resposta_registrada, _on_quiz_resposta)


func _process(delta: float) -> void:
	_ler_vida_inicial()
	if pode_contar():
		RunStats.somar_tempo(segundos_contados(delta, Engine.time_scale))


## Segundos de tempo REAL de jogo de um frame: o delta já vem multiplicado pelo time_scale
## (câmera lenta do modo comando), então a divisão devolve o tempo real.
static func segundos_contados(delta: float, time_scale: float) -> float:
	return minf(delta, MAX_DELTA_S) / maxf(time_scale, MIN_TIME_SCALE)


## True só com o jogador de fato jogando: run em andamento, fase em curso e Player vivo.
func pode_contar() -> bool:
	if RunStats.finalizada or _fase_concluida:
		return false
	return not CombatUtils.is_dead_actor(get_parent())


## Guarda a vida máxima do Player na primeira vez (antes de qualquer bônus de habilidade).
func _ler_vida_inicial() -> void:
	if RunStats.vida_max_inicial_jogador > 0.0:
		return
	var hp_max: Variant = get_parent().get(&"hp_maximo")
	if hp_max != null:
		RunStats.vida_max_inicial_jogador = float(hp_max)


## Fase concluída. Sem próxima cena é a última: fecha a run, calcula e abre a tela final.
func _on_level_completed(next_scene: String) -> void:
	_fase_concluida = true
	RunStats.registrar_fim_de_fase()
	if next_scene.is_empty():
		_finalizar_run()


## Só aqui a pontuação é calculada (durante o jogo nada é calculado nem exibido).
func _finalizar_run() -> void:
	RunStats.finalizar()
	var resultado: ScoreResult = ScoreCalculator.calcular(RunStats.capturar(), _config)
	var recorde: Dictionary = HighScoreStore.registrar(resultado.total, resultado.rank, RunStats.tempo_s)
	# Depois do letreiro "FIM DE JOGO" da HUD; timer de jogo (respeita a pausa).
	var timer: SceneTreeTimer = CombatUtils.game_timer(self, _config.atraso_tela_final_s)
	if timer != null:
		timer.timeout.connect(_abrir_tela_final.bind(resultado, recorde))


func _abrir_tela_final(resultado: ScoreResult, recorde: Dictionary) -> void:
	ResultScreen.abrir(self, resultado, recorde)


## Abate: conta o tipo e a sequência (janela em tempo de jogo).
func _on_enemy_died(_enemy: Node2D, kind: StringName, _world_position: Vector2) -> void:
	RunStats.registrar_abate(kind, _config.janela_combo_s)


## Dano efetivo causado a um inimigo (o HealthComponent já limita ao que sobrava de vida).
func _on_enemy_damaged(_enemy: Node2D, _kind: StringName, amount: int, _current: int, _max: int) -> void:
	RunStats.registrar_dano_causado(float(amount))


## Dano aplicado ao jogador (já depois de i-frames e escudo; inclui o dano do erro no quiz).
func _on_player_damaged(amount: int) -> void:
	RunStats.registrar_dano_tomado(float(amount))


## Procura o quiz na cena do Player (Fase 2) e conta os acertos de primeira.
func _ligar_quiz() -> void:
	var player: Node = get_parent()
	if player == null:
		return
	var raiz: Node = player.owner if player.owner != null else get_tree().current_scene
	if raiz == null:
		return
	var achados: Array[Node] = CombatUtils.find_descendants(raiz, func(n: Node) -> bool: return n is QuizScreen)
	if achados.is_empty():
		return
	_quiz = achados[0] as QuizScreen
	CombatUtils.connect_once(_quiz.resposta_registrada, _on_quiz_resposta)


## Cada pergunta é feita uma vez, então todo acerto é "de primeira".
func _on_quiz_resposta(_indice: int, correta: bool, _motivo: StringName) -> void:
	if correta:
		RunStats.registrar_acerto_quiz()

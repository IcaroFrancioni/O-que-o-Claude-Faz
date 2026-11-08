extends Node
## Teste de integração com as fases reais: o Player nasce com o RunRecorder, o tempo corre,
## a run reseta no início, a troca de fase não zera e a última fase abre a tela final.
## Rodar: godot --headless --path . res://qa/flow_test.tscn

const FASE_1: String = "res://Scenes/Fase1/fase_1.tscn"
const FASE_3: String = "res://Scenes/Fase3/fase_3.tscn"
const ARQUIVO_TESTE: String = "user://returing_recordes_fluxo_teste.cfg"

var _falhas: int = 0
var _total: int = 0
var _fase: Node = null


func _ready() -> void:
	HighScoreStore.caminho = ARQUIVO_TESTE
	_rodar.call_deferred()


func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _abrir_fase(caminho: String) -> void:
	if _fase != null:
		_fase.queue_free()
		await _frames(3)
	_fase = (load(caminho) as PackedScene).instantiate()
	get_tree().root.add_child(_fase)
	get_tree().current_scene = _fase
	await _frames(15)


func _recorder() -> RunRecorder:
	var player: Node = _fase.find_child("Player", true, false)
	return player.get_node_or_null("RunRecorder") as RunRecorder if player != null else null


func _tela() -> ResultScreen:
	for filho: Node in _fase.get_children():
		if filho is ResultScreen:
			return filho
	return null


func _rodar() -> void:
	# --- Fase 1: início de run ---
	RunStats.tempo_s = 123.0
	RunStats.abates_por_tipo = {&"lixo": 9}
	await _abrir_fase(FASE_1)
	_confere(_recorder() != null, "Fase 1: o Player nasce com o RunRecorder")
	_confere(RunStats.tempo_s < 5.0 and RunStats.abates_por_tipo.is_empty(), "Fase 1: a run começa zerada (RunState.reset)")
	await _frames(30)
	_confere(RunStats.tempo_s > 0.0, "Fase 1: o relógio corre jogando")
	_confere(RunStats.vida_max_inicial_jogador == 100.0, "Fase 1: vida inicial lida do Player real")

	# Abate real pelo EventBus enquanto joga.
	EventBus.enemy_died.emit(_fase, &"drone", Vector2.ZERO)
	_confere(int(RunStats.abates_por_tipo.get(&"drone", 0)) == 1, "Fase 1: abate registrado")

	# --- Fase 1 concluída: a troca de fase NÃO zera a run ---
	var tempo_antes: float = RunStats.tempo_s
	EventBus.level_completed.emit("res://Scenes/Fase2/Fase2.tscn")
	_confere(RunStats.tempos_por_fase.size() == 1, "Fase 1 concluída: tempo da fase registrado")
	_confere(not RunStats.finalizada and _tela() == null, "Fase 1 concluída: ainda não finaliza nem abre a tela")
	await _frames(20)
	_confere(is_equal_approx(RunStats.tempo_s, tempo_antes), "Fase 1 concluída: o intervalo até a próxima fase não conta")

	# --- Fase 3 (última): mesma run, sem reset, e a tela final abre ---
	await _abrir_fase(FASE_3)
	_confere(RunStats.tempos_por_fase.size() == 1 and int(RunStats.abates_por_tipo.get(&"drone", 0)) == 1,
			"Fase 3: a run continua (sem reset na troca de fase)")
	await _frames(20)
	_confere(RunStats.tempo_s > tempo_antes, "Fase 3: o relógio continua somando")
	var recorder: RunRecorder = _recorder()
	_confere(recorder != null, "Fase 3: o Player nasce com o RunRecorder")
	recorder._config.atraso_tela_final_s = 0.2
	EventBus.level_completed.emit("")
	_confere(RunStats.finalizada, "Fase 3: a run foi finalizada")
	_confere(RunStats.tempos_por_fase.size() == 2, "Fase 3: tempo da fase registrado")
	await get_tree().create_timer(0.6, true, false, true).timeout
	await _frames(3)
	var tela: ResultScreen = _tela()
	_confere(tela != null, "Fase 3: a tela final abriu")
	_confere(get_tree().paused, "Tela final: árvore pausada")
	_confere(not HighScoreStore.carregar().is_empty(), "Tela final: recorde salvo")
	if tela != null:
		_confere(tela.resultado.total == ScoreCalculator.calcular(RunStats.capturar(), recorder._config).total,
				"Tela final: total bate com o cálculo da run")

	# Nada mais é contado depois de finalizar.
	var tempo_final: float = RunStats.tempo_s
	await _frames(10)
	_confere(is_equal_approx(RunStats.tempo_s, tempo_final), "Depois da run finalizada o tempo não anda")

	# Run nova: o reset volta ao estado inicial.
	RunState.reset()
	_confere(not RunStats.finalizada and RunStats.tempo_s == 0.0 and RunStats.tempos_por_fase.is_empty(),
			"RunState.reset zera a run (nova run)")

	if tela != null:
		tela.queue_free()
		await _frames(2)
	if FileAccess.file_exists(ARQUIVO_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO_TESTE))
	_fase.queue_free()
	await _frames(3)
	print("flow_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)

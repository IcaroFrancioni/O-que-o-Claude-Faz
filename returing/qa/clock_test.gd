extends Node
## Testes do relógio de jogo e dos contadores (RunStats / RunRecorder).
## Rodar: godot --headless --path . res://qa/clock_test.tscn  (cena: precisa dos autoloads)

const _DEAD_STUB: GDScript = preload("res://qa/dead_player_stub.gd")

var _falhas: int = 0
var _total: int = 0


func _ready() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	_testar_formula()
	await _testar_relogio()
	_testar_sequencia()
	await _testar_ganchos()
	_testar_sem_sinais_de_pontuacao()
	print("clock_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)


func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


func _perto(a: float, b: float, margem: float = 0.0001) -> bool:
	return absf(a - b) <= margem


func _testar_formula() -> void:
	_confere(_perto(RunRecorder.segundos_contados(0.016, 1.0), 0.016), "delta normal")
	_confere(_perto(RunRecorder.segundos_contados(1.0, 1.0), 0.25), "travada cortada em 0,25 s")
	_confere(_perto(RunRecorder.segundos_contados(0.3 * 0.1, 0.3), 0.1), "time_scale 0,3 conta tempo real")
	_confere(RunRecorder.segundos_contados(0.01, 0.0) > 0.0, "time_scale zero não estoura")


## Cria um "Player" falso (só precisa de esta_morto e hp_maximo) com o recorder como filho.
func _novo_jogador() -> Node:
	var jogador := Node.new()
	jogador.set_script(_DEAD_STUB)
	var recorder := RunRecorder.new()
	recorder.name = "RunRecorder"
	jogador.add_child(recorder)
	get_tree().root.add_child(jogador)
	return jogador


func _recorder(jogador: Node) -> RunRecorder:
	return jogador.get_node("RunRecorder") as RunRecorder


## Roda `n` frames e devolve quanto o tempo avançou.
func _avancar_frames(n: int) -> float:
	var antes: float = RunStats.tempo_s
	for i: int in n:
		await get_tree().process_frame
	return RunStats.tempo_s - antes


func _testar_relogio() -> void:
	RunStats.reset()
	var jogador: Node = _novo_jogador()
	await get_tree().process_frame

	_confere(await _avancar_frames(5) > 0.0, "tempo avança jogando")
	_confere(RunStats.vida_max_inicial_jogador == 100.0, "vida inicial lida do Player")

	get_tree().paused = true
	_confere(_perto(await _avancar_frames(5), 0.0), "árvore pausada não conta")
	get_tree().paused = false

	jogador.set(&"morto", true)
	_confere(_perto(await _avancar_frames(5), 0.0), "Player em DEAD não conta")
	jogador.set(&"morto", false)
	_confere(await _avancar_frames(5) > 0.0, "volta a contar com o Player vivo")

	var antes_fase: float = RunStats.tempo_s
	EventBus.level_completed.emit("res://x.tscn")
	_confere(RunStats.tempos_por_fase.size() == 1, "tempo da fase registrado")
	_confere(_perto(RunStats.tempos_por_fase[0], antes_fase), "tempo da fase = tempo acumulado")
	_confere(_perto(await _avancar_frames(5), 0.0), "transição entre fases não conta")

	jogador.queue_free()
	await get_tree().process_frame

	# Recorder novo (próxima fase) e run finalizada.
	var jogador2: Node = _novo_jogador()
	await get_tree().process_frame
	_confere(await _avancar_frames(5) > 0.0, "nova fase volta a contar")
	RunStats.finalizar()
	_confere(_perto(await _avancar_frames(5), 0.0), "run finalizada não conta")
	jogador2.queue_free()
	await get_tree().process_frame
	RunStats.reset()

	# Câmera lenta: 1 s real de jogo com time_scale 0,3 conta ~1 s.
	var jogador3: Node = _novo_jogador()
	await get_tree().process_frame
	Engine.time_scale = 0.3
	var inicio_ms: int = Time.get_ticks_msec()
	var antes: float = RunStats.tempo_s
	while Time.get_ticks_msec() - inicio_ms < 1000:
		await get_tree().process_frame
	var real_s: float = float(Time.get_ticks_msec() - inicio_ms) / 1000.0
	var contado: float = RunStats.tempo_s - antes
	Engine.time_scale = 1.0
	_confere(absf(contado - real_s) < 0.15, "time_scale 0,3: contado %.2f s vs real %.2f s" % [contado, real_s])
	jogador3.queue_free()
	await get_tree().process_frame


func _testar_sequencia() -> void:
	RunStats.reset()
	RunStats.registrar_abate(&"a", 3.0)
	RunStats.tempo_s = 2.0
	RunStats.registrar_abate(&"a", 3.0)
	RunStats.tempo_s = 5.0
	RunStats.registrar_abate(&"b", 3.0)  # exatamente 3,0 s depois: continua
	_confere(RunStats.maior_sequencia_abates == 3, "sequência continua dentro da janela")
	RunStats.tempo_s = 8.5
	RunStats.registrar_abate(&"b", 3.0)  # 3,5 s depois: recomeça
	_confere(RunStats.maior_sequencia_abates == 3, "sequência recomeça fora da janela")
	_confere(int(RunStats.abates_por_tipo[&"b"]) == 2, "abates por tipo")
	RunStats.reset()


## Eventos reais do EventBus chegam em RunStats (e o quiz da cena é encontrado).
func _testar_ganchos() -> void:
	RunStats.reset()
	var conexoes_antes: int = EventBus.enemy_died.get_connections().size()
	var quiz := (load("res://levels/Quiz/Quiz.tscn") as PackedScene).instantiate() as QuizScreen
	add_child(quiz)  # a cena de teste vira a "fase" onde o recorder procura o quiz
	var jogador: Node = _novo_jogador()
	await get_tree().process_frame
	await get_tree().process_frame
	var inimigo := Node2D.new()
	EventBus.enemy_died.emit(inimigo, &"drone", Vector2.ZERO)
	EventBus.enemy_died.emit(inimigo, &"drone", Vector2.ZERO)
	EventBus.enemy_died.emit(inimigo, &"tank", Vector2.ZERO)
	_confere(int(RunStats.abates_por_tipo[&"drone"]) == 2 and int(RunStats.abates_por_tipo[&"tank"]) == 1, "abates por tipo via EventBus")
	_confere(RunStats.maior_sequencia_abates == 3, "sequência via EventBus (mesmo frame)")
	EventBus.enemy_damaged.emit(inimigo, &"drone", 25, 15, 40)
	EventBus.enemy_damaged.emit(inimigo, &"drone", 15, 0, 40)
	_confere(_perto(RunStats.dano_causado, 40.0), "dano causado via EventBus")
	EventBus.player_damaged.emit(7)
	EventBus.player_damaged.emit(3)
	_confere(_perto(RunStats.dano_tomado, 10.0), "dano tomado via EventBus")
	quiz.resposta_registrada.emit(0, true, &"acerto")
	quiz.resposta_registrada.emit(1, false, &"erro")
	quiz.resposta_registrada.emit(2, true, &"acerto")
	_confere(RunStats.acertos_quiz == 2, "só acertos contam no quiz")
	RunStats.finalizar()
	EventBus.enemy_died.emit(inimigo, &"drone", Vector2.ZERO)
	EventBus.player_damaged.emit(50)
	_confere(int(RunStats.abates_por_tipo[&"drone"]) == 2 and _perto(RunStats.dano_tomado, 10.0), "run finalizada não registra mais")
	inimigo.free()
	jogador.queue_free()
	quiz.queue_free()
	await get_tree().process_frame
	_confere(EventBus.enemy_died.get_connections().size() == conexoes_antes, "sinais desconectados na saída")
	RunStats.reset()


func _testar_sem_sinais_de_pontuacao() -> void:
	var sinais: Array[Dictionary] = RunStats.new().get_signal_list()
	var proprios: int = 0
	for s: Dictionary in sinais:
		if not ClassDB.class_has_signal("RefCounted", s["name"]):
			proprios += 1
	_confere(proprios == 0, "RunStats não tem sinais próprios")

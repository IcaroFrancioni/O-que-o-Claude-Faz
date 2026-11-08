extends Node
## Regressões da auditoria de QA. R1, R5 e R6 reproduziam defeitos reais antes da correção (R2 a R4 são proteções).
## Rodar: godot --headless --path . res://qa/regressao_test.tscn

const FASE_2: String = "res://Scenes/Fase2/Fase2.tscn"
const FASE_3: String = "res://Scenes/Fase3/fase_3.tscn"
const ARQUIVO_TESTE: String = "user://returing_recordes_regressao_teste.cfg"

var _falhas: int = 0
var _total: int = 0
var _fase: Node = null
var _emissoes: Array[String] = []


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


func _telas() -> Array[ResultScreen]:
	var achadas: Array[ResultScreen] = []
	for filho: Node in _fase.get_children():
		if filho is ResultScreen:
			achadas.append(filho)
	return achadas


func _rodar() -> void:
	_regressao_config_incompleta()
	await _regressao_quiz_da_fase_2()
	await _regressao_fim_duplicado_e_entrada_no_hud()
	await _regressao_run_sem_inimigos()
	await _regressao_valor_zero()
	if _fase != null:
		_fase.queue_free()
		await _frames(3)
	if FileAccess.file_exists(ARQUIVO_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO_TESTE))
	print("regressao_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)


## R1: `limites_razao_vida` com menos de 3 valores (edição no Inspector) derrubava o cálculo.
func _regressao_config_incompleta() -> void:
	var cfg := ScoreConfig.new()
	cfg.limites_razao_vida = [2.0]
	var run := RunSnapshot.new()
	run.abates_por_tipo = {&"tank": 1}
	run.vida_max_inicial_jogador = 100.0
	var resultado: ScoreResult = ScoreCalculator.calcular(run, cfg)
	_confere(resultado != null and resultado.pontos_abates > 0, "R1: limites incompletos não derrubam o cálculo")


## R2: o quiz real da Fase 2 é encontrado e os acertos são contados.
func _regressao_quiz_da_fase_2() -> void:
	RunStats.reset()
	await _abrir_fase(FASE_2)
	var recorder: RunRecorder = _recorder()
	_confere(recorder != null, "R2: Player da Fase 2 tem o RunRecorder")
	if recorder == null:
		return
	await _frames(3)
	var quiz: QuizScreen = _fase.find_child("Quiz", true, false) as QuizScreen
	_confere(quiz != null, "R2: Fase 2 tem o QuizScreen")
	_confere(recorder._quiz == quiz and quiz != null, "R2: o recorder encontrou o quiz da fase")
	if quiz != null:
		quiz.resposta_registrada.emit(0, true, &"acerto")
		quiz.resposta_registrada.emit(1, false, &"erro")
		_confere(RunStats.acertos_quiz == 1, "R2: só o acerto do quiz real conta")


func _anota_menu() -> void:
	_emissoes.append("menu")


func _anota_cena(_caminho: String) -> void:
	_emissoes.append("cena")


## R3 e R4 foram hipóteses de defeito que a auditoria NÃO reproduziu; ficam como proteção contra regressão:
## R3: `level_completed("")` repetido não pode abrir duas telas; R4: Enter logo na abertura não pode acionar o HUD.
func _regressao_fim_duplicado_e_entrada_no_hud() -> void:
	RunStats.reset()
	await _abrir_fase(FASE_3)
	var recorder: RunRecorder = _recorder()
	recorder._config.atraso_tela_final_s = 0.1
	EventBus.main_menu_requested.connect(_anota_menu)
	EventBus.scene_change_requested.connect(_anota_cena)
	EventBus.level_completed.emit("")
	EventBus.level_completed.emit("")
	await get_tree().create_timer(0.35, true, false, true).timeout
	await _frames(3)
	_confere(_telas().size() == 1, "R3: duas notificações de fim abrem uma tela só (abriu %d)" % _telas().size())
	_confere(RunStats.tempos_por_fase.size() == 1, "R3: tempo da fase registrado uma vez (%d)" % RunStats.tempos_por_fase.size())

	for i: int in 6:  # Enter martelado nos primeiros instantes (HUD com o botão Menu focado)
		var ev := InputEventAction.new()
		ev.action = &"ui_accept"
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
	_confere(_emissoes.is_empty(), "R4: Enter na abertura não aciona botões do HUD (%s)" % [_emissoes])
	EventBus.main_menu_requested.disconnect(_anota_menu)
	EventBus.scene_change_requested.disconnect(_anota_cena)
	for tela: ResultScreen in _telas():
		tela.queue_free()
	await _frames(2)
	get_tree().paused = false


## R5: sem inimigos abatidos o título "INIMIGOS ABATIDOS" ficava invisível no fim natural da animação
## (e aparecia depois de "pular").
func _regressao_run_sem_inimigos() -> void:
	var run := RunSnapshot.new()
	run.tempo_s = 400.0
	run.tempos_por_fase = [100.0, 100.0, 200.0]
	run.vida_max_inicial_jogador = 100.0
	var resultado: ScoreResult = ScoreCalculator.calcular(run, ScoreConfig.carregar())
	var tela: ResultScreen = ResultScreen.abrir(self, resultado, {}, true)
	tela.entrada_ignorada_s = 0.0
	var terminou: Array[bool] = [false]
	tela.animacao_terminou.connect(func() -> void: terminou[0] = true)
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	tela._input(ev)  # 1º pular: acelera, mas o fim ainda é natural
	var inicio_ms: int = Time.get_ticks_msec()
	while not terminou[0] and Time.get_ticks_msec() - inicio_ms < 15000:
		await get_tree().process_frame
	_confere(terminou[0], "R5: animação sem inimigos termina")
	_confere(tela._cabecalho_inimigos.modulate.a == 1.0, "R5: cabeçalho de inimigos visível no fim natural")
	tela.queue_free()
	await _frames(2)
	get_tree().paused = false


## R6: sem dano tomado a tela mostrava "-0" (e "+0" nos bônus vazios); zero é só "0".
func _regressao_valor_zero() -> void:
	var run := RunSnapshot.new()
	run.tempo_s = 400.0
	run.vida_max_inicial_jogador = 100.0
	var resultado: ScoreResult = ScoreCalculator.calcular(run, ScoreConfig.carregar())
	var tela: ResultScreen = ResultScreen.abrir(self, resultado, {}, false)
	_confere(tela._linha_penalidade.valor.text == "0", "R6: dano tomado zero aparece como 0 (apareceu '%s')" % tela._linha_penalidade.valor.text)
	_confere(tela._linhas_extras_ui[1].valor.text == "0", "R6: bônus zerado aparece como 0 (apareceu '%s')" % tela._linhas_extras_ui[1].valor.text)
	tela.queue_free()
	await _frames(2)
	get_tree().paused = false

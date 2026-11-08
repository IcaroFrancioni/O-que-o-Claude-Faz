extends Node
## Testes da tela final: duração da sequência, "pular" (1ª vez acelera, 2ª vai ao fim) e estado final.
## Rodar: godot --headless --path . res://qa/result_test.tscn   (leva ~25 s: mede tempo real)

const DURACAO_MIN_S: float = 15.0
const DURACAO_MAX_S: float = 20.0
const ESPERA_MAXIMA_S: float = 40.0

var _falhas: int = 0
var _total: int = 0
var _resultado: ScoreResult = null
var _recorde: Dictionary = {}


func _ready() -> void:
	_rodar.call_deferred()


func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


func _rodar() -> void:
	_montar_dados()
	_testar_formatos()
	await _testar_duracao_completa()
	await _testar_pular()
	print("result_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)


func _montar_dados() -> void:
	var cfg: ScoreConfig = ScoreConfig.carregar()
	var run := RunSnapshot.new()
	run.tempo_s = 780.0
	run.tempos_por_fase = [190.0, 220.0, 370.0]
	run.abates_por_tipo = {&"drone": 8, &"robo": 9, &"tank": 6, &"guide": 1}
	run.maior_sequencia_abates = 5
	run.dano_causado = 5400.0
	run.dano_tomado = 200.0
	run.acertos_quiz = 3
	run.vida_max_inicial_jogador = 100.0
	_resultado = ScoreCalculator.calcular(run, cfg)
	_recorde = {"novo_recorde": true, "anterior": {"total": 12000, "rank": &"B", "tempo_s": 900.0},
			"atual": {"total": _resultado.total, "rank": _resultado.rank, "tempo_s": run.tempo_s}}


func _testar_formatos() -> void:
	_confere(ResultScreen.formatar_tempo(1020.32) == "17:00.32", "tempo 17:00.32")
	_confere(ResultScreen.formatar_tempo(0.0) == "00:00.00", "tempo zero")
	_confere(ResultScreen.formatar_tempo(61.5) == "01:01.50", "tempo 01:01.50")
	_confere(ResultScreen.formatar_parcial(190.0) == "03:10", "parcial 03:10")
	_confere(ResultScreen.formatar_decimal(3.0) == "3,0", "decimal com vírgula")


func _nova_tela(animar: bool) -> ResultScreen:
	var tela: ResultScreen = ResultScreen.abrir(self, _resultado, _recorde, animar)
	return tela


func _fechar(tela: ResultScreen) -> void:
	tela.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _aperta_accept(tela: ResultScreen) -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	tela._input(ev)


func _confere_estado_final(tela: ResultScreen, rotulo: String) -> void:
	_confere(tela._estado == ResultScreen.Estado.FIM, rotulo + ": estado FIM")
	_confere(tela._linha_total.valor.text == str(_resultado.total), rotulo + ": total final exibido")
	_confere(tela._linha_penalidade.valor.text == "-%d" % _resultado.penalidade, rotulo + ": decréscimo exibido")
	_confere(tela._odometro.text.contains("%d" % _resultado.total), rotulo + ": odômetro no total")
	_confere(tela._letra_rank.text == String(_resultado.rank), rotulo + ": letra do rank")
	_confere(tela._letra_rank.scale == Vector2.ONE, rotulo + ": letra com escala 1")
	_confere(is_equal_approx(tela._nome_rank.visible_ratio, 1.0), rotulo + ": nome do rank completo")
	_confere(tela._botao_jogar.has_focus(), rotulo + ": foco no primeiro botão")
	_confere(tela._botoes.modulate.a == 1.0, rotulo + ": botões visíveis")


func _testar_duracao_completa() -> void:
	Engine.time_scale = 0.3  # a tela precisa devolver para 1.0
	var inicio_ms: int = Time.get_ticks_msec()
	var tela: ResultScreen = _nova_tela(true)
	_confere(Engine.time_scale == 1.0, "entra com Engine.time_scale = 1.0")
	_confere(get_tree().paused, "pausa a árvore enquanto aberta")
	_confere(tela._estado == ResultScreen.Estado.ANIMANDO, "começa animando")
	_confere(tela._botao_jogar.focus_mode == Control.FOCUS_NONE, "botões sem foco durante a animação")

	var terminou: Array[bool] = [false]
	tela.animacao_terminou.connect(func() -> void: terminou[0] = true)
	while not terminou[0] and float(Time.get_ticks_msec() - inicio_ms) / 1000.0 < ESPERA_MAXIMA_S:
		await get_tree().process_frame
	var duracao: float = float(Time.get_ticks_msec() - inicio_ms) / 1000.0
	print("  duração da sequência completa: %.2f s" % duracao)
	_confere(terminou[0], "a animação termina")
	_confere(duracao >= DURACAO_MIN_S and duracao <= DURACAO_MAX_S,
			"duração %.2f s entre %.0f e %.0f s" % [duracao, DURACAO_MIN_S, DURACAO_MAX_S])
	_confere_estado_final(tela, "fim natural")
	await _fechar(tela)
	_confere(not get_tree().paused, "fechar a tela despausa a árvore")


func _testar_pular() -> void:
	# Entradas logo no começo são ignoradas.
	var tela: ResultScreen = _nova_tela(true)
	_aperta_accept(tela)
	_confere(tela._estado == ResultScreen.Estado.ANIMANDO, "entrada nos primeiros instantes é ignorada")
	await get_tree().create_timer(tela.entrada_ignorada_s + 0.1, true, false, true).timeout

	# 1ª vez: acelera ×4.
	var inicio_ms: int = Time.get_ticks_msec()
	_aperta_accept(tela)
	_confere(tela._estado == ResultScreen.Estado.RAPIDO, "1º pular: modo rápido")
	_confere(is_equal_approx(tela._velocidade, tela.velocidade_rapida), "1º pular: velocidade ×4")
	_confere(tela._estado != ResultScreen.Estado.FIM, "1º pular não vai ao fim")

	# 2ª vez: vai direto ao estado final.
	_aperta_accept(tela)
	_confere_estado_final(tela, "2º pular")
	_confere(float(Time.get_ticks_msec() - inicio_ms) < 500.0, "2º pular é imediato")
	await _fechar(tela)

	# Só 1 pular e esperar: termina em cerca de 1/4 do tempo.
	tela = _nova_tela(true)
	await get_tree().create_timer(tela.entrada_ignorada_s + 0.1, true, false, true).timeout
	var terminou: Array[bool] = [false]
	tela.animacao_terminou.connect(func() -> void: terminou[0] = true)
	inicio_ms = Time.get_ticks_msec()
	_aperta_accept(tela)
	while not terminou[0] and float(Time.get_ticks_msec() - inicio_ms) / 1000.0 < ESPERA_MAXIMA_S:
		await get_tree().process_frame
	var rapida: float = float(Time.get_ticks_msec() - inicio_ms) / 1000.0
	print("  restante da sequência a ×4: %.2f s" % rapida)
	_confere(terminou[0] and rapida < DURACAO_MAX_S / 3.0, "a ×4 o restante termina bem mais rápido")
	await _fechar(tela)

	# Sem animação: já nasce no estado final.
	tela = _nova_tela(false)
	_confere_estado_final(tela, "sem animação")
	await _fechar(tela)

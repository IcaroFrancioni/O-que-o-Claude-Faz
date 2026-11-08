extends Node
## Modo comando com teclas simuladas numa fase real: Ctrl abre, setas digitam, Enter confirma; o Alan anda livre.
## Rodar: godot --headless --path . res://qa/ctrl_test.tscn

var _falhas: int = 0
var _total: int = 0
var _fase: Node = null
var _ativadas: Array[StringName] = []


func _ready() -> void:
	_rodar.call_deferred()


func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	print(("  ok    " if condicao else "  FALHA ") + nome)
	if not condicao:
		_falhas += 1


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _tecla(keycode: Key, apertada: bool, ctrl: bool = false, localizacao: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = apertada
	ev.ctrl_pressed = ctrl
	ev.location = localizacao
	Input.parse_input_event(ev)


## Aperta e solta cada tecla em sequência.
func _digitar(teclas: Array[Key]) -> void:
	for tecla: Key in teclas:
		_tecla(tecla, true)
		await _frames(2)
		_tecla(tecla, false)
		await _frames(2)


func _rodar() -> void:
	RunState.reset()
	_fase = (load("res://Scenes/Fase1/fase_1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_fase)
	get_tree().current_scene = _fase
	await _frames(20)
	var player: Player = _fase.find_child("Player", true, false) as Player
	var hab: AbilityComponent = player.get_node("AbilityComponent") as AbilityComponent
	_confere(hab._setup_done, "AbilityComponent terminou o setup")
	hab.ability_activated.connect(func(d: AbilityData) -> void: _ativadas.append(d.id))
	var avisos: Array[StringName] = []
	hab.command_unavailable.connect(func(m: StringName) -> void: avisos.append(m))

	# 1) Sem habilidades (início da run): Ctrl só avisa.
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)
	await _frames(3)
	_confere(not hab.command_active, "sem habilidades: modo comando não abre")
	_confere(avisos.has(&"sem_habilidades"), "sem habilidades: o aviso é emitido (%s)" % [avisos])
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(3)

	# 2) Com uma habilidade (Escudo: cima, baixo, esquerda, direita).
	var escudo: AbilityData = load("res://abilities/data/escudo.tres") as AbilityData
	hab.abilities = [escudo]
	var falhas_sinal: Array[int] = [0]
	hab.input_failed.connect(func() -> void: falhas_sinal[0] += 1)
	_confere(player.state == Player.State.IDLE, "Player parado (IDLE)")

	# Apertar e soltar o Ctrl já basta: o modo fica aberto (não precisa segurar).
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(3)
	_confere(hab.command_active, "Ctrl esquerdo (apertar e soltar) abre o modo comando")
	_confere(is_equal_approx(Engine.time_scale, 0.2) and is_equal_approx(hab.command_time_scale, 0.2),
			"câmera lenta em 0.2 com o modo aberto (%.2f)" % Engine.time_scale)

	# O jogador continua livre para andar com o modo aberto.
	var x0: float = player.global_position.x
	_tecla(KEY_D, true)
	await get_tree().create_timer(0.6, true, false, true).timeout  # tempo real: a câmera lenta atrasa a física
	_confere(player.state == Player.State.MOVE and player.global_position.x > x0 + 1.0,
			"modo aberto: o Alan anda com WASD")
	_tecla(KEY_D, false)
	await _frames(3)

	# Sequência errada + Enter: erro, o modo continua aberto e o buffer zera.
	await _digitar([KEY_UP, KEY_UP])
	await _digitar([KEY_ENTER])
	_confere(falhas_sinal[0] == 1 and hab.command_active and hab._sequence.is_empty(),
			"sequência errada + Enter: erro, modo continua aberto")

	# Backspace apaga a última seta.
	await _digitar([KEY_UP, KEY_DOWN, KEY_BACKSPACE])
	_confere(hab._sequence.size() == 1, "Backspace apaga a última seta")
	await _digitar([KEY_BACKSPACE])

	# Sequência certa: só dispara no Enter, e o Enter fecha o modo.
	await _digitar([KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT])
	_confere(not _ativadas.has(&"escudo"), "setas completas sem Enter: ainda não ativa")
	await _digitar([KEY_ENTER])
	_confere(_ativadas.has(&"escudo"), "sequência ↑↓←→ + Enter ativou o Escudo (%s)" % [_ativadas])
	_confere(not hab.command_active, "Enter fecha o modo comando")
	_confere(is_equal_approx(Engine.time_scale, 1.0), "Enter devolve o tempo normal")

	# 3) As setas não movem o Alan.
	var pos: Vector2 = player.global_position
	_tecla(KEY_UP, true)
	await _frames(12)
	_confere(player.state == Player.State.IDLE and player.global_position.distance_to(pos) < 0.5,
			"seta para cima não move o Alan")
	_tecla(KEY_UP, false)
	await _frames(3)

	# 4) Ctrl direito abre e apertar o Ctrl de novo cancela.
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_RIGHT)
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_RIGHT)
	await _frames(3)
	_confere(hab.command_active, "Ctrl direito abre o modo comando")
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_RIGHT)
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_RIGHT)
	await _frames(3)
	_confere(not hab.command_active, "apertar o Ctrl de novo cancela o modo")

	_fase.queue_free()
	await _frames(3)
	Engine.time_scale = 1.0
	print("ctrl_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)

extends Node
## As 9 habilidades novas num fluxo de jogo real: fase de verdade (ondas, inimigos e chefe de verdade) e
## ativação como o jogador faz (Ctrl, setas e Enter por eventos de teclado), sem chamar `_activate` direto.
## Cada efeito roda por 1,5 s de jogo e é cortado; no fim confere que nada ficou alterado (atributos, velocidade
## dos inimigos, drone, minas). Qualquer erro de script aparece no console.
##   godot --headless --path . res://tests/habilidades_fluxo_test.tscn   (leva ~1 min)

const FASE_2: String = "res://Scenes/Fase2/Fase2.tscn"
const FASE_3: String = "res://Scenes/Fase3/fase_3.tscn"
## Direção da seta -> tecla (AbilityData.Dir: UP, DOWN, LEFT, RIGHT).
const TECLAS_SETA: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
const IDS: Array[StringName] = [
	&"reflexos", &"carga_rapida", &"pele_de_ferro", &"pulso_gelido", &"mina_binaria",
	&"drone_aliado", &"tiro_em_leque", &"maquina_enigma", &"overclock",
]
const ATRIBUTOS: Array[StringName] = [
	StatModifiers.DASH_COOLDOWN, StatModifiers.CHARGE_TIME, StatModifiers.DAMAGE_TAKEN,
	StatModifiers.DAMAGE, StatModifiers.MOVE_SPEED,
]

var _falhas: int = 0
var _total: int = 0
var _fase: Node = null
var _player: Player = null
var _hab: AbilityComponent = null
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


## Espera `s` segundos de JOGO (o tempo de física avança com Engine.time_scale).
func _jogo(s: float) -> void:
	var frames: int = int(s * float(Engine.physics_ticks_per_second))
	for i: int in frames:
		await get_tree().physics_frame


func _tecla(keycode: Key, apertada: bool, ctrl: bool = false, lado: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = apertada
	ev.ctrl_pressed = ctrl
	ev.location = lado
	Input.parse_input_event(ev)


func _abrir_fase(caminho: String) -> void:
	if _fase != null:
		_fase.queue_free()
		await _frames(4)
	RunState.reset()
	_fase = (load(caminho) as PackedScene).instantiate()
	get_tree().root.add_child(_fase)
	get_tree().current_scene = _fase
	await _frames(20)
	_player = _fase.find_child("Player", true, false) as Player
	_hab = _player.get_node("AbilityComponent") as AbilityComponent
	_hab.command_time_scale = 1.0  # sem câmera lenta: o teste só digita
	_ativadas.clear()
	_hab.ability_activated.connect(func(d: AbilityData) -> void: _ativadas.append(d.id))


## Ctrl, a sequência e Enter, como o jogador.
func _digitar(data: AbilityData) -> void:
	_tecla(KEY_CTRL, true, false, KEY_LOCATION_LEFT)
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(3)
	for dir: int in data.sequence:
		_tecla(TECLAS_SETA[dir], true)
		await _frames(2)
		_tecla(TECLAS_SETA[dir], false)
		await _frames(2)
	_tecla(KEY_ENTER, true)
	await _frames(2)
	_tecla(KEY_ENTER, false)
	await _frames(2)


func _inimigos_vivos() -> Array[EnemyBase]:
	var lista: Array[EnemyBase] = []
	for no: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var inimigo: EnemyBase = no as EnemyBase
		if inimigo != null and CombatUtils.is_targetable(inimigo):
			lista.append(inimigo)
	return lista


func _velocidades() -> Dictionary:
	var mapa: Dictionary = {}
	for inimigo: EnemyBase in _inimigos_vivos():
		mapa[inimigo.get_instance_id()] = inimigo.move_speed
	return mapa


func _rodar() -> void:
	await _abrir_fase(FASE_2)
	_hab.abilities.clear()
	for id: StringName in IDS:
		var dados: AbilityData = load("res://abilities/data/%s.tres" % id) as AbilityData
		_hab.abilities.append(dados)
	_hab.abilities_changed.emit()
	await _frames(5)
	var antes: Dictionary = _velocidades()
	print("-- Fase 2 (%d inimigos)" % antes.size())
	for id: StringName in IDS:
		var dados: AbilityData = _hab.abilities[IDS.find(id)]
		_ativadas.clear()
		_hab._cooldowns.clear()
		_player.hp = _player.hp_maximo
		await _digitar(dados)
		_confere(_ativadas.has(id), "%s: Ctrl + setas + Enter ativou" % id)
		_confere(_hab.get_cooldown_left(id) > 0.0, "%s: recarga iniciada (%.0f s)" % [id, _hab.get_cooldown_left(id)])
		_confere(not _hab.command_active, "%s: o modo comando fechou" % id)
		await _jogo(1.5)
		match id:
			&"mina_binaria":
				_confere(get_tree().get_nodes_in_group(BinaryMine.GROUP_MINES).size() >= 1, "%s: a mina está no chão" % id)
			&"drone_aliado":
				_confere(_player.get_node_or_null("AllyDrone") != null, "%s: o drone está orbitando" % id)
			&"pulso_gelido", &"maquina_enigma":
				var lentos: int = 0
				for inimigo: EnemyBase in _inimigos_vivos():
					lentos += 1 if EnemySlow.is_slowed(inimigo) else 0
				_confere(lentos > 0 or _inimigos_vivos().is_empty(), "%s: há inimigos lentos (%d)" % [id, lentos])
			&"reflexos", &"carga_rapida", &"pele_de_ferro", &"overclock":
				var mudou: bool = false
				for atributo: StringName in ATRIBUTOS:
					mudou = mudou or _hab.stats.get_mult(atributo) != 1.0
				_confere(mudou, "%s: os atributos do jogador mudaram" % id)
		_hab._cancel_all_effects()
		await _frames(3)
		for atributo: StringName in ATRIBUTOS:
			_confere(_hab.stats.get_mult(atributo) == 1.0, "%s: %s voltou a 1.0 ao cortar o efeito" % [id, atributo])
		_confere(_player.get_node_or_null("AllyDrone") == null, "%s: nenhum drone sobrou" % id)
	for no: Node in get_tree().get_nodes_in_group(BinaryMine.GROUP_MINES):
		(no as BinaryMine).recycle()

	# Velocidade dos inimigos: quem sobreviveu voltou exatamente ao valor de antes.
	var depois: Dictionary = _velocidades()
	var diferentes: int = 0
	for chave: Variant in depois:
		if antes.has(chave) and antes[chave] != depois[chave]:
			diferentes += 1
	_confere(diferentes == 0, "Fase 2: nenhum inimigo ficou com a velocidade alterada (%d diferentes)" % diferentes)

	# Com o chefe da fase 3: Pulso Gélido não o afeta e a Enigma o deixa 30% mais lento.
	await _abrir_fase(FASE_3)
	_hab.abilities.clear()
	for id: StringName in [&"pulso_gelido", &"maquina_enigma"]:
		_hab.abilities.append(load("res://abilities/data/%s.tres" % id) as AbilityData)
	_hab.abilities_changed.emit()
	await _frames(5)
	var chefe: EnemyBase = null
	for inimigo: EnemyBase in _inimigos_vivos():
		if inimigo.enemy_kind == &"guide":
			chefe = inimigo
	print("-- Fase 3 (chefe %s)" % ("encontrado" if chefe != null else "não encontrado"))
	if chefe != null:
		var base: float = chefe.move_speed
		_player.global_position = chefe.global_position + Vector2(40, 0)
		_hab._cooldowns.clear()
		await _digitar(_hab.abilities[0])
		await _jogo(0.5)
		_confere(chefe.move_speed == base, "chefe: o Pulso Gélido não o afeta")
		_hab._cancel_all_effects()
		_hab._cooldowns.clear()
		await _digitar(_hab.abilities[1])
		await _jogo(0.5)
		_confere(is_equal_approx(chefe.move_speed, base * 0.7), "chefe: a Enigma o deixa 30%% mais lento (%.1f -> %.1f)" % [base, chefe.move_speed])
		_hab._cancel_all_effects()
		await _frames(3)
		_confere(chefe.move_speed == base, "chefe: velocidade original exata depois de cortar a Enigma")
	_fase.queue_free()
	await _frames(3)
	print("habilidades_fluxo_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)

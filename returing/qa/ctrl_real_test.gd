extends Node
## Modo comando (Ctrl, setas, Enter) num fluxo de jogo real, sem atalhos: ondas de verdade, XP de verdade, menu de
## level-up respondido pelo teclado, habilidade aprendida pelo menu e Ctrl em cada fase.
## Rodar: godot --headless --path . res://qa/ctrl_real_test.tscn   (leva ~20 s)

const FASES: Array[String] = [
	"res://Scenes/Fase1/fase_1.tscn",
	"res://Scenes/Fase2/Fase2.tscn",
	"res://Scenes/Fase3/fase_3.tscn",
]
## Direção da seta -> tecla (AbilityData.Dir: UP, DOWN, LEFT, RIGHT).
const TECLAS_SETA: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

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


func _segundos(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _tecla(keycode: Key, apertada: bool, ctrl: bool = false, lado: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = apertada
	ev.ctrl_pressed = ctrl
	ev.location = lado
	Input.parse_input_event(ev)


func _acao(nome: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = nome
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = InputEventAction.new()
	ev.action = nome
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(2)


func _abrir_fase(caminho: String) -> void:
	if _fase != null:
		_fase.queue_free()
		await _frames(4)
	_fase = (load(caminho) as PackedScene).instantiate()
	get_tree().root.add_child(_fase)
	get_tree().current_scene = _fase
	await _frames(20)
	_player = _fase.find_child("Player", true, false) as Player
	_hab = _player.get_node("AbilityComponent") as AbilityComponent
	_ativadas.clear()
	_hab.ability_activated.connect(func(d: AbilityData) -> void: _ativadas.append(d.id))


func _matar_inimigos() -> int:
	var mortos: int = 0
	for inimigo: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		if CombatUtils.apply_damage(inimigo, 99999, _player):
			mortos += 1
	return mortos


## Usa o modo comando como o jogador: aperta Ctrl, digita a sequência da habilidade e confirma com Enter.
## `em_recarga` = não zera a recarga: a sequência deve ser recusada (comportamento do jogo, 20 s).
func _usar_habilidade(rotulo: String, andando: bool, em_recarga: bool = false) -> void:
	var data: AbilityData = _hab.abilities[0]
	_ativadas.clear()
	var recusas: Array[int] = [0]
	var contar: Callable = func() -> void: recusas[0] += 1
	_hab.input_failed.connect(contar)
	if not em_recarga:
		_hab._cooldowns.clear()  # cada uso do teste começa com a habilidade pronta
	if andando:
		_tecla(KEY_D, true)
		await _frames(12)
		_confere(_player.state == Player.State.MOVE, rotulo + ": Player andando (MOVE)")
	_tecla(KEY_CTRL, true, false, KEY_LOCATION_LEFT)
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(3)
	_confere(_hab.command_active, rotulo + ": Ctrl abre o modo comando")
	for dir: int in data.sequence:
		_tecla(TECLAS_SETA[dir], true)
		await _frames(2)
		_tecla(TECLAS_SETA[dir], false)
		await _frames(2)
	_confere(not _ativadas.has(data.id), rotulo + ": sem Enter não ativa")
	_tecla(KEY_ENTER, true)
	await _frames(2)
	_tecla(KEY_ENTER, false)
	await _frames(2)
	if em_recarga:
		_confere(not _ativadas.has(data.id) and recusas[0] > 0, rotulo + ": em recarga a sequência é recusada")
	else:
		_confere(_ativadas.has(data.id), rotulo + ": sequência ativou '%s'" % data.id)
		_confere(_hab.get_cooldown_left(data.id) > 0.0, rotulo + ": recarga iniciada (%.0f s)" % _hab.get_cooldown_left(data.id))
	_hab.input_failed.disconnect(contar)
	if em_recarga:  # erro mantém o modo aberto: cancela com o Ctrl
		_confere(_hab.command_active, rotulo + ": erro mantém o modo aberto")
		_tecla(KEY_CTRL, true, false, KEY_LOCATION_LEFT)
		await _frames(3)
		_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(5)
	_confere(not _hab.command_active, rotulo + ": modo fechado ao final")
	_confere(is_equal_approx(Engine.time_scale, 1.0), rotulo + ": tempo normal")
	if andando:
		_tecla(KEY_D, false)
		await _frames(3)


func _rodar() -> void:
	RunState.reset()  # run nova, como ao iniciar o jogo
	await _abrir_fase(FASES[0])
	print("== Fase 1 ==")
	_confere(_hab.abilities.is_empty(), "início da run: sem habilidades")
	_player.conceder_invulnerabilidade(9999.0)

	# Sem habilidade o Ctrl só avisa.
	var avisos: Array[StringName] = []
	_hab.command_unavailable.connect(func(m: StringName) -> void: avisos.append(m))
	_tecla(KEY_CTRL, true, false, KEY_LOCATION_LEFT)
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(3)
	_confere(not _hab.command_active and avisos.has(&"sem_habilidades"), "sem habilidades: Ctrl só avisa")

	# Joga de verdade: as ondas nascem sozinhas e cada abate dá XP, até o nível 1.
	var mortos: int = 0
	var inicio_ms: int = Time.get_ticks_msec()
	while RunState.level < 1 and Time.get_ticks_msec() - inicio_ms < 40000:
		mortos += _matar_inimigos()
		await _frames(5)
	_confere(RunState.level >= 1, "ondas reais deram XP até o nível 1 (%d abates, xp %d)" % [mortos, RunState.xp])

	# Menu de level-up: abre sozinho com o jogo livre, pausa a árvore, escolhe-se com o teclado.
	var menu: LevelUpMenu = null
	inicio_ms = Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio_ms < 5000:
		menu = _player.find_child("LevelUpMenu", true, false) as LevelUpMenu
		if menu != null and menu.is_open():
			break
		await _frames(2)
	_confere(menu != null and menu.is_open(), "menu de level-up abriu sozinho")
	_confere(get_tree().paused, "menu pausa o jogo")
	# Ctrl com o menu aberto não pode abrir o modo comando.
	_tecla(KEY_CTRL, true, false, KEY_LOCATION_LEFT)
	await _frames(3)
	_confere(not _hab.command_active, "menu aberto: Ctrl não abre o modo comando")
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(2)
	await _segundos(menu.input_delay + 0.2)
	for tentativa: int in 4:
		if not menu.is_open():
			break
		await _acao(&"ui_accept")  # carta focada; se for lendária, confirma
		await _segundos(0.3)
	_confere(not menu.is_open() and not get_tree().paused, "carta escolhida pelo teclado; o jogo volta a rodar")
	_confere(_hab.abilities.size() == 1, "habilidade aprendida pelo menu: %s" % [_hab.abilities.map(func(a: AbilityData) -> StringName: return a.id)])
	if _hab.abilities.is_empty():
		_fim()
		return
	_player.conceder_invulnerabilidade(9999.0)

	await _usar_habilidade("Fase 1 parado", false)
	await _usar_habilidade("Fase 1 em recarga", false, true)
	await _usar_habilidade("Fase 1 andando", true)

	# Com inimigos vivos em volta.
	inicio_ms = Time.get_ticks_msec()
	while get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY).is_empty() and Time.get_ticks_msec() - inicio_ms < 8000:
		await _frames(5)
	_confere(not get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY).is_empty(), "há inimigos vivos na fase")
	await _usar_habilidade("Fase 1 com inimigos", false)

	# As outras fases herdam a run (habilidades restauradas pelo RunState).
	for i: int in [1, 2]:
		await _abrir_fase(FASES[i])
		print("== Fase %d ==" % (i + 1))
		_player.conceder_invulnerabilidade(9999.0)
		_confere(_hab.abilities.size() == 1, "habilidade restaurada na fase")
		if not _hab.abilities.is_empty():
			await _usar_habilidade("Fase %d" % (i + 1), false)
	_fim()


func _fim() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	print("ctrl_real_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)

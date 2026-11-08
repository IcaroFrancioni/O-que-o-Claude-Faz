extends Node
## Teste automatizado do modo celular. Rode com:
##   godot --path . res://tests/mobile_test.tscn -- --mobile
## Injeta toques reais (InputEventScreenTouch/Drag) e confere tiro, espada, câmera, escala e mira assistida.

const LEVEL: String = "res://Scenes/Fase2/Fase2.tscn"

var _fails: int = 0
var _checks: int = 0
var _player: Player = null
var _mc: Node = null
var _plat: Node = null


var root: Window = null


func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()


func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label)


## Posição lógica (coordenadas do jogo) -> pixel da janela (o stretch do projeto muda a escala).
func _to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos


func paused_dbg() -> bool:
	return get_tree().paused


var _was_paused: bool = false


func frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame
		if get_tree().paused != _was_paused:
			_was_paused = get_tree().paused
			print("   EVT paused=", _was_paused, " quiz=", get_tree().current_scene, " ", root.find_children("Quiz","",true,false).map(func(node): return node.visible), " pause=", root.find_children("Pause","",true,false).map(func(node): return node.visible))


func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _to_window(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _to_window(pos)
	Input.parse_input_event(e)


func active_projectiles() -> Array[PlayerProjectile]:
	var out: Array[PlayerProjectile] = []
	for n: Node in root.find_children("*", "PlayerProjectile", true, false):
		var p := n as PlayerProjectile
		if p.is_in_use():
			out.append(p)
	return out


func reset_player() -> void:
	_player.global_position = Vector2(560, 330)
	_player.velocity = Vector2.ZERO
	_player.hp = _player.hp_maximo
	for p: PlayerProjectile in active_projectiles():
		p.recycle()
	await frames(30)


## Toca no analógico de mira na direção `angle` e solta depois de `hold` quadros. Devolve o 1º tiro.
func tap_shot(angle: float, hold: int) -> Dictionary:
	var aim_center: Vector2 = _mc.call("_rest_aim")
	var dir := Vector2.from_angle(angle)
	touch(0, aim_center + dir * 60.0, true)
	await frames(hold)
	touch(0, aim_center + dir * 60.0, false)
	var shot: Dictionary = {}
	for i: int in 30:
		await get_tree().physics_frame
		var list: Array[PlayerProjectile] = active_projectiles()
		if not list.is_empty():
			var p: PlayerProjectile = list[0]
			shot = {"dir": p.direction, "damage": p.damage, "scale": p.scale.x, "pos": p.global_position,
					"frames": i}
			break
	return shot


func _run() -> void:
	_mc = root.get_node("MobileControls")
	_plat = root.get_node("Platform")
	EventBus.level_completed.connect(func(n: String) -> void: print("   EVT level_completed ", n, " t=", Time.get_ticks_msec()))
	EventBus.player_died.connect(func() -> void: print("   EVT player_died"))
	EventBus.game_over.connect(func() -> void: print("   EVT game_over"))
	EventBus.level_started.connect(func() -> void: print("   EVT level_started"))
	var packed: PackedScene = load(LEVEL)
	var level: Node = packed.instantiate()
	root.add_child(level)
	get_tree().current_scene = level  # como no jogo: tiros e efeitos nascem sob a fase
	await frames(10)
	_player = level.get_node("Player") as Player
	await frames(30)

	print("-- Escala, câmera e valores base")
	check(_plat.is_mobile, "_plat.is_mobile")
	check(is_equal_approx(_player.scale.x, 1.5), "player com 150%% do tamanho (%s)" % _player.scale)
	var cam: Camera2D = root.get_viewport().get_camera_2d()
	check(cam != null and cam is FollowCamera, "FollowCamera ativa")
	check(cam != null and is_equal_approx(cam.zoom.x, 2.0), "zoom 2x")
	check(_player.max_damage == 68, "dano máximo do tiro = 68 (+70%%) (%d)" % _player.max_damage)
	check(_player.weapon.damage == 50, "dano da espada = 50 (dobro) (%d)" % _player.weapon.damage)
	var sword := _player.weapon as Sword
	var shape := sword.hitbox_shape.shape as CircleShape2D
	check(is_equal_approx(shape.radius, 28.0 * 1.4), "hitbox da espada +40%% (raio %.1f)" % shape.radius)

	print("-- Câmera segue o player")
	_player.global_position = Vector2(700, 300)
	await frames(60)
	check(cam.get_screen_center_position().distance_to(Vector2(700, 300)) < 3.0,
			"câmera centrada no player (%s)" % cam.get_screen_center_position())
	_player.global_position = Vector2(5, 5)
	await frames(60)
	var c2: Vector2 = cam.get_screen_center_position()
	check(c2.x >= 0.0 and c2.y >= 0.0, "câmera respeita o limite (%s)" % c2)

	print("-- Botão de arma: alterna para o tiro")
	await reset_player()
	var wb: Vector2 = _mc.call("_button_center", &"weapon")
	touch(1, wb, true)
	await frames(2)
	touch(1, wb, false)
	await frames(2)
	check(_mc.weapon_ranged, "weapon_ranged = true")

	print("-- Toque rápido (1 quadro) em 8 direções + 2 ângulos quebrados, sem inimigo")
	var angles: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0, 22.0, 200.0]
	for a: float in angles:
		await reset_player()
		var shot: Dictionary = await tap_shot(deg_to_rad(a), 1)
		var ok: bool = not shot.is_empty()
		check(ok, "toque em %d°: saiu tiro" % int(a))
		if ok:
			var got: float = rad_to_deg((shot["dir"] as Vector2).angle())
			var diff: float = absf(wrapf(got - a, -180.0, 180.0))
			check(diff < 2.0, "toque em %d°: direção %.1f° (erro %.1f°)" % [int(a), got, diff])
			check(int(shot["damage"]) >= 20, "toque em %d°: dano %d >= mínimo" % [int(a), int(shot["damage"])])

	print("-- Tiro carregado (segurar 1.5 s)")
	await reset_player()
	var charged: Dictionary = await tap_shot(deg_to_rad(30.0), 90)
	check(not charged.is_empty(), "tiro carregado saiu")
	print("   DBG shown=", _mc._shown, " blocked=", _mc._blocked, " paused=", paused_dbg(), " state=", _player.state, " hp=", _player.hp, " dead=", _player.esta_morto(), " fingers=", _mc._fingers)
	if not charged.is_empty():
		check(int(charged["damage"]) == 68, "dano carregado = 68 (%d)" % int(charged["damage"]))
		check(is_equal_approx(float(charged["scale"]), 4.5), "escala do tiro carregado = 4.5 (%.2f)" % float(charged["scale"]))

	print("-- Arrastar o analógico depois de tocar muda a direção")
	await reset_player()
	var center: Vector2 = _mc.call("_rest_aim")
	touch(0, center + Vector2(60, 0), true)
	await frames(3)
	drag(0, center + Vector2(0, 60))
	await frames(3)
	touch(0, center + Vector2(0, 60), false)
	var shot_drag: Dictionary = {}
	for i: int in 30:
		await get_tree().physics_frame
		var l: Array[PlayerProjectile] = active_projectiles()
		if not l.is_empty():
			shot_drag = {"dir": l[0].direction}
			break
	check(not shot_drag.is_empty() and absf(rad_to_deg((shot_drag["dir"] as Vector2).angle()) - 90.0) < 2.0,
			"direção final = 90° (para baixo)")

	print("-- Mira assistida: inimigo levemente fora da linha")
	await reset_player()
	var enemy_scene: PackedScene = load("res://enemies/tank/TankEnemy.tscn")
	var enemy := enemy_scene.instantiate() as EnemyBase
	level.add_child(enemy)
	enemy.global_position = _player.global_position + Vector2.from_angle(deg_to_rad(14.0)) * 330.0
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(5)
	# A mira automática do toque rápido já apontaria para o inimigo; usamos o arrasto para mirar reto (0°).
	touch(0, center + Vector2(60, 0), true)
	drag(0, center + Vector2(75, 0))
	await frames(3)
	touch(0, center + Vector2(75, 0), false)
	var start_dir := Vector2.RIGHT
	var turned: float = 0.0
	var seen: bool = false
	for i: int in 40:
		await get_tree().physics_frame
		var l2: Array[PlayerProjectile] = active_projectiles()
		if not l2.is_empty():
			seen = true
			turned = absf(rad_to_deg(start_dir.angle_to(l2[0].direction)))
			if i > 25:
				break
	check(seen, "tiro com assistência saiu")
	check(turned > 2.0 and turned < 20.0, "tiro curvou %.1f° em direção ao inimigo (leve)" % turned)
	# Não libera o inimigo (a fase concluiria); só o tira do caminho.
	enemy.global_position = Vector2(6000, 6000)
	await frames(3)

	print("-- Espada: segurar o analógico bate; toque rápido bate")
	await reset_player()
	touch(1, wb, true)
	await frames(2)
	touch(1, wb, false)
	await frames(2)
	check(not _mc.weapon_ranged, "weapon_ranged = false (espada)")
	print("-- Espada: mira enquanto segura, golpeia ao soltar")
	touch(0, center + Vector2(0, 60), true)
	await frames(30)
	var swung_while_held: bool = _player.state == Player.State.ATTACK_MELEE
	check(not swung_while_held, "não golpeia enquanto o dedo segura")
	check(_player.is_aiming_sword(), "mira da espada visível enquanto segura")
	var ind: Node = _player.get_node("AimIndicator")
	check(ind.visible, "AimIndicator visível")
	check(_player.get_sword_direction().distance_to(Vector2.DOWN) < 0.01, "mira da espada aponta para baixo")
	touch(0, center + Vector2(0, 60), false)
	var saw_after_release: bool = false
	for i: int in 10:
		await get_tree().physics_frame
		if _player.state == Player.State.ATTACK_MELEE:
			saw_after_release = true
			break
	check(saw_after_release, "golpeia ao soltar")
	check(_player.is_aiming_sword(), "mira da espada continua durante o golpe")
	await frames(40)
	check(not _player.is_aiming_sword() and not ind.visible, "mira some depois do golpe")
	var saw_melee: bool = false
	touch(0, center + Vector2(60, 0), true)
	await frames(1)
	touch(0, center + Vector2(60, 0), false)
	for i: int in 20:
		await get_tree().physics_frame
		if _player.state == Player.State.ATTACK_MELEE:
			saw_melee = true
			break
	check(saw_melee, "toque rápido de 1 quadro faz a espada bater")
	await frames(40)

	print("-- Espada acerta o inimigo (mira automática do toque, escala 1.5)")
	await reset_player()
	var hits: Array[int] = []
	_player.causou_dano.connect(func(_a: Node, q: int) -> void: hits.append(q))
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.set_physics_process(false)
	enemy.state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.global_position = _player.global_position + Vector2.from_angle(deg_to_rad(40.0)) * 95.0
	await frames(5)
	touch(0, center + Vector2(60, 0), true)
	await frames(1)
	touch(0, center + Vector2(60, 0), false)
	await frames(40)
	check(not hits.is_empty() and hits[0] == 50, "espada causou 50 de dano (%s)" % str(hits))
	enemy.global_position = Vector2(6000, 6000)
	await frames(3)

	print("-- Toque rápido logo depois de um dash não se perde")
	await reset_player()
	print("   DBG before toggle ranged=", _mc.weapon_ranged, " shown=", _mc._shown, " blocked=", _mc._blocked, " paused=", get_tree().paused, " dead=", _player.esta_morto(), " inTree=", _player.is_inside_tree(), " state=", _player.state, " pos=", _player.global_position)
	touch(1, wb, true)
	await frames(2)
	print("   DBG during toggle fingers=", _mc._fingers, " ranged=", _mc.weapon_ranged)
	touch(1, wb, false)
	await frames(2)  # volta ao tiro
	var db: Vector2 = _mc.call("_button_center", &"dash")
	touch(2, db, true)
	await frames(2)
	touch(2, db, false)
	print("   DBG ranged=", _mc.weapon_ranged, " state=", _player.state)
	var late: Dictionary = await tap_shot(deg_to_rad(60.0), 1)
	print("   DBG after: late=", late, " pending=", _mc._tap_pending, " state=", _player.state, " shoot=", _mc._act_state.get(&"charge_shoot"))
	check(not late.is_empty(), "tiro saiu mesmo logo após o dash")

	print("== %d verificações, %d falhas" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)

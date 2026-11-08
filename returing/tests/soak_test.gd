extends Node
## Teste de estresse: joga uma fase com toques aleatórios (mover, mirar, atirar, espada, dash, trocar arma).
## Procura erros de script, travadas de estado e tiros perdidos.
##   godot --headless --path . res://tests/soak_test.tscn -- --mobile <cena> <segundos> [godmode]

var root: Window = null
var rng := RandomNumberGenerator.new()


func _to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos


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


func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = args[1]
	var seconds: float = float(args[2])
	var god: bool = args.size() > 3
	rng.seed = 12345
	var level: Node = load(scene_path).instantiate()
	root.add_child(level)
	get_tree().current_scene = level
	for i in 20:
		await get_tree().physics_frame
	var player: Player = level.get_node_or_null("Player") as Player
	var mc := MobileControls
	var stats := {"shots": 0, "melee": 0, "dash": 0, "hits": 0, "stuck": 0}
	if player != null:
		player.estado_mudou.connect(func(s: int) -> void:
			if s == Player.State.ATTACK_RANGED: stats["shots"] += 1
			elif s == Player.State.ATTACK_MELEE: stats["melee"] += 1
			elif s == Player.State.DASH: stats["dash"] += 1)
		player.causou_dano.connect(func(_a: Node, _q: int) -> void: stats["hits"] += 1)
		if god:
			player.hp_maximo = 100000
			player.hp = 100000
	var t_end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var aim_c: Vector2 = mc._rest_aim()
	var mv_c: Vector2 = mc._rest_move()
	var move_down := false
	var ticks := 0
	while Time.get_ticks_msec() < t_end:
		ticks += 1
		await get_tree().physics_frame
		if not is_instance_valid(player):
			break
		var r: float = rng.randf()
		# movimento: pressiona/arrasta/solta
		if r < 0.02:
			if move_down:
				touch(1, mv_c, false)
				move_down = false
			else:
				touch(1, mv_c, true)
				drag(1, mv_c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 80.0))
				move_down = true
		elif move_down and r < 0.08:
			drag(1, mv_c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 80.0))
		# mira/ataque
		var r2: float = rng.randf()
		if r2 < 0.03:
			var a: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 70.0)
			touch(2, aim_c + a, true)
			drag(2, aim_c + a * 1.1)
			var hold: int = [1, 1, 2, 5, 30, 80][rng.randi() % 6]
			for k in hold:
				await get_tree().physics_frame
			touch(2, aim_c + a, false)
		elif r2 < 0.04:
			var wb: Vector2 = mc._button_center(&"weapon")
			touch(3, wb, true)
			await get_tree().physics_frame
			touch(3, wb, false)
		elif r2 < 0.06:
			var db: Vector2 = mc._button_center(&"dash")
			touch(4, db, true)
			await get_tree().physics_frame
			touch(4, db, false)
		# trava de estado: ficar em ATTACK_RANGED/MELEE por muito tempo sem dedo
		if is_instance_valid(player) and not mc._aim_down and not mc._tap_pending and player.state == Player.State.ATTACK_RANGED:
			stats["stuck"] += 1
	print("SOAK ", scene_path, " ticks=", ticks, " stats=", stats, " hp=", player.hp if is_instance_valid(player) else -1, " paused=", get_tree().paused)
	get_tree().quit()

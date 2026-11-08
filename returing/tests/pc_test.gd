extends Node
## Teste automatizado do modo PC (sem --mobile): tudo deve continuar como o jogo original,
## só com as mudanças de combate (dano do tiro/espada, hitbox da espada, tiro rápido).
##   godot --headless --path . res://tests/pc_test.tscn

const LEVEL: String = "res://Scenes/Fase2/Fase2.tscn"

var _fails: int = 0
var _checks: int = 0
var _player: Player = null
var _hits: Array[int] = []


func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label)


func frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func active_projectiles() -> Array[PlayerProjectile]:
	var out: Array[PlayerProjectile] = []
	for n: Node in get_tree().root.find_children("*", "PlayerProjectile", true, false):
		var p := n as PlayerProjectile
		if p.is_in_use():
			out.append(p)
	return out


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load(LEVEL).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await frames(40)
	_player = level.get_node("Player") as Player
	_player.causou_dano.connect(func(_alvo: Node, q: int) -> void: _hits.append(q))

	print("-- Valores base do PC")
	check(not Platform.is_mobile, "Platform.is_mobile = false")
	check(not MobileControls.ativo, "MobileControls inativo")
	check(is_equal_approx(_player.scale.x, 1.0), "player no tamanho original")
	check(get_viewport().get_camera_2d() == null, "Fase2 sem câmera nova (como antes)")
	check(Platform.aim_assist == false, "sem mira assistida")
	check(_player.max_damage == 68, "dano máximo do tiro = 68 (%d)" % _player.max_damage)
	check(_player.weapon.damage == 50, "dano da espada = 50 (%d)" % _player.weapon.damage)
	var shape := (_player.weapon as Sword).hitbox_shape.shape as CircleShape2D
	check(is_equal_approx(shape.radius, 39.2), "hitbox da espada +40%% (%.1f)" % shape.radius)

	print("-- Tiro carregado (segurando charge_shoot 1.5 s)")
	_player.global_position = Vector2(560, 330)
	await frames(10)
	Input.action_press(&"charge_shoot")
	await frames(90)
	Input.action_release(&"charge_shoot")
	await frames(3)
	var list: Array[PlayerProjectile] = active_projectiles()
	check(not list.is_empty(), "tiro saiu")
	if not list.is_empty():
		check(list[0].damage == 68, "dano = 68 (%d)" % list[0].damage)
		check(is_equal_approx(list[0].scale.x, 3.0), "escala = 3.0 (%.2f)" % list[0].scale.x)
		check(list[0]._assist_target == null, "sem curva de mira assistida")
	for p: PlayerProjectile in active_projectiles():
		p.recycle()
	await frames(40)

	print("-- Clique rápido no tiro (1 quadro) ainda atira")
	Input.action_press(&"charge_shoot")
	await frames(1)
	Input.action_release(&"charge_shoot")
	await frames(6)
	list = active_projectiles()
	check(not list.is_empty(), "clique rápido gerou tiro")
	if not list.is_empty():
		check(list[0].damage >= 10 and list[0].damage < 20, "dano mínimo sem bônus de toque (%d)" % list[0].damage)
	for p: PlayerProjectile in active_projectiles():
		p.recycle()
	await frames(40)

	print("-- Espada: acerta um inimigo na direção do cursor")
	var to_mouse: Vector2 = (_player.get_global_mouse_position() - _player.global_position).normalized()
	var enemy := (load("res://enemies/tank/TankEnemy.tscn") as PackedScene).instantiate() as EnemyBase
	level.add_child(enemy)
	enemy.global_position = _player.global_position + to_mouse * 60.0
	# Desliga só a IA (um corpo com process_mode DISABLED sai do espaço de física).
	enemy.set_physics_process(false)
	enemy.state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(5)
	_hits.clear()
	Input.action_press(&"attack_sword")
	await frames(2)
	Input.action_release(&"attack_sword")
	await frames(30)
	check(not _hits.is_empty(), "espada acertou")
	if not _hits.is_empty():
		check(_hits[0] == 50, "dano da espada = 50 (%d)" % _hits[0])
	print("== %d verificações, %d falhas" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)

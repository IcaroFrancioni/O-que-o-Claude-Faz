extends Node
## Tira capturas do modo celular: godot --path . res://tests/mobile_shot.tscn -- --mobile <cena> <prefixo> [pc]

var root: Window = null

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

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = args[1]
	var prefix: String = args[2]
	var win: Window = root
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1500, 675)
	await get_tree().process_frame
	var level: Node = load(scene_path).instantiate()
	root.add_child(level)
	get_tree().current_scene = level  # como no jogo: tiros e efeitos nascem sob a fase
	await frames(60)
	var mc = MobileControls
	var _player: Player = level.get_node("Player")
	await snap(prefix + "_a_start.png")
	if mc.ativo:
		var c: Vector2 = mc._rest_aim()
		var sword_mode: bool = args.size() > 3 and args[3] == "sword"
		if not sword_mode:
			touch(1, mc._button_center(&"weapon"), true)
			await frames(2)
			touch(1, mc._button_center(&"weapon"), false)
			await frames(2)
		touch(0, c + Vector2(55, -30), true)
		await frames(50)
		await snap(prefix + "_b_charging_diag.png")
		touch(0, c + Vector2(55, -30), false)
		await frames(3)
		await snap(prefix + "_c_shot_flying.png")
	else:
		Input.action_press(&"charge_shoot")
		await frames(50)
		await snap(prefix + "_b_charging.png")
		Input.action_release(&"charge_shoot")
		await frames(10)
		await snap(prefix + "_c_shot_flying.png")
	get_tree().quit()

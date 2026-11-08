extends Node
## Capturas de telas de UI no formato de celular: godot --path . res://tests/ui_shot.tscn -- --mobile <cena> <png> [acao]
## acao: pause | quiz | gameover | complete

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var win: Window = get_tree().root
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1500, 675)
	await get_tree().process_frame
	var level: Node = load(args[1]).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await frames(50)
	var action: String = args[3] if args.size() > 3 else ""
	match action:
		"pause":
			var e := InputEventAction.new()
			e.action = &"Pause"
			e.pressed = true
			Input.parse_input_event(e)
			await frames(10)
		"quiz":
			var player: Player = level.get_node("Player")
			player.global_position = level.get_node("Terminal").global_position + Vector2(0, 40)
			await frames(20)
			level.get_node("Terminal")._activate()
			await frames(20)
		"gameover":
			EventBus.game_over.emit()
			await frames(10)
		"wait":
			await frames(420)
		"complete":
			EventBus.level_completed.emit("")
			await frames(10)
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(args[2])
	print("saved ", args[2])
	get_tree().quit()

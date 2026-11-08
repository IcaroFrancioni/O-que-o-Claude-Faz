extends Node
## Captura as telas de menu para conferir o visual.
## godot --path . res://qa/menus_shot.tscn -- <acao> <png> [largura altura]
## acao: menu | menu_settings | menu_down | pause | pause_settings | levelup | tutorial | cutscene | complete | gameover | quiz

const LEVEL_1: String = "res://Scenes/Fase1/fase_1.tscn"
const LEVEL_2: String = "res://Scenes/Fase2/Fase2.tscn"


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var action: String = args[0]
	var png: String = args[1]
	var width: int = int(args[2]) if args.size() > 3 else 1152
	var height: int = int(args[3]) if args.size() > 3 else 648
	var win: Window = get_tree().root
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(width, height)
	await _frames(2)

	match action:
		"menu":
			await _open("res://Scenes/Start/menu_start.tscn")
		"menu_settings":
			var menu: Node = await _open("res://Scenes/Start/menu_start.tscn")
			menu.get_node("Center/Column/MenuPanel/Buttons/Settings_button").pressed.emit()
			await _frames(20)
		"menu_down":
			# navega com o teclado: uma vez para baixo (foco em Configurações)
			await _open("res://Scenes/Start/menu_start.tscn")
			_press(&"ui_down")
			await _frames(20)
		"pause":
			await _open(LEVEL_1)
			_press(&"Pause")
			await _frames(25)
		"pause_settings":
			var level: Node = await _open(LEVEL_1)
			_press(&"Pause")
			await _frames(25)
			level.get_node("Pause/Root/Center/Panel/MainPage/SettingsButton").pressed.emit()
			await _frames(20)
		"levelup":
			var menu: LevelUpMenu = LevelUpMenu.new()
			menu.input_delay = 0.0
			get_tree().root.add_child(menu)
			var offer: Array[AbilityData] = []
			for file: String in ["cavaleiro_imbativel", "tiro_perfurante", "cura"]:
				offer.append(load("res://abilities/data/%s.tres" % file) as AbilityData)
			var owned: Array[AbilityData] = [offer[2]]
			menu.open(3, offer, owned)
			await _frames(60)
		"tutorial":
			await _open("res://Scenes/Tutorial/tutorial.tscn")
		"cutscene":
			await _open("res://Scenes/Cut1/cutscene1.tscn")
			await _frames(10)
		"complete":
			await _open(LEVEL_1)
			EventBus.level_completed.emit(LEVEL_2)
			await _frames(20)
		"gameover":
			await _open(LEVEL_1)
			EventBus.game_over.emit()
			await _frames(20)
		"quiz":
			var level: Node = await _open(LEVEL_2)
			var player: Player = level.get_node("Player")
			player.global_position = level.get_node("Terminal").global_position + Vector2(0, 40)
			await _frames(20)
			level.get_node("Terminal")._activate()
			await _frames(30)
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(png)
	print("saved ", png)
	get_tree().quit()


func _open(path: String) -> Node:
	var scene: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await _frames(45)
	return scene


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)

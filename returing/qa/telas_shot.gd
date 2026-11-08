extends Node
## Capturas da tela inicial e da tela de game over (botões).
## Rodar (com janela): godot --path . res://qa/telas_shot.tscn -- <pasta_de_saida> <prefixo>


func _ready() -> void:
	_rodar.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _salvar(caminho: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(caminho)
	print("salvo ", caminho)


func _rodar() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var janela: Window = get_tree().root
	janela.mode = Window.MODE_WINDOWED
	janela.size = Vector2i(1152, 648)
	await _frames(2)

	var inicio: Node = (load("res://Scenes/Start/menu_start.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inicio)
	get_tree().current_scene = inicio
	await _frames(40)
	await _salvar("%s/%s_inicio.png" % [args[0], args[1]])
	inicio.queue_free()
	await _frames(4)

	RunState.reset()
	var fase: Node = (load("res://Scenes/Fase1/fase_1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(fase)
	get_tree().current_scene = fase
	await _frames(30)
	EventBus.game_over.emit()
	await _frames(20)
	await _salvar("%s/%s_gameover_a.png" % [args[0], args[1]])
	await get_tree().create_timer(6.0, true, false, true).timeout  # o "Tentar de novo" aparece depois do retry_delay
	await _frames(20)
	await _salvar("%s/%s_gameover_b.png" % [args[0], args[1]])
	get_tree().quit()

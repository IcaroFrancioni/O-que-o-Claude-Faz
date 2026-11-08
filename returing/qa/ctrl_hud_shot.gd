extends Node
## Capturas da HUD de habilidades: faixa compacta com a colinha e painel do modo comando.
## Rodar (com janela): godot --path . res://qa/ctrl_hud_shot.tscn -- <pasta_de_saida>


func _ready() -> void:
	_rodar.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _tecla(keycode: Key, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = apertada
	ev.ctrl_pressed = keycode == KEY_CTRL
	Input.parse_input_event(ev)


func _salvar(caminho: String) -> void:
	await RenderingServer.frame_post_draw
	var imagem: Image = get_tree().root.get_texture().get_image()
	imagem.save_png(caminho)
	# Recorte ampliado do canto da HUD de habilidades (a colinha é pequena).
	var canto: Image = imagem.get_region(Rect2i(imagem.get_width() - 322, imagem.get_height() - 118, 322, 118))
	canto.resize(canto.get_width() * 3, canto.get_height() * 3, Image.INTERPOLATE_NEAREST)
	canto.save_png(caminho.replace(".png", "_zoom.png"))
	print("salvo ", caminho)


func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	var janela: Window = get_tree().root
	janela.mode = Window.MODE_WINDOWED
	janela.size = Vector2i(1152, 648)
	await _frames(2)
	RunState.reset()
	var fase: Node = (load("res://Scenes/Fase1/fase_1.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(fase)
	get_tree().current_scene = fase
	await _frames(30)
	var player: Player = fase.find_child("Player", true, false) as Player
	var hab: AbilityComponent = player.get_node("AbilityComponent") as AbilityComponent
	player.conceder_invulnerabilidade(99999.0)
	hab.abilities = [
		hab.catalog.find_by_id(&"escudo"),
		hab.catalog.find_by_id(&"cavaleiro_imbativel"),
		hab.catalog.find_by_id(&"passo_agil"),
	]
	hab.abilities_changed.emit()
	await _frames(20)
	await _salvar(pasta + "/hud_compacta.png")
	hab._cooldowns[&"escudo"] = 8.0
	hab.cooldown_changed.emit(hab.abilities[0], 8.0, 20.0)
	await _frames(10)
	await _salvar(pasta + "/hud_recarga.png")
	_tecla(KEY_CTRL, true)
	await _frames(2)
	_tecla(KEY_CTRL, false)
	await _frames(2)
	for k: Key in [KEY_UP, KEY_DOWN]:
		_tecla(k, true)
		await _frames(2)
		_tecla(k, false)
		await _frames(2)
	await _frames(10)
	await _salvar(pasta + "/hud_modo_comando.png")
	Engine.time_scale = 1.0
	get_tree().quit()

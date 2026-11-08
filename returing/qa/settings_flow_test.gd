extends Node
## Teste de fluxo das configurações: abre o menu principal, entra em Configurações, mexe nos sliders,
## confere os buses, volta com ui_cancel e testa o foco por teclado. Restaura os volumes no fim.
## Rodar: godot --path . res://qa/settings_flow_test.tscn   (precisa de janela: o foco só existe com ela)

var _falhas: int = 0


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _ready() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var musica_original: float = AudioSettings.get_volume(&"Music")
	var sfx_original: float = AudioSettings.get_volume(&"SFX")

	var menu: Node = (load("res://Scenes/Start/menu_start.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	await _frames(30)

	var iniciar: Button = menu.get_node("Center/Column/MenuPanel/Buttons/Start_button")
	var config: Button = menu.get_node("Center/Column/MenuPanel/Buttons/Settings_button")
	var botoes: Control = menu.get_node("Center/Column/MenuPanel/Buttons")
	_checar(iniciar.has_focus(), "o foco começa em Iniciar")

	_tecla(&"ui_down")
	await _frames(5)
	_checar(config.has_focus(), "seta para baixo leva o foco a Configurações")

	config.pressed.emit()
	await _frames(5)
	var painel: SettingsPanel = null
	for filho: Node in menu.get_node("Center/Column/MenuPanel").get_children():
		if filho is SettingsPanel:
			painel = filho
	_checar(painel != null and painel.visible and not botoes.visible, "Configurações abre e esconde a página principal")

	var sliders: Array[HSlider] = []
	_coletar(painel, sliders)
	_checar(sliders.size() == 2, "há 2 sliders")
	if sliders.size() == 2:
		_checar(sliders[0].has_focus(), "o foco vai para o primeiro slider")
		sliders[0].value = 50.0  # efeitos sonoros
		var sfx: int = AudioServer.get_bus_index(&"SFX")
		_checar(absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.5)) < 0.01, "slider em 50% = -6,02 dB no bus SFX")
		sliders[1].value = 0.0  # música
		var musica: int = AudioServer.get_bus_index(&"Music")
		_checar(AudioServer.is_bus_mute(musica), "slider em 0% silencia o bus Music")

	_tecla(&"ui_cancel")
	await _frames(5)
	_checar(botoes.visible and not painel.visible, "ui_cancel volta para a página principal")
	_checar(config.has_focus(), "o foco volta para Configurações")

	AudioSettings.set_volume(&"Music", musica_original)
	AudioSettings.set_volume(&"SFX", sfx_original)
	AudioSettings.save_settings()
	print("settings_flow_test: %d falha(s)" % _falhas)
	get_tree().quit(1 if _falhas > 0 else 0)


func _coletar(no: Node, saida: Array[HSlider]) -> void:
	for filho: Node in no.get_children():
		if filho is HSlider:
			saida.append(filho)
		_coletar(filho, saida)


func _tecla(acao: StringName) -> void:
	var evento: InputEventAction = InputEventAction.new()
	evento.action = acao
	evento.pressed = true
	Input.parse_input_event(evento)
	var solto: InputEventAction = InputEventAction.new()
	solto.action = acao
	solto.pressed = false
	Input.parse_input_event(solto)


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("ok      ", descricao)
	else:
		printerr("FALHOU  ", descricao)
		_falhas += 1

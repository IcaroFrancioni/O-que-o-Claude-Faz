extends TesteBase
## Configurações no celular: página do acelerômetro (sensibilidade, zona morta, intervalo e "Calibrar"), valores
## salvos em user://. Rode com --mobile --mobile-config=user://teste_config.cfg

func rodar() -> void:
	var mc: Node = get_node("/root/MobileControls")
	var ti: Node = get_node("/root/TiltInput")
	ti.simulate_with_keys = false
	MobileSettings.wipe()
	await set_window()
	load_level("res://Scenes/Fase1/fase_1.tscn")
	await frames(60)
	player().conceder_invulnerabilidade(9999.0)
	var pause_menu: Node = level.get_node("Pause")
	pause_menu.pause()
	await frames(5)
	var settings_button: Button = pause_menu.get_node("Root/Center/Panel/MainPage/SettingsButton") as Button
	await tap(0, settings_button.get_global_rect().get_center())
	await frames(5)
	var settings: SettingsPanel = pause_menu.get_node("Root/Center/Panel").find_children("*", "SettingsPanel", true, false)[0] as SettingsPanel
	check(settings.visible, "a tela de configurações abriu")
	var tilt_button: Button = settings.get_node_or_null("TiltButton") as Button
	check(tilt_button != null and tilt_button.text == "Acelerômetro", "configurações têm a página 'Acelerômetro' no celular")
	await tap(0, tilt_button.get_global_rect().get_center())
	await frames(5)
	var page: Control = settings.get_node("TiltPage") as Control
	check(page.visible, "a página do acelerômetro abriu")
	var sliders: Array[Node] = page.find_children("*", "HSlider", true, false)
	check(sliders.size() == 3, "três sliders: sensibilidade, zona morta e intervalo (%d)" % sliders.size())
	check(ti.is_active(), "o sensor é ligado enquanto a página está aberta (indicador ao vivo)")
	# Mexer nos sliders muda o TiltInput.
	(sliders[0] as HSlider).value = 180.0
	(sliders[1] as HSlider).value = 140.0
	(sliders[2] as HSlider).value = 450.0
	check(is_equal_approx(ti.sensitivity, 1.8), "o slider de sensibilidade muda o TiltInput (%.2f)" % ti.sensitivity)
	check(is_equal_approx(ti.deadzone, 1.4), "o slider de zona morta muda o TiltInput (%.2f)" % ti.deadzone)
	check(is_equal_approx(ti.cooldown, 0.45), "o slider de intervalo muda o TiltInput (%.2f)" % ti.cooldown)
	# Calibrar.
	var calibrate: Button = page.find_child("CalibrateButton", true, false) as Button
	check(calibrate != null and calibrate.text == "Calibrar", "botão 'Calibrar'")
	Input.set_accelerometer(gravity(0.0, 0.0))
	await real_seconds(0.8)
	Input.set_accelerometer(gravity(20.0, 0.0))
	await real_seconds(0.8)
	check(ti.current_tilt.x > 0.15, "antes de calibrar, a pose inclinada aparece como inclinação (%s)" % ti.current_tilt)
	await tap(0, calibrate.get_global_rect().get_center())
	await real_seconds(0.6)
	check(ti.current_tilt.length() < 0.05, "depois de calibrar, a pose atual é o neutro (%s)" % ti.current_tilt)
	var auto_check: CheckButton = page.find_child("AutoCalibrate", true, false) as CheckButton
	check(auto_check != null and auto_check.button_pressed, "opção 'Calibrar ao abrir o modo comando' ligada por padrão")
	check(ti.saved_neutral != Vector3.ZERO, "o botão Calibrar guardou a pose neutra")
	await tap(0, auto_check.get_global_rect().get_center())
	check(not ti.auto_calibrate, "desligar a opção faz o modo comando usar a pose guardada")
	# Voltar grava os ajustes.
	var back: Button = page.find_child("TiltBackButton", true, false) as Button
	await tap(0, back.get_global_rect().get_center())
	await frames(5)
	check(not page.visible and not ti.is_active(), "voltar fecha a página e desliga o sensor")
	var cfg: ConfigFile = ConfigFile.new()
	check(cfg.load("user://teste_config.cfg") == OK, "as configurações foram gravadas em user://")
	check(not bool(cfg.get_value("tilt", "auto_calibrate", true)) and cfg.get_value("tilt", "neutral", Vector3.ZERO) is Vector3 and cfg.get_value("tilt", "neutral", Vector3.ZERO) != Vector3.ZERO,
			"a pose calibrada e a opção foram gravadas")
	check(is_equal_approx(float(cfg.get_value("tilt", "sensitivity", 0.0)), 1.8) and is_equal_approx(float(cfg.get_value("tilt", "cooldown", 0.0)), 0.45),
			"sensibilidade e intervalo gravados")
	Input.set_accelerometer(Vector3.ZERO)
	MobileSettings.wipe()

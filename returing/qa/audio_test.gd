extends Node
## Teste do AudioSettings: buses existem, 0 = mudo, conversão linear -> dB e salvar/carregar.
## Guarda os volumes do jogador e os restaura no fim.
## Rodar: godot --headless --path . res://qa/audio_test.tscn

var _falhas: int = 0


func _ready() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var musica_original: float = AudioSettings.get_volume(&"Music")
	var sfx_original: float = AudioSettings.get_volume(&"SFX")

	_checar(AudioServer.get_bus_index(&"Music") != -1, "bus Music existe")
	_checar(AudioServer.get_bus_index(&"SFX") != -1, "bus SFX existe")

	var sfx: int = AudioServer.get_bus_index(&"SFX")
	AudioSettings.set_volume(&"SFX", 0.0)
	_checar(AudioServer.is_bus_mute(sfx), "volume 0 silencia o bus")
	AudioSettings.set_volume(&"SFX", 0.5)
	_checar(not AudioServer.is_bus_mute(sfx), "volume 0,5 não silencia")
	_checar(absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.5)) < 0.01, "0,5 vira %.2f dB" % linear_to_db(0.5))

	# Salvar e carregar: muda, grava, bagunça na memória e recarrega do arquivo.
	AudioSettings.set_volume(&"Music", 0.25)
	AudioSettings.save_settings()
	AudioSettings.set_volume(&"Music", 1.0)
	AudioSettings.load_settings()
	AudioSettings.apply_all()
	_checar(is_equal_approx(AudioSettings.get_volume(&"Music"), 0.25), "volume da música volta de user://settings.cfg")

	# Restaura o que o jogador tinha.
	AudioSettings.set_volume(&"Music", musica_original)
	AudioSettings.set_volume(&"SFX", sfx_original)
	AudioSettings.save_settings()

	print("audio_test: %d falha(s)" % _falhas)
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("ok      ", descricao)
	else:
		printerr("FALHOU  ", descricao)
		_falhas += 1

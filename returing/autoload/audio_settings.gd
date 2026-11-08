extends Node
## Autoload AudioSettings: volumes dos buses "Music" e "SFX".
## Garante que os buses existam, carrega os volumes de user://settings.cfg ao iniciar o jogo,
## aplica ao AudioServer (linear -> dB; 0 = mudo) e salva depois de cada mudança.

## O volume de um bus mudou (0.0 a 1.0).
signal volume_changed(bus: StringName, linear: float)

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "audio"
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
## Volume inicial (linear). 1.0 = 0 dB, ou seja, o jogo soa como antes de existir o ajuste.
const DEFAULT_VOLUME: float = 1.0
## Espera (s) depois da última mudança antes de gravar o arquivo (evita gravar a cada passo do slider).
const SAVE_DELAY: float = 0.5
## Volume (dB) usado para silenciar.
const MUTE_DB: float = -80.0

var _volumes: Dictionary[StringName, float] = {
	BUS_MUSIC: DEFAULT_VOLUME,
	BUS_SFX: DEFAULT_VOLUME,
}
var _save_timer: Timer = null
var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # o menu de pause muda o volume com o jogo pausado
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.ignore_time_scale = true
	add_child(_save_timer)
	_save_timer.timeout.connect(save_settings)
	load_settings()
	apply_all()


## Grava o que ainda não foi salvo (o jogo pode fechar antes do tempo de espera acabar).
func _exit_tree() -> void:
	if _dirty:
		save_settings()


## Volume atual do bus (0.0 a 1.0).
func get_volume(bus: StringName) -> float:
	return _volumes.get(bus, DEFAULT_VOLUME)


## Muda o volume do bus (0.0 a 1.0), aplica na hora e agenda o salvamento.
func set_volume(bus: StringName, linear: float) -> void:
	if not _volumes.has(bus):
		push_warning("AudioSettings: bus '%s' desconhecido." % bus)
		return
	_volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply(bus)
	_dirty = true
	_save_timer.start()
	volume_changed.emit(bus, _volumes[bus])


## Aplica todos os volumes guardados ao AudioServer.
func apply_all() -> void:
	for bus: StringName in _volumes:
		_apply(bus)


## Lê user://settings.cfg. Sem arquivo (primeira execução) ficam os valores padrão.
func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus: StringName in _volumes.keys():
		var stored: Variant = config.get_value(SECTION, _config_key(bus), DEFAULT_VOLUME)
		_volumes[bus] = clampf(float(stored), 0.0, 1.0)


## Grava os volumes em user://settings.cfg, preservando outras seções do arquivo.
func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)  # se não existir, começa vazio
	for bus: StringName in _volumes:
		config.set_value(SECTION, _config_key(bus), _volumes[bus])
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("AudioSettings: não foi possível salvar %s (erro %d)." % [SETTINGS_PATH, error])
		return
	_dirty = false


## Converte volume linear (0 a 1) em dB; 0 vira o valor de mudo.
static func linear_to_bus_db(linear: float) -> float:
	return MUTE_DB if linear <= 0.0 else linear_to_db(linear)


func _apply(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index == -1:
		return
	var linear: float = _volumes[bus]
	AudioServer.set_bus_mute(index, linear <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_bus_db(linear))


## Cria o bus (enviando para o Master) se o default_bus_layout.tres não o tiver.
func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, BUS_MASTER)


func _config_key(bus: StringName) -> String:
	return "%s_volume" % String(bus).to_lower()

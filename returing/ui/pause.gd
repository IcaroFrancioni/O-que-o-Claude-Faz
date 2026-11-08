extends CanvasLayer
## Menu de pause. Visual dos menus (tema compartilhado); a lógica de pausa é a de sempre:
## só abre com o jogo livre (pausa de outra tela, como quiz e menu de escolha, é respeitada).
## Tem duas páginas no mesmo painel: a principal e as configurações de áudio (SettingsPanel).

const ACTION_PAUSE: StringName = &"Pause"
const ACTION_CANCEL: StringName = &"ui_cancel"
## Escala inicial do painel na abertura.
const OPEN_SCALE: float = 0.94

@export_group("Animação")
## Duração (s) da abertura e do fechamento (no máximo 0,2).
@export_range(0.05, 0.2, 0.01) var open_time: float = Palette.FADE_TIME
@export_range(0.05, 0.2, 0.01) var close_time: float = Palette.FADE_TIME

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _panel: Control = $Root/Center/Panel
@onready var _main_page: Control = $Root/Center/Panel/MainPage
@onready var _continue_button: Button = $Root/Center/Panel/MainPage/ContinueButton
@onready var _settings_button: Button = $Root/Center/Panel/MainPage/SettingsButton
@onready var _reset_button: Button = $Root/Center/Panel/MainPage/ResetButton
@onready var _exit_button: Button = $Root/Center/Panel/MainPage/ExitButton

var _settings: SettingsPanel = null
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
## True só quando foi ESTE menu que pausou a árvore.
var _paused_by_menu: bool = false
var _tween: Tween = null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua ouvindo a tecla com o jogo pausado
	visible = false
	_dim.color = Palette.dim_color()
	_settings = SettingsPanel.new()
	_settings.visible = false
	_panel.add_child(_settings)
	_settings.back_requested.connect(_show_main_page)
	_panel.resized.connect(_center_pivot)
	_continue_button.pressed.connect(resume)
	_settings_button.pressed.connect(_show_settings_page)
	_reset_button.pressed.connect(_on_reset_pressed)
	_exit_button.pressed.connect(_on_menu_pressed)


func _exit_tree() -> void:
	if _paused_by_menu and is_inside_tree():
		get_tree().paused = false
		Input.mouse_mode = _previous_mouse_mode


## Alterna a pausa pela tecla; `ui_cancel` (ex.: botão B do controle) só fecha o menu aberto.
## Dentro das configurações, a mesma tecla volta para a página principal em vez de fechar.
func _unhandled_input(event: InputEvent) -> void:
	var toggles: bool = event.is_action_pressed(ACTION_PAUSE)
	var closes: bool = _paused_by_menu and event.is_action_pressed(ACTION_CANCEL)
	if not toggles and not closes:
		return
	if get_tree().paused and not _paused_by_menu:
		return  # pausa de outra tela (quiz, menu de escolha): a tecla não mexe nela
	get_viewport().set_input_as_handled()
	if _paused_by_menu and _settings.visible:
		_show_main_page()
	elif _paused_by_menu:
		resume()
	else:
		pause()


func pause() -> void:
	Engine.time_scale = 1.0  # a câmera lenta do modo comando não vale dentro do menu
	get_tree().paused = true
	_paused_by_menu = true
	_set_page(false)
	visible = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_animate(true)
	_continue_button.grab_focus()


func resume() -> void:
	UiFx.swallow_attack_input()  # o clique em "Continuar" não pode virar um golpe
	get_tree().paused = false
	_paused_by_menu = false
	Input.mouse_mode = _previous_mouse_mode
	get_viewport().gui_release_focus()  # o foco do botão não vaza para o jogo
	_animate(false)


func _on_reset_pressed() -> void:
	resume()
	EventBus.level_restart_requested.emit()


func _on_menu_pressed() -> void:
	resume()
	EventBus.main_menu_requested.emit()


func _show_settings_page() -> void:
	_set_page(true)
	_settings.focus_first()


func _show_main_page() -> void:
	_set_page(false)
	_settings_button.grab_focus()


## Alterna a página visível do painel (false = principal, true = configurações).
func _set_page(settings: bool) -> void:
	_main_page.visible = not settings
	_settings.visible = settings


func _center_pivot() -> void:
	_panel.pivot_offset = _panel.size * 0.5


## Abre (fade + o painel cresce um pouco) ou fecha (fade e some).
func _animate(opening: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = UiTween.create(self)
	if opening:
		_root.modulate.a = 0.0
		_panel.scale = Vector2.ONE * OPEN_SCALE
		_tween.set_parallel(true)
		_tween.tween_property(_root, ^"modulate:a", 1.0, open_time)
		_tween.tween_property(_panel, ^"scale", Vector2.ONE, open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(_root, ^"modulate:a", 0.0, close_time)
		_tween.tween_callback(func() -> void: visible = false)

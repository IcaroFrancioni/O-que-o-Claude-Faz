extends Control
## Menu principal. Só cuida do visual (cores da Palette em imagens que a cena não pode colorir
## sozinha, fade e foco inicial) e de alternar entre a página principal e as configurações de áudio.
## A navegação continua nos botões Start e Quit.

@onready var _stars: TextureRect = $Stars
@onready var _title: TextureRect = $Center/Column/Title
@onready var _column: Control = $Center/Column
@onready var _menu_panel: Control = $Center/Column/MenuPanel
@onready var _buttons: Control = $Center/Column/MenuPanel/Buttons
@onready var _first_button: Button = $Center/Column/MenuPanel/Buttons/Start_button
@onready var _settings_button: Button = $Center/Column/MenuPanel/Buttons/Settings_button

var _settings: SettingsPanel = null


func _ready() -> void:
	# As imagens são brancas: tinge com a paleta (nada de branco puro na tela).
	_stars.modulate = Palette.TEXT_DIM
	_title.modulate = Palette.TEXT
	_settings = SettingsPanel.new()
	_settings.visible = false
	_menu_panel.add_child(_settings)
	_settings.back_requested.connect(_show_main_page)
	_settings_button.pressed.connect(_show_settings_page)
	# Todos os botões são alcançáveis sem mouse; o foco começa no primeiro.
	_first_button.grab_focus.call_deferred()
	_fade_in()


## Nas configurações, `ui_cancel` (Esc, botão B) volta para a página principal.
func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_main_page()


func _show_settings_page() -> void:
	_set_page(true)
	_settings.focus_first()


func _show_main_page() -> void:
	_set_page(false)
	_settings_button.grab_focus()


## Alterna a página visível da caixa (false = principal, true = configurações).
## Nas configurações o logo sai para a caixa caber na tela.
func _set_page(settings: bool) -> void:
	_buttons.visible = not settings
	_settings.visible = settings
	_title.visible = not settings


## Fade rápido (<= 0,2 s) do conteúdo ao abrir o menu.
func _fade_in() -> void:
	_column.modulate.a = 0.0
	var tween: Tween = UiTween.create(self)
	tween.tween_property(_column, ^"modulate:a", 1.0, Palette.FADE_TIME)

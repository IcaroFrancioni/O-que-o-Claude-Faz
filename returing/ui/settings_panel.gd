class_name SettingsPanel
extends VBoxContainer
## Tela de configurações de áudio: um slider (0 a 100%) para efeitos sonoros e outro para a música.
## Reutilizável: o pause e o menu principal colocam esta caixa dentro do próprio painel e a
## alternam com a página principal. Quem usa só escuta `back_requested` (botão "Voltar").
## Os volumes ficam no autoload AudioSettings (buses "SFX" e "Music", salvos em user://settings.cfg).

## O jogador pediu para voltar (botão "Voltar").
signal back_requested

const TITLE: String = "CONFIGURAÇÕES"
const BACK_TEXT: String = "Voltar"
const SFX_LABEL: String = "Efeitos sonoros"
const MUSIC_LABEL: String = "Música principal"
## Largura mínima (px) da caixa e altura (px) do botão e do slider.
const PANEL_WIDTH: float = 400.0
const BUTTON_HEIGHT: float = 56.0
const SLIDER_HEIGHT: float = 24.0
const PERCENT_WIDTH: float = 72.0

var _sliders: Array[HSlider] = []
var _back_button: PixelButton = null


func _ready() -> void:
	custom_minimum_size.x = PANEL_WIDTH
	add_theme_constant_override(&"separation", Palette.UNIT * 2)

	var title: Label = Label.new()
	title.text = TITLE
	title.theme_type_variation = &"PanelTitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	add_child(HSeparator.new())

	_add_slider_row(SFX_LABEL, &"SFX")
	_add_slider_row(MUSIC_LABEL, &"Music")

	add_child(HSeparator.new())
	_back_button = PixelButton.new()
	_back_button.text = BACK_TEXT
	_back_button.custom_minimum_size.y = BUTTON_HEIGHT
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)


## Dá o foco ao primeiro slider (para navegar sem mouse).
func focus_first() -> void:
	if not _sliders.is_empty():
		_sliders[0].grab_focus()


## Uma linha: rótulo à esquerda, porcentagem à direita e o slider embaixo.
func _add_slider_row(label_text: String, bus: StringName) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override(&"separation", Palette.UNIT)
	add_child(row)

	var header: HBoxContainer = HBoxContainer.new()
	row.add_child(header)
	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var percent: Label = Label.new()
	percent.custom_minimum_size.x = PERCENT_WIDTH
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(percent)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size.y = SLIDER_HEIGHT
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	# Valor inicial ANTES de conectar o sinal: abrir a tela não deve regravar o volume.
	slider.value = roundf(AudioSettings.get_volume(bus) * 100.0)
	_update_percent(percent, slider.value)
	slider.value_changed.connect(_on_slider_changed.bind(bus, percent))
	row.add_child(slider)
	_sliders.append(slider)


func _on_slider_changed(value: float, bus: StringName, percent: Label) -> void:
	AudioSettings.set_volume(bus, value / 100.0)
	_update_percent(percent, value)


func _update_percent(percent: Label, value: float) -> void:
	percent.text = "%d%%" % roundi(value)


func _on_back_pressed() -> void:
	back_requested.emit()

class_name Dialogue
extends CanvasLayer
## Diálogo reutilizável: recebe um array de falas, escreve cada uma com efeito typewriter e emite `finished`.
## Sem contadores no quadro: a digitação, a pausa entre falas e o tremor da voz são Tweens/Timers.
##
## Dois visuais, ambos copiados do que o jogo já tem:
##   VOICE: a voz do tutorial (VT323 44 px, #d8ecff com brilho azul, no alto da tela, sem caixa).
##   BOX:   a caixa da cutscene (Panel do main_theme: marrom com borda dourada, botão "Avançar"),
##          com nome de quem fala em dourado e, se houver, a ilustração de fundo (TextureRect como na cutscene).
##
## Uso rápido (cria, toca e se remove sozinho):
##   var d: Dialogue = Dialogue.show_lines(self, ["Primeira fala", "Segunda"], Dialogue.Style.BOX, "???", tex)
##   await d.finished
##
## Enter/Espaço/E ou clique completam a fala e depois avançam. Segurar ESC pula o diálogo todo (`skipped`).

signal line_started(index: int)  # Uma fala começou a ser digitada (índice no array).
signal finished  # O diálogo terminou (última fala ou pulado).
signal skipped  # O jogador pulou o diálogo segurando ESC (vem antes de `finished`).

enum Style { VOICE, BOX }

const THEME: Theme = preload("res://themes/main_theme.tres")

# ===== BALANCEAMENTO / VISUAL =====
const LAYER_INDEX: int = 120  # Acima do HUD (10), do Pause (100) e dos efeitos (118); abaixo do fade de cena (128).
const BACKDROP_LAYER: int = 117  # A ilustração fica ABAIXO dos efeitos de tela (o chiado a cobre e revela).
const INPUT_GRACE_MSEC: int = 180  # Ignora entradas nos primeiros ms de cada fala.
const SKIP_HOLD_TIME: float = 0.8  # Tempo (s) segurando ESC para pular.
# Voz do tutorial (igual a TutorialUi).
const VOICE_FONT_SIZE: int = 44
const VOICE_COLOR: Color = Color("#d8ecff")
const VOICE_GLOW: Color = Color("#4aa8ff")
const VOICE_TOP: float = 54.0
const VOICE_WIDTH: float = 960.0
const VOICE_JITTER: float = 1.3  # Tremor da voz (px) a cada VOICE_JITTER_STEP.
const VOICE_JITTER_STEP: float = 0.06
# Caixa da cutscene (mesmas medidas de cutscene1.tscn).
const BOX_FONT_SIZE: int = 32
const BOX_NAME_SIZE: int = 28
const BOX_HINT_SIZE: int = 22

@export_group("Texto")
@export var style: Style = Style.BOX
@export_range(5.0, 120.0, 1.0) var chars_per_second: float = 38.0  # Velocidade da digitação.
@export var speaker: String = ""  # Nome mostrado em dourado (só no BOX).
@export var backdrop: Texture2D = null  # Ilustração de fundo (só no BOX).

@export_group("Avanço")
## Liga: depois de digitar a fala, espera `hold_time` e passa para a próxima sozinho.
@export var auto_advance: bool = true
@export_range(0.0, 10.0, 0.1) var hold_time: float = 1.4  # Pausa depois de cada fala.
@export var allow_skip: bool = true  # Permite completar/avançar com tecla ou clique e pular segurando ESC.
@export var free_on_finish: bool = false  # Remove o nó da cena quando termina.

var _lines: PackedStringArray = PackedStringArray()
var _index: int = -1
var _typing: bool = false
var _playing: bool = false
var _line_start_msec: int = 0
var _tween: Tween = null
var _jitter_tween: Tween = null

var _root: Control = null
var _label: Label = null  # Texto da fala (os dois estilos).
var _name_label: Label = null  # Nome de quem fala (BOX).
var _box: Panel = null  # Caixa (BOX).
var _button: Button = null  # "Avançar" (BOX).
var _backdrop_layer: CanvasLayer = null
var _backdrop_rect: TextureRect = null
var _skip_label: Label = null
var _skip_timer: Timer = null


func _init() -> void:
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS  # Funciona com o jogo pausado.


func _ready() -> void:
	_build_ui()
	visible = false


## Cria, adiciona em `parent` e toca as falas. Devolve o diálogo (use `await d.finished`).
static func show_lines(parent: Node, new_lines: PackedStringArray, new_style: Style = Style.BOX,
		new_speaker: String = "", new_backdrop: Texture2D = null) -> Dialogue:
	var dialogue: Dialogue = Dialogue.new()
	dialogue.free_on_finish = true
	dialogue.style = new_style
	dialogue.speaker = new_speaker
	dialogue.backdrop = new_backdrop
	parent.add_child(dialogue)
	dialogue.play(new_lines)
	return dialogue


## Toca as falas em ordem. A primeira começa no fim do quadro (dá tempo de ligar os sinais depois do play()).
## Array vazio termina logo em seguida.
func play(new_lines: PackedStringArray) -> void:
	_lines = new_lines
	_index = -1
	_playing = true
	if _root == null:
		_build_ui()
	_apply_style()
	visible = true
	_next_line.call_deferred()


func is_playing() -> bool:
	return _playing


## Texto da fala atual (usado nos testes).
func get_current_text() -> String:
	return _label.text if _label != null else ""


## Fecha o diálogo agora (emite `finished`).
func stop() -> void:
	if _playing:
		_close()


func _input(event: InputEvent) -> void:
	if not _playing or not allow_skip:
		return
	if event.is_action(&"ui_cancel") and not event.is_echo():  # ESC: segurar para pular.
		if event.is_pressed():
			_skip_timer.start(SKIP_HOLD_TIME)
			_skip_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			_skip_timer.stop()
			_skip_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
		get_viewport().set_input_as_handled()
		return
	var pressed: bool = event.is_action_pressed(&"ui_accept")
	if not pressed and event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if not pressed or Time.get_ticks_msec() - _line_start_msec < INPUT_GRACE_MSEC:
		return
	get_viewport().set_input_as_handled()
	_advance()


## Completa a digitação ou, se já completa, passa para a próxima fala.
func _advance() -> void:
	if not _playing:
		return
	if _typing:
		_kill_tween()
		_typing = false
		_label.visible_ratio = 1.0
		_line_start_msec = Time.get_ticks_msec()
		_tween = create_tween()
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_append_hold()
	else:
		_next_line()


func _next_line() -> void:
	if not _playing:
		return
	_index += 1
	if _index >= _lines.size():
		_close()
		return
	var text: String = _lines[_index]
	_label.text = text
	_label.visible_ratio = 0.0
	_line_start_msec = Time.get_ticks_msec()
	_typing = true
	line_started.emit(_index)
	_kill_tween()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_label, "visible_ratio", 1.0, maxf(float(text.length()) / chars_per_second, 0.05))
	_tween.tween_callback(_on_typed)
	_append_hold()


func _on_typed() -> void:
	_typing = false


func _append_hold() -> void:
	if auto_advance:
		_tween.tween_interval(hold_time)
		_tween.tween_callback(_next_line)


func _close() -> void:
	_kill_tween()
	if _jitter_tween != null and _jitter_tween.is_valid():
		_jitter_tween.kill()
	_typing = false
	_playing = false
	visible = false
	_backdrop_layer.visible = false
	finished.emit()
	if free_on_finish:
		queue_free()


## Segurou ESC por SKIP_HOLD_TIME: pula o diálogo todo.
func _on_skip_held() -> void:
	if _playing:
		skipped.emit()
		_close()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Mostra só as peças do estilo atual e liga o tremor da voz.
func _apply_style() -> void:
	var is_box: bool = style == Style.BOX
	_box.visible = is_box
	_name_label.visible = is_box and not speaker.is_empty()
	_name_label.text = speaker
	_button.visible = is_box
	_backdrop_layer.visible = is_box and backdrop != null
	_backdrop_rect.texture = backdrop
	_skip_label.visible = allow_skip
	_label.reparent(_box if is_box else _root, false)
	if is_box:
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.offset_left = 32.0
		_label.offset_right = -160.0
		_label.offset_top = 32.0 if not speaker.is_empty() else 16.0
		_label.offset_bottom = -12.0
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_label.add_theme_font_size_override(&"font_size", BOX_FONT_SIZE)
		_label.add_theme_color_override(&"font_color", Palette.TEXT)
		_label.add_theme_constant_override(&"outline_size", 0)
	else:
		_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_label.offset_left = -VOICE_WIDTH * 0.5
		_label.offset_right = VOICE_WIDTH * 0.5
		_label.offset_top = VOICE_TOP
		_label.offset_bottom = VOICE_TOP + 116.0
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_label.add_theme_font_size_override(&"font_size", VOICE_FONT_SIZE)
		_label.add_theme_color_override(&"font_color", VOICE_COLOR)
		_label.add_theme_color_override(&"font_outline_color", Color(VOICE_GLOW, 0.35))
		_label.add_theme_constant_override(&"outline_size", 10)
		_start_voice_jitter()


## Tremor da voz como no tutorial, mas por Tween em loop (sem código por quadro).
func _start_voice_jitter() -> void:
	if _jitter_tween != null and _jitter_tween.is_valid():
		_jitter_tween.kill()
	_jitter_tween = create_tween().set_loops()
	_jitter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_jitter_tween.tween_interval(VOICE_JITTER_STEP)
	_jitter_tween.tween_callback(_jitter_voice)


func _jitter_voice() -> void:
	if style != Style.VOICE:
		return
	var jx: float = randf_range(-VOICE_JITTER, VOICE_JITTER)
	var jy: float = randf_range(-VOICE_JITTER, VOICE_JITTER)
	_label.offset_left = -VOICE_WIDTH * 0.5 + jx
	_label.offset_right = VOICE_WIDTH * 0.5 + jx
	_label.offset_top = VOICE_TOP + jy
	_label.offset_bottom = VOICE_TOP + 116.0 + jy


## Monta tudo uma vez: ilustração (camada própria), raiz com tema, caixa, nome, botão e aviso de pular.
func _build_ui() -> void:
	if _root != null:
		return
	_backdrop_layer = CanvasLayer.new()
	_backdrop_layer.layer = BACKDROP_LAYER
	add_child(_backdrop_layer)
	_backdrop_rect = TextureRect.new()
	_backdrop_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_layer.add_child(_backdrop_rect)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = THEME
	add_child(_root)

	_box = Panel.new()  # Mesmas medidas do TextBox de cutscene1.tscn.
	_box.anchor_top = 1.0
	_box.anchor_right = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 120.0
	_box.offset_top = -140.0
	_box.offset_right = -120.0
	_box.offset_bottom = -24.0
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_box)

	_name_label = Label.new()
	_name_label.position = Vector2(32.0, 6.0)
	_name_label.add_theme_font_size_override(&"font_size", BOX_NAME_SIZE)
	_name_label.add_theme_color_override(&"font_color", Palette.ACCENT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_name_label)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_label)

	_button = Button.new()  # O botão "Avançar" da cutscene (visual vem do tema).
	_button.text = "Avançar"
	_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_button.anchor_left = 1.0
	_button.anchor_top = 1.0
	_button.offset_left = -156.0
	_button.offset_top = -84.0
	_button.offset_right = -20.0
	_button.offset_bottom = -28.0
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_button_pressed)
	_box.add_child(_button)

	_skip_label = Label.new()  # "Segure ESC para pular", como na cutscene.
	_skip_label.text = "Segure ESC para pular"
	_skip_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip_label.offset_left = -300.0
	_skip_label.offset_right = -16.0
	_skip_label.offset_top = 12.0
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_label.add_theme_font_size_override(&"font_size", BOX_HINT_SIZE)
	_skip_label.add_theme_color_override(&"font_color", Palette.TEXT_DIM)
	_skip_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_skip_label)

	_skip_timer = Timer.new()
	_skip_timer.one_shot = true
	_skip_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_skip_timer.timeout.connect(_on_skip_held)
	add_child(_skip_timer)


func _on_button_pressed() -> void:
	if allow_skip:
		_advance()

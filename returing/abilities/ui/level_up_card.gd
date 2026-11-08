class_name LevelUpCard
extends PanelContainer
## Carta de habilidade do menu de level-up: amuleto, nome, efeito, recarga/duração e setas.
## Cartas lendárias ganham moldura dourada dupla, ornamentos nos cantos e o aviso de perda.

signal selected(ability: AbilityData)

const COLOR_TEXT: Color = Palette.TEXT
const COLOR_TEXT_MUTED: Color = Palette.TEXT_DIM
const COLOR_WARNING: Color = Palette.DANGER
const COLOR_WARNING_BG: Color = Palette.PANEL
## Anel de foco: mesmo destaque (ACCENT) dos botões.
const COLOR_FOCUS: Color = Palette.ACCENT

const CARD_WIDTH: float = 240.0
const AMULET_SIZE: float = 128.0
const TEXT_WIDTH: float = 210.0
const DESCRIPTION_HEIGHT: float = 72.0
## Tamanhos em múltiplos de 16 (fontes pixeladas).
const FONT_TITLE: int = Palette.FONT_BODY
const FONT_BODY: int = Palette.FONT_SMALL
const FONT_SMALL: int = Palette.FONT_SMALL
## Escala da carta em foco/hover e na entrada, e duração (s) das animações.
const HIGHLIGHT_SCALE: float = 1.04
const ENTER_SCALE: float = 0.92
const ENTER_TIME: float = 0.22
const HIGHLIGHT_TIME: float = 0.12
## Distância (px) da moldura dourada interna até a borda da carta.
const FRAME_INSET: float = 6.0
const CORNER_SIZE: float = 14.0
## Altura mínima do banner de aviso da lendária (3 linhas de texto pequeno).
const WARNING_HEIGHT: float = 88.0

const RARITY_NAMES: Dictionary = {
	AbilityData.Rarity.COMUM: "COMUM",
	AbilityData.Rarity.AVANCADA: "AVANÇADA",
	AbilityData.Rarity.LENDARIA: "LENDÁRIA",
}
const WARNING_TEXT: String = "Ao escolher esta lendária você perde TODAS as outras habilidades desta run."

var ability: AbilityData = null
var _color: Color = Color.WHITE
var _legendary: bool = false
var _overlay: Control = null
var _read_only: bool = false
var _scale_target: float = 1.0
var _scale_tween: Tween = null


## Triângulo de alerta desenhado por código.
class _AlertIcon extends Control:
	const COLOR: Color = Palette.DANGER
	const ICON_SIZE: float = 26.0

	func _init() -> void:
		custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var tri: PackedVector2Array = PackedVector2Array([
			Vector2(w * 0.5, h * 0.06), Vector2(w * 0.97, h * 0.92), Vector2(w * 0.03, h * 0.92), Vector2(w * 0.5, h * 0.06),
		])
		draw_polyline(tri, COLOR, 2.5, true)
		draw_line(Vector2(w * 0.5, h * 0.36), Vector2(w * 0.5, h * 0.62), COLOR, 2.5, true)
		draw_circle(Vector2(w * 0.5, h * 0.77), 1.8, COLOR)


## `reserve_warning_space`: reserva o espaço do banner (cartas comuns ao lado de uma lendária),
## para as setas de todas as cartas ficarem na mesma altura.
## `read_only`: carta de consulta (menu de build): navega e destaca, mas nunca emite `selected`.
func setup(data: AbilityData, reserve_warning_space: bool = false, read_only: bool = false) -> void:
	_read_only = read_only
	ability = data
	_legendary = data.rarity == AbilityData.Rarity.LENDARIA
	_color = AmuletIcon.color_for_rarity(data.rarity)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = CARD_WIDTH
	_build_content(reserve_warning_space)
	_build_overlay()
	_ignore_mouse_in_children(self)
	mouse_entered.connect(grab_focus)
	focus_entered.connect(_set_highlight.bind(true))
	focus_exited.connect(_set_highlight.bind(false))
	resized.connect(_center_pivot)


func _build_content(reserve_warning_space: bool) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)

	var rarity: Label = _label(str(RARITY_NAMES[ability.rarity]), FONT_SMALL, _color)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rarity)

	var amulet: AmuletIcon = AmuletIcon.new()
	amulet.custom_minimum_size = Vector2(AMULET_SIZE, AMULET_SIZE)
	amulet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	amulet.set_ability(ability)
	box.add_child(amulet)

	var title: Label = _label(ability.display_name, FONT_TITLE,
			AmuletIcon.COLOR_LEGENDARY_LIGHT if _legendary else COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # nomes longos quebram em 2 linhas
	title.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(title)

	var description: Label = _label(ability.description, FONT_BODY, COLOR_TEXT)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(TEXT_WIDTH, DESCRIPTION_HEIGHT)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL  # empurra recarga e setas para baixo
	box.add_child(description)

	var info: Label = _label(_info_text(), FONT_SMALL, COLOR_TEXT_MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)

	var arrows: ArrowSequenceView = ArrowSequenceView.new()
	arrows.set_sequence(ability.sequence)
	arrows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(arrows)

	if _legendary and not _read_only:  # o aviso de perda é da ESCOLHA; a build consultada já foi escolhida
		box.add_child(_build_warning())
	elif reserve_warning_space and not _read_only:
		var spacer: Control = Control.new()
		spacer.custom_minimum_size.y = WARNING_HEIGHT
		box.add_child(spacer)


func _info_text() -> String:
	var recarga: String = "Recarga %s s" % _fmt(ability.cooldown)
	if ability.duration > 0.0:
		return "%s  ·  Duração %s s" % [recarga, _fmt(ability.duration)]
	return "%s  ·  Instantânea" % recarga


func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, floorf(value)) else "%.1f" % value


## Banner de perda: obrigatório em toda carta lendária.
func _build_warning() -> Control:
	var banner: PanelContainer = PanelContainer.new()
	var style: PixelBox = PixelBox.new()
	style.fill_color = COLOR_WARNING_BG
	style.border_color = COLOR_WARNING
	style.outline_width = 0
	style.corner_cut = 0
	style.set_content_margin_all(8.0)
	banner.add_theme_stylebox_override(&"panel", style)
	banner.custom_minimum_size.y = WARNING_HEIGHT
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	banner.add_child(row)
	var icon: _AlertIcon = _AlertIcon.new()
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text: Label = _label(WARNING_TEXT, FONT_SMALL, COLOR_WARNING)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = TEXT_WIDTH - _AlertIcon.ICON_SIZE - 8.0
	row.add_child(text)
	return banner


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


## Só a carta recebe o mouse: tudo dentro dela deixa o clique passar.
func _ignore_mouse_in_children(node: Node) -> void:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_in_children(child)


func _gui_input(event: InputEvent) -> void:
	if _read_only:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		selected.emit(ability)
	elif event.is_action_pressed(&"ui_accept"):
		accept_event()
		selected.emit(ability)


## Moldura e foco ficam num filho que cobre o conteúdo: ele é desenhado por cima do fundo da carta.
func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_paint_overlay)


func _paint_overlay() -> void:
	# O filho cobre só a área de conteúdo: a carta inteira começa nas margens do estilo para fora dele.
	var style: StyleBox = get_theme_stylebox(&"panel")
	var margin: Vector2 = Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
	var card_rect: Rect2 = Rect2(-margin, _overlay.size + margin * 2.0)
	if _legendary:
		_paint_legendary_frame(card_rect)
	if has_focus():
		_overlay.draw_rect(card_rect, COLOR_FOCUS, false, 2.0)


## Moldura dourada dupla com ornamentos nos cantos.
func _paint_legendary_frame(card_rect: Rect2) -> void:
	var gold: Color = AmuletIcon.COLOR_LEGENDARY
	var light: Color = AmuletIcon.COLOR_LEGENDARY_LIGHT
	var inner: Rect2 = card_rect.grow(-FRAME_INSET)
	var line: Color = gold
	line.a = 0.8
	_overlay.draw_rect(inner, line, false, 1.0)
	var corners: Array[Vector2] = [
		inner.position,
		Vector2(inner.end.x, inner.position.y),
		inner.end,
		Vector2(inner.position.x, inner.end.y),
	]
	var signs: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0)]
	for i: int in corners.size():
		var corner: Vector2 = corners[i]
		var sign_v: Vector2 = signs[i]
		_overlay.draw_line(corner, corner + Vector2(sign_v.x * CORNER_SIZE, 0.0), light, 2.5, true)
		_overlay.draw_line(corner, corner + Vector2(0.0, sign_v.y * CORNER_SIZE), light, 2.5, true)
		var d: float = CORNER_SIZE * 0.32
		var c: Vector2 = corner - sign_v * 3.0
		_overlay.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0.0, -d), c + Vector2(d, 0.0), c + Vector2(0.0, d), c + Vector2(-d, 0.0),
		]), gold)


func _center_pivot() -> void:
	pivot_offset = size * 0.5


## Foco e hover: a carta cresce um pouco (o anel branco é desenhado pelo overlay).
func _set_highlight(on: bool) -> void:
	_overlay.queue_redraw()
	_scale_target = HIGHLIGHT_SCALE if on else 1.0
	_animate_scale(HIGHLIGHT_TIME, 0.0, false)


## Entrada: a carta aparece (fade + cresce) depois de `delay` segundos.
func play_entrance(delay: float) -> void:
	modulate.a = 0.0
	scale = Vector2.ONE * ENTER_SCALE
	var fade: Tween = UiTween.create(self)
	fade.tween_property(self, ^"modulate:a", 1.0, ENTER_TIME).set_delay(delay)
	_animate_scale(ENTER_TIME, delay, true)


## Uma única animação de escala por vez: foco durante a entrada não briga com ela.
func _animate_scale(time: float, delay: float, pop: bool) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = UiTween.create(self)
	var step: PropertyTweener = _scale_tween.tween_property(self, ^"scale", Vector2.ONE * _scale_target, time).set_delay(delay)
	if pop:
		step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

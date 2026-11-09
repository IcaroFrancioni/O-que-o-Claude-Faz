class_name CooldownSlot
extends Control
## Slot de uma habilidade na HUD de cooldown: amuleto, varredura radial da recarga, tempo restante,
## anel de duração (efeito ativo) e pulso dourado ao ficar pronta. Sem habilidade, vira um slot vazio.
## Só mostra o que recebe em `update_cooldown`: quem manda os valores é a HUD (sinais do componente).

## Tamanho do slot (maior no celular, para o toque ser confortável).
const SLOT_SIZE: float = 56.0
const TOUCH_SLOT_SIZE: float = 64.0
const COLOR_SWEEP: Color = Color(0.82, 0.85, 0.95, 0.34)
const COLOR_SWEEP_EDGE: Color = Color(1.0, 1.0, 1.0, 0.7)
const COLOR_COOLING_TINT: Color = Color(0.0, 0.0, 0.0, 0.3)
const COLOR_EMPTY: Color = Color(0.72, 0.7, 0.62, 0.28)
## Cor do anel de duração na fase de penalidade (Overclock), distinta do dourado do bônus.
const COLOR_PENALTY: Color = UiPalette.DANGER
const RING_WIDTH: float = 3.0
const RING_GAP: float = 4.0
const SWEEP_POINTS: int = 48
const PULSE_TIME: float = 0.55
const PULSE_GROWTH: float = 0.45
## Tamanho do número do cooldown: 1,5 x Palette.FONT_BASE (16): o 2x (32) cobria o ícone do amuleto.
const FONT_SIZE: int = Palette.FONT_BASE + Palette.FONT_BASE / 2
const OUTLINE_SIZE: int = 3
## Abaixo disto (s) o tempo mostra uma casa decimal.
const DECIMAL_BELOW: float = 10.0

## Clique (ou toque) no amuleto: a HUD repassa para quem abre o menu de build.
signal pressed(ability: AbilityData)

var ability: AbilityData = null

var _amulet: AmuletIcon = null
var _overlay: Control = null
var _label: Label = null
var _remaining: float = 0.0
var _total: float = 1.0
var _cooling: bool = false
var _pulse: float = 0.0
var _pulse_tween: Tween = null


func _init() -> void:
	var side: float = TOUCH_SLOT_SIZE if Platform.is_mobile else SLOT_SIZE
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_amulet = AmuletIcon.new()
	add_child(_amulet)
	_amulet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pixel_font: Font = Palette.load_theme().default_font  # VT323 (a mesma dos menus); o tema da HUD não tem fonte
	if pixel_font != null:
		_label.add_theme_font_override(&"font", pixel_font)
	_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_label.add_theme_color_override(&"font_color", UiPalette.TEXT)
	_label.add_theme_color_override(&"font_outline_color", UiPalette.OUTLINE)
	_label.add_theme_constant_override(&"outline_size", OUTLINE_SIZE)
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_amulet.set_ability(ability)
	_update_clickable()


func _exit_tree() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()


## Define a habilidade do slot (null = slot vazio).
func set_ability(data: AbilityData) -> void:
	ability = data
	_remaining = 0.0
	_cooling = false
	_update_clickable()
	if _amulet != null:
		_amulet.set_ability(data)
		_label.text = ""
		_overlay.queue_redraw()


## Só slot com habilidade recebe clique (STOP: o clique é consumido aqui e não chega ao jogo).
func _update_clickable() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if ability != null else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ability != null else Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if ability != null and click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit(ability)


## Estado atual da recarga (segundos restantes e total). Com `animate`, o fim da recarga pulsa.
func update_cooldown(remaining: float, total: float, animate: bool = true) -> void:
	if ability == null:
		return
	var was_cooling: bool = _cooling
	_remaining = remaining
	_total = maxf(total, 0.01)
	_cooling = remaining > 0.0
	_label.text = _format_time(remaining) if _cooling else ""
	_overlay.queue_redraw()
	if animate and was_cooling and not _cooling:
		_start_pulse()


## True enquanto o efeito da habilidade ainda está ativo (a recarga conta desde a ativação).
func is_effect_active() -> bool:
	return ability != null and _cooling and ability.duration > 0.0 and (_total - _remaining) < ability.duration


## True durante a fase de penalidade de uma habilidade com duas fases (Overclock).
func is_penalty_active() -> bool:
	return is_effect_active() and ability.is_penalty_at(_total - _remaining)


## Texto do tempo: inteiro a partir de 10 s e uma casa decimal abaixo disso.
static func _format_time(seconds: float) -> String:
	if seconds >= DECIMAL_BELOW:
		return "%d" % ceili(seconds)
	return "%.1f" % maxf(seconds, 0.0)


func _start_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = UiTween.create_pausable(self)  # o pulso congela junto com o jogo pausado
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, PULSE_TIME)


func _set_pulse(value: float) -> void:
	_pulse = value
	_overlay.queue_redraw()


# --- Desenho ---

func _hex(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in AmuletIcon.HEX_SIDES:
		points.append(center + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / float(AmuletIcon.HEX_SIDES)) * radius)
	return points


func _hex_radius() -> float:
	var legendary: bool = ability != null and ability.rarity == AbilityData.Rarity.LENDARIA
	return minf(size.x, size.y) * 0.5 * (AmuletIcon.RADIUS_LEGENDARY if legendary else AmuletIcon.RADIUS_NORMAL)


func _draw_overlay() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = _hex_radius()
	if ability == null:  # slot vazio: contorno discreto
		var outline: PackedVector2Array = _hex(center, radius)
		outline.append(outline[0])
		_overlay.draw_polyline(outline, COLOR_EMPTY, 2.0, true)
		return
	if _cooling:
		var hex: PackedVector2Array = _hex(center, radius)
		_overlay.draw_colored_polygon(hex, COLOR_COOLING_TINT)
		var fraction: float = clampf(_remaining / _total, 0.0, 1.0)
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(_sweep_polygon(center, radius * 1.2, fraction), hex):
			_overlay.draw_colored_polygon(piece, COLOR_SWEEP)
		# linha do ponteiro: marca até onde a recarga já andou
		var edge_angle: float = -PI * 0.5 + (1.0 - fraction) * TAU
		_overlay.draw_line(center, center + Vector2.from_angle(edge_angle) * radius, COLOR_SWEEP_EDGE, 2.0, true)
		if is_effect_active():  # anel de duração: encolhe até o efeito acabar
			var left: float = 1.0 - (_total - _remaining) / ability.duration
			_overlay.draw_arc(center, radius + RING_GAP, -PI * 0.5, -PI * 0.5 + TAU * clampf(left, 0.0, 1.0),
					SWEEP_POINTS, COLOR_PENALTY if is_penalty_active() else UiPalette.GOLD, RING_WIDTH, true)
	if _pulse > 0.0:  # pulso: o contorno dourado se expande e some
		var ring: PackedVector2Array = _hex(center, radius * (1.0 + PULSE_GROWTH * (1.0 - _pulse)))
		ring.append(ring[0])
		var color: Color = UiPalette.GOLD_BRIGHT
		color.a = _pulse
		_overlay.draw_polyline(ring, color, RING_WIDTH, true)


## Setor que cobre a fração `fraction` da volta, no sentido horário, terminando no topo.
func _sweep_polygon(center: Vector2, radius: float, fraction: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([center])
	var start: float = -PI * 0.5 + (1.0 - fraction) * TAU
	var steps: int = maxi(2, int(ceilf(float(SWEEP_POINTS) * fraction)))
	for i: int in range(steps + 1):
		points.append(center + Vector2.from_angle(start + TAU * fraction * float(i) / float(steps)) * radius)
	return points

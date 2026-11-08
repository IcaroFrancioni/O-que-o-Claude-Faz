class_name TouchCommandPad
extends Control
## Controles de toque do modo comando (só no celular): um botão "CMD" que abre/fecha o modo e,
## com o modo aberto, quatro botões de seta. Fica na faixa do topo da tela, onde o `MobileControls`
## não inicia analógicos (as barras de vida e o botão de pausa ficam nos cantos).
## Trata o toque por conta própria porque o `MobileControls` consome os cliques emulados do toque.

## Toque no amuleto de uma habilidade da faixa compacta (abre o menu de build).
signal build_requested(ability: AbilityData)

const COLOR_FILL: Color = Color(0.62, 0.62, 0.62, 0.5)
const COLOR_FILL_ACTIVE: Color = Color(0.91, 0.76, 0.35, 0.65)
const COLOR_RING: Color = Color(0.85, 0.85, 0.85, 0.5)
const COLOR_ICON: Color = Color(1.0, 1.0, 1.0, 0.9)
const BUTTON_RADIUS: float = 24.0
const BUTTON_SPACING: float = 62.0
## Centro vertical da fileira: abaixo da barra de XP e dentro da faixa sem analógicos do topo.
const ROW_Y: float = 52.0
## Folga na área de toque.
const HIT_SLACK: float = 1.2
const FONT_SIZE: int = 12
## Ordem dos botões de seta na fileira.
const ARROWS: Array = [
	AbilityData.Dir.UP, AbilityData.Dir.DOWN, AbilityData.Dir.LEFT, AbilityData.Dir.RIGHT,
]

var _abilities: AbilityComponent = null
var _hud: CommandHud = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Platform.is_mobile:
		visible = false
		set_process_input(false)


func setup(abilities: AbilityComponent, hud: CommandHud = null) -> void:
	_abilities = abilities
	_hud = hud
	CombatUtils.connect_once(abilities.command_mode_changed, _on_state_changed)
	CombatUtils.connect_once(abilities.abilities_changed, queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(_abilities):
		CombatUtils.disconnect_if_connected(_abilities.command_mode_changed, _on_state_changed)
		CombatUtils.disconnect_if_connected(_abilities.abilities_changed, queue_redraw)


func _on_state_changed(_active: bool) -> void:
	queue_redraw()


## Centro do botão `index` (0 = CMD; 1 a 4 = setas), com a fileira centralizada na tela.
func _button_center(index: int) -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var first: float = view.x * 0.5 - BUTTON_SPACING * 2.0
	return Vector2(first + BUTTON_SPACING * float(index), ROW_Y)


func _is_shown() -> bool:
	return Platform.is_mobile and _abilities != null and not _abilities.abilities.is_empty()


func _input(event: InputEvent) -> void:
	if not _is_shown():
		return
	var pos: Vector2 = Vector2.ZERO
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var click: InputEventMouseButton = event as InputEventMouseButton
	if touch != null and touch.pressed:
		pos = touch.position
	elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
			and Platform.mouse_as_finger and click.device != InputEvent.DEVICE_ID_EMULATION:
		pos = click.position  # PC com `--mobile`: o mouse faz o papel do dedo
	else:
		return
	if _handle_press(pos):
		get_viewport().set_input_as_handled()


## True se o toque caiu num botão.
func _handle_press(pos: Vector2) -> bool:
	if pos.distance_to(_button_center(0)) <= BUTTON_RADIUS * HIT_SLACK:
		_abilities.toggle_command_mode()
		return true
	if not _abilities.command_active:
		return _try_slot_tap(pos)
	for i: int in ARROWS.size():
		if pos.distance_to(_button_center(i + 1)) <= BUTTON_RADIUS * HIT_SLACK:
			_abilities.press_arrow(ARROWS[i])
			return true
	return false


## True se o toque caiu num amuleto da faixa compacta.
func _try_slot_tap(pos: Vector2) -> bool:
	if _hud == null:
		return false
	for entry: Dictionary in _hud.get_slot_hit_rects():
		if (entry["rect"] as Rect2).has_point(pos):
			build_requested.emit(entry["ability"] as AbilityData)
			return true
	return false


func _draw() -> void:
	if not _is_shown():
		return
	var active: bool = _abilities.command_active
	var cmd_center: Vector2 = _button_center(0)
	draw_circle(cmd_center, BUTTON_RADIUS, COLOR_FILL_ACTIVE if active else COLOR_FILL)
	draw_arc(cmd_center, BUTTON_RADIUS, 0.0, TAU, 32, COLOR_RING, 2.0, true)
	var font: Font = ThemeDB.fallback_font
	var label_size: Vector2 = font.get_string_size("CMD", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	draw_string(font, cmd_center + Vector2(-label_size.x * 0.5, FONT_SIZE * 0.35), "CMD",
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_ICON)
	if not active:
		return
	for i: int in ARROWS.size():
		var center: Vector2 = _button_center(i + 1)
		draw_circle(center, BUTTON_RADIUS, COLOR_FILL)
		draw_arc(center, BUTTON_RADIUS, 0.0, TAU, 32, COLOR_RING, 2.0, true)
		var angle: float = float(ArrowSequenceView.DIR_ANGLE.get(ARROWS[i], 0.0))
		var points: PackedVector2Array = PackedVector2Array()
		for corner: Vector2 in ArrowSequenceView.ARROW_SHAPE:
			points.append(center + corner.rotated(angle) * BUTTON_RADIUS * 0.5)
		draw_colored_polygon(points, COLOR_ICON)

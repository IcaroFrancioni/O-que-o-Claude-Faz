class_name ArrowSequenceView
extends Control
## Desenha uma sequência de setas por código. Usado pela HUD de comando e pelo menu de level-up.
## Estados: normal, apagada (não combina) e em cooldown (cinza). Setas acertadas ficam acesas.

enum State { NORMAL, DIMMED, COOLDOWN }

const COLOR_NORMAL: Color = Color(0.86, 0.88, 0.92, 1.0)
const COLOR_HIT: Color = Color("#e8c15a")
const COLOR_DIMMED: Color = Color(0.86, 0.88, 0.92, 0.22)
const COLOR_COOLDOWN: Color = Color(0.42, 0.43, 0.47, 0.85)
const COLOR_PULSE: Color = Color(1.0, 1.0, 1.0, 1.0)
## Contorno do formato da seta apontando para cima (unidades de meia-célula).
const ARROW_SHAPE: Array[Vector2] = [
	Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.42, 0.0), Vector2(0.42, 1.0),
	Vector2(-0.42, 1.0), Vector2(-0.42, 0.0), Vector2(-1.0, 0.0),
]
## Ângulo de cada direção (a forma base aponta para cima).
const DIR_ANGLE: Dictionary = {
	AbilityData.Dir.UP: 0.0,
	AbilityData.Dir.RIGHT: PI * 0.5,
	AbilityData.Dir.DOWN: PI,
	AbilityData.Dir.LEFT: PI * 1.5,
}
const SHAKE_PIXELS: float = 5.0
const SHAKE_TIME: float = 0.3
const PULSE_TIME: float = 0.45

## Tamanho de cada seta e espaço entre elas (px).
@export var arrow_size: float = 18.0:
	set(value):
		arrow_size = value
		update_minimum_size()
		queue_redraw()
@export var arrow_gap: float = 5.0:
	set(value):
		arrow_gap = value
		update_minimum_size()
		queue_redraw()

var _sequence: Array[int] = []
var _progress: int = 0
var _state: State = State.NORMAL
var _shake_offset: float = 0.0
var _pulse: float = 0.0
var _shake_tween: Tween = null
var _pulse_tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_sequence(new_sequence: Array[int]) -> void:
	_sequence = new_sequence.duplicate()
	_progress = 0
	update_minimum_size()
	queue_redraw()


## Quantas setas já foram acertadas (ficam acesas).
func set_progress(count: int) -> void:
	_progress = clampi(count, 0, _sequence.size())
	queue_redraw()


func set_state(new_state: State) -> void:
	if new_state == _state:
		return
	_state = new_state
	queue_redraw()


## Treme as setas (erro de digitação).
func shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = UiTween.create_pausable(self)
	_shake_tween.tween_method(_apply_shake, 0.0, 1.0, SHAKE_TIME)


## Pequeno brilho (habilidade ficou pronta).
func pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = UiTween.create_pausable(self)
	_pulse_tween.tween_method(_apply_pulse, 1.0, 0.0, PULSE_TIME)


func _apply_shake(t: float) -> void:
	_shake_offset = sin(t * 40.0) * SHAKE_PIXELS * (1.0 - t)
	queue_redraw()


func _apply_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var count: int = _sequence.size()
	if count == 0:
		return Vector2(0.0, arrow_size)
	return Vector2(float(count) * (arrow_size + arrow_gap) - arrow_gap, arrow_size)


func _draw() -> void:
	var half: float = arrow_size * 0.5
	for i: int in _sequence.size():
		var center: Vector2 = Vector2(float(i) * (arrow_size + arrow_gap) + half + _shake_offset, half)
		var angle: float = float(DIR_ANGLE.get(_sequence[i], 0.0))
		var points: PackedVector2Array = PackedVector2Array()
		for corner: Vector2 in ARROW_SHAPE:
			points.append(center + corner.rotated(angle) * half * 0.92)
		draw_colored_polygon(points, _color_for(i))


func _color_for(index: int) -> Color:
	var base: Color = COLOR_NORMAL
	if index < _progress:
		base = COLOR_HIT
	else:
		match _state:
			State.DIMMED:
				base = COLOR_DIMMED
			State.COOLDOWN:
				base = COLOR_COOLDOWN
	return base.lerp(COLOR_PULSE, _pulse * 0.8)

class_name ShieldEffect
extends AbilityEffect
## Escudo: invulnerabilidade pela duração da habilidade, com um círculo ao redor do personagem.

const DEFAULT_TIME: float = 3.0
## Nos últimos segundos o círculo pisca para avisar que vai acabar.
const BLINK_TIME: float = 0.6

@export var radius: float = 26.0
@export var shield_color: Color = Color(0.45, 0.8, 1.0, 1.0)

var _time_left: float = DEFAULT_TIME
var _age: float = 0.0


func _on_activate() -> void:
	_time_left = data.duration if data != null and data.duration > 0.0 else DEFAULT_TIME
	caster.conceder_invulnerabilidade(_time_left)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	_time_left -= delta
	queue_redraw()
	if _time_left <= 0.0:
		_finish()


## Cancelado antes do fim (ex.: lendária apagando as outras): a invulnerabilidade também termina.
func _on_cleanup() -> void:
	if _time_left > 0.0 and is_instance_valid(caster):
		caster.remover_invulnerabilidade()


func _draw() -> void:
	var pulso: float = 0.5 + 0.5 * sin(_age * 8.0)
	var alpha: float = 1.0
	if _time_left < BLINK_TIME:
		alpha = 0.35 + 0.65 * pulso
	var fill: Color = shield_color
	fill.a = 0.10 * alpha
	draw_circle(Vector2.ZERO, radius, fill)
	var borda: Color = shield_color
	borda.a = (0.55 + 0.35 * pulso) * alpha
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, borda, 2.0)
	var interna: Color = shield_color
	interna.a = 0.3 * alpha
	draw_arc(Vector2.ZERO, radius - 4.0, 0.0, TAU, 48, interna, 1.0)

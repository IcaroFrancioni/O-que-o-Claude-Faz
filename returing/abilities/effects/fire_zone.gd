class_name FireZone
extends PooledArea
## Chão em chamas deixado pelo Rastro de Fogo: causa dano por tick em quem estiver dentro e some.

@export var flame_color: Color = Color(1.0, 0.45, 0.1, 0.6)
@export var core_color: Color = Color(1.0, 0.85, 0.3, 0.8)

## Quantos pontos de chama são desenhados dentro da área.
const FLAME_COUNT: int = 6
## Tempo final (s) em que a chama esmaece.
const FADE_TIME: float = 0.6
## Intervalo (s) entre redesenhos da chama.
const REDRAW_INTERVAL: float = 0.08

var _damage: int = 0
var _tick_interval: float = 0.5
var _life_left: float = 0.0
var _tick_left: float = 0.0
var _radius: float = 30.0
var _source: Node = null
var _redraw_left: float = 0.0
## Tempo de vida acumulado (anima a chama junto com o tempo do jogo, que congela na pausa).
var _age: float = 0.0
var _overlapping: Array[Area2D] = []

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	super._ready()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


## Acende a chama em `origin`.
func ignite(origin: Vector2, radius: float, damage: int, tick_interval: float, lifetime: float, source: Node) -> void:
	global_position = origin
	_radius = radius
	_damage = damage
	_tick_interval = maxf(tick_interval, 0.05)
	_life_left = maxf(lifetime, 0.1)
	_age = 0.0
	_tick_left = 0.0
	_source = source
	_overlapping.clear()
	CombatUtils.set_unique_circle_radius(_shape, radius)
	queue_redraw()


func _on_pool_deactivate() -> void:
	_overlapping.clear()
	_source = null


func _physics_process(delta: float) -> void:
	_age += delta
	_life_left -= delta
	if _life_left <= 0.0:
		recycle()
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += _tick_interval
		_burn()
	_redraw_left -= delta
	if _redraw_left <= 0.0:
		_redraw_left = REDRAW_INTERVAL
		queue_redraw()


## Causa dano em todo mundo que está dentro da chama.
func _burn() -> void:
	var origem: Node = _source if CombatUtils.is_alive(_source) else self
	for i: int in range(_overlapping.size() - 1, -1, -1):
		var area: Area2D = _overlapping[i]
		if not CombatUtils.is_alive(area):
			_overlapping.remove_at(i)
			continue
		CombatUtils.apply_damage(area, _damage, origem)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(CombatUtils.GROUP_HURTBOX) and not _overlapping.has(area):
		_overlapping.append(area)


func _on_area_exited(area: Area2D) -> void:
	_overlapping.erase(area)


func _draw() -> void:
	var fade: float = clampf(_life_left / FADE_TIME, 0.0, 1.0)
	var t: float = _age
	var base: Color = flame_color
	base.a *= 0.35 * fade
	draw_circle(Vector2.ZERO, _radius, base)
	for i: int in FLAME_COUNT:
		var ang: float = TAU * float(i) / float(FLAME_COUNT) + float(i) * 0.7
		var dist: float = _radius * (0.25 + 0.45 * fmod(float(i) * 0.37, 1.0))
		var centro: Vector2 = Vector2.from_angle(ang) * dist
		var altura: float = _radius * (0.45 + 0.25 * sin(t * 9.0 + float(i) * 1.7))
		var largura: float = _radius * 0.2
		var cor: Color = flame_color
		cor.a *= fade
		draw_colored_polygon(PackedVector2Array([
			centro + Vector2(-largura, 0.0),
			centro + Vector2(0.0, -altura),
			centro + Vector2(largura, 0.0),
		]), cor)
		var miolo: Color = core_color
		miolo.a *= fade
		draw_colored_polygon(PackedVector2Array([
			centro + Vector2(-largura * 0.5, 0.0),
			centro + Vector2(0.0, -altura * 0.55),
			centro + Vector2(largura * 0.5, 0.0),
		]), miolo)

class_name AimIndicator
extends Node2D
## Mira do ataque (estilo Brawl Stars), sempre translúcida (~80% de transparência):
## - Tiro: retângulo que sai da boca do cano com a largura do tiro (cresce com a carga) e o
##   comprimento do alcance dele (corta na parede).
## - Espada: a área real do golpe (círculo da hitbox) à frente do player, ligada por uma linha.

const SHOT_FILL: Color = Color(0.4, 0.85, 1.0, 0.2)
const SHOT_EDGE: Color = Color(0.7, 0.95, 1.0, 0.35)
const SWORD_FILL: Color = Color(1.0, 0.65, 0.25, 0.2)
const SWORD_EDGE: Color = Color(1.0, 0.82, 0.55, 0.4)
const EDGE_WIDTH: float = 1.5
## Camada de física tratada como parede (igual à do projétil).
const WALL_MASK: int = 1

enum Mode { NONE, SHOT, SWORD }

var player: Player = null

var _mode: Mode = Mode.NONE
var _length: float = 0.0
var _width: float = 0.0
var _radius: float = 0.0


func _ready() -> void:
	top_level = true  # ignora a escala/rotação do player: tudo é medido em pixels de mundo
	z_index = 4
	visible = false


func _process(_delta: float) -> void:
	_mode = Mode.NONE
	if CombatUtils.is_alive(player):
		if player.is_aiming_shot():
			_update_shot()
		elif player.is_aiming_sword():
			_update_sword()
	if _mode == Mode.NONE:
		if visible:
			visible = false
		return
	visible = true
	queue_redraw()


func _update_shot() -> void:
	_mode = Mode.SHOT
	var origin: Vector2 = player.get_muzzle_position()
	var direction: Vector2 = player.get_shot_direction()
	global_position = origin
	global_rotation = direction.angle()
	_width = PlayerProjectile.width_for_charge(player.get_charge_ratio())
	_length = player.get_shot_range()
	var wall: Dictionary = CombatUtils.trace_wall(player, origin, origin + direction * _length, WALL_MASK)
	if not wall.is_empty():
		_length = origin.distance_to(wall["position"] as Vector2)


func _update_sword() -> void:
	var sword := player.weapon as Sword
	_mode = Mode.SWORD
	var direction: Vector2 = player.get_sword_direction()
	global_position = sword.global_position
	global_rotation = direction.angle()
	_length = sword.get_zone_distance()
	_radius = sword.get_zone_radius()


func _draw() -> void:
	match _mode:
		Mode.SHOT:
			var rect := Rect2(0.0, -_width * 0.5, _length, _width)
			draw_rect(rect, SHOT_FILL)
			draw_rect(rect, SHOT_EDGE, false, EDGE_WIDTH)
		Mode.SWORD:
			var center := Vector2(_length, 0.0)
			draw_line(Vector2.ZERO, center, SWORD_EDGE, EDGE_WIDTH)
			draw_circle(center, _radius, SWORD_FILL)
			draw_arc(center, _radius, 0.0, TAU, 48, SWORD_EDGE, EDGE_WIDTH, true)

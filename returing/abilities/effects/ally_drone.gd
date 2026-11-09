class_name AllyDrone
extends Node2D
## Drone do Drone Aliado: orbita o Player e atira no inimigo mais próximo ao alcance.
## É criado em tempo de execução pelo `DroneAllyEffect` como filho do Player (o `Turing.tscn` não muda).
## Os tiros vêm do `PoolHub` (`PlayerProjectile`, com `shooter` = Player, então nunca o acertam).

## Raio (px) do corpo do drone.
const BODY_RADIUS: float = 6.0

var projectile_scene: PackedScene = null
var damage: int = 18
var fire_interval: float = 0.8
var orbit_radius: float = 48.0
## Velocidade da órbita em radianos por segundo.
var orbit_speed: float = 2.2
var aim_range: float = 280.0
## Carga (0 a 1) usada só para o tamanho do tiro.
var shot_charge: float = 0.2
var color: Color = Color(1.0, 0.82, 0.4, 1.0)

var _player: Player = null
var _angle: float = 0.0
var _fire_left: float = 0.0
var _age: float = 0.0
var _aim: Vector2 = Vector2.RIGHT


func setup(player: Player) -> void:
	_player = player
	position = Vector2.RIGHT * orbit_radius
	_fire_left = fire_interval * 0.5  # o primeiro tiro não sai no mesmo instante


func _physics_process(delta: float) -> void:
	_age += delta
	_angle = fmod(_angle + orbit_speed * delta, TAU)
	position = Vector2.from_angle(_angle) * orbit_radius
	_fire_left -= delta
	var target: Node2D = _nearest_enemy()
	if target != null:
		_aim = (target.global_position - global_position).normalized()
		if _fire_left <= 0.0 and _shoot(_aim):
			_fire_left = fire_interval
	queue_redraw()


## Inimigo vivo mais próximo dentro do alcance (null se não houver).
func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist: float = aim_range
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var foe: Node2D = node as Node2D
		if foe == null or not CombatUtils.is_targetable(foe):
			continue
		var dist: float = foe.global_position.distance_to(global_position)
		if dist <= best_dist:
			best = foe
			best_dist = dist
	return best


## Dispara um tiro. False se o pool ainda não entregou (tenta de novo no frame seguinte).
func _shoot(direction: Vector2) -> bool:
	if projectile_scene == null or not CombatUtils.is_alive(_player):
		return false
	var shot: PlayerProjectile = PoolHub.acquire(projectile_scene, _player, PlayerProjectile) as PlayerProjectile
	if shot == null:
		return false
	shot.launch(global_position, direction, damage, shot_charge, _player, false)
	CombatUtils.connect_once(shot.damage_dealt, Callable(_player, &"_on_projectile_damage_dealt"))
	return true


func _draw() -> void:
	var rotor: float = _age * 18.0
	draw_circle(Vector2.ZERO, BODY_RADIUS, Color(0.06, 0.07, 0.1, 0.95))
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 16, color, 2.0)
	for side: float in [-1.0, 1.0]:  # duas hélices girando
		var hub: Vector2 = Vector2(side * (BODY_RADIUS + 3.0), -3.0)
		draw_line(hub + Vector2.from_angle(rotor) * 4.0, hub - Vector2.from_angle(rotor) * 4.0, color, 1.5)
	draw_line(Vector2.ZERO, _aim * (BODY_RADIUS + 3.0), color, 2.0)  # cano apontando para o alvo

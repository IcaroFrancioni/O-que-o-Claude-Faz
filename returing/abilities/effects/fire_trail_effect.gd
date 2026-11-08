class_name FireTrailEffect
extends AbilityEffect
## Rastro de Fogo: o próximo golpe de espada deixa chamas no chão, na direção do golpe.
## Espera o golpe por até `data.duration` segundos (8 s se a duração não estiver definida).

const DEFAULT_WAIT: float = 8.0

@export var zone_scene: PackedScene

@export_group("Rastro")
## Quantas chamas o rastro tem.
@export_range(1, 8) var segments: int = 3
## Distância (px) do Player até a primeira chama.
@export var first_offset: float = 24.0
## Distância (px) entre as chamas.
@export var spacing: float = 30.0
@export var zone_radius: float = 30.0
## Quanto tempo (s) cada chama fica no chão.
@export var zone_lifetime: float = 4.0
## Dano de cada tick e intervalo entre ticks (s).
@export var tick_damage: int = 6
@export var tick_interval: float = 0.5

var _time_left: float = DEFAULT_WAIT
var _zones: Array[FireZone] = []
var _consumed: bool = false


func _on_activate() -> void:
	if caster.weapon == null or zone_scene == null:
		_finish()
		return
	_time_left = data.duration if data != null and data.duration > 0.0 else DEFAULT_WAIT
	PoolHub.prewarm(zone_scene, caster, segments)  # cria as chamas antes do golpe
	CombatUtils.connect_once(caster.weapon.attack_started, _on_attack_started)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0 and not _consumed:
		_finish()


func _on_attack_started() -> void:
	if _consumed:
		return
	_consumed = true
	var dir: Vector2 = caster.aim_direction
	for i: int in segments:
		var zone: FireZone = PoolHub.acquire(zone_scene, caster, FireZone) as FireZone
		if zone == null:
			continue
		zone.ignite(caster.global_position + dir * (first_offset + spacing * float(i)),
				zone_radius, tick_damage, tick_interval, zone_lifetime, caster)
		_zones.append(zone)
	_finish()


## Cancelar (ex.: lendária apagando as outras) também apaga as chamas já acesas.
func cancel() -> void:
	for zone: FireZone in _zones:
		if is_instance_valid(zone):
			zone.recycle()
	_zones.clear()
	super.cancel()


func _on_cleanup() -> void:
	if is_instance_valid(caster) and caster.weapon != null:
		CombatUtils.disconnect_if_connected(caster.weapon.attack_started, _on_attack_started)

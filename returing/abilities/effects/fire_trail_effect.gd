class_name FireTrailEffect
extends AbilityEffect
## Rastro de Fogo: o próximo golpe de espada deixa chamas no chão, na direção do golpe.
## Espera o golpe por até `data.duration` segundos (8 s se a duração não estiver definida).
## Enquanto está armado, um halo de fogo brilha na espada (nó desenhado por este efeito: a espada não muda).
## O halo some ao consumir o golpe, ao expirar, ao morrer e na troca de cena (o efeito termina em todos).

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

@export_group("Halo na espada")
@export var halo_color: Color = Color(1.0, 0.5, 0.12, 1.0)
@export var halo_core_color: Color = Color(1.0, 0.85, 0.35, 1.0)
## Raio (px) do halo e distância (px) à frente da espada, na direção da mira.
@export var halo_radius: float = 13.0
@export var halo_distance: float = 16.0

var _time_left: float = DEFAULT_WAIT
var _zones: Array[FireZone] = []
var _consumed: bool = false
var _age: float = 0.0


func _on_activate() -> void:
	if caster.weapon == null or zone_scene == null:
		_finish()
		return
	_time_left = data.duration if data != null and data.duration > 0.0 else DEFAULT_WAIT
	PoolHub.prewarm(zone_scene, caster, segments)  # cria as chamas antes do golpe
	CombatUtils.connect_once(caster.weapon.attack_started, _on_attack_started)


func _physics_process(delta: float) -> void:
	_age += delta
	_time_left -= delta
	queue_redraw()
	if _time_left <= 0.0 and not _consumed:
		_finish()


## True enquanto o rastro está armado e o halo aparece na espada.
func is_halo_visible() -> bool:
	return not _cleaned and not _consumed


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


## Halo de fogo na ponta da espada: brilho pulsando e três chamas que balançam.
func _draw() -> void:
	if not is_halo_visible() or not is_instance_valid(caster) or caster.weapon == null:
		return
	var centro: Vector2 = caster.weapon.position + caster.aim_direction * halo_distance
	var pulso: float = 0.5 + 0.5 * sin(_age * 10.0)
	var brilho: Color = halo_color
	brilho.a = 0.2 + 0.15 * pulso
	draw_circle(centro, halo_radius, brilho)
	var anel: Color = halo_color
	anel.a = 0.55 + 0.35 * pulso
	draw_arc(centro, halo_radius, 0.0, TAU, 24, anel, 1.5)
	for i: int in 3:
		var base: Vector2 = centro + Vector2((float(i) - 1.0) * 5.0, 4.0)
		var altura: float = halo_radius * (0.8 + 0.35 * sin(_age * 12.0 + float(i) * 2.1))
		var largura: float = 3.0
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-largura, 0.0), base + Vector2(0.0, -altura), base + Vector2(largura, 0.0),
		]), halo_color)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-largura * 0.5, 0.0), base + Vector2(0.0, -altura * 0.55), base + Vector2(largura * 0.5, 0.0),
		]), halo_core_color)

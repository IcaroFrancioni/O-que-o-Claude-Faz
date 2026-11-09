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

## Chama pixelada do halo (gerada por `tests/gerar_sprites.gd`): tira de quadros lado a lado.
const HALO_PATH: String = "res://abilities/sprites/fire_halo.png"
const HALO_W: int = 8
const HALO_H: int = 12
const HALO_FRAMES: int = 4
const HALO_FPS: float = 12.0
const EMBER_COLORS: Array[Color] = [Color("#ff6a00"), Color("#d81414"), Color("#ffc414")]

@export_group("Halo na espada")
## Cada pixel do sprite vira NxN pixels na tela.
@export_range(1, 6) var halo_pixel_scale: int = 3
## Distância (px) à frente da espada, na direção da mira.
@export var halo_distance: float = 16.0

var _time_left: float = DEFAULT_WAIT
var _zones: Array[FireZone] = []
var _consumed: bool = false
var _age: float = 0.0
var _halo: Texture2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_halo = load(HALO_PATH) as Texture2D


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


## Halo de fogo na ponta da espada: chama pixelada animada e brasas subindo (tudo em pixels inteiros).
func _draw() -> void:
	if _halo == null or not is_halo_visible() or not is_instance_valid(caster) or caster.weapon == null:
		return
	var centro: Vector2 = (caster.weapon.position + caster.aim_direction * halo_distance).round()
	var largura: float = float(HALO_W * halo_pixel_scale)
	var altura: float = float(HALO_H * halo_pixel_scale)
	var quadro: int = int(_age * HALO_FPS) % HALO_FRAMES
	draw_texture_rect_region(_halo, Rect2(centro.x - largura * 0.5, centro.y - altura * 0.5, largura, altura),
			Rect2(quadro * HALO_W, 0, HALO_W, HALO_H))
	for i: int in 3:  # brasas: quadradinhos de 2 px que sobem e somem
		var subida: float = fmod(_age * 14.0 + float(i) * 7.0, 16.0)
		var brasa: Vector2 = (centro + Vector2(float(i - 1) * 6.0, -altura * 0.5 - subida)).round()
		var cor: Color = EMBER_COLORS[i % EMBER_COLORS.size()]
		cor.a = 1.0 - subida / 16.0
		draw_rect(Rect2(brasa, Vector2(2.0, 2.0)), cor)

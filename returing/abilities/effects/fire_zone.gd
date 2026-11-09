class_name FireZone
extends PooledArea
## Chão em chamas deixado pelo Rastro de Fogo: causa dano por tick em quem estiver dentro e some.

## Sprites pixelados (gerados por `tests/gerar_sprites.gd`): tira de chamas e chão chamuscado.
const FLAME_PATH: String = "res://abilities/sprites/fire_flame.png"
const GROUND_PATH: String = "res://abilities/sprites/fire_ground.png"
const FLAME_W: int = 16
const FLAME_H: int = 24
const FLAME_FRAMES: int = 6
## Quadros por segundo da chama.
const FLAME_FPS: float = 10.0
## Cada pixel do sprite vira 2x2 pixels na tela.
const PIXEL_SCALE: int = 2
## Quantos pontos de chama são desenhados dentro da área.
const FLAME_COUNT: int = 6
## Tempo final (s) em que a chama esmaece.
const FADE_TIME: float = 0.6
## Intervalo (s) entre redesenhos da chama.
const REDRAW_INTERVAL: float = 0.05

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
var _flame_sheet: Texture2D = null
var _ground: Texture2D = null

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flame_sheet = load(FLAME_PATH) as Texture2D
	_ground = load(GROUND_PATH) as Texture2D
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


## Acende a chama em `origin`.
func ignite(origin: Vector2, radius: float, damage: int, tick_interval: float, lifetime: float, source: Node) -> void:
	global_position = origin.round()  # posição inteira: o sprite pixelado não tremula
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
	if _flame_sheet == null or _ground == null:
		return
	var fade: float = clampf(_life_left / FADE_TIME, 0.0, 1.0)
	var tom: Color = Color(1.0, 1.0, 1.0, fade)
	draw_texture_rect(_ground, Rect2(-_radius, -_radius, _radius * 2.0, _radius * 2.0), false, tom)
	# Chamas de trás para frente (as mais baixas na tela por último), todas com posição inteira.
	var bases: Array[Vector2] = []
	for i: int in FLAME_COUNT:
		var ang: float = TAU * float(i) / float(FLAME_COUNT) + float(i) * 0.7
		var dist: float = _radius * (0.25 + 0.45 * fmod(float(i) * 0.37, 1.0))
		bases.append((Vector2.from_angle(ang) * dist).round())
	var ordem: Array[int] = []
	for i: int in FLAME_COUNT:
		ordem.append(i)
	ordem.sort_custom(func(a: int, b: int) -> bool: return bases[a].y < bases[b].y)
	var largura: float = float(FLAME_W * PIXEL_SCALE)
	var altura: float = float(FLAME_H * PIXEL_SCALE)
	for i: int in ordem:
		var quadro: int = (int(_age * FLAME_FPS) + i) % FLAME_FRAMES
		# a base da chama fica no ponto sorteado; ela encolhe um pouco no fim da vida
		var h: float = altura * lerpf(0.6, 1.0, fade)
		draw_texture_rect_region(_flame_sheet, Rect2(bases[i].x - largura * 0.5, bases[i].y - h, largura, h),
				Rect2(quadro * FLAME_W, 0, FLAME_W, FLAME_H), tom)

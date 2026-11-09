class_name BinaryMine
extends PooledArea
## Mina Binária (reaproveitada pelo PoolHub): fica no chão, arma depois de um instante e explode
## quando o primeiro inimigo chega perto, causando dano em todos os inimigos do raio da explosão.
## Some sozinha ao fim do tempo de vida, se quem a plantou morreu ou perdeu a habilidade.
## Não precisa de forma de colisão: a proximidade é medida pela distância até o grupo `enemy`.

const GROUP_MINES: StringName = &"binary_mine"
## Duração (s) da animação da explosão.
const BOOM_TIME: float = 0.3
const BODY_RADIUS: float = 9.0
const PULSE_SPEED: float = 7.0
const LABEL_SIZE: int = 12

@export var idle_color: Color = Color(0.55, 0.9, 1.0, 1.0)
@export var armed_color: Color = Color(1.0, 0.45, 0.25, 1.0)

var _damage: int = 0
var _blast_radius: float = 80.0
var _trigger_radius: float = 36.0
var _life_left: float = 0.0
var _arm_left: float = 0.0
var _boom_left: float = 0.0
var _age: float = 0.0
var _exploded: bool = false
var _source: Node = null
var _owner_ability: StringName = &""


## Planta a mina em `origin`. `owner_ability` é o id da habilidade (a mina some se o Player a perder).
func plant(origin: Vector2, damage: int, blast_radius: float, trigger_radius: float, lifetime: float,
		arm_time: float, source: Node, owner_ability: StringName) -> void:
	global_position = origin
	_damage = damage
	_blast_radius = blast_radius
	_trigger_radius = trigger_radius
	_life_left = maxf(lifetime, 0.1)
	_arm_left = maxf(arm_time, 0.0)
	_boom_left = 0.0
	_age = 0.0
	_exploded = false
	_source = source
	_owner_ability = owner_ability
	queue_redraw()


## Tempo (s) desde que foi plantada (a mais antiga é descartada quando passa do limite de minas).
func get_age() -> float:
	return _age


func is_armed() -> bool:
	return not _exploded and _arm_left <= 0.0


func is_exploded() -> bool:
	return _exploded


func _on_pool_activate() -> void:
	add_to_group(GROUP_MINES)


## Volta ao pool com o estado limpo.
func _on_pool_deactivate() -> void:
	if is_in_group(GROUP_MINES):
		remove_from_group(GROUP_MINES)
	_damage = 0
	_life_left = 0.0
	_arm_left = 0.0
	_boom_left = 0.0
	_age = 0.0
	_exploded = false
	_source = null
	_owner_ability = &""
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	if _exploded:
		_boom_left -= delta
		queue_redraw()
		if _boom_left <= 0.0:
			recycle()
		return
	_life_left -= delta
	if _life_left <= 0.0 or not _owner_is_valid():
		recycle()
		return
	if _arm_left > 0.0:
		_arm_left -= delta
	elif _enemy_close():
		_explode()
	queue_redraw()


## Quem plantou continua vivo e ainda tem a habilidade (a lendária apaga as outras).
func _owner_is_valid() -> bool:
	if not CombatUtils.is_targetable(_source):
		return false
	var player: Player = _source as Player
	if player != null and player.abilities != null and _owner_ability != &"":
		return player.abilities.has_ability(_owner_ability)
	return true


func _enemy_close() -> bool:
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var foe: Node2D = node as Node2D
		if foe != null and CombatUtils.is_targetable(foe) \
				and foe.global_position.distance_to(global_position) <= _trigger_radius:
			return true
	return false


func _explode() -> void:
	_exploded = true
	_boom_left = BOOM_TIME
	var origem: Node = _source if CombatUtils.is_alive(_source) else self
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var foe: Node2D = node as Node2D
		if foe == null or not CombatUtils.is_targetable(foe):
			continue
		if foe.global_position.distance_to(global_position) <= _blast_radius:
			CombatUtils.apply_damage(foe, _damage, origem)
	queue_redraw()


func _draw() -> void:
	if _exploded:
		var t: float = clampf(1.0 - _boom_left / BOOM_TIME, 0.0, 1.0)
		var cor: Color = armed_color
		cor.a = 1.0 - t
		draw_arc(Vector2.ZERO, _blast_radius * t, 0.0, TAU, 48, cor, 3.0)
		var fill: Color = armed_color
		fill.a = (1.0 - t) * 0.2
		draw_circle(Vector2.ZERO, _blast_radius * t, fill)
		return
	var armed: bool = is_armed()
	var cor_corpo: Color = armed_color if armed else idle_color
	var pulso: float = 0.5 + 0.5 * sin(_age * PULSE_SPEED)
	draw_circle(Vector2.ZERO, BODY_RADIUS, Color(0.05, 0.06, 0.09, 0.9))
	var borda: Color = cor_corpo
	borda.a = (0.55 + 0.4 * pulso) if armed else 0.5
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 20, borda, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-7.0, 4.0), "01", HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, cor_corpo)

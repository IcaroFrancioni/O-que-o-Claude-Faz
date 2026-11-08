class_name PlayerProjectile
extends PooledArea
## Tiro carregado do player (reaproveitado pelo PoolHub).

## Avisa quem atirou que o tiro acertou.
signal damage_dealt(target: Node, amount: int)

## Raio do tiro com 0% de carga (igual ao CircleShape2D da cena): a largura base do ataque do player.
const BASE_RADIUS: float = 5.0
## Escala do tiro com 100% de carga, em relação ao tamanho mínimo.
const MAX_CHARGE_SCALE: float = 3.0

# --- Mira assistida (só celular) ---
## Alcance máximo (px) em que um inimigo pode atrair o tiro.
const ASSIST_RANGE: float = 520.0
## Meio-ângulo do cone à frente do tiro onde um inimigo conta como "quase na mira".
const ASSIST_CONE_DEG: float = 30.0
## Quanto o tiro pode curvar por segundo (leve: o jogador ainda precisa mirar).
const ASSIST_TURN_DEG_PER_SEC: float = 85.0

@export var speed: float = 300.0
@export var lifetime: float = 2.0
## Camadas que contam como parede.
@export_flags_2d_physics var wall_mask: int = 1

## Direção fixa, decidida no disparo.
var direction: Vector2 = Vector2.RIGHT
var damage: int = 0
var shooter: Node = null

var _life_left: float = 0.0
var _consumido: bool = false
## Inimigo que está atraindo o tiro (mira assistida); null = tiro reto.
var _assist_target: Node2D = null


func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Dispara o tiro de `origin` na direção `aim`; a carga (0.0 a 1.0) define o tamanho.
## `assist` liga a mira assistida: o tiro curva um pouco para o inimigo mais próximo da linha de tiro.
func launch(origin: Vector2, aim: Vector2, new_damage: int, charge_ratio: float, from_shooter: Node,
		assist: bool = false) -> void:
	global_position = origin
	direction = aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	global_rotation = direction.angle()
	damage = new_damage
	shooter = from_shooter
	apply_charge(charge_ratio)
	_life_left = lifetime
	_consumido = false
	_assist_target = _pick_assist_target() if assist else null
	_block_if_spawned_behind_wall(origin)


## Se há parede entre quem atirou e a boca da arma (ex.: parede de 1 tile encostada no player), o tiro
## morre na parede em vez de nascer do outro lado dela.
func _block_if_spawned_behind_wall(muzzle: Vector2) -> void:
	var shooter_body := shooter as Node2D
	if shooter_body == null:
		return
	var spawn: Dictionary = CombatUtils.trace_spawn(self, shooter_body.global_position, muzzle, wall_mask)
	if spawn["blocked"] as bool:
		global_position = spawn["position"] as Vector2
		_consumir()


## Escala o tiro pela carga: 0.0 = tamanho mínimo, 1.0 = MAX_CHARGE_SCALE vezes o mínimo
## (e vezes a escala dos sprites da plataforma).
func apply_charge(ratio: float) -> void:
	scale = Vector2.ONE * charge_scale(ratio) * Platform.sprite_scale


## Fator de escala do tiro para uma carga (sem a escala de plataforma).
static func charge_scale(ratio: float) -> float:
	return lerpf(1.0, MAX_CHARGE_SCALE, clampf(ratio, 0.0, 1.0))


## Largura do tiro (px, no mundo) para uma carga: o diâmetro da hitbox. Usada pela barra de mira.
static func width_for_charge(ratio: float) -> float:
	return BASE_RADIUS * 2.0 * charge_scale(ratio) * Platform.sprite_scale


## Inimigo vivo mais alinhado com a direção do tiro, dentro do cone e sem parede no caminho.
func _pick_assist_target() -> Node2D:
	var best: Node2D = null
	var best_angle: float = deg_to_rad(ASSIST_CONE_DEG)
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var enemy := node as Node2D
		if enemy == null or not CombatUtils.is_targetable(enemy) or not enemy.is_inside_tree():
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() > ASSIST_RANGE or offset.length() < 1.0:
			continue
		var angle: float = absf(direction.angle_to(offset))
		if angle >= best_angle:
			continue
		if not CombatUtils.trace_wall(self, global_position, enemy.global_position, wall_mask).is_empty():
			continue
		best = enemy
		best_angle = angle
	return best


## Curva a direção um pouco em direção ao alvo da mira assistida.
func _steer_towards_assist_target(delta: float) -> void:
	if not CombatUtils.is_targetable(_assist_target):
		_assist_target = null
		return
	var offset: Vector2 = _assist_target.global_position - global_position
	# Passou do inimigo (ou está em cima dele): deixa de puxar para não fazer "rodinha".
	if offset.length() < 12.0 or direction.dot(offset) <= 0.0:
		_assist_target = null
		return
	var max_step: float = deg_to_rad(ASSIST_TURN_DEG_PER_SEC) * delta
	direction = direction.rotated(clampf(direction.angle_to(offset), -max_step, max_step)).normalized()
	global_rotation = direction.angle()


## Anda em linha reta até bater ou acabar o tempo.
func _physics_process(delta: float) -> void:
	if _assist_target != null:
		_steer_towards_assist_target(delta)
	# Testa o trecho todo.
	if CombatUtils.move_until_wall(self, direction * speed * delta, wall_mask):
		_consumir()
		return
	_life_left -= delta
	if _life_left <= 0.0:
		_consumir()


## Bateu em um corpo.
func _on_body_entered(body: Node2D) -> void:
	if _consumido or body == shooter:
		return
	if CombatUtils.can_take_damage(body):
		_aplicar_dano(body, body)
	_consumir()


## Bateu em uma hurtbox.
func _on_area_entered(area: Area2D) -> void:
	if _consumido or not area.is_in_group(CombatUtils.GROUP_HURTBOX):
		return
	var raiz := CombatUtils.get_actor(area)
	if raiz == shooter:
		return
	_aplicar_dano(area, raiz)
	_consumir()


## Aplica o dano em nome de quem atirou.
func _aplicar_dano(alvo: Node, notificar: Node) -> void:
	var origem: Node = shooter if CombatUtils.is_alive(shooter) else self
	if CombatUtils.apply_damage(alvo, damage, origem):
		damage_dealt.emit(notificar, damage)


## Volta ao pool uma vez só.
func _consumir() -> void:
	if _consumido:
		return
	_consumido = true
	recycle()

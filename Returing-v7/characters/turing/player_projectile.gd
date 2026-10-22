class_name PlayerProjectile
extends Area2D
## Projétil do tiro carregado. Configurado antes de entrar na árvore.
## Avisa o atirador do dano causado pelo sinal `damage_dealt` (sem chamar métodos dele).

## Dano aplicado a um alvo. `target` é o ator atingido (não a hurtbox).
signal damage_dealt(target: Node, amount: int)

@export var speed: float = 300.0
@export var lifetime: float = 2.0

@export_group("Mira (mouse)")
## Se verdadeiro, o projétil curva em direção à posição ATUAL do cursor enquanto voa.
## O Player sobrescreve este valor ao disparar (veja projectile_follows_cursor).
@export var follow_cursor: bool = true
## Velocidade máxima de curva, em graus por segundo. 0 = vira instantaneamente para o cursor.
@export_range(0.0, 1440.0, 10.0, "or_greater") var turn_rate_deg: float = 0.0
## Ao chegar a esta distância (px) do cursor, o projétil para de seguir e voa reto.
## Evita que ele fique orbitando ou tremendo em volta do cursor.
@export var arrival_radius: float = 10.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 0
var shooter: Node = null

var _life_left: float = 0.0
var _consumido: bool = false
## True depois que o projétil alcançou o cursor (deixa de segui-lo).
var _reached_cursor: bool = false


## Normaliza a direção e conecta as colisões.
func _ready() -> void:
	direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	# `direction` é um vetor de MUNDO: posição e rotação também são tratadas em
	# mundo, senão o tiro saía torto sob um pai com transform próprio.
	global_rotation = direction.angle()
	_life_left = lifetime
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Segue o cursor (se habilitado), avança e encerra quando o tempo de vida acaba.
func _physics_process(delta: float) -> void:
	if follow_cursor and not _reached_cursor:
		_steer_to_cursor(delta)
	global_position += direction * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_consumir()


## Aponta `direction` para a posição atual do mouse (no mundo, já considerando a câmera).
## Com turn_rate_deg > 0 a curva é limitada; com 0 o projétil vira de uma vez.
func _steer_to_cursor(delta: float) -> void:
	var to_cursor: Vector2 = get_global_mouse_position() - global_position
	if to_cursor.length() <= arrival_radius:
		_reached_cursor = true  # chegou: daqui em diante voa reto
		return

	var target_angle: float = to_cursor.angle()
	var angle: float = direction.angle()
	if turn_rate_deg > 0.0:
		var max_step: float = deg_to_rad(turn_rate_deg) * delta
		angle += clampf(angle_difference(angle, target_angle), -max_step, max_step)
	else:
		angle = target_angle
	direction = Vector2.from_angle(angle)
	global_rotation = angle


## Bateu em corpo: dano se der e some.
func _on_body_entered(body: Node2D) -> void:
	if _consumido or body == shooter:
		return  # nunca colide com quem atirou
	if CombatUtils.can_take_damage(body):
		_aplicar_dano(body, body)
	_consumir()  # parede ou corpo atingido


## Bateu em hurtbox: dano e some.
func _on_area_entered(area: Area2D) -> void:
	# Atravessa áreas que não são Hurtbox
	if _consumido or not area.is_in_group(CombatUtils.GROUP_HURTBOX):
		return
	var raiz := CombatUtils.get_actor(area)
	if raiz == shooter:
		return
	_aplicar_dano(area, raiz)
	_consumir()


## Aplica o dano em nome do atirador e avisa por sinal quando o alvo aceita.
func _aplicar_dano(alvo: Node, notificar: Node) -> void:
	var origem: Node = shooter if CombatUtils.is_alive(shooter) else self
	if CombatUtils.apply_damage(alvo, damage, origem):
		damage_dealt.emit(notificar, damage)


## Some uma única vez.
func _consumir() -> void:
	if _consumido:
		return
	_consumido = true
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	queue_free()

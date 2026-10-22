class_name EnemyBase
extends CharacterBody2D
## Base de todos os inimigos (Drone, Tank, Robo).
## Responsável por: alvo, movimento (com desvio de paredes), animação segura, dano e morte.
## A IA fica nos estados (StateWarden + EnemyState). As cenas já vêm montadas com
## referências preenchidas e sinais de dano/morte conectados; _ready usa connect_once
## para que cenas montadas à mão também funcionem, sem conexões duplicadas.

signal damaged(amount: int)
signal died(enemy: EnemyBase)

const ANIM_DEATH: StringName = &"death"

@export_group("Identidade")
@export var enemy_kind: StringName = &"enemy"

@export_group("Movimento")
@export var move_speed: float = 100.0

@export_group("Navegação (desvio de paredes)")
## Liga o desvio de paredes por raycast em navigate_towards(). Desligado = linha reta.
@export var avoid_obstacles: bool = true
## Camadas de física tratadas como obstáculo (padrão: camada 1, "Mundo").
@export_flags_2d_physics var obstacle_mask: int = 1
@export_range(4, 32, 1) var avoid_ray_count: int = 16
## Alcance dos raios, medido a partir da borda do corpo.
@export_range(16.0, 200.0, 1.0) var avoid_probe_distance: float = 56.0
## Intervalo entre varreduras dos raios (0 = todo frame).
@export_range(0.0, 0.5, 0.01) var avoid_update_interval: float = 0.05
## Velocidade máxima de giro do rumo, em graus por segundo.
@export_range(90.0, 1440.0, 10.0) var avoid_turn_rate: float = 540.0
## Desenha os raios (verde = livre, vermelho = parede) e o rumo atual, para ajustar os valores.
@export var debug_steering: bool = false:
	set(value):
		debug_steering = value
		queue_redraw()

@export_group("Visual")
## True = os quadros da spritesheet olham para a direita.
@export var frames_face_right: bool = true
@export var hurt_flash_color: Color = Color(3.0, 3.0, 3.0, 1.0)
@export_range(0.0, 1.0, 0.01) var hurt_flash_time: float = 0.12
## Tempo máximo esperando a animação de morte antes de liberar o nó.
@export_range(0.1, 5.0, 0.1) var death_timeout: float = 1.5

@export_group("Referências (já ligadas na cena)")
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var body_collision: CollisionShape2D
@export var health: HealthComponent
@export var hurtbox: Hurtbox
@export var detection_area: Area2D
@export var state_machine: StateWarden

## Alvo atual (o Player). Trocar o alvo invalida o cache de validade abaixo.
var target: Node2D = null:
	set(value):
		target = value
		_target_frame = -1
var spawn_position: Vector2 = Vector2.ZERO

var _dead: bool = false
var _flash_tween: Tween = null
var _current_anim: StringName = &""
var _sprite_offset_x: float = 0.0
var _steering: ObstacleSteering = null
## Hitboxes da cena, coletadas uma única vez (desligadas de uma vez na morte).
var _hitboxes: Array[Hitbox] = []
## Cache de has_target() por frame de física: a validação é feita várias vezes por
## frame (estado + distância + direção) e cada uma custa has_method + call.
var _target_frame: int = -1
var _target_valid: bool = false


func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_ENEMY)


func _ready() -> void:
	spawn_position = global_position
	if sprite != null:
		_sprite_offset_x = sprite.offset.x
	_validate_references()
	_connect_signals()
	EnemyEvents.bind(self, enemy_kind, health)
	_on_enemy_ready()
	_collect_hitboxes()
	if state_machine != null:
		state_machine.start()


## Gancho para subclasses (configurar hitboxes, raios etc.) antes da IA iniciar.
func _on_enemy_ready() -> void:
	pass


func _validate_references() -> void:
	var missing: PackedStringArray = []
	if sprite == null: missing.append("sprite")
	if animation_player == null: missing.append("animation_player")
	if health == null: missing.append("health")
	if hurtbox == null: missing.append("hurtbox")
	if detection_area == null: missing.append("detection_area")
	if state_machine == null: missing.append("state_machine")
	if not missing.is_empty():
		push_warning("%s '%s': referências não atribuídas: %s" % [enemy_kind, name, ", ".join(missing)])


## Fallback das conexões que já estão gravadas na cena.
func _connect_signals() -> void:
	if health != null:
		CombatUtils.connect_once(health.damaged, _on_health_damaged)
		CombatUtils.connect_once(health.died, _on_health_died)
	if detection_area != null:
		CombatUtils.connect_once(detection_area.body_entered, _on_detection_body_entered)
		CombatUtils.connect_once(detection_area.body_exited, _on_detection_body_exited)
	CombatUtils.connect_once(EventBus.player_died, _on_player_died)


func _exit_tree() -> void:
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)


# --- Alvo -----------------------------------------------------------------------

## Resolvido uma vez por frame de física (ver _target_frame).
func has_target() -> bool:
	var frame: int = Engine.get_physics_frames()
	if frame != _target_frame:
		_target_frame = frame
		_target_valid = CombatUtils.is_targetable(target)
	return _target_valid


func distance_sq_to_target() -> float:
	return global_position.distance_squared_to(target.global_position) if has_target() else INF


func direction_to_target() -> Vector2:
	return global_position.direction_to(target.global_position) if has_target() else Vector2.ZERO


func drop_target() -> void:
	target = null


func _on_detection_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		target = body


## Por padrão o inimigo esquece o alvo ao perder a visão (Robo pode manter aggro permanente).
func _on_detection_body_exited(body: Node2D) -> void:
	if body == target:
		target = null


func _on_player_died() -> void:
	drop_target()


# --- Movimento ------------------------------------------------------------------

func move_towards(point: Vector2, speed: float) -> void:
	var to_point: Vector2 = point - global_position
	velocity = to_point.normalized() * speed if to_point.length_squared() > 1.0 else Vector2.ZERO
	face_direction(velocity)
	move_and_slide()


func stop_moving() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func brake(delta: float, deceleration: float = -1.0) -> void:
	var decel: float = deceleration if deceleration > 0.0 else move_speed * 4.0
	velocity = velocity.move_toward(Vector2.ZERO, decel * delta)
	move_and_slide()


func face_direction(direction: Vector2) -> void:
	if sprite == null or absf(direction.x) < 0.01:
		return
	var looking_left: bool = direction.x < 0.0
	_set_sprite_flip(looking_left if frames_face_right else not looking_left)


## Espelha o sprite mantendo o conteúdo centralizado (o offset X também é espelhado).
func _set_sprite_flip(flipped: bool) -> void:
	sprite.flip_h = flipped
	sprite.offset.x = -_sprite_offset_x if flipped else _sprite_offset_x


func face_target() -> void:
	if has_target():
		face_direction(target.global_position - global_position)


# --- Navegação (desvio de paredes) ---------------------------------------------------

## Como move_towards(), mas contorna paredes (ver ObstacleSteering). Chame uma vez por
## frame de física enquanto estiver indo até `point`.
func navigate_towards(point: Vector2, speed: float, delta: float) -> void:
	var to_point: Vector2 = point - global_position
	if not avoid_obstacles or to_point.length_squared() <= 1.0:
		move_towards(point, speed)
		return
	var heading: Vector2 = _get_steering().steer(
			get_world_2d().direct_space_state, _get_nav_origin(), to_point.normalized(), speed, delta)
	velocity = heading * speed
	face_direction(velocity)
	move_and_slide()
	if debug_steering:
		queue_redraw()


## Encurta o trajeto (da posição atual até `point`) no primeiro obstáculo, com folga do corpo.
## Serve para sortear destinos que o inimigo alcança em linha reta.
func trim_to_free_space(point: Vector2) -> Vector2:
	return _get_steering().trim_segment(get_world_2d().direct_space_state, _get_nav_origin(), point)


## True uma única vez depois que o desvio detectou que o inimigo travou (não sai do lugar).
func consume_navigation_stuck() -> bool:
	return _steering != null and _steering.consume_stuck()


## Zera o estado do desvio. Chame ao entrar em um estado que passa a usar navigate_towards().
func reset_navigation() -> void:
	if _steering != null:
		_steering.reset(_get_nav_origin())


## Origem dos raios: o centro da colisão do corpo (cai para a posição do nó se faltar).
func _get_nav_origin() -> Vector2:
	return body_collision.global_position if body_collision != null else global_position


## Cria o desvio sob demanda: inimigos que não navegam (Tank, Dummy) não pagam por ele.
func _get_steering() -> ObstacleSteering:
	if _steering == null:
		var exclude: Array[RID] = [get_rid()]
		_steering = ObstacleSteering.new()
		_steering.configure(obstacle_mask, avoid_ray_count, avoid_probe_distance,
				_estimate_body_radius(), avoid_update_interval, avoid_turn_rate, exclude)
	return _steering


## Raio aproximado do corpo, lido da forma de colisão (círculo, cápsula ou retângulo).
func _estimate_body_radius() -> float:
	const FALLBACK_RADIUS: float = 12.0
	if body_collision == null or body_collision.shape == null:
		return FALLBACK_RADIUS
	var shape: Shape2D = body_collision.shape
	var scale_factor: float = maxf(absf(body_collision.global_scale.x), absf(body_collision.global_scale.y))
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius * scale_factor
	if shape is CapsuleShape2D:
		return (shape as CapsuleShape2D).radius * scale_factor
	if shape is RectangleShape2D:
		var size: Vector2 = (shape as RectangleShape2D).size
		return maxf(size.x, size.y) * 0.5 * scale_factor
	return FALLBACK_RADIUS


func _draw() -> void:
	if debug_steering and _steering != null:
		_steering.draw_debug(self, _get_nav_origin())


# --- Animação -------------------------------------------------------------------

## Toca uma animação se existir. Não reinicia a mesma (evita "travar" no 1º quadro),
## a não ser que restart = true (ex.: golpes consecutivos).
func play_anim(anim_name: StringName, restart: bool = false, speed_scale: float = 1.0) -> void:
	if animation_player == null or (_dead and anim_name != ANIM_DEATH):
		return
	if not animation_player.has_animation(anim_name):
		return
	animation_player.speed_scale = speed_scale
	if anim_name == _current_anim and animation_player.is_playing() and not restart:
		return
	_current_anim = anim_name
	animation_player.play(anim_name)
	if restart:
		animation_player.seek(0.0, true)


# --- Dano e morte ---------------------------------------------------------------

func is_dead() -> bool:
	return _dead


## API de dano no corpo (a Hurtbox entrega aqui). false = recusado.
func take_damage(amount: int, source: Variant = null) -> bool:
	if _dead or health == null:
		return false
	return health.take_damage(amount, source) > 0


func _on_health_damaged(amount: int) -> void:
	damaged.emit(amount)
	_flash()


func _on_health_died() -> void:
	die()


## Morte: trava a IA, desliga colisões/hitboxes, anima e libera o nó.
func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	if state_machine != null:
		state_machine.die()  # para a IA (exit() do estado atual fecha hitboxes)
	set_physics_process(false)
	velocity = Vector2.ZERO
	if hurtbox != null:
		hurtbox.set_active(false)
	if detection_area != null:
		detection_area.set_deferred(&"monitoring", false)
	if body_collision != null:
		body_collision.set_deferred(&"disabled", true)
	for hitbox: Hitbox in _hitboxes:
		if CombatUtils.is_valid(hitbox):
			hitbox.set_active(false)
	_on_death()
	_play_death_and_free()


## Coleta as Hitboxes da cena uma única vez: percorrer a subárvore na morte
## (find_children) custa uma varredura e uma alocação justamente no pior momento.
func _collect_hitboxes() -> void:
	_hitboxes.clear()
	for node: Node in find_children("*", "Hitbox", true, false):
		_hitboxes.append(node as Hitbox)


## Gancho de morte (ex.: Robo deixa armadilha).
func _on_death() -> void:
	pass


## Corrotina: espera a animação "death" e libera o nó.
## Um timer de segurança garante a liberação mesmo se a animação for interrompida.
func _play_death_and_free() -> void:
	_kill_flash()
	if animation_player != null and animation_player.has_animation(ANIM_DEATH):
		play_anim(ANIM_DEATH, true)
		get_tree().create_timer(death_timeout, false).timeout.connect(queue_free)
		await animation_player.animation_finished
	queue_free()


func _flash() -> void:
	if sprite == null or _dead:
		return
	_kill_flash()
	sprite.self_modulate = hurt_flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, ^"self_modulate", Color.WHITE, hurt_flash_time)


func _kill_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if sprite != null:
		sprite.self_modulate = Color.WHITE

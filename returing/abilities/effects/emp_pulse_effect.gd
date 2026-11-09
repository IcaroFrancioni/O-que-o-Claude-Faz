class_name EmpPulseEffect
extends AbilityEffect
## Pulso EMP: onda circular ao redor do Player com dano leve, empurrão e atordoamento.
## Os inimigos não têm atordoamento próprio: aqui ele é feito por fora, sem editar nenhum inimigo.
## O inimigo volta ao estado de repouso (cancelando o ataque em curso), a máquina de estados fica
## travada durante o atordoamento e, no fim, ele volta a perseguir se ainda enxerga o Player.

## Raio padrão (px) do pulso. A prévia do EMP (`EmpRangePreview`) lê o mesmo valor: fonte única.
const DEFAULT_RADIUS: float = 140.0

@export_group("Pulso")
@export var radius: float = DEFAULT_RADIUS
@export var damage: int = 15
## Distância (px) do empurrão e o tempo (s) que ele leva.
@export var push_distance: float = 90.0
@export_range(0.05, 1.0, 0.01) var push_time: float = 0.18
## Duração (s) da animação do anel.
@export_range(0.1, 2.0, 0.05) var ring_time: float = 0.45
@export_flags_2d_physics var wall_mask: int = 1
@export var ring_color: Color = Color(0.45, 0.85, 1.0, 1.0)

@export_group("Atordoamento")
## Tempo (s) que os inimigos atingidos ficam parados (0 desliga).
@export_range(0.0, 10.0, 0.1) var stun_time: float = 1.5
## Inimigos que não podem ser atordoados (chefões têm fases próprias).
@export var stun_exclude_kinds: Array[StringName] = [&"guide"]
@export var stun_tint: Color = Color(0.6, 0.85, 1.4, 1.0)

## Cada item: { "enemy": Node2D, "dir": Vector2, "left": float }.
var _pushes: Array[Dictionary] = []
## Cada item: { "enemy": EnemyBase, "left": float }.
var _stuns: Array[Dictionary] = []
var _age: float = 0.0


func _on_activate() -> void:
	top_level = true  # o anel fica parado no mundo, sem herdar a escala do Player
	global_position = caster.global_position
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var enemy: Node2D = node as Node2D
		if enemy == null or not CombatUtils.is_targetable(enemy):
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() > radius:
			continue
		CombatUtils.apply_damage(enemy, damage, caster)
		if CombatUtils.is_dead_actor(enemy):
			continue
		var dir: Vector2 = offset.normalized() if offset.length() > 1.0 else Vector2.RIGHT
		_pushes.append({"enemy": enemy, "dir": dir, "left": push_distance})
		_stun(enemy)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	_update_pushes(delta)
	_update_stuns(delta)
	queue_redraw()
	if _age >= ring_time and _pushes.is_empty() and _stuns.is_empty():
		_finish()


func _update_pushes(delta: float) -> void:
	var step_max: float = push_distance / push_time * delta
	for i: int in range(_pushes.size() - 1, -1, -1):
		var push: Dictionary = _pushes[i]
		var left: float = float(push["left"])
		if not is_instance_valid(push["enemy"]) or left <= 0.0:
			_pushes.remove_at(i)
			continue
		var enemy: Node2D = push["enemy"] as Node2D
		if not CombatUtils.is_alive(enemy):
			_pushes.remove_at(i)
			continue
		var step: float = minf(step_max, left)
		CombatUtils.move_until_wall(enemy, (push["dir"] as Vector2) * step, wall_mask)
		push["left"] = left - step


# --- Atordoamento ---

func _stun(enemy: Node2D) -> void:
	var foe: EnemyBase = enemy as EnemyBase
	if stun_time <= 0.0 or foe == null or foe.state_machine == null or stun_exclude_kinds.has(foe.enemy_kind):
		return
	for entry: Dictionary in _stuns:
		if entry["enemy"] == foe:
			entry["left"] = stun_time  # já atordoado: renova o tempo
			return
	foe.state_machine.request(StateWarden.State.IDLE)  # sai do ataque (o exit() fecha as hitboxes)
	foe.state_machine.locked = true
	foe.velocity = Vector2.ZERO
	if foe.sprite != null:
		foe.sprite.modulate = stun_tint
	CombatUtils.connect_once(foe.died, _on_stunned_died)
	_stuns.append({"enemy": foe, "left": stun_time})


func _update_stuns(delta: float) -> void:
	for i: int in range(_stuns.size() - 1, -1, -1):
		var entry: Dictionary = _stuns[i]
		entry["left"] = float(entry["left"]) - delta
		if not is_instance_valid(entry["enemy"]):
			_stuns.remove_at(i)
			continue
		var foe: EnemyBase = entry["enemy"] as EnemyBase
		if not CombatUtils.is_alive(foe):
			_stuns.remove_at(i)
		elif float(entry["left"]) <= 0.0:
			_release(foe)
			_stuns.remove_at(i)


## Morreu atordoado: destrava a máquina antes de ela receber `die()` (que `EnemyBase` chama logo depois).
func _on_stunned_died(enemy: EnemyBase) -> void:
	if enemy.state_machine != null:
		enemy.state_machine.locked = false
	if enemy.sprite != null:
		enemy.sprite.modulate = Color.WHITE
	for i: int in range(_stuns.size() - 1, -1, -1):
		if _stuns[i]["enemy"] == enemy:
			_stuns.remove_at(i)


## Devolve o controle ao inimigo.
func _release(foe: EnemyBase) -> void:
	CombatUtils.disconnect_if_connected(foe.died, _on_stunned_died)
	if foe.sprite != null:
		foe.sprite.modulate = Color.WHITE
	var warden: StateWarden = foe.state_machine
	if warden == null:
		return
	warden.locked = false
	if not foe.is_dead() and foe.has_target():
		warden.request(StateWarden.State.CHASE)


## Cancelar (ou sair da árvore) também solta quem ainda está atordoado.
func _on_cleanup() -> void:
	for entry: Dictionary in _stuns:
		if not is_instance_valid(entry["enemy"]):
			continue
		var foe: EnemyBase = entry["enemy"] as EnemyBase
		if CombatUtils.is_alive(foe):
			_release(foe)
	_stuns.clear()


func _draw() -> void:
	var t: float = clampf(_age / ring_time, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var fade: float = 1.0 - t
	var cor: Color = ring_color
	cor.a = fade
	draw_arc(Vector2.ZERO, radius * eased, 0.0, TAU, 64, cor, 3.0)
	var interno: Color = ring_color
	interno.a = fade * 0.12
	draw_circle(Vector2.ZERO, radius * eased, interno)

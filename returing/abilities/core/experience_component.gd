class_name ExperienceComponent
extends Node
## XP e níveis (filho do Player). Não conhece a UI: ela escuta `xp_changed` e `level_up`.

signal xp_changed(xp: int, xp_proximo: int, nivel: int)
signal level_up(novo_nivel: int)

@export_group("XP")
## XP acumulado necessário para cada nível (o último valor é o nível máximo).
@export var xp_por_nivel: Array[int] = [100, 250, 400]
## Cada inimigo morto dá um inteiro aleatório entre estes dois valores.
@export var xp_min: int = 20
@export var xp_max: int = 30

var _player: Player = null


func _ready() -> void:
	_player = get_parent() as Player
	CombatUtils.connect_once(EventBus.enemy_died, _on_enemy_died)
	_setup.call_deferred()


func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.enemy_died, _on_enemy_died)


func _setup() -> void:
	if not is_inside_tree():
		return
	var scene_root: Node = null
	if _player != null:
		scene_root = _player.owner
	if scene_root == null:
		scene_root = get_tree().current_scene
	RunState.begin_scene(scene_root.scene_file_path if scene_root != null else "")
	_emit_xp()


## Reemite o estado atual (para a UI que acabou de conectar).
func refresh() -> void:
	_emit_xp()


func get_max_level() -> int:
	return xp_por_nivel.size()


func is_max_level() -> bool:
	return RunState.level >= get_max_level()


## XP acumulado em que o nível atual começou.
func get_level_floor() -> int:
	return 0 if RunState.level <= 0 else xp_por_nivel[mini(RunState.level, get_max_level()) - 1]


## XP acumulado necessário para o próximo nível (o do nível máximo, se já chegou lá).
func get_next_threshold() -> int:
	if xp_por_nivel.is_empty():
		return 0
	return xp_por_nivel[mini(RunState.level, get_max_level() - 1)]


## Níveis alcançados cujo menu de escolha ainda não foi resolvido (em ordem).
func get_pending_levels() -> Array[int]:
	var result: Array[int] = []
	for n: int in range(RunState.resolved_level + 1, RunState.level + 1):
		result.append(n)
	return result


## Soma XP e emite um `level_up` por nível cruzado (no nível máximo, ignora).
func add_xp(amount: int) -> void:
	if amount <= 0 or xp_por_nivel.is_empty() or is_max_level():
		return
	var teto: int = xp_por_nivel[get_max_level() - 1]
	RunState.xp = mini(RunState.xp + amount, teto)
	while RunState.level < get_max_level() and RunState.xp >= xp_por_nivel[RunState.level]:
		RunState.level += 1
		level_up.emit(RunState.level)
	_emit_xp()


func _on_enemy_died(_enemy: Node2D, _kind: StringName, _world_position: Vector2) -> void:
	if _player != null and _player.esta_morto():
		return
	add_xp(randi_range(mini(xp_min, xp_max), maxi(xp_min, xp_max)))


func _emit_xp() -> void:
	xp_changed.emit(RunState.xp, get_next_threshold(), RunState.level)
